#include <QUuid>
#include "CommunityClient.h"

#include <QCryptographicHash>
#include <QDate>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHttpMultiPart>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMimeDatabase>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRandomGenerator>
#include <QSaveFile>
#include <QSet>
#include <QUrlQuery>
#include <QWebSocket>
#include <algorithm>

#ifdef Q_OS_WIN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <dpapi.h>
#endif

namespace {
QByteArray compact(const QJsonValue& value)
{
    return value.isArray() ? QJsonDocument(value.toArray()).toJson(QJsonDocument::Compact)
                           : QJsonDocument(value.toObject()).toJson(QJsonDocument::Compact);
}

QByteArray randomSecret()
{
    QByteArray bytes(32, Qt::Uninitialized);
    for (int i = 0; i < bytes.size(); ++i)
        bytes[i] = char(QRandomGenerator::system()->generate() & 0xff);
    return bytes.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
}

void addField(QHttpMultiPart* multipart, const QString& name, const QString& value)
{
    QHttpPart part;
    part.setHeader(QNetworkRequest::ContentDispositionHeader, QStringLiteral("form-data; name=\"%1\"").arg(name));
    part.setBody(value.toUtf8());
    multipart->append(part);
}

void addBytes(QHttpMultiPart* multipart, const QString& name, const QByteArray& bytes, const QString& filename)
{
    QHttpPart part;
    part.setHeader(QNetworkRequest::ContentDispositionHeader,
                   QStringLiteral("form-data; name=\"%1\"; filename=\"%2\"").arg(name, filename));
    part.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/octet-stream"));
    part.setBody(bytes);
    multipart->append(part);
}

QHttpMultiPart* fileMultipart(const QString& path, const QVariantMap& fields)
{
    auto multipart = new QHttpMultiPart(QHttpMultiPart::FormDataType);
    for (auto it = fields.cbegin(); it != fields.cend(); ++it)
        addField(multipart, it.key(), it.value().toString());
    auto file = new QFile(path, multipart);
    if (!file->open(QIODevice::ReadOnly)) {
        delete multipart;
        return nullptr;
    }
    QHttpPart part;
    QString filename = QFileInfo(path).fileName();
    filename.replace('"', '_').replace('\r', '_').replace('\n', '_');
    part.setHeader(QNetworkRequest::ContentDispositionHeader,
                   QStringLiteral("form-data; name=\"file\"; filename=\"%1\"").arg(filename));
    part.setHeader(QNetworkRequest::ContentTypeHeader, QMimeDatabase().mimeTypeForFile(path).name());
    part.setBodyDevice(file);
    multipart->append(part);
    return multipart;
}

QString responseError(const QJsonValue& value, int status, const QString& networkError)
{
    const auto detail = value.toObject().value(QStringLiteral("detail"));
    if (detail.isString()) return detail.toString();
    if (detail.isArray()) return QStringLiteral("请检查输入内容的格式和长度");
    if (status == 401) return QStringLiteral("登录已失效，请重新登录");
    if (status == 403) return QStringLiteral("当前账号无权执行此操作");
    if (status == 404) return QStringLiteral("服务接口或资源不存在");
    return status > 0 ? QStringLiteral("请求失败（%1）").arg(status)
                      : QStringLiteral("连接失败：%1").arg(networkError);
}

QVariantList logRows(const QJsonValue& value)
{
    if (value.isArray()) return value.toArray().toVariantList();
    QVariantList rows;
    for (const auto& line : value.toString().split('\n', Qt::SkipEmptyParts)) rows.append(line);
    return rows;
}
}

struct CommunityClient::Feed
{
    QString name, path;
    QWebSocket socket;
    QTimer retry, heartbeat;
    Success receive;
    int attempts = 0;
    bool active = true;
};

CommunityClient::CommunityClient(const QString& dataDirectory, QObject* parent)
    : QObject(parent), m_network(this), m_dataDirectory(QDir(dataDirectory).filePath(QStringLiteral("community"))),
      m_dailyDate(QDate::currentDate().toString(Qt::ISODate))
{
    m_pollTimer.setInterval(30000);
    connect(&m_pollTimer, &QTimer::timeout, this, [this] {
        if (!m_authenticated) return;
        request("GET", "/api/v1/community/status", {}, [this](const QJsonValue& value) {
            m_community = value.toObject().toVariantMap();
            emit changed();
        });
    });
    m_sessionTimer.setInterval(60000);
    connect(&m_sessionTimer, &QTimer::timeout, this, [this] {
        if (!m_refreshToken.isEmpty() && tokenExpiring()) refreshAccess([](bool) {});
    });
    m_sessionTimer.start();
}

CommunityClient::~CommunityClient() { stopFeeds(); }

QString CommunityClient::segment(const QString& value) { return QString::fromLatin1(QUrl::toPercentEncoding(value)); }

void CommunityClient::setFailure(const QString& operation, const QString& message)
{
    m_error = message;
    emit changed();
    emit operationFailed(operation, message);
}

void CommunityClient::clearError() { m_error.clear(); emit changed(); }

bool CommunityClient::tokenExpiring() const
{
    const auto parts = m_accessToken.split('.');
    if (parts.size() != 3) return true;
    const auto payload = QJsonDocument::fromJson(QByteArray::fromBase64(parts[1], QByteArray::Base64UrlEncoding)).object();
    return payload.value("exp").toDouble() <= QDateTime::currentSecsSinceEpoch() + 60;
}

QNetworkReply* CommunityClient::request(const QByteArray& method, const QString& path, const QJsonValue& payload,
                                       Success success, Failure failure, bool auth, bool retried,
                                       const MultipartFactory& multipart)
{
    // All authenticated requests stay on the configured community origin, including redirects.
    if (!path.startsWith(QStringLiteral("/api/v1/")) || path.startsWith(QStringLiteral("//"))) {
        setFailure(QStringLiteral("request"), QStringLiteral("无效的接口地址"));
        return nullptr;
    }
    if (auth && !retried && !m_refreshToken.isEmpty() && tokenExpiring()) {
        refreshAccess([this, method, path, payload, success, failure, multipart](bool ok) {
            if (ok) request(method, path, payload, success, failure, true, true, multipart);
            else if (failure) failure(401, QStringLiteral("无法刷新登录，请检查网络或重新登录"));
        });
        return nullptr;
    }
    QNetworkRequest req(m_origin.resolved(QUrl(path)));
    req.setRawHeader("User-Agent", "DeeraftApp/Desktop");
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    req.setTransferTimeout(multipart ? 180000 : 20000);
    const QByteArray usedToken = m_accessToken;
    if (auth && !usedToken.isEmpty()) req.setRawHeader("Authorization", "Bearer " + usedToken);
    QNetworkReply* reply = nullptr;
    if (multipart) {
        auto body = multipart();
        if (!body) {
            const auto message = QStringLiteral("无法读取上传文件");
            if (failure) failure(0, message); else setFailure(path, message);
            return nullptr;
        }
        reply = m_network.sendCustomRequest(req, method, body);
        body->setParent(reply);
    } else {
        if (method != "GET") req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
        reply = m_network.sendCustomRequest(req, method, payload.isUndefined() || payload.isNull() ? QByteArray{} : compact(payload));
    }
    ++m_pending;
    emit changed();
    const int generation = m_generation;
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, method, path, payload, success, failure, auth, retried, multipart, usedToken, generation] {
        --m_pending;
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const auto bytes = reply->readAll();
        QJsonParseError parseError;
        const auto document = QJsonDocument::fromJson(bytes, &parseError);
        const QJsonValue value = document.isArray() ? QJsonValue(document.array()) : QJsonValue(document.object());
        const bool ok = status >= 200 && status < 300 && reply->error() == QNetworkReply::NoError;
        const auto message = responseError(value, status, reply->errorString());
        reply->deleteLater();
        emit changed();
        if (generation != m_generation) return;
        if (status == 401 && auth && !retried && !m_refreshToken.isEmpty()) {
            auto retry = [this, method, path, payload, success, failure, multipart](bool refreshed) {
                if (refreshed) request(method, path, payload, success, failure, true, true, multipart);
                else if (failure) failure(401, QStringLiteral("登录刷新失败"));
            };
            if (usedToken != m_accessToken) retry(true); else refreshAccess(retry);
            return;
        }
        if (ok && (bytes.isEmpty() || parseError.error == QJsonParseError::NoError)) {
            if (success) success(value);
        } else {
            if (status == 401 && auth) clearSession(false);
            if (failure) failure(status, message); else setFailure(path, message);
        }
    });
    return reply;
}

void CommunityClient::refreshAccess(std::function<void(bool)> continuation)
{
    m_refreshWaiters.push_back(std::move(continuation));
    if (m_refreshing) return;
    if (m_refreshToken.isEmpty()) {
        auto waiters = std::move(m_refreshWaiters);
        m_refreshWaiters.clear();
        for (auto& waiter : waiters) waiter(false);
        return;
    }
    m_refreshing = true;
    const auto credential = m_refreshToken;
    const int generation = m_generation;
    auto finish = [this, generation](bool ok) {
        if (generation != m_generation) return;
        m_refreshing = false;
        auto waiters = std::move(m_refreshWaiters);
        m_refreshWaiters.clear();
        for (auto& waiter : waiters) {
            if (generation != m_generation) break;
            waiter(ok);
        }
    };
    request("POST", "/api/v1/mobile/auth/refresh", QJsonObject{{"refresh_token", QString::fromUtf8(credential)}},
            [this, finish](const QJsonValue& value) {
        const auto token = value.toObject().value("access_token").toString().toUtf8();
        if (token.isEmpty()) { setFailure("session", QStringLiteral("登录刷新响应无效")); finish(false); return; }
        m_accessToken = token;
        const auto refresh = value.toObject().value("refresh_token").toString().toUtf8();
        if (!refresh.isEmpty()) m_refreshToken = refresh;
        persistSession();
        if (m_authenticated) startFeeds();
        finish(true);
    }, [this, finish](int status, const QString& message) {
        // A network interruption must not discard the persisted long-lived refresh credential.
        if (status == 401) {
            finish(false);
            clearSession(false);
        } else finish(false);
        setFailure("session", message);
    }, false);
}

void CommunityClient::persistSession()
{
    QDir().mkpath(m_dataDirectory);
    const auto plaintext = compact(QJsonObject{{"access_token", QString::fromUtf8(m_accessToken)},
                                               {"refresh_token", QString::fromUtf8(m_refreshToken)},
                                               {"profile", QJsonObject::fromVariantMap(m_profile)}});
#ifdef Q_OS_WIN
    DATA_BLOB input{DWORD(plaintext.size()), reinterpret_cast<BYTE*>(const_cast<char*>(plaintext.constData()))};
    DATA_BLOB output{};
    if (!CryptProtectData(&input, L"DeeraftApp community session", nullptr, nullptr, nullptr,
                          CRYPTPROTECT_UI_FORBIDDEN, &output)) {
        setFailure("session", QStringLiteral("无法安全保存登录，下次启动需要重新登录"));
        return;
    }
    const QByteArray ciphertext(reinterpret_cast<const char*>(output.pbData), output.cbData);
    LocalFree(output.pbData);
    QSaveFile file(QDir(m_dataDirectory).filePath(QStringLiteral("session.dat")));
    if (!file.open(QIODevice::WriteOnly) || file.write(ciphertext) != ciphertext.size() || !file.commit())
        setFailure("session", QStringLiteral("无法保存登录，请检查数据目录权限"));
#else
    Q_UNUSED(plaintext)
    // This module targets Windows. Never fall back to plaintext token storage on another platform.
#endif
}

void CommunityClient::restoreSession()
{
    if (!m_accessToken.isEmpty()) return;
    QFile file(QDir(m_dataDirectory).filePath(QStringLiteral("session.dat")));
    if (!file.open(QIODevice::ReadOnly)) return;
#ifdef Q_OS_WIN
    const auto ciphertext = file.readAll();
    DATA_BLOB input{DWORD(ciphertext.size()), reinterpret_cast<BYTE*>(const_cast<char*>(ciphertext.constData()))};
    DATA_BLOB output{};
    if (!CryptUnprotectData(&input, nullptr, nullptr, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &output)) {
        setFailure("session", QStringLiteral("无法读取此 Windows 用户的登录，请重新登录"));
        return;
    }
    const auto value = QJsonDocument::fromJson(QByteArray(reinterpret_cast<const char*>(output.pbData), output.cbData)).object();
    SecureZeroMemory(output.pbData, output.cbData);
    LocalFree(output.pbData);
    m_accessToken = value.value("access_token").toString().toUtf8();
    m_refreshToken = value.value("refresh_token").toString().toUtf8();
    m_profile = value.value("profile").toObject().toVariantMap();
    if (!m_accessToken.isEmpty() || !m_refreshToken.isEmpty()) loadProfile(true);
#endif
}

void CommunityClient::acceptSession(const QJsonValue& value)
{
    const auto data = value.toObject();
    const auto token = data.value("access_token").toString().toUtf8();
    if (token.isEmpty()) { setFailure("login", QStringLiteral("登录响应无效")); return; }
    m_accessToken = token;
    m_refreshToken = data.value("refresh_token").toString().toUtf8();
    persistSession();
    loadProfile(true);
}

void CommunityClient::loadProfile(bool live)
{
    request("GET", "/api/v1/auth/me", {}, [this, live](const QJsonValue& value) {
        m_profile = value.toObject().toVariantMap();
        m_authenticated = true;
        m_error.clear();
        persistSession();
        emit changed();
        if (live) { refresh(); startFeeds(); }
    });
}

void CommunityClient::login(const QString& username, const QString& password)
{
    if (username.trimmed().isEmpty() || password.isEmpty()) { setFailure("login", QStringLiteral("请输入用户名和密码")); return; }
    clearSession(false);
    request("POST", "/api/v1/mobile/auth/login", QJsonObject{{"username", username.trimmed()}, {"password", password}},
            [this](const QJsonValue& value) { acceptSession(value); }, {}, false);
}

void CommunityClient::registerAccount(const QString& username, const QString& password)
{
    if (username.trimmed().isEmpty() || password.isEmpty()) { setFailure("register", QStringLiteral("请输入用户名和密码")); return; }
    clearSession(false);
    request("POST", "/api/v1/auth/register", QJsonObject{{"username", username.trimmed()}, {"password", password}},
            [this, username, password](const QJsonValue&) { login(username, password); }, {}, false);
}

void CommunityClient::clearSession(bool notifyServer)
{
    const auto oldRefresh = m_refreshToken;
    ++m_generation;
    stopFeeds();
    cancelUpload();
    m_accessToken.clear(); m_refreshToken.clear();
    m_authenticated = false;
    m_refreshing = false;
    m_refreshWaiters.clear();
    m_profile.clear(); m_community.clear(); m_hostedStatus.clear(); m_rconConfig.clear();
    m_activity.clear(); m_servers.clear(); m_chat.clear(); m_playtime.clear(); m_daily.clear(); m_liveRooms.clear();
    m_users.clear(); m_logLines.clear(); m_backups.clear();
    m_logServer.clear(); m_error.clear(); m_commandResult.clear();
    m_oauthState.clear(); m_oauthVerifier.clear(); m_oauthStarted = 0;
    QFile::remove(QDir(m_dataDirectory).filePath(QStringLiteral("session.dat")));
    emit changed();
    if (notifyServer && !oldRefresh.isEmpty())
        request("POST", "/api/v1/mobile/auth/logout", QJsonObject{{"refresh_token", QString::fromUtf8(oldRefresh)}},
                [](const QJsonValue&) {}, [](int, const QString&) {}, false);
}

void CommunityClient::logout() { clearSession(true); }

void CommunityClient::refresh()
{
    if (!m_authenticated) return;
    m_error.clear();
    request("GET", "/api/v1/community/status", {}, [this](const QJsonValue& v) { m_community = v.toObject().toVariantMap(); emit changed(); });
    request("GET", "/api/v1/servers", {}, [this](const QJsonValue& v) { m_servers = v.toArray().toVariantList(); emit changed(); });
    request("GET", "/api/v1/servers/player/me/playtime", {}, [this](const QJsonValue& v) {
        m_playtime = v.toArray().toVariantList();
        std::stable_sort(m_playtime.begin(), m_playtime.end(), [](const QVariant& a, const QVariant& b) {
            return a.toMap().value("playtime_minutes").toDouble() > b.toMap().value("playtime_minutes").toDouble();
        });
        emit changed();
    });
    loadDaily(m_dailyDate);
    if (m_chat.isEmpty()) request("GET", "/api/v1/mobile/chat?num=300", {}, [this](const QJsonValue& v) {
        // The socket may have delivered its initial snapshot while HTTP was in flight.
        if (m_chat.isEmpty()) mergeChat(v.toObject().value("messages"), true);
    });
    loadLiveRooms();
}

void CommunityClient::loadDaily(const QString& date)
{
    if (!QDate::fromString(date, Qt::ISODate).isValid()) { setFailure("daily", QStringLiteral("日期格式应为 YYYY-MM-DD")); return; }
    m_dailyDate = date;
    emit changed();
    request("GET", "/api/v1/mobile/daily-playtime?date=" + date, {}, [this, date](const QJsonValue& v) {
        if (m_dailyDate != date) return;
        m_daily = v.toObject().value("players").toArray().toVariantList();
        emit changed();
    });
}

void CommunityClient::updateProfile(const QString& username, const QString& bio)
{
    if (bio.size() > 280) { setFailure("profile", QStringLiteral("简介最多 280 个字符")); return; }
    auto updateBio = [this, bio] {
        request("PUT", "/api/v1/auth/me/bio", QJsonObject{{"bio", bio}}, [this](const QJsonValue& v) {
            m_profile = v.toObject().toVariantMap(); persistSession(); emit changed();
            emit operationFinished("profile", v.toVariant());
        });
    };
    if (username.trimmed() == m_profile.value("username").toString()) { updateBio(); return; }
    request("PUT", "/api/v1/auth/me/username", QJsonObject{{"username", username.trimmed()}},
            [this, updateBio](const QJsonValue& v) {
        const auto data = v.toObject();
        m_accessToken = data.value("access_token").toString().toUtf8();
        m_profile = data.value("profile").toObject().toVariantMap();
        persistSession(); startFeeds(); emit changed(); updateBio();
    });
}

void CommunityClient::uploadImage(const QString& path, const QUrl& url, bool avatar)
{
    const auto filePath = url.isLocalFile() ? url.toLocalFile() : url.toString();
    const QFileInfo info(filePath);
    if (!info.isFile() || info.size() <= 0 || info.size() > 5 * 1024 * 1024) {
        setFailure("image", QStringLiteral("请选择不超过 5 MB 的图片")); return;
    }
    request("POST", path, {}, [this, avatar](const QJsonValue& v) {
        if (avatar) { m_profile = v.toObject().toVariantMap(); persistSession(); emit changed(); }
        else refresh();
        emit operationFinished(avatar ? "avatar" : "cover", v.toVariant());
    }, {}, true, false, [filePath] { return fileMultipart(filePath, {}); });
}

void CommunityClient::uploadAvatar(const QUrl& url) { uploadImage("/api/v1/auth/me/avatar", url, true); }
void CommunityClient::uploadCover(const QString& name, const QUrl& url)
{ uploadImage("/api/v1/servers/" + segment(name) + "/upload_image", url, false); }

void CommunityClient::serverAction(const QString& action, const QString& name, const QVariantMap& args)
{
    if (action == "backups") { loadBackups(name); return; }
    QByteArray method = "POST";
    QString path = "/api/v1/servers/" + segment(name);
    auto body = QJsonObject::fromVariantMap(args);
    if (action == "start") { path = "/api/v1/servers/start"; body.insert("name", name); }
    else if (action == "stop") path = "/api/v1/servers/kill";
    else if (action == "update") method = "PUT";
    else if (action == "backup" || action == "restore") path += "/" + action;
    else if (action == "delete") method = "DELETE";
    else { setFailure(action, QStringLiteral("未知操作")); return; }
    request(method, path, body, [this, action, name](const QJsonValue& value) {
        emit operationFinished(action, value.toVariant());
        refresh();
        if (action == "backup" || action == "restore") loadBackups(name);
    });
}

void CommunityClient::loadBackups(const QString& name)
{
    request("GET", "/api/v1/servers/" + segment(name) + "/backups", {}, [this](const QJsonValue& v) {
        m_backups = v.toObject().value("backups").toArray().toVariantList(); emit changed();
    });
}

void CommunityClient::loadUsers(const QString& search)
{
    request("GET", "/api/v1/auth/users?search=" + segment(search), {}, [this](const QJsonValue& v) {
        m_users = v.toArray().toVariantList(); emit changed();
    });
}

void CommunityClient::setUserRole(int id, const QString& role)
{
    if (id <= 0 || (role != "admin" && role != "user")) { setFailure("role", QStringLiteral("角色或用户无效")); return; }
    request("PATCH", "/api/v1/auth/users/" + QString::number(id) + "/role", QJsonObject{{"role", role}},
            [this](const QJsonValue& v) { emit operationFinished("role", v.toVariant()); loadUsers(); loadProfile(false); });
}

void CommunityClient::loadLiveRooms()
{
    request("GET", "/api/v1/servers/live/rooms", {}, [this](const QJsonValue& v) {
        m_liveRooms = v.toArray().toVariantList(); emit changed();
    });
}

void CommunityClient::saveLiveRooms(const QVariantList& rooms)
{
    request("PUT", "/api/v1/servers/live/rooms", QJsonArray::fromVariantList(rooms), [this](const QJsonValue& v) {
        emit operationFinished("liveRooms", v.toVariant()); loadLiveRooms();
    });
}

void CommunityClient::loadLiveStatus(const QString& id)
{
    request("GET", "/api/v1/servers/live/status?room_id=" + segment(id), {}, [this, id](const QJsonValue& v) {
        emit liveStatusReceived(id, v.toObject().toVariantMap());
    });
}

void CommunityClient::loadLogs(const QString& name, int lines)
{
    request("GET", "/api/v1/servers/" + segment(name) + "/logs?lines=" + QString::number(std::clamp(lines, 1, 1000)), {},
            [this, name](const QJsonValue& v) {
        if (!m_logServer.isEmpty() && name != m_logServer) return;
        m_logLines = logRows(v.toObject().value("logs"));
        emit changed();
    });
}

void CommunityClient::watchLogs(const QString& name)
{
    m_logServer = name;
    m_logLines.clear();
    if (m_authenticated) startFeeds();
    if (!name.isEmpty()) { loadLogs(name); loadRconConfig(name); }
    emit changed();
}

void CommunityClient::loadRconConfig(const QString& name)
{
    request("GET", "/api/v1/servers/" + segment(name) + "/rcon/config", {}, [this](const QJsonValue& v) {
        m_rconConfig = v.toObject().toVariantMap(); emit changed();
    });
}

void CommunityClient::sendCommand(const QString& name, const QString& command, bool mcdr)
{
    if (command.trimmed().isEmpty()) return;
    request("POST", "/api/v1/servers/" + segment(name) + (mcdr ? "/mcdr/console" : "/rcon/command"),
            QJsonObject{{mcdr ? "line" : "command", command}}, [this](const QJsonValue& v) {
        m_commandResult = v.toObject().value("response").toString(); emit changed();
        emit operationFinished("command", v.toVariant());
    });
}

QUrl CommunityClient::imageUrl(const QString& path) const
{
    if (path.isEmpty()) return {};
    const auto url = m_origin.resolved(QUrl(path));
    if (url.scheme() == "https" || (url.scheme() == "http" && url.host() == m_origin.host())) return url;
    return {};
}

void CommunityClient::startFeeds()
{
    stopFeeds();
    if (!m_authenticated) return;
    addFeed("activity", "/api/v1/mobile/activity/ws", [this](const QJsonValue& v){const auto obj=v.toObject();mergeActivity(obj.value("items"),obj.value("type").toString()=="initial_activity");});
    addFeed("chat", "/api/v1/mobile/chat/ws", [this](const QJsonValue& v) {
        const auto obj = v.toObject();
        mergeChat(obj.value("messages"), obj.value("type").toString() == "initial_chat_messages");
    });
    addFeed("status", "/api/v1/servers/status/ws", [this](const QJsonValue& v) {
        m_hostedStatus = v.toObject().toVariantMap(); emit changed();
    });
    if (!m_logServer.isEmpty() && m_profile.value("role").toString() == "admin")
        addFeed("logs", "/api/v1/servers/" + segment(m_logServer) + "/logs/ws", [this](const QJsonValue& v) {
            const auto obj = v.toObject();
            const auto rows = logRows(obj.value("logs"));
            if (obj.value("type").toString() == "initial_logs") m_logLines = rows;
            else m_logLines.append(rows);
            while (m_logLines.size() > 2000) m_logLines.removeFirst();
            emit changed();
        });
    m_pollTimer.start();
}

void CommunityClient::stopFeeds()
{
    m_pollTimer.stop();
    for (auto& feed : m_feeds) {
        feed->active = false;
        feed->retry.stop(); feed->heartbeat.stop();
        feed->socket.disconnect(this);
        feed->socket.abort();
    }
    m_feeds.clear();
    m_connectionStatus.clear();
}

void CommunityClient::addFeed(const QString& name, const QString& path, Success receive)
{
    auto holder = std::make_unique<Feed>();
    auto feed = holder.get();
    feed->name = name; feed->path = path; feed->receive = std::move(receive);
    feed->retry.setSingleShot(true);
    feed->heartbeat.setInterval(20000);
    connect(&feed->retry, &QTimer::timeout, this, [this, feed] { connectFeed(feed); });
    connect(&feed->heartbeat, &QTimer::timeout, this, [feed] { feed->socket.sendTextMessage(QStringLiteral("ping")); });
    connect(&feed->socket, &QWebSocket::connected, this, [this, feed] {
        feed->attempts = 0; feed->heartbeat.start();
        if (feed->name == "chat") { m_connectionStatus = QStringLiteral("已连接"); emit changed(); }
    });
    connect(&feed->socket, &QWebSocket::textMessageReceived, this, [feed](const QString& message) {
        if (!feed->active || message == "pong") return;
        const auto doc = QJsonDocument::fromJson(message.toUtf8());
        if (doc.isObject()) feed->receive(doc.object());
    });
    connect(&feed->socket, &QWebSocket::disconnected, this, [this, feed] {
        feed->heartbeat.stop();
        if (!feed->active || !m_authenticated) return;
        if (feed->socket.closeCode() == QWebSocketProtocol::CloseCodePolicyViolated) {
            if (feed->name == "logs" && !tokenExpiring()) {
                setFailure("logs", QStringLiteral("没有日志访问权限")); return;
            }
            // Defer refresh: rebuilding feeds must not delete a socket inside its own signal handler.
            QTimer::singleShot(0, this, [this] {
                refreshAccess([this](bool ok) { if (!ok) { m_connectionStatus = QStringLiteral("连接中断"); emit changed(); } });
            });
            return;
        }
        if (!feed->retry.isActive())
            feed->retry.start(std::min(30000, 1000 * (1 << std::min(feed->attempts++, 5))));
        if (feed->name == "chat") { m_connectionStatus = QStringLiteral("正在重连"); emit changed(); }
    });
    m_feeds.push_back(std::move(holder));
    connectFeed(feed);
}

void CommunityClient::connectFeed(Feed* feed)
{
    if (!feed->active || !m_authenticated) return;
    QUrl url = m_origin.resolved(QUrl(feed->path));
    url.setScheme(m_origin.scheme() == "https" ? "wss" : "ws");
    if(feed->name=="activity"){
        QNetworkRequest request(url);request.setRawHeader("Authorization","Bearer "+m_accessToken);feed->socket.open(request);
    }else{
        QUrlQuery query;query.addQueryItem(QStringLiteral("token"),QString::fromUtf8(m_accessToken));url.setQuery(query);feed->socket.open(url);
    }
}

void CommunityClient::mergeChat(const QJsonValue& value, bool snapshot)
{
    if (!value.isArray()) return;
    const auto incoming = value.toArray().toVariantList();
    if (snapshot) m_chat = incoming;
    else {
        // History contains repeated identical messages; use ids where available, otherwise suffix overlap.
        auto key = [](const QVariant& v) {
            const auto m = v.toMap();
            if (m.contains("id") && !m.value("id").isNull()) return QStringLiteral("id:") + m.value("id").toString();
            return m.value("time").toString() + QChar(0) + m.value("player").toString() + QChar(0)
                   + m.value("type").toString() + QChar(0) + m.value("message").toString();
        };
        int overlap = 0;
        for (int size = 1; size <= std::min(m_chat.size(), incoming.size()); ++size) {
            bool matches = true;
            for (int i = 0; i < size; ++i)
                if (key(m_chat[m_chat.size() - size + i]) != key(incoming[i])) { matches = false; break; }
            if (matches) overlap = size;
        }
        QSet<QString> knownIds;
        for (const auto& item : m_chat) if (item.toMap().contains("id")) knownIds.insert(key(item));
        for (int i = overlap; i < incoming.size(); ++i) {
            const auto id = key(incoming[i]);
            if (id.startsWith("id:") && knownIds.contains(id)) continue;
            m_chat.append(incoming[i]);
            if (id.startsWith("id:")) knownIds.insert(id);
        }
    }
    while (m_chat.size() > 300) m_chat.removeFirst();
    emit changed();
}

void CommunityClient::uploadServer(const QUrl& fileUrl, const QVariantMap& metadata, bool chunked)
{
    if (m_uploading) { setFailure("upload", QStringLiteral("已有上传任务")); return; }
    const auto path = fileUrl.isLocalFile() ? fileUrl.toLocalFile() : fileUrl.toString();
    const QFileInfo info(path);
    if (!info.isFile() || info.size() <= 0 || info.suffix().compare("zip", Qt::CaseInsensitive) != 0) {
        setFailure("upload", QStringLiteral("请选择有效的 ZIP 文件")); return;
    }
    for (const auto& field : {"name", "version", "launch_command"}) {
        if (metadata.value(field).toString().trimmed().isEmpty()) { setFailure("upload", QStringLiteral("请填写名称、版本和启动命令")); return; }
    }
    m_uploadPath = path; m_uploadSize = info.size(); m_uploading = true; m_uploadProgress = 0;
    const int epoch = ++m_uploadEpoch;
    emit changed();
    auto failed = [this, epoch](int, const QString& message) {
        if (epoch != m_uploadEpoch) return;
        m_uploading = false; m_uploadReply.clear(); setFailure("upload", message);
    };
    if (!chunked) {
        m_uploadReply = request("POST", "/api/v1/servers/upload", {}, [this, epoch](const QJsonValue& v) {
            if (epoch != m_uploadEpoch) return;
            m_uploading = false; m_uploadProgress = 1; emit changed(); emit operationFinished("upload", v.toVariant()); refresh();
        }, failed, true, false, [this, path, metadata, epoch] {
            return epoch == m_uploadEpoch ? fileMultipart(path, metadata) : nullptr;
        });
        if (m_uploadReply) connect(m_uploadReply, &QNetworkReply::uploadProgress, this, [this, epoch](qint64 sent, qint64 total) {
            if (epoch == m_uploadEpoch && total > 0) { m_uploadProgress = double(sent) / total; emit changed(); }
        });
        return;
    }
    constexpr qint64 chunkSize = 8 * 1024 * 1024;
    m_chunkCount = int((m_uploadSize + chunkSize - 1) / chunkSize); m_chunkIndex = 0;
    auto fields = metadata;
    fields.insert("total_size", QString::number(m_uploadSize)); fields.insert("total_chunks", QString::number(m_chunkCount));
    m_uploadReply = request("POST", "/api/v1/servers/upload/init", {}, [this, epoch](const QJsonValue& v) {
        if (epoch != m_uploadEpoch) return;
        m_uploadId = v.toObject().value("upload_id").toString();
        if (m_uploadId.isEmpty()) { m_uploading = false; setFailure("upload", QStringLiteral("上传会话无效")); return; }
        nextChunk(epoch);
    }, failed, true, false, [this, fields, epoch] {
        if (epoch != m_uploadEpoch) return static_cast<QHttpMultiPart*>(nullptr);
        auto body = new QHttpMultiPart(QHttpMultiPart::FormDataType);
        for (auto it = fields.cbegin(); it != fields.cend(); ++it) addField(body, it.key(), it.value().toString());
        return body;
    });
}

void CommunityClient::nextChunk(int epoch)
{
    if (epoch != m_uploadEpoch || !m_uploading) return;
    auto failed = [this, epoch](int, const QString& message) {
        if (epoch != m_uploadEpoch) return;
        m_uploading = false; m_uploadReply.clear(); setFailure("upload", message);
    };
    if (m_chunkIndex >= m_chunkCount) {
        m_uploadReply = request("POST", "/api/v1/servers/upload/complete", {}, [this, epoch](const QJsonValue& v) {
            if (epoch != m_uploadEpoch) return;
            m_uploading = false; m_uploadProgress = 1; emit changed(); emit operationFinished("upload", v.toVariant()); refresh();
        }, failed, true, false, [this, epoch] {
            if (epoch != m_uploadEpoch) return static_cast<QHttpMultiPart*>(nullptr);
            auto body = new QHttpMultiPart(QHttpMultiPart::FormDataType); addField(body, "upload_id", m_uploadId); return body;
        });
        return;
    }
    const int index = m_chunkIndex;
    m_uploadReply = request("POST", "/api/v1/servers/upload/chunk", {}, [this, epoch](const QJsonValue&) {
        if (epoch != m_uploadEpoch) return;
        ++m_chunkIndex; m_uploadProgress = double(m_chunkIndex) / m_chunkCount; emit changed(); nextChunk(epoch);
    }, failed, true, false, [this, epoch, index] {
        if (epoch != m_uploadEpoch) return static_cast<QHttpMultiPart*>(nullptr);
        QFile file(m_uploadPath);
        constexpr qint64 size = 8 * 1024 * 1024;
        if (!file.open(QIODevice::ReadOnly) || file.size() != m_uploadSize || !file.seek(qint64(index) * size)) return static_cast<QHttpMultiPart*>(nullptr);
        const auto bytes = file.read(size);
        if (bytes.size() != std::min(size, m_uploadSize - qint64(index) * size)) return static_cast<QHttpMultiPart*>(nullptr);
        auto body = new QHttpMultiPart(QHttpMultiPart::FormDataType);
        addField(body, "upload_id", m_uploadId); addField(body, "chunk_index", QString::number(index));
        addBytes(body, "chunk", bytes, QStringLiteral("chunk-%1.bin").arg(index)); return body;
    });
}

void CommunityClient::cancelUpload()
{
    ++m_uploadEpoch;
    if (m_uploadReply) m_uploadReply->abort();
    m_uploadReply.clear(); m_uploading = false; m_uploadProgress = 0;
    emit changed();
}

void CommunityClient::startMicrosoftLogin()
{
    m_oauthVerifier = randomSecret(); m_oauthState = randomSecret(); m_oauthStarted = QDateTime::currentSecsSinceEpoch();
    const auto challenge = QCryptographicHash::hash(m_oauthVerifier, QCryptographicHash::Sha256)
                               .toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
    request("POST", "/api/v1/mobile/auth/microsoft/start",
            QJsonObject{{"code_challenge", QString::fromLatin1(challenge)}, {"client_state", QString::fromLatin1(m_oauthState)}},
            [this](const QJsonValue& v) {
        const QUrl url(v.toObject().value("authorize_url").toString());
        if (url.scheme() != "https" || url.host() != "login.microsoftonline.com") {
            setFailure("microsoft", QStringLiteral("授权地址无效")); return;
        }
        emit microsoftAuthorizationStarted(url);
        if (!QDesktopServices::openUrl(url)) setFailure("microsoft", QStringLiteral("无法打开浏览器"));
    }, {}, false);
}

void CommunityClient::completeMicrosoftLogin(const QUrl& url)
{
    if (url.scheme() != "deeraft" || url.host() != "oauth" || url.path() != "/callback") return;
    const QUrlQuery query(url);
    const auto elapsed = QDateTime::currentSecsSinceEpoch() - m_oauthStarted;
    if (m_oauthState.isEmpty() || query.queryItemValue("state").toUtf8() != m_oauthState || elapsed < 0 || elapsed > 300) {
        setFailure("microsoft", QStringLiteral("登录状态已过期，请重新登录")); return;
    }
    const auto verifier = m_oauthVerifier;
    m_oauthState.clear(); m_oauthVerifier.clear(); m_oauthStarted = 0;
    const auto code = query.queryItemValue("code");
    if (code.isEmpty() || query.hasQueryItem("error")) { setFailure("microsoft", QStringLiteral("微软登录未完成")); return; }
    request("POST", "/api/v1/mobile/auth/microsoft/exchange",
            QJsonObject{{"code", code}, {"code_verifier", QString::fromLatin1(verifier)}},
            [this](const QJsonValue& v) { clearSession(false); acceptSession(v); }, {}, false);
}

void CommunityClient::reportGameStarted(const QString& name,const QString& version){
 if(!m_authenticated)return;
 const auto event=QUuid::createUuid().toString(QUuid::WithoutBraces);
 request("POST","/api/v1/mobile/activity",QJsonObject{{"event_id",event},{"instance",name.left(120)},{"version",version.left(128)}},[this](const QJsonValue& result){mergeActivity(QJsonArray{result},false);},[](int,const QString&){/* Community delivery never blocks local gameplay. */});
}
void CommunityClient::mergeActivity(const QJsonValue& value,bool snapshot){
 if(snapshot)m_activity.clear();
 for(const auto& item:value.toArray()){auto row=item.toObject().toVariantMap();if(row.value("event_id").toString().isEmpty())continue;bool seen=false;for(const auto& existing:m_activity)if(existing.toMap().value("id")==row.value("id")){seen=true;break;}if(seen)continue;m_activity.prepend(row);if(!snapshot)emit activityReceived(row.value("player").toString(),row.value("instance").toString());}
 std::stable_sort(m_activity.begin(),m_activity.end(),[](const QVariant& a,const QVariant& b){return a.toMap().value("id").toLongLong()>b.toMap().value("id").toLongLong();});
 while(m_activity.size()>100)m_activity.removeLast();emit changed();
}

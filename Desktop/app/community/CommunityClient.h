#pragma once

#include <QByteArray>
#include <QJsonValue>
#include <QNetworkAccessManager>
#include <QPointer>
#include <QTimer>
#include <QUrl>
#include <QVariant>
#include <functional>
#include <memory>
#include <vector>

class QHttpMultiPart;
class QNetworkReply;
class QWebSocket;

// Community identity is intentionally independent from the launcher's Minecraft accounts.
class CommunityClient final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool authenticated READ authenticated NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QVariantMap profile READ profile NOTIFY changed)
    Q_PROPERTY(QVariantMap community READ community NOTIFY changed)
    Q_PROPERTY(QVariantList servers READ servers NOTIFY changed)
    Q_PROPERTY(QVariantList chat READ chat NOTIFY changed)
    Q_PROPERTY(QVariantList playtime READ playtime NOTIFY changed)
    Q_PROPERTY(QVariantList daily READ daily NOTIFY changed)
    Q_PROPERTY(QString dailyDate READ dailyDate NOTIFY changed)
    Q_PROPERTY(QVariantMap hostedStatus READ hostedStatus NOTIFY changed)
    Q_PROPERTY(QVariantList liveRooms READ liveRooms NOTIFY changed)
    Q_PROPERTY(QVariantList users READ users NOTIFY changed)
    Q_PROPERTY(QVariantList logLines READ logLines NOTIFY changed)
    Q_PROPERTY(QVariantList backups READ backups NOTIFY changed)
    Q_PROPERTY(QVariantMap rconConfig READ rconConfig NOTIFY changed)
    Q_PROPERTY(QString commandResult READ commandResult NOTIFY changed)
    Q_PROPERTY(bool uploading READ uploading NOTIFY changed)
    Q_PROPERTY(double uploadProgress READ uploadProgress NOTIFY changed)
    Q_PROPERTY(QString connectionStatus READ connectionStatus NOTIFY changed)

public:
    explicit CommunityClient(const QString& dataDirectory, QObject* parent = nullptr);
    ~CommunityClient() override;

    bool authenticated() const { return m_authenticated; }
    bool busy() const { return m_pending > 0; }
    QString error() const { return m_error; }
    QVariantMap profile() const { return m_profile; }
    QVariantMap community() const { return m_community; }
    QVariantList servers() const { return m_servers; }
    QVariantList chat() const { return m_chat; }
    QVariantList playtime() const { return m_playtime; }
    QVariantList daily() const { return m_daily; }
    QString dailyDate() const { return m_dailyDate; }
    QVariantMap hostedStatus() const { return m_hostedStatus; }
    QVariantList liveRooms() const { return m_liveRooms; }
    QVariantList users() const { return m_users; }
    QVariantList logLines() const { return m_logLines; }
    QVariantList backups() const { return m_backups; }
    QVariantMap rconConfig() const { return m_rconConfig; }
    QString commandResult() const { return m_commandResult; }
    bool uploading() const { return m_uploading; }
    double uploadProgress() const { return m_uploadProgress; }
    QString connectionStatus() const { return m_connectionStatus; }

    Q_INVOKABLE void restoreSession();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void login(const QString& username, const QString& password);
    Q_INVOKABLE void registerAccount(const QString& username, const QString& password);
    Q_INVOKABLE void logout();
    Q_INVOKABLE void clearError();
    Q_INVOKABLE void updateProfile(const QString& username, const QString& bio);
    Q_INVOKABLE void uploadAvatar(const QUrl& fileUrl);
    Q_INVOKABLE void loadDaily(const QString& date);
    // action: start, stop, update, backup, backups, restore, delete; args match the website API.
    Q_INVOKABLE void serverAction(const QString& action, const QString& name, const QVariantMap& args = {});
    Q_INVOKABLE void loadBackups(const QString& name);
    Q_INVOKABLE void loadUsers(const QString& search = {});
    Q_INVOKABLE void setUserRole(int userId, const QString& role);
    Q_INVOKABLE void loadLiveRooms();
    Q_INVOKABLE void saveLiveRooms(const QVariantList& rooms);
    Q_INVOKABLE void loadLiveStatus(const QString& roomId);
    Q_INVOKABLE void uploadCover(const QString& name, const QUrl& fileUrl);
    Q_INVOKABLE void watchLogs(const QString& name);
    Q_INVOKABLE void loadLogs(const QString& name, int lines = 200);
    Q_INVOKABLE void loadRconConfig(const QString& name);
    Q_INVOKABLE void sendCommand(const QString& name, const QString& command, bool mcdr = false);
    Q_INVOKABLE void uploadServer(const QUrl& fileUrl, const QVariantMap& metadata, bool chunked = true);
    Q_INVOKABLE void cancelUpload();
    Q_INVOKABLE void startMicrosoftLogin();
    Q_INVOKABLE void completeMicrosoftLogin(const QUrl& callbackUrl);
    Q_INVOKABLE QUrl imageUrl(const QString& path) const;

signals:
    void changed();
    void operationFinished(const QString& operation, const QVariant& result);
    void operationFailed(const QString& operation, const QString& message);
    void liveStatusReceived(const QString& roomId, const QVariantMap& status);
    void microsoftAuthorizationStarted(const QUrl& authorizationUrl);

private:
    friend class CommunityClientTest;
    using Success = std::function<void(const QJsonValue&)>;
    using Failure = std::function<void(int, const QString&)>;
    using MultipartFactory = std::function<QHttpMultiPart*()>;
    struct Feed;
    QNetworkReply* request(const QByteArray& method, const QString& path, const QJsonValue& payload,
                           Success success, Failure failure = {}, bool authenticated = true,
                           bool retried = false, const MultipartFactory& multipart = {});
    void refreshAccess(std::function<void(bool)> continuation);
    void acceptSession(const QJsonValue& value);
    void loadProfile(bool startFeeds);
    void setFailure(const QString& operation, const QString& message);
    void persistSession();
    void clearSession(bool notifyServer);
    bool tokenExpiring() const;
    void startFeeds();
    void stopFeeds();
    void addFeed(const QString& name, const QString& path, Success receive);
    void connectFeed(Feed* feed);
    void mergeChat(const QJsonValue& value, bool snapshot);
    void uploadImage(const QString& path, const QUrl& fileUrl, bool avatar);
    void nextChunk(int epoch);
    static QString segment(const QString& value);

    QNetworkAccessManager m_network;
    QString m_dataDirectory;
    const QUrl m_origin = QUrl(QStringLiteral("http://mc.ainfinitythecoder.cn"));
    QByteArray m_accessToken, m_refreshToken;
    bool m_authenticated = false;
    bool m_refreshing = false;
    int m_pending = 0, m_generation = 0;
    std::vector<std::function<void(bool)>> m_refreshWaiters;
    QString m_error, m_dailyDate, m_connectionStatus, m_commandResult, m_logServer;
    QVariantMap m_profile, m_community, m_hostedStatus, m_rconConfig;
    QVariantList m_servers, m_chat, m_playtime, m_daily, m_liveRooms, m_users, m_logLines, m_backups;
    std::vector<std::unique_ptr<Feed>> m_feeds;
    QTimer m_pollTimer, m_sessionTimer;
    bool m_uploading = false;
    double m_uploadProgress = 0;
    int m_uploadEpoch = 0, m_chunkIndex = 0, m_chunkCount = 0;
    qint64 m_uploadSize = 0;
    QString m_uploadPath, m_uploadId;
    QPointer<QNetworkReply> m_uploadReply;
    QByteArray m_oauthVerifier, m_oauthState;
    qint64 m_oauthStarted = 0;
};

#include "NativeExternalLaunchController.h"

#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QSet>
#include <QStandardPaths>
#include <QSysInfo>

namespace Deeraft {
namespace {

bool ruleApplies(const QJsonObject &rule, const QVariantMap &features, const QString &architecture)
{
    const auto os = rule.value("os").toObject();
    const auto name = os.value("name").toString();
#ifdef Q_OS_WIN
    const auto currentOs = QStringLiteral("windows");
#elif defined(Q_OS_MACOS)
    const auto currentOs = QStringLiteral("osx");
#else
    const auto currentOs = QStringLiteral("linux");
#endif
    if (!name.isEmpty() && name != currentOs)
        return false;
    const auto arch = os.value("arch").toString();
    if (!arch.isEmpty() && arch != architecture && !(arch == "x86_64" && architecture == "amd64"))
        return false;
    const auto versionPattern = os.value("version").toString();
    if (!versionPattern.isEmpty() && !QRegularExpression(versionPattern).match(QSysInfo::kernelVersion()).hasMatch())
        return false;
    const auto featureRules = rule.value("features").toObject();
    for (auto it = featureRules.begin(); it != featureRules.end(); ++it)
        if (features.value(it.key(), false).toBool() != it.value().toBool())
            return false;
    return true;
}

bool allowed(const QJsonObject &object, const QVariantMap &features, const QString &architecture)
{
    if (!object.contains("rules"))
        return true;
    bool allow = false;
    for (const auto &value : object.value("rules").toArray()) {
        const auto rule = value.toObject();
        if (ruleApplies(rule, features, architecture))
            allow = rule.value("action").toString() == "allow";
    }
    return allow;
}

QString artifactPath(const QJsonObject &library)
{
    auto path = library.value("downloads").toObject().value("artifact").toObject().value("path").toString();
    if (!path.isEmpty())
        return path;
    const auto coordinate = library.value("name").toString();
    const auto extensionParts = coordinate.split('@');
    const auto parts = extensionParts.first().split(':');
    if (parts.size() < 3)
        return {};
    auto group = parts[0];
    group.replace('.', '/');
    const auto classifier = parts.size() >= 4 ? '-' + parts[3] : QString();
    return group + '/' + parts[1] + '/' + parts[2] + '/' + parts[1] + '-' + parts[2] + classifier + '.'
        + (extensionParts.size() >= 2 ? extensionParts[1] : QStringLiteral("jar"));
}

QString safeLibraryPath(const QString &root, const QString &path)
{
    if (path.isEmpty() || QDir::isAbsolutePath(path))
        return {};
    const auto normalized = QDir::cleanPath(path);
    if (normalized == ".." || normalized.startsWith("../"))
        return {};
    return QDir(root).filePath(normalized);
}

QStringList manifestArguments(const QJsonArray &arguments, const QVariantMap &features, const QString &architecture)
{
    QStringList result;
    for (const auto &value : arguments) {
        if (value.isString()) {
            result.append(value.toString());
        } else if (value.isObject()) {
            const auto argument = value.toObject();
            if (!allowed(argument, features, architecture))
                continue;
            const auto argValue = argument.value("value");
            if (argValue.isString())
                result.append(argValue.toString());
            else
                for (const auto &item : argValue.toArray())
                    result.append(item.toString());
        }
    }
    return result;
}

QStringList stringList(const QVariant &value)
{
    if (value.metaType().id() == QMetaType::QString)
        return QProcess::splitCommand(value.toString());
    return value.toStringList();
}

bool substitute(QStringList &arguments, const QVariantMap &variables, QString &error)
{
    static const QRegularExpression placeholder(QStringLiteral("\\$\\{([^}]+)\\}"));
    for (auto &argument : arguments) {
        auto matches = placeholder.globalMatch(argument);
        QStringList names;
        while (matches.hasNext())
            names.append(matches.next().captured(1));
        for (const auto &name : names) {
            if (!variables.contains(name)) {
                error = QStringLiteral("不支持的启动参数：%1").arg(name);
                return false;
            }
            argument.replace("${" + name + '}', variables.value(name).toString());
        }
    }
    return true;
}

} // namespace

NativeExternalLaunchController::NativeExternalLaunchController(ExternalGameCatalog *catalog, const QString &dataDirectory, QObject *parent)
    : QObject(parent), m_catalog(catalog), m_dataDirectory(dataDirectory)
{
    connect(&m_process, &QProcess::started, this, [this] {
        emit runningChanged();
        emit started();
    });
    connect(&m_process, &QProcess::readyReadStandardOutput, this, [this] {
        emit logLine(redact(QString::fromUtf8(m_process.readAllStandardOutput())));
    });
    connect(&m_process, &QProcess::readyReadStandardError, this, [this] {
        emit logLine(redact(QString::fromUtf8(m_process.readAllStandardError())));
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError) {
        setError(m_process.errorString());
        if (m_process.state() == QProcess::NotRunning) {
            releaseLock();
            emit runningChanged();
        }
    });
    connect(&m_process, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        releaseLock();
        emit runningChanged();
        emit finished(code, status == QProcess::CrashExit);
    });
}

NativeExternalLaunchController::~NativeExternalLaunchController()
{
    // Destruction must not relinquish the directory lock while Java is alive.
    if (m_process.state() != QProcess::NotRunning) {
        m_process.kill();
        m_process.waitForFinished(5000);
    }
    releaseLock();
}

QVariantMap NativeExternalLaunchController::buildPlan(const QVariantMap &resolved, const QVariantMap &session,
                                                     const QVariantMap &java, const QString &nativesDirectory)
{
    QVariantMap result{{"valid", false}};
    auto fail = [&result](const QString &error) { result.insert("error", error); return result; };
    if (!resolved.value("valid").toBool())
        return fail(resolved.value("error").toString());
    if (session.value("playerName").toString().isEmpty() || session.value("uuid").toString().isEmpty())
        return fail(QStringLiteral("请选择 Minecraft 账号"));
    auto javaPath = java.value("javaPath").toString();
    if (javaPath.isEmpty())
        return fail(QStringLiteral("请先选择 Java"));
    if (!QDir::isAbsolutePath(javaPath))
        javaPath = QStandardPaths::findExecutable(javaPath);
    if (javaPath.isEmpty() || !QFileInfo::exists(javaPath))
        return fail(QStringLiteral("找不到 Java 可执行文件"));
    const auto manifest = QJsonObject::fromVariantMap(resolved.value("versionJson").toMap());
    const auto features = java.value("features").toMap();
    const auto architecture = java.value("architecture", "amd64").toString();
    const auto librariesDirectory = resolved.value("librariesDirectory").toString();
    QStringList classpath;
    QStringList natives;
    QStringList missing;
    QSet<QString> paths;
    for (const auto &value : manifest.value("libraries").toArray()) {
        const auto library = value.toObject();
        if (!allowed(library, features, architecture))
            continue;
        const auto path = safeLibraryPath(librariesDirectory, artifactPath(library));
        const auto nativeClassifiers = library.value("natives").toObject();
        // Legacy natives-only entries must not add an absent base artifact.
        const bool hasArtifact = library.value("downloads").toObject().contains("artifact") || nativeClassifiers.isEmpty();
        if (hasArtifact) {
            if (path.isEmpty())
                return fail(QStringLiteral("无效的依赖路径"));
            if (!paths.contains(path)) {
                paths.insert(path);
                classpath.append(path);
                if (!QFileInfo::exists(path))
                    missing.append(path);
            }
        }
#ifdef Q_OS_WIN
        auto classifier = nativeClassifiers.value("windows").toString();
#elif defined(Q_OS_MACOS)
        auto classifier = nativeClassifiers.value("osx").toString();
#else
        auto classifier = nativeClassifiers.value("linux").toString();
#endif
        classifier.replace("${arch}", java.value("architectureBits", 64).toInt() == 32 ? "32" : "64");
        if (!classifier.isEmpty()) {
            auto artifact = library.value("downloads").toObject().value("classifiers").toObject().value(classifier).toObject().value("path").toString();
            if (artifact.isEmpty()) {
                auto coordinate = library.value("name").toString().split(':');
                if (coordinate.size() < 3)
                    return fail(QStringLiteral("无效的原生依赖"));
                coordinate = coordinate.mid(0, 3);
                coordinate.append(classifier);
                artifact = artifactPath(QJsonObject{{"name", coordinate.join(':')}});
            }
            auto native = safeLibraryPath(librariesDirectory, artifact);
            if (native.isEmpty())
                return fail(QStringLiteral("无效的原生依赖路径"));
            natives.append(native);
            if (!QFileInfo::exists(native))
                missing.append(native);
        }
    }
    const auto clientJar = resolved.value("clientJar").toString();
    classpath.append(clientJar);
    if (!QFileInfo::exists(clientJar))
        missing.append(clientJar);
    if (!missing.isEmpty()) {
        result.insert("missingFiles", missing);
        return fail(QStringLiteral("这个版本缺少 %1 个文件，请先在原启动器中补全，或使用 DeeraftApp 安装版本").arg(missing.size()));
    }
    const auto mainClass = manifest.value("mainClass").toString();
    if (mainClass.isEmpty())
        return fail(QStringLiteral("版本缺少 mainClass"));
    auto uuid = session.value("uuid").toString();
    uuid.remove('-');
    const auto assetId = manifest.value("assetIndex").toObject().value("id").toString(manifest.value("assets").toString());
    QVariantMap variables{
        {"auth_player_name", session.value("playerName")}, {"auth_uuid", uuid},
        {"auth_access_token", session.value("accessToken", "0")},
        {"auth_session", session.value("session", "0")}, {"auth_xuid", session.value("xuid", "")},
        {"user_type", session.value("userType", "offline")}, {"user_properties", session.value("userProperties", "{}")},
        {"clientid", session.value("clientId", "")}, {"version_name", resolved.value("id")},
        {"version_type", manifest.value("type").toString("release")}, {"game_directory", resolved.value("gameDirectory")},
        {"assets_root", resolved.value("assetsDirectory")}, {"assets_index_name", assetId},
        {"game_assets", QDir(resolved.value("assetsDirectory").toString()).filePath("virtual/" + assetId)},
        {"natives_directory", nativesDirectory}, {"library_directory", librariesDirectory},
        {"launcher_name", "DeeraftApp"}, {"launcher_version", "1.0"},
        {"classpath", classpath.join(QDir::listSeparator())}, {"classpath_separator", QString(QDir::listSeparator())},
        {"resolution_width", java.value("width", 854)}, {"resolution_height", java.value("height", 480)}
    };
    QStringList arguments;
    const int minimum = java.value("minMemoryMiB", 512).toInt();
    const int maximum = java.value("maxMemoryMiB", 4096).toInt();
    if (minimum <= 0 || maximum < minimum)
        return fail(QStringLiteral("Java 内存设置无效"));
    arguments << QStringLiteral("-Xms%1m").arg(minimum) << QStringLiteral("-Xmx%1m").arg(maximum);
    const auto manifestArgs = manifest.value("arguments").toObject();
    auto jvmArgs = manifestArguments(manifestArgs.value("jvm").toArray(), features, architecture);
    if (jvmArgs.isEmpty())
        jvmArgs << "-Djava.library.path=${natives_directory}" << "-cp" << "${classpath}";
    arguments << jvmArgs << stringList(java.value("jvmArguments"));
    arguments << mainClass;
    if (manifestArgs.contains("game"))
        arguments << manifestArguments(manifestArgs.value("game").toArray(), features, architecture);
    else
        arguments << QProcess::splitCommand(manifest.value("minecraftArguments").toString());
    arguments << stringList(java.value("gameArguments"));
    QString error;
    if (!substitute(arguments, variables, error))
        return fail(error);
    result.insert("valid", true);
    result.insert("javaPath", javaPath);
    result.insert("arguments", arguments);
    result.insert("workingDirectory", resolved.value("gameDirectory"));
    result.insert("nativeJars", natives);
    result.insert("nativesDirectory", nativesDirectory);
    return result;
}

bool NativeExternalLaunchController::launch(const QString &rootId, const QString &versionId, const QVariantMap &session, const QVariantMap &javaOptions)
{
    if (running()) {
        setError(QStringLiteral("请先关闭正在运行的游戏"));
        return false;
    }
    m_lockKey = m_catalog->acquireLaunchLock(rootId, versionId);
    if (m_lockKey.isEmpty()) {
        setError(m_catalog->error());
        return false;
    }
    m_versionId = versionId;
    const auto natives = QDir(m_dataDirectory).filePath("external-natives/" + m_lockKey);
    const auto resolved = m_catalog->resolveVersion(rootId, versionId);
    const auto plan = buildPlan(resolved, session, javaOptions, natives);
    if (!plan.value("valid").toBool()) {
        setError(plan.value("error").toString());
        releaseLock();
        return false;
    }
    const auto nativeJars = plan.value("nativeJars").toStringList();
    if (!nativeJars.isEmpty()) {
        QString error;
        if (!QDir().mkpath(natives) || !m_extractor || !m_extractor(nativeJars, natives, error)) {
            setError(error.isEmpty() ? QStringLiteral("无法解压原生依赖") : error);
            releaseLock();
            return false;
        }
    }
    if (!QDir().mkpath(plan.value("workingDirectory").toString())) {
        setError(QStringLiteral("无法创建游戏运行目录"));
        releaseLock();
        return false;
    }
    m_secrets.clear();
    for (const auto &key : {"accessToken", "session"}) {
        const auto value = session.value(key).toString();
        if (value.size() > 8)
            m_secrets.append(value);
    }
    auto environment = QProcessEnvironment::systemEnvironment();
    // Launchers should own JVM options rather than inherit unrelated system injections.
    environment.remove("_JAVA_OPTIONS");
    environment.remove("JAVA_TOOL_OPTIONS");
    environment.remove("JDK_JAVA_OPTIONS");
    const auto extraEnvironment = javaOptions.value("environment").toMap();
    for (auto i = extraEnvironment.begin(); i != extraEnvironment.end(); ++i)
        environment.insert(i.key(), i.value().toString());
    m_process.setProcessEnvironment(environment);
    m_process.setWorkingDirectory(plan.value("workingDirectory").toString());
    m_process.setProgram(plan.value("javaPath").toString());
    m_process.setArguments(plan.value("arguments").toStringList());
    setError({});
    m_process.start();
    emit runningChanged();
    return true;
}

void NativeExternalLaunchController::stop()
{
    if (m_process.state() != QProcess::NotRunning)
        m_process.terminate();
}

void NativeExternalLaunchController::setError(const QString &error)
{
    if (m_error == error)
        return;
    m_error = error;
    emit errorChanged();
}

void NativeExternalLaunchController::releaseLock()
{
    if (!m_lockKey.isEmpty()) {
        m_catalog->releaseLaunchLock(m_lockKey);
        m_lockKey.clear();
    }
}

QString NativeExternalLaunchController::redact(QString line) const
{
    for (const auto &secret : m_secrets)
        line.replace(secret, "[redacted]");
    return line;
}

} // namespace Deeraft

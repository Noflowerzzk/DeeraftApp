#include "ExternalGameCatalog.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QLockFile>
#include <QSaveFile>
#include <QSet>
#include <QUrl>
#include <QRegularExpression>
#include <QFutureWatcher>
#include <QtConcurrentRun>
#include <QTimer>

namespace Deeraft {
namespace {

constexpr qint64 MaxJsonSize = 16 * 1024 * 1024;

QString canonical(const QString &path)
{
    const QFileInfo info(path);
    return QDir::cleanPath(info.canonicalFilePath().isEmpty() ? info.absoluteFilePath() : info.canonicalFilePath());
}

QString hashPath(QString path)
{
#ifdef Q_OS_WIN
    path = path.toCaseFolded();
#endif
    return QString::fromLatin1(QCryptographicHash::hash(path.toUtf8(), QCryptographicHash::Sha256).toHex());
}

bool safeVersionId(const QString &id)
{
    return !id.isEmpty() && id != "." && id != ".." && !id.contains('/') && !id.contains('\\') && !id.contains(':');
}

QJsonObject readJson(const QString &path, QString &error)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        error = QStringLiteral("无法读取 %1：%2").arg(path, file.errorString());
        return {};
    }
    if (file.size() > MaxJsonSize) {
        error = QStringLiteral("配置文件过大：%1").arg(path);
        return {};
    }
    QJsonParseError parseError;
    auto document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        error = QStringLiteral("JSON 格式错误：%1（%2）").arg(path, parseError.errorString());
        return {};
    }
    return document.object();
}

// PCL INI files also exist without section headers. Read only known data files,
// without QSettings' platform-specific conversion of backslashes and escapes.
QVariantMap readIni(const QString &path)
{
    QFile file(path);
    QVariantMap result;
    if (!file.open(QIODevice::ReadOnly) || file.size() > MaxJsonSize)
        return result;
    auto content = QString::fromUtf8(file.readAll());
    content.remove(QChar(0xfeff));
    for (const auto &line : content.split('\n')) {
        const QString trimmed = line.trimmed();
        const auto separator = trimmed.indexOf('=');
        if (separator <= 0 || trimmed.startsWith(';') || trimmed.startsWith('#'))
            continue;
        result.insert(trimmed.left(separator).trimmed(), trimmed.mid(separator + 1).trimmed());
    }
    return result;
}

bool iniBool(const QVariant &value)
{
    auto text = value.toString().trimmed().toLower();
    return text == "true" || text == "1" || text == "yes";
}

QString libraryKey(const QJsonValue &library)
{
    const auto parts = library.toObject().value("name").toString().split(':');
    return parts.size() >= 2 ? parts[0] + ':' + parts[1] + (parts.size() >= 4 ? ':' + parts[3] : QString()) : QString();
}

QJsonObject mergeVersion(QJsonObject parent, const QJsonObject &child)
{
    for (auto i = child.begin(); i != child.end(); ++i) {
        if (i.key() == "libraries") {
            auto libraries = parent.value("libraries").toArray();
            for (const auto &library : i.value().toArray()) {
                const auto key = libraryKey(library);
                for (qsizetype n = libraries.size(); n > 0; --n)
                    if (!key.isEmpty() && libraryKey(libraries[n - 1]) == key)
                        libraries.removeAt(n - 1);
                libraries.append(library);
            }
            parent.insert(i.key(), libraries);
        } else if (i.key() == "arguments") {
            auto args = parent.value("arguments").toObject();
            const auto newArgs = i.value().toObject();
            for (auto a = newArgs.begin(); a != newArgs.end(); ++a) {
                auto values = args.value(a.key()).toArray();
                for (const auto &value : a.value().toArray())
                    values.append(value);
                args.insert(a.key(), values);
            }
            parent.insert(i.key(), args);
        } else if (i.value().isObject() && parent.value(i.key()).isObject()) {
            parent.insert(i.key(), mergeVersion(parent.value(i.key()).toObject(), i.value().toObject()));
        } else {
            parent.insert(i.key(), i.value());
        }
    }
    return parent;
}

QJsonObject resolveInheritance(const QString &root, const QString &id, QSet<QString> &visited,
                               QStringList &chain, QString &error)
{
    if (!safeVersionId(id) || visited.contains(id) || visited.size() >= 64) {
        error = QStringLiteral("版本继承无效或存在循环：%1").arg(id);
        return {};
    }
    visited.insert(id);
    const auto path = QDir(root).filePath(QStringLiteral("versions/%1/%1.json").arg(id));
    auto child = readJson(path, error);
    if (!error.isEmpty())
        return {};
    const auto parentId = child.value("inheritsFrom").toString();
    QJsonObject result;
    if (!parentId.isEmpty()) {
        result = resolveInheritance(root, parentId, visited, chain, error);
        if (!error.isEmpty())
            return {};
    }
    chain.append(id);
    return mergeVersion(result, child);
}

bool moddedVersion(const QJsonObject &version)
{
    for (const auto &value : version.value("libraries").toArray()) {
        const auto name = value.toObject().value("name").toString().toLower();
        if (name.contains("forge") || name.contains("fabric") || name.contains("quilt") || name.contains("liteloader") || name.contains("laby"))
            return true;
    }
    const auto main = version.value("mainClass").toString().toLower();
    return main.contains("modlauncher") || main.contains("launchwrapper") || main.contains("fabric") || main.contains("quilt");
}

QString customDirectory(const QString &directory, const QString &root)
{
    return canonical(QDir::isAbsolutePath(directory) ? directory : QDir(root).filePath(directory));
}

QString legacyHmclDirectory(const QJsonObject &settings, const QString &root, const QString &versionDirectory)
{
    auto type = settings.value("gameDirType");
    const auto mode = type.isDouble() ? QString::number(type.toInt()) : type.toString().toUpper();
    if (mode == "VERSION_FOLDER" || mode == "1")
        return versionDirectory;
    if (mode == "CUSTOM" || mode == "2") {
        const auto custom = settings.value("gameDir").toString();
        if (!custom.isEmpty())
            return customDirectory(custom, root);
    }
    return root;
}

QString resolveGameDirectory(const QString &root, const QString &versionDirectory, const QJsonObject &version,
                             const QVariantMap &options, QString &source, QStringList &warnings)
{
    const auto modernFile = QDir(versionDirectory).filePath(".hmcl/config/instance-game-settings.json");
    const auto legacyFile = QDir(versionDirectory).filePath("hmclversion.cfg");
    if (QFileInfo::exists(modernFile)) {
        source = "HMCL";
        QString error;
        const auto settings = readJson(modernFile, error);
        if (!error.isEmpty()) {
            warnings.append(error);
            return {};
        }
        if (settings.value("overrideProperties").toArray().contains("runningDirectory")) {
            const auto directory = settings.value("runningDirectory").toString();
            return directory.isEmpty() ? versionDirectory : customDirectory(directory, root);
        }
        const auto globalDirectory = options.value("hmclRunningDirectory").toString();
        if (!globalDirectory.isEmpty())
            return customDirectory(globalDirectory, root);
        if (settings.contains("parent") && !settings.value("parent").isNull() && !options.contains("hmclRunningDirectory"))
        {
            warnings.append(QStringLiteral("HMCL 此版本继承全局配置；请确认运行目录（未读取 HMCL 账号配置文件）"));
            return {};
        }
        return root;
    }
    if (QFileInfo::exists(legacyFile)) {
        source = "HMCL";
        QString error;
        auto settings = readJson(legacyFile, error);
        if (!error.isEmpty()) {
            warnings.append(error);
            return {};
        }
        if (settings.value("usesGlobal").toBool()) {
            const auto globalSettings = QJsonObject::fromVariantMap(options.value("hmclGlobalSettings").toMap());
            if (globalSettings.isEmpty()) {
                warnings.append(QStringLiteral("HMCL 此版本使用全局隔离设置；请确认运行目录"));
                return {};
            }
            settings = globalSettings;
        }
        return legacyHmclDirectory(settings, root, versionDirectory);
    }

    const auto pclFile = QDir(versionDirectory).filePath("PCL/Setup.ini");
    const bool pcl = QFileInfo::exists(pclFile) || QDir(root).exists("PCL");
    const auto config = readIni(pclFile);
    if (pcl) {
        source = "PCL";
        bool isolation;
        if (config.contains("VersionArgumentIndieV2")) {
            isolation = iniBool(config.value("VersionArgumentIndieV2"));
        } else if (config.value("VersionArgumentIndie", -1).toInt() > 0) {
            isolation = config.value("VersionArgumentIndie").toInt() == 1;
        } else if (!QDir(QDir(versionDirectory).filePath("mods")).entryList(QDir::Files | QDir::NoDotAndDotDot).isEmpty()
                   || !QDir(QDir(versionDirectory).filePath("saves")).entryList(QDir::Dirs | QDir::NoDotAndDotDot).isEmpty()) {
            isolation = true;
        } else {
            const auto global = options.value("pclIsolation", 4).toInt();
            const bool modded = moddedVersion(version);
            const auto type = version.value("type").toString();
            const bool nonRelease = !type.isEmpty() && type != "release";
            isolation = global == 0 ? false : global == 1 ? modded : global == 2 ? nonRelease : global == 3 ? (modded || nonRelease) : true;
            if (!options.contains("pclIsolation"))
                warnings.append(QStringLiteral("PCL 未设置独立隔离选项；使用 PCL 默认的全部隔离，可在目录设置中调整"));
        }
        return isolation ? versionDirectory : root;
    }
    source = "Minecraft";
    if (QFileInfo::exists(QDir(versionDirectory).filePath("modpack.cfg")))
        return versionDirectory;
    return root;
}

} // namespace

QString ExternalVersionResolver::normalizeRoot(const QString &path)
{
    auto local = QUrl(path);
    QString candidate = canonical(local.isLocalFile() ? local.toLocalFile() : path);
    if (QFileInfo(candidate).fileName().compare("versions", Qt::CaseInsensitive) == 0)
        candidate = QFileInfo(candidate).absolutePath();
    if (!QDir(candidate).exists("versions") && QDir(candidate).exists(".minecraft/versions"))
        candidate = canonical(QDir(candidate).filePath(".minecraft"));
    if(!QDir(candidate).exists("versions") && QDir(candidate).exists("instances"))candidate=canonical(QDir(candidate).filePath("instances"));
    return candidate;
}

QString ExternalVersionResolver::rootId(const QString &path)
{
    return hashPath(normalizeRoot(path));
}

QVariantMap ExternalVersionResolver::resolve(const QString &path, const QString &versionId, const QVariantMap &options)
{
    const auto root = normalizeRoot(path);
    QVariantMap result{{"id", versionId}, {"root", root}, {"rootId", rootId(root)}, {"valid", false}};
    const auto instanceDirectory=QDir(root).filePath(versionId);
    if(safeVersionId(versionId) && QFileInfo::exists(QDir(instanceDirectory).filePath("instance.cfg"))) {
        QString error;
        const auto pack=readJson(QDir(instanceDirectory).filePath("mmc-pack.json"),error);
        if(!error.isEmpty()){result["error"]=error;return result;}
        const auto settings=readIni(QDir(instanceDirectory).filePath("instance.cfg"));
        QString version,loader;
        for(const auto& value:pack["components"].toArray()) {
            const auto c=value.toObject();const auto uid=c["uid"].toString();const auto v=c["version"].toString(c["cachedVersion"].toString());
            if(uid=="net.minecraft")version=v;
            const QMap<QString,QString> names{{"net.fabricmc.fabric-loader","Fabric"},{"net.minecraftforge","Forge"},{"net.neoforged","NeoForge"},{"org.quiltmc.quilt-loader","Quilt"},{"optifine.OptiFine","OptiFine"}};
            if(names.contains(uid))loader=names[uid]+" "+v;
        }
        auto game=QDir(instanceDirectory).filePath(".minecraft");
        if(!QDir(game).exists())game=QDir(instanceDirectory).filePath("minecraft");
        result["format"]="prism";result["instanceDirectory"]=instanceDirectory;result["versionDirectory"]=instanceDirectory;
        const auto shared=QFileInfo(root).dir().absolutePath();
        result["librariesDirectory"]=QDir(shared).filePath("libraries");result["assetsDirectory"]=QDir(shared).filePath("assets");
        result["metadataDirectory"]=QDir(shared).filePath("meta");
        result["gameDirectory"]=game;result["name"]=settings.value("name",versionId);result["icon"]=settings.value("iconKey","default");
        result["version"]=version;result["loader"]=loader;result["valid"]=!version.isEmpty();
        if(version.isEmpty())result["error"]=QStringLiteral("实例配置缺少 Minecraft 版本信息：%1/mmc-pack.json").arg(instanceDirectory);
        return result;
    }
    if (!QDir(root).exists("versions") || !safeVersionId(versionId)) {
        result.insert("error", QStringLiteral("无效的 Minecraft 目录或版本名称"));
        return result;
    }
    QSet<QString> visited;
    QStringList chain;
    QString error;
    const auto version = resolveInheritance(root, versionId, visited, chain, error);
    if (!error.isEmpty()) {
        result.insert("error", error);
        return result;
    }
    const auto directory = canonical(QDir(root).filePath("versions/" + versionId));
    QString source;
    QStringList warnings;
    auto gameDirectory = resolveGameDirectory(root, directory, version, options, source, warnings);
    const auto overrideDirectory = options.value("versionDirectories").toMap().value(versionId).toString();
    if (!overrideDirectory.isEmpty())
        gameDirectory = customDirectory(overrideDirectory, root);

    QString jarId = version.value("jar").toString();
    if (!safeVersionId(jarId)) {
        jarId.clear();
        for (auto i = chain.crbegin(); i != chain.crend(); ++i) {
            if (QFileInfo::exists(QDir(root).filePath(QStringLiteral("versions/%1/%1.jar").arg(*i)))) {
                jarId = *i;
                break;
            }
        }
        if (jarId.isEmpty() && !chain.isEmpty())
            jarId = chain.first();
    }
    const auto jar = QDir(root).filePath(QStringLiteral("versions/%1/%1.jar").arg(jarId));
    if (!QFileInfo::exists(jar))
        warnings.append(QStringLiteral("客户端文件尚未下载"));
    result.insert("versionDirectory", directory);
    result.insert("gameDirectory", gameDirectory);
    result.insert("assetsDirectory", QDir(root).filePath("assets"));
    result.insert("librariesDirectory", QDir(root).filePath("libraries"));
    result.insert("clientJar", jar);
    result.insert("inheritance", chain);
    result.insert("versionJson", version.toVariantMap());
    QString minecraft=version.value("clientVersion").toString(),loader;
    for(const auto& patch:version.value("patches").toArray()) {
        const auto p=patch.toObject();const auto id=p["id"].toString().toLower();
        if(id=="game" || id=="minecraft")minecraft=p["version"].toString();
        const QMap<QString,QString> names{{"fabric","Fabric"},{"forge","Forge"},{"neoforge","NeoForge"},{"quilt","Quilt"},{"optifine","OptiFine"}};
        if(names.contains(id))loader=names[id]+" "+p["version"].toString();
    }
    for(const auto& item:version.value("libraries").toArray()) {
        const auto name=item.toObject()["name"].toString();const auto parts=name.split(':');
        if(parts.size()<3)continue;
        const QMap<QString,QString> names{{"net.fabricmc:fabric-loader","Fabric"},{"net.minecraftforge:forge","Forge"},{"net.neoforged:neoforge","NeoForge"},{"org.quiltmc:quilt-loader","Quilt"},{"optifine:OptiFine","OptiFine"}};
        const auto key=parts[0]+":"+parts[1];if(names.contains(key))loader=names[key]+" "+parts[2];
    }
    if(minecraft.isEmpty()) {
        for(const auto& candidate:chain)if(QRegularExpression("^(?:\\d+\\.\\d+(?:\\.\\d+)?|\\d{2}w\\d{2}[a-z])$").match(candidate).hasMatch()){minecraft=candidate;break;}
    }
    if(minecraft.isEmpty())minecraft=version.value("id").toString(versionId);
    result["version"]=minecraft;result["loader"]=loader;result["format"]="minecraft";
    result.insert("source", source);
    result.insert("modded", moddedVersion(version));
    result.insert("warnings", warnings);
    result.insert("valid", !gameDirectory.isEmpty());
    if (gameDirectory.isEmpty())
        result.insert("error", QStringLiteral("运行目录不明确，请先确认隔离设置"));
    return result;
}

QVariantList ExternalVersionResolver::scan(const QString &path, const QVariantMap &options)
{
    const auto root = normalizeRoot(path);
    if(!QDir(root).exists("versions")) {
        QVariantList result;
        for(const auto& id:QDir(root).entryList(QDir::Dirs|QDir::NoDotAndDotDot,QDir::Name|QDir::IgnoreCase))
            if(QFileInfo::exists(QDir(root).filePath(id+"/instance.cfg")) && QFileInfo::exists(QDir(root).filePath(id+"/mmc-pack.json")))result.append(resolve(root,id,options));
        return result;
    }
    const QDir versions(QDir(root).filePath("versions"));
    QVariantList result;
    for (const auto &id : versions.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name | QDir::IgnoreCase)) {
        if (QFileInfo::exists(versions.filePath(id + '/' + id + ".json")))
            result.append(resolve(root, id, options));
    }
    return result;
}

QString ExternalVersionResolver::validateRoot(const QString &path,const QVariantList &rows)
{
    if(path.trimmed().isEmpty())return QStringLiteral("请选择实例目录");
    const QUrl url(path);
    if(!url.scheme().isEmpty()&&url.scheme().size()>1&&!url.isLocalFile())return QStringLiteral("请选择本机文件夹，不能使用网页地址");
    const QFileInfo selected(url.isLocalFile()?url.toLocalFile():path);
    if(!selected.exists())return QStringLiteral("所选目录不存在：%1").arg(path);
    if(!selected.isDir())return QStringLiteral("请选择文件夹，不能选择文件：%1").arg(path);
    if(!selected.isReadable())return QStringLiteral("所选目录无法读取：%1").arg(path);
    const QDir original(selected.absoluteFilePath());
    if(original.exists("instance.cfg")&&original.exists("mmc-pack.json"))
        return QStringLiteral("这是单个实例文件夹，请选择上一级实例目录：%1").arg(selected.absolutePath());
    const auto root=normalizeRoot(path);const QDir folder(root);
    if(folder.exists("instance.cfg")&&folder.exists("mmc-pack.json"))
        return QStringLiteral("这是单个实例文件夹，请选择上一级实例目录：%1").arg(QFileInfo(root).absolutePath());
    if(rows.isEmpty()){
        if(QFileInfo(root).fileName().compare("mods",Qt::CaseInsensitive)==0)
            return QStringLiteral("这是模组文件夹，请选择包含 versions 的 .minecraft 文件夹，或包含多个实例的 instances 文件夹");
        return QStringLiteral("所选文件夹没有可识别的实例。请选择包含 versions 的 .minecraft 文件夹，或包含 instance.cfg 和 mmc-pack.json 实例的 instances 文件夹：%1").arg(root);
    }
    for(const auto& value:rows)if(!value.toMap().value("version").toString().isEmpty())return {};
    const auto reason=rows.first().toMap().value("error").toString();
    return QStringLiteral("目录中的实例配置无法识别：%1").arg(reason.isEmpty()?root:reason);
}

ExternalGameCatalog::ExternalGameCatalog(const QString &dataDirectory, QObject *parent)
    : QObject(parent), m_dataDirectory(canonical(dataDirectory)), m_catalogFile(QDir(m_dataDirectory).filePath("external-games.json"))
{
    if (QFileInfo::exists(m_catalogFile)) {
        QString error;
        const auto catalog = readJson(m_catalogFile, error);
        if (!error.isEmpty())
            setError(error);
        else if (catalog.value("schema").toInt() != 1)
            setError(QStringLiteral("不支持的外部目录配置版本"));
        else
            m_roots = catalog.value("roots").toArray().toVariantList();
    }
    QTimer::singleShot(0,this,[this]{for(const auto& value:m_roots){const auto root=value.toMap();if(!m_rows.contains(root.value("id").toString()))scanAsync(root.value("path").toString(),root.value("options").toMap(),false);}});
}

ExternalGameCatalog::~ExternalGameCatalog() = default;

void ExternalGameCatalog::setError(const QString &error)
{
    if (m_error == error)
        return;
    m_error = error;
    emit errorChanged();
}

bool ExternalGameCatalog::save(const QVariantList &roots)
{
    if (!QDir().mkpath(m_dataDirectory)) {
        setError(QStringLiteral("无法创建 DeeraftApp 数据目录"));
        return false;
    }
    // Other DeeraftApp processes must not overwrite catalog changes concurrently.
    QLockFile lock(m_catalogFile + ".lock");
    if (!lock.tryLock(0)) {
        setError(QStringLiteral("目录列表正在被另一个 DeeraftApp 使用"));
        return false;
    }
    QSaveFile file(m_catalogFile);
    const auto bytes = QJsonDocument(QJsonObject{{"schema", 1}, {"roots", QJsonArray::fromVariantList(roots)}}).toJson();
    if (!file.open(QIODevice::WriteOnly) || file.write(bytes) != bytes.size() || !file.commit()) {
        setError(QStringLiteral("无法保存目录列表：%1").arg(file.errorString()));
        return false;
    }
    m_roots = roots;
    setError({});
    emit rootsChanged();
    return true;
}

QVariantMap ExternalGameCatalog::findRoot(const QString &id) const
{
    for (const auto &entry : m_roots)
        if (entry.toMap().value("id").toString() == id)
            return entry.toMap();
    return {};
}

QString ExternalGameCatalog::addRoot(const QString &path)
{
    const auto rows=ExternalVersionResolver::scan(path);
    const auto error=ExternalVersionResolver::validateRoot(path,rows);
    if(!error.isEmpty()){setError(error);return {};}
    return acceptRoot(path,rows);
}

QString ExternalGameCatalog::acceptRoot(const QString &path,const QVariantList &rows)
{
    const auto root = ExternalVersionResolver::normalizeRoot(path);
    const auto id = ExternalVersionResolver::rootId(root);
    if (!findRoot(id).isEmpty()) {
        m_rows[id]=rows;setError({});publishVersions();
        return id;
    }
    auto roots = m_roots;
    roots.append(QVariantMap{{"id", id}, {"path", root}, {"name", QFileInfo(root).fileName()}, {"options", QVariantMap()}});
    if (!save(roots))
        return {};
    m_rows[id]=rows;publishVersions();
    return id;
}

void ExternalGameCatalog::publishVersions()
{
    m_versions.clear();
    for(const auto& value:m_roots)m_versions.append(m_rows.value(value.toMap().value("id").toString()));
    emit versionsChanged();
}

void ExternalGameCatalog::addRootAsync(const QString &path)
{
    const auto id=ExternalVersionResolver::rootId(path);
    scanAsync(path,findRoot(id).value("options").toMap(),true);
}

void ExternalGameCatalog::scanAsync(const QString &path,const QVariantMap &options,bool importing)
{
    const auto id=ExternalVersionResolver::rootId(path);
    const auto ticket=++m_scanGeneration[id];
    m_pendingScans.insert(id);emit scanningChanged();
    auto watcher=new QFutureWatcher<QVariantList>(this);
    connect(watcher,&QFutureWatcher<QVariantList>::finished,this,[this,watcher,path,id,ticket,importing]{
        const auto rows=watcher->result();watcher->deleteLater();
        if(m_scanGeneration.value(id)!=ticket)return;
        m_pendingScans.remove(id);emit scanningChanged();
        const auto error=ExternalVersionResolver::validateRoot(path,rows);
        if(!error.isEmpty()){setError(error);if(importing)emit importFailed(path,error);return;}
        if(importing){if(acceptRoot(path,rows).isEmpty())emit importFailed(path,m_error);else emit importFinished(path,rows.size());}
        else if(!findRoot(id).isEmpty()){m_rows[id]=rows;publishVersions();}
    });
    watcher->setFuture(QtConcurrent::run([path,options]{return ExternalVersionResolver::scan(path,options);}));
}

bool ExternalGameCatalog::removeRoot(const QString &id)
{
    auto roots = m_roots;
    bool found = false;
    for (qsizetype i = roots.size(); i > 0; --i) {
        if (roots[i - 1].toMap().value("id").toString() == id) {
            roots.removeAt(i - 1);
            found = true;
        }
    }
    if (!found) {
        setError(QStringLiteral("目录关联不存在"));
        return false;
    }
    if (!save(roots))
        return false;
    ++m_scanGeneration[id];m_pendingScans.remove(id);emit scanningChanged();
    m_rows.remove(id);publishVersions();
    return true;
}

bool ExternalGameCatalog::setRootOptions(const QString &id, const QVariantMap &options)
{
    auto roots = m_roots;
    for (auto &entry : roots) {
        auto root = entry.toMap();
        if (root.value("id").toString() != id)
            continue;
        auto merged = root.value("options").toMap();
        for (auto i = options.begin(); i != options.end(); ++i)
            merged.insert(i.key(), i.value());
        root.insert("options", merged);
        entry = root;
        if (!save(roots))
            return false;
        scanAsync(root.value("path").toString(),merged,false);
        return true;
    }
    setError(QStringLiteral("目录关联不存在"));
    return false;
}

QVariantList ExternalGameCatalog::scanRoot(const QString &id)
{
    const auto root = findRoot(id);
    if (root.isEmpty()) {
        setError(QStringLiteral("目录关联不存在"));
        return {};
    }
    const auto rows = ExternalVersionResolver::scan(root.value("path").toString(), root.value("options").toMap());
    m_rows[id]=rows;
    setError({});
    publishVersions();
    return rows;
}

QVariantMap ExternalGameCatalog::resolveVersion(const QString &id, const QString &versionId)
{
    const auto root = findRoot(id);
    if (root.isEmpty()) {
        setError(QStringLiteral("目录关联不存在"));
        return {{"valid", false}, {"error", m_error}};
    }
    auto version = ExternalVersionResolver::resolve(root.value("path").toString(), versionId, root.value("options").toMap());
    setError(version.value("error").toString());
    return version;
}

QString ExternalGameCatalog::acquireLaunchLock(const QString &id, const QString &versionId)
{
    const auto version = resolveVersion(id, versionId);
    if (!version.value("valid").toBool())
        return {};
    const auto key = hashPath(canonical(version.value("gameDirectory").toString()));
    const auto directory = QDir(m_dataDirectory).filePath("locks");
    if (!QDir().mkpath(directory)) {
        setError(QStringLiteral("无法创建启动锁目录"));
        return {};
    }
    if (m_locks.count(key)) {
        setError(QStringLiteral("这个游戏目录已在使用中"));
        return {};
    }
    auto lock = std::make_unique<QLockFile>(QDir(directory).filePath(key + ".lock"));
    lock->setStaleLockTime(0);
    if (!lock->tryLock(0)) {
        setError(QStringLiteral("这个游戏目录已被另一个 DeeraftApp 使用"));
        return {};
    }
    m_locks.emplace(key, std::move(lock));
    setError({});
    return key;
}

void ExternalGameCatalog::releaseLaunchLock(const QString &key)
{
    m_locks.erase(key);
}

} // namespace Deeraft

#include "ResourceReuseTask.h"
#include "DesktopBridge.h"
#include "Application.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/PackProfile.h"
#include "minecraft/Library.h"
#include "net/HttpMetaCache.h"
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFutureWatcher>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QTimer>
#include <QtConcurrentRun>
#include <archive.h>
#include <archive_entry.h>

namespace {
QString safeRelative(const QString& root,const QString& path){auto relative=QDir(root).relativeFilePath(path);return QDir::isAbsolutePath(relative)||relative==".."||relative.startsWith("../")?QString():relative;}
QByteArray digest(const QString& path,const QString& sha,const std::shared_ptr<std::atomic_bool>& cancel,bool jar,QJsonObject& memo,int& hashed){
    const QFileInfo info(path);const auto key=info.absoluteFilePath();const auto prior=memo.value(key).toObject();
    if(info.isFile()&&info.isReadable()&&info.size()>0&&prior["size"].toDouble()==info.size()&&prior["modified"].toDouble()==info.lastModified().toMSecsSinceEpoch()&&prior["sha1"].toString()==sha.toLower()&&prior["jar"].toBool()==jar&&prior["md5"].toString().size()==32)return prior["md5"].toString().toLatin1();
    QFile file(path);if(!file.open(QIODevice::ReadOnly)||file.size()==0)return {};
    ++hashed;
    // Unsigned Maven JARs still require a readable ZIP with valid entry CRCs.
    if(sha.isEmpty()&&jar){
        if(!file.read(4).startsWith("PK"))return {};
        file.seek(0);
        auto reader=archive_read_new();archive_read_support_format_zip(reader);archive_read_support_filter_all(reader);
        const auto filename=path.toStdWString();bool valid=archive_read_open_filename_w(reader,filename.c_str(),65536)==ARCHIVE_OK;archive_entry* entry=nullptr;int status=ARCHIVE_EOF;char block[65536];
        while(valid&&!*cancel&&(status=archive_read_next_header(reader,&entry))==ARCHIVE_OK){la_ssize_t count;while((count=archive_read_data(reader,block,sizeof(block)))>0){if(*cancel){valid=false;break;}}if(count<0)valid=false;}
        valid=valid&&!*cancel&&status==ARCHIVE_EOF;archive_read_free(reader);if(!valid)return {};
    }
    if(sha.isEmpty()&&!jar){
        const auto document=QJsonDocument::fromJson(file.readAll());
        if(!document.isObject()||!document.object().value("objects").isObject())return {};
        const auto objects=document.object().value("objects").toObject();
        for(const auto& object:objects){const auto value=object.toObject();const auto hash=value["hash"].toString();if(hash.size()!=40||QByteArray::fromHex(hash.toLatin1()).toHex()!=hash.toLatin1().toLower()||!value["size"].isDouble()||value["size"].toDouble()<0)return {};}
        file.seek(0);
    }
    QCryptographicHash expected(QCryptographicHash::Sha1),md5(QCryptographicHash::Md5);
    while(!file.atEnd()){if(*cancel)return {};auto chunk=file.read(1024*1024);if(chunk.isEmpty()&&file.error()!=QFile::NoError)return {};expected.addData(chunk);md5.addData(chunk);}
    if(!sha.isEmpty()&&expected.result().toHex()!=sha.toLatin1().toLower())return {};
    const auto result=md5.result().toHex();
    memo[key]=QJsonObject{{"size",double(info.size())},{"modified",double(info.lastModified().toMSecsSinceEpoch())},{"sha1",sha.toLower()},{"jar",jar},{"md5",QString::fromLatin1(result)}};
    return result;
}
bool copy(const QString& from,const QString& to,const std::shared_ptr<std::atomic_bool>& cancel){
    if(QFileInfo(from).absoluteFilePath()==QFileInfo(to).absoluteFilePath())return true;
    QFile input(from);if(!input.open(QIODevice::ReadOnly)||!QDir().mkpath(QFileInfo(to).absolutePath()))return false;
    QSaveFile output(to);if(!output.open(QIODevice::WriteOnly))return false;
    while(!input.atEnd()){if(*cancel)return false;auto bytes=input.read(1024*1024);if(bytes.isEmpty()&&input.error()!=QFile::NoError)return false;if(output.write(bytes)!=bytes.size())return false;}
    return !*cancel&&output.commit();
}
}
ResourceReuseTask::ResourceReuseTask(MinecraftInstance* instance):m_instance(instance){setObjectName(tr("本地资源检查"));setProperty("taskIcon","fact_check");DesktopBridge::trackTask(this);}
bool ResourceReuseTask::abort(){*m_cancelled=true;if(isRunning())emitAborted();return true;}
QVariantMap ResourceReuseTask::reuse(const QVariantList& files,const QString& assetSource,const QString& assetTarget,const QString& indexId,const QString& indexSha,const std::shared_ptr<std::atomic_bool>& cancelled,const std::shared_ptr<std::atomic_int>& progress,const QString& ledgerPath,bool quickAssets){
    QVariantList verified;QStringList badAssets;int reused=0,missing=0,hashed=0,referencedAssets=0;QString readOnlyAssets;
    const auto ledger=!ledgerPath.isEmpty()?ledgerPath:assetTarget.isEmpty()?QString():QDir(assetTarget).filePath(".deeraft-verified.json");
    QFile previous(ledger);QJsonObject memo;if(!ledger.isEmpty()&&previous.open(QIODevice::ReadOnly))memo=QJsonDocument::fromJson(previous.readAll()).object();previous.close();
    auto ensure=[&](const QString& target,const QStringList& sources,const QString& sha,const QString& base,const QString& relative){
        if(*cancelled)return false;
        const bool jar=base=="libraries"||base.startsWith("directory-libraries-");
        auto hash=digest(target,sha,cancelled,jar,memo,hashed);bool existed=QFileInfo::exists(target);
        if(hash.isEmpty())for(const auto& source:sources){hash=digest(source,sha,cancelled,jar,memo,hashed);if(!hash.isEmpty()&&copy(source,target,cancelled)){memo.remove(QFileInfo(target).absoluteFilePath());hash=digest(target,sha,cancelled,jar,memo,hashed);if(!hash.isEmpty()){++reused;break;}}hash.clear();}
        ++*progress;
        if(hash.isEmpty()){++missing;if(existed&&base=="objects")badAssets.append(target);if(base!="objects")verified.append(QVariantMap{{"base",base},{"relative",relative},{"valid",false}});return false;}
        if(base!="objects")verified.append(QVariantMap{{"base",base},{"relative",relative},{"valid",true},{"md5",hash},{"modified",QFileInfo(target).lastModified().toMSecsSinceEpoch()}});
        return true;
    };
    for(const auto& value:files){auto f=value.toMap();ensure(f["target"].toString(),f["sources"].toStringList(),f["sha1"].toString(),f.value("base","libraries").toString(),f["relative"].toString());if(*cancelled)break;}
    if(!indexId.isEmpty()&&!indexId.contains('/')&&!indexId.contains('\\')&&indexId!=".."){
        const auto relative=indexId+".json",target=QDir(assetTarget).filePath("indexes/"+relative);
        const auto source=QDir(assetSource).filePath("indexes/"+relative);
        const auto local=digest(source,QString(),cancelled,false,memo,hashed);
        if(!local.isEmpty()){
            QFile file(source);file.open(QIODevice::ReadOnly);const auto index=QJsonDocument::fromJson(file.readAll()).object();const auto objects=index["objects"].toObject();
            bool complete=!index["virtual"].toBool()&&!index["map_to_resources"].toBool();
            if(complete)for(const auto& item:objects){if(*cancelled){complete=false;break;}const auto object=item.toObject();const auto hash=object["hash"].toString();const auto path=QDir(assetSource).filePath("objects/"+hash.left(2)+"/"+hash);const QFileInfo info(path);if(quickAssets){if(!info.isFile()||info.size()!=object["size"].toDouble()){complete=false;++missing;}}else if(digest(path,hash,cancelled,false,memo,hashed).isEmpty()){complete=false;break;}++*progress;}
            if(complete){readOnlyAssets=QDir(assetSource).absolutePath();referencedAssets=objects.size();}
        }
        if(readOnlyAssets.isEmpty()&&!(quickAssets&&QFileInfo(assetSource).absoluteFilePath()==QFileInfo(assetTarget).absoluteFilePath()&&!local.isEmpty())){
        if(!local.isEmpty()&&local!=digest(target,QString(),cancelled,false,memo,hashed)&&copy(source,target,cancelled)){memo.remove(QFileInfo(target).absoluteFilePath());++reused;}
        // Imported installed indexes can legitimately precede upstream language-only updates.
        if(ensure(target,{source},local.isEmpty()?indexSha:QString(),"asset_indexes",relative)){
            QFile index(target);if(index.open(QIODevice::ReadOnly)){
                const auto objects=QJsonDocument::fromJson(index.readAll()).object().value("objects").toObject();
                for(auto it=objects.begin();it!=objects.end()&&!*cancelled;++it){auto o=it.value().toObject();auto sha=o["hash"].toString();if(sha.size()!=40||QByteArray::fromHex(sha.toLatin1()).size()!=20)continue;auto path="objects/"+sha.left(2)+"/"+sha;ensure(QDir(assetTarget).filePath(path),{QDir(assetSource).filePath(path)},sha,"objects",path);}
            }
        }
        }
    }
    if(!ledger.isEmpty()&&!*cancelled){QDir().mkpath(QFileInfo(ledger).absolutePath());QSaveFile file(ledger);if(file.open(QIODevice::WriteOnly)){file.write(QJsonDocument(memo).toJson(QJsonDocument::Compact));file.commit();}}
    return {{"verified",verified},{"badAssets",badAssets},{"reused",reused},{"missing",missing},{"hashedFiles",hashed},{"readOnlyAssets",readOnlyAssets},{"referencedAssets",referencedAssets}};
}
void ResourceReuseTask::executeTask(){
    if(!m_instance->property("deeraftDirectoryInstance").toBool()){emitSucceeded();return;}
    setStatus(tr("校验并复用本地资源"));
    const auto profile=m_instance->getPackProfile()->getProfile();
    const auto sourceLibraries=m_instance->property("deeraftSourceLibraries").toString();
    const auto targetLibraries=m_instance->librariesPath().absolutePath();
    QList<LibraryPtr> libraries=profile->getLibraries()+profile->getNativeLibraries()+profile->getMavenFiles();libraries.append(profile->getMainJar());for(const auto& agent:profile->getAgents())libraries.append(agent.library);
    QVariantList plan;QSet<QString> seen;
    for(const auto& library:libraries){if(!library||library->isLocal()||!library->isActive(m_instance->runtimeContext()))continue;QStringList jar,native,n32,n64;library->getApplicableFiles(m_instance->runtimeContext(),jar,native,n32,n64,m_instance->getLocalLibraryPath());for(const auto& target:jar+native+n32+n64){auto relative=safeRelative(targetLibraries,target);if(relative.isEmpty()||seen.contains(target))continue;seen.insert(target);QStringList sources{QDir(sourceLibraries).filePath(relative)};for(const auto& candidate:library->sourcePaths(m_instance->runtimeContext(),target)){const auto path=QDir(sourceLibraries).filePath(candidate);if(!safeRelative(sourceLibraries,path).isEmpty())sources.append(path);}if(library==profile->getMainJar()&&!m_instance->property("deeraftSourceClient").toString().isEmpty())sources.prepend(m_instance->property("deeraftSourceClient").toString());plan.append(QVariantMap{{"base",m_instance->runtimeContext().librariesCacheBase.isEmpty()?QStringLiteral("libraries"):m_instance->runtimeContext().librariesCacheBase},{"target",target},{"sources",sources},{"relative",relative},{"sha1",library->expectedSha1(m_instance->runtimeContext(),target)}});}}
    const auto assets=profile->getMinecraftAssets();
    auto progress=std::make_shared<std::atomic_int>(0);auto timer=new QTimer(this);timer->setInterval(100);connect(timer,&QTimer::timeout,this,[this,progress]{setStatus(tr("已检查 %1 个本地文件").arg(progress->load()));});timer->start();
    auto watcher=new QFutureWatcher<QVariantMap>(this);connect(watcher,&QFutureWatcher<QVariantMap>::finished,this,[this,watcher,timer]{timer->stop();const auto result=watcher->result();watcher->deleteLater();if(!isRunning())return;for(const auto& value:result["verified"].toList()){auto r=value.toMap();auto entry=APPLICATION->metacache()->resolveEntry(r["base"].toString(),r["relative"].toString());entry->setStale(!r["valid"].toBool());if(r["valid"].toBool()){entry->setMD5Sum(QString::fromLatin1(r["md5"].toByteArray()));entry->setLocalChangedTimestamp(r["modified"].toLongLong());entry->makeEternal(true);}if(r["valid"].toBool())APPLICATION->metacache()->updateEntry(entry);}qInfo()<<"Local resource reuse:"<<result["reused"].toInt()<<"copied,"<<result["missing"].toInt()<<"missing,"<<result["hashedFiles"].toInt()<<"hashed";m_instance->setProperty("deeraftAssetsRoot",m_instance->property("deeraftSourceAssets"));m_instance->setProperty("deeraftAssetsComplete",!result["readOnlyAssets"].toString().isEmpty());m_instance->setProperty("deeraftBadAssets",result["badAssets"]);setStatus(result["missing"].toInt()?tr("需要补充 %1 个文件").arg(result["missing"].toInt()):tr("本地资源已就绪"));emitSucceeded();});
    watcher->setFuture(QtConcurrent::run(&ResourceReuseTask::reuse,plan,m_instance->property("deeraftSourceAssets").toString(),m_instance->property("deeraftSourceAssets").toString(),assets?assets->id:QString(),assets?assets->sha1:QString(),m_cancelled,progress,QDir(APPLICATION->dataRoot()).filePath("cache/resource-checks-"+QString::fromLatin1(QCryptographicHash::hash(sourceLibraries.toUtf8(),QCryptographicHash::Sha256).toHex())+".json"),true));
}

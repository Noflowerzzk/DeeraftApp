#include "DesktopBridge.h"
#include "Application.h"
#include "InstanceList.h"
#include "compat/ExternalGameCatalog.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/PackProfile.h"
#include "minecraft/Component.h"
#include "minecraft/MojangVersionFormat.h"
#include "minecraft/OneSixVersionFormat.h"
#include <QProcess>
#include "settings/INISettingsObject.h"
#include "settings/Setting.h"
#include <QCryptographicHash>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>
#include <QSaveFile>

namespace {
class DirectoryInstance final : public MinecraftInstance {
public:
    DirectoryInstance(SettingsObject* global,std::unique_ptr<SettingsObject> settings,const QString& metadata,const QString& game)
        :MinecraftInstance(global,std::move(settings),metadata),m_game(game){}
    QString gameRoot() const override{const auto custom=m_settings->get("DeeraftGameDirectory").toString();return custom.isEmpty()?m_game:custom;}
private:
    QString m_game;
};
}

DesktopBridge::~DesktopBridge()=default;
void DesktopBridge::loadInstanceDirectories(){
    // Listing directories must not initialize every instance, copy its libraries or resolve dependencies.
    // Native objects are created only for the selected instance or an explicit launch/settings action.
    emit changed();
}

BaseInstance* DesktopBridge::resolveDirectoryReference(const QString& reference)const{
    if(reference.startsWith("external:"))return resolveInstance(reference);
    if(auto instance=APPLICATION->instances()->getInstanceById(reference))return instance;
    const auto catalog=parent()->findChild<Deeraft::ExternalGameCatalog*>();if(!catalog)return nullptr;
    for(const auto& value:catalog->versions()){
        const auto row=value.toMap();const auto id="external:"+row.value("rootId").toString()+":"+row.value("id").toString();
        if(QString::fromLatin1(QCryptographicHash::hash(id.toUtf8(),QCryptographicHash::Sha256).toHex())==reference)return resolveInstance(id);
    }
    return nullptr;
}

BaseInstance* DesktopBridge::resolveInstance(const QString& id) const {
    if(!id.startsWith("external:"))return APPLICATION->instances()->getInstanceById(id);
    if(auto found=m_externalInstances.find(id);found!=m_externalInstances.end())return found->second.data();
    if(auto existing=APPLICATION->instances()->getInstanceById(id)){m_externalInstances.emplace(id,existing);return existing;}
    const auto fields=id.split(':');if(fields.size()!=3)return nullptr;
    auto catalog=parent()->findChild<Deeraft::ExternalGameCatalog*>();if(!catalog)return nullptr;
    const auto row=catalog->resolveVersion(fields[1],fields[2]);
    if(row.value("version").toString().isEmpty())return nullptr;
    const auto directory=APPLICATION->dataRoot()+"/directory-instances/"+QString::fromLatin1(QCryptographicHash::hash(id.toUtf8(),QCryptographicHash::Sha256).toHex());
    QDir().mkpath(directory);
    const bool prism=row.value("format").toString()=="prism";
    const bool existing=QFileInfo::exists(directory+"/instance.cfg");
    const auto source=row.value("instanceDirectory").toString();
    // Only metadata is mirrored. Existing mods, worlds and configs stay in their original directory.
    if(prism && !QFileInfo::exists(directory+"/instance.cfg"))QFile::copy(source+"/instance.cfg",directory+"/instance.cfg");
    if(prism && !QFileInfo::exists(directory+"/mmc-pack.json")) {
        QFile::copy(source+"/mmc-pack.json",directory+"/mmc-pack.json");
        QDirIterator patches(source+"/patches",QStringList{"*.json"},QDir::Files,QDirIterator::Subdirectories);
        while(patches.hasNext()){
            const auto from=patches.next();const auto to=directory+"/patches/"+QDir(source+"/patches").relativeFilePath(from);
            QDir().mkpath(QFileInfo(to).absolutePath());QFile::copy(from,to);
        }
        for(const auto& folder:{QStringLiteral("libraries"),QStringLiteral("jarmods")}){
            const auto base=QFileInfo(source+"/"+folder).canonicalFilePath();if(base.isEmpty())continue;
            QDirIterator files(base,QDir::Files,QDirIterator::Subdirectories);
            while(files.hasNext()){
                const auto from=files.next();const auto canonical=QFileInfo(from).canonicalFilePath();
                if(canonical.isEmpty()||QDir(base).relativeFilePath(canonical).startsWith("../"))continue;
                const auto to=directory+"/"+folder+"/"+QDir(base).relativeFilePath(from);
                QDir().mkpath(QFileInfo(to).absolutePath());if(!QFile::copy(from,to))return nullptr;
            }
        }
    }
    if(!QFileInfo::exists(directory+"/mmc-pack.json")) {
        QJsonArray components{QJsonObject{{"uid","net.minecraft"},{"version",row.value("version").toString()},{"important",true}}};
        const auto loader=row.value("loader").toString();const auto split=loader.indexOf(' ');
        const QMap<QString,QString> uids{{"Fabric","net.fabricmc.fabric-loader"},{"Forge","net.minecraftforge"},{"NeoForge","net.neoforged"},{"Quilt","org.quiltmc.quilt-loader"},{"OptiFine","optifine.OptiFine"}};
        if(split>0 && uids.contains(loader.left(split)))components.append(QJsonObject{{"uid",uids[loader.left(split)]},{"version",loader.mid(split+1)}});
        if(loader.startsWith("OptiFine ")){
            const auto json=QJsonObject::fromVariantMap(row.value("versionJson").toMap());
            for(const auto& item:json.value("patches").toArray()){
                const auto data=item.toObject();if(data.value("id").toString().compare("optifine",Qt::CaseInsensitive)!=0)continue;
                auto patch=MojangVersionFormat::versionFileFromJson(QJsonDocument(data),"OptiFine");
                patch->uid="optifine.OptiFine";patch->name="OptiFine";patch->version=loader.mid(9);patch->minecraftVersion.clear();patch->order=100;
                auto arguments=QProcess::splitCommand(data.value("minecraftArguments").toString());
                for(const auto& arg:data.value("arguments").toObject().value("game").toArray())if(arg.isString())arguments.append(arg.toString());
                for(int i=0;i+1<arguments.size();++i)if(arguments[i]=="--tweakClass")patch->addTweakers.append(arguments[i+1]);
                const auto rawLibraries=data.value("libraries").toArray();
                for(int i=0;i<patch->libraries.size() && i<rawLibraries.size();++i){
                    const auto lib=rawLibraries[i].toObject();const auto parts=lib.value("name").toString().split(':');if(parts.size()<3)continue;
                    auto relative=lib.value("downloads").toObject().value("artifact").toObject().value("path").toString();
                    if(relative.isEmpty()){auto group=parts[0];group.replace('.','/');relative=group+"/"+parts[1]+"/"+parts[2]+"/"+parts[1]+"-"+parts[2]+(parts.size()>3?"-"+parts[3]:"")+".jar";}
                    const auto libraryRoot=QFileInfo(row.value("librariesDirectory").toString()).canonicalFilePath();
                    const auto from=QFileInfo(QDir(libraryRoot).filePath(relative)).canonicalFilePath();
                    if(libraryRoot.isEmpty() || from.isEmpty() || !relative.endsWith(".jar",Qt::CaseInsensitive)
                       || QDir(libraryRoot).relativeFilePath(from).startsWith("../") || QDir::isAbsolutePath(relative))continue;
                    QDir().mkpath(directory+"/libraries");const auto to=directory+"/libraries/"+QFileInfo(relative).fileName();
                    if(!QFileInfo::exists(to) && !QFile::copy(from,to))return nullptr;
                    patch->libraries[i]->setHint("local");
                }
                QDir().mkpath(directory+"/patches");QSaveFile file(directory+"/patches/optifine.OptiFine.json");
                if(!file.open(QIODevice::WriteOnly))return nullptr;
                file.write(OneSixVersionFormat::versionFileToJson(patch).toJson());
                if(!file.commit())return nullptr;
            }
        }
        QSaveFile pack(directory+"/mmc-pack.json");if(!pack.open(QIODevice::WriteOnly))return nullptr;
        pack.write(QJsonDocument(QJsonObject{{"formatVersion",1},{"components",components}}).toJson());if(!pack.commit())return nullptr;
    }
    auto settings=std::make_unique<INISettingsObject>(directory+"/instance.cfg");
    const auto game=row.value("gameDirectory").toString();
    auto instance=std::make_unique<DirectoryInstance>(APPLICATION->settings(),std::move(settings),directory,game.isEmpty()?row.value("root").toString():game);
    if(!existing)instance->setName(row.value("name",fields[2]).toString());
    instance->setProperty("deeraftDirectoryInstance",true);
    instance->setProperty("deeraftSourceLibraries",row.value("librariesDirectory"));
    instance->setProperty("deeraftSourceAssets",row.value("assetsDirectory"));
    instance->setProperty("deeraftSourceClient",row.value("clientJar"));
    instance->setProperty("deeraftRootId",fields[1]);instance->setProperty("deeraftVersionId",fields[2]);
    instance->setProperty("deeraftNeedsDirectory",!row.value("valid").toBool());
    auto raw=instance.get();auto self=const_cast<DesktopBridge*>(this);
    raw->settings()->set("InstanceType","OneSix");
    // Publish ownership/cache before loading any model. QML resource requests can re-enter this method.
    APPLICATION->instances()->registerDirectoryInstance(id,std::move(instance));
    m_externalInstances.emplace(id,raw);
    raw->getPackProfile()->loadLocalComponents();
    QObject::connect(raw->getPackProfile(),&QAbstractItemModel::modelReset,self,&DesktopBridge::changed,Qt::QueuedConnection);
    QObject::connect(raw->getPackProfile(),&QAbstractItemModel::dataChanged,self,&DesktopBridge::changed,Qt::QueuedConnection);
    QObject::connect(raw->settings()->getSetting("DeeraftGameDirectory").get(),&Setting::SettingChanged,self,[catalog,fields,raw,self](const Setting&,const QVariant& value){
        const auto directory=value.toString();if(directory.isEmpty())return;
        QVariantMap directories;for(const auto& value:catalog->roots()){const auto root=value.toMap();if(root.value("id").toString()==fields[1])directories=root.value("options").toMap().value("versionDirectories").toMap();}
        directories[fields[2]]=directory;catalog->setRootOptions(fields[1],{{"versionDirectories",directories}});raw->setProperty("deeraftNeedsDirectory",false);emit self->changed();
    });
    QObject::connect(raw,&BaseInstance::propertiesChanged,self,&DesktopBridge::changed);
    QObject::connect(raw,&BaseInstance::minecraftStarted,self,[self,raw]{emit self->gameStarted(raw->name(),qobject_cast<MinecraftInstance*>(raw)->getPackProfile()->getComponentVersion("net.minecraft"));emit self->changed();});
    QObject::connect(raw,&BaseInstance::runningStatusChanged,self,[self]{emit self->changed();});
    return raw;
}

QVariantMap DesktopBridge::externalStates() const {
    QVariantMap result;
    for(const auto& [id,instance]:m_externalInstances){
        if(!instance)continue;
        QString loader;auto profile=qobject_cast<MinecraftInstance*>(instance.data())->getPackProfile();
        const auto versionOf=[profile](const QString& uid){auto value=profile->getComponentVersion(uid);if(value.isEmpty())if(auto component=profile->getComponent(uid))value=component->m_version;return value;};
        const QMap<QString,QString> names{{"net.fabricmc.fabric-loader","Fabric"},{"net.minecraftforge","Forge"},{"net.neoforged","NeoForge"},{"org.quiltmc.quilt-loader","Quilt"},{"optifine.OptiFine","OptiFine"}};
        for(auto it=names.begin();it!=names.end();++it){const auto value=versionOf(it.key());if(!value.isEmpty())loader=it.value()+" "+value;}
        result[id]=QVariantMap{{"name",instance->name()},{"icon",instance->iconKey()},{"version",versionOf("net.minecraft")},{"loader",loader},{"running",instance->isRunning()},{"seconds",instance->totalTimePlayed()},{"maxMemory",instance->settings()->get("MaxMemAlloc")},{"javaVersion",instance->settings()->get("JavaVersion")}};
    }
    return result;
}

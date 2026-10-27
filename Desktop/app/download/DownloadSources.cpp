#include "DownloadSources.h"
#include "Application.h"
#include <QSettings>
QString DownloadSources::s_settingsPath;
DownloadSources::DownloadSources(const QString& dir,QObject* parent):QObject(parent){s_settingsPath=dir+"/desktop.ini";}
int DownloadSources::currentMode(){const QString path=s_settingsPath.isEmpty()&&APPLICATION?APPLICATION->dataRoot()+"/desktop.ini":s_settingsPath;return path.isEmpty()?0:QSettings(path,QSettings::IniFormat).value("downloadSource",0).toInt();}
int DownloadSources::mode()const{return currentMode();}
void DownloadSources::setMode(int value){if(value<0||value>2)return;QSettings(s_settingsPath,QSettings::IniFormat).setValue("downloadSource",value);emit changed();}
QUrl DownloadSources::mirror(const QUrl& original){
    if(currentMode()==2 || original.scheme()!="https" || !original.userInfo().isEmpty() || original.hasQuery() || original.hasFragment())return original;
    auto host=original.host().toLower();QString prefix;
    if(host=="resources.download.minecraft.net")prefix="/assets";
    else if(host=="libraries.minecraft.net"||host=="maven.minecraftforge.net"||host=="maven.fabricmc.net")prefix="/maven";
    else if(host=="maven.neoforged.net" && original.path().startsWith("/releases/")){
        auto result=original;result.setHost("bmclapi2.bangbang93.com");result.setPath("/maven"+original.path().mid(9));return result;
    }
    else if(host=="piston-data.mojang.com"||host=="piston-meta.mojang.com"||host=="launcher.mojang.com"||host=="launchermeta.mojang.com")prefix="";
    else if(host=="meta.fabricmc.net")prefix="/fabric-meta";
    else return original;
    auto result=original;result.setHost("bmclapi2.bangbang93.com");result.setPath(prefix+original.path());return result;
}

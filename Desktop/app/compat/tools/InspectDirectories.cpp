#include "ExternalGameCatalog.h"
#include <QCoreApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDir>
#include <QTextStream>
int main(int argc,char** argv){
    QCoreApplication app(argc,argv);QJsonArray roots;
    for(const auto& path:app.arguments().mid(1)){
        QJsonArray instances;
        for(const auto& value:Deeraft::ExternalVersionResolver::scan(path)){
            const auto row=value.toMap();const auto game=row.value("gameDirectory").toString();QJsonObject out;
            for(const auto& key:{"id","name","version","loader","gameDirectory","valid","error"})if(row.contains(key))out[key]=QJsonValue::fromVariant(row.value(key));
            out["mods"]=QDir(game+"/mods").entryList(QStringList{"*.jar","*.jar.disabled"},QDir::Files).size();
            out["worlds"]=QDir(game+"/saves").entryList(QDir::Dirs|QDir::NoDotAndDotDot).size();instances.append(out);
        }
        roots.append(QJsonObject{{"path",path},{"instances",instances}});
    }
    QTextStream(stdout)<<QJsonDocument(roots).toJson();return 0;
}

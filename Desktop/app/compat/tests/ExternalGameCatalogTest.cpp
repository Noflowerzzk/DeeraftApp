#include "ExternalGameCatalog.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QTemporaryDir>
#include <QTest>
#include <QTimer>
#include <QSignalSpy>

using namespace Deeraft;

class ExternalGameCatalogTest final : public QObject
{
    Q_OBJECT

    static bool write(const QString &path, const QByteArray &content)
    {
        if (!QDir().mkpath(QFileInfo(path).absolutePath()))
            return false;
        QFile file(path);
        return file.open(QIODevice::WriteOnly) && file.write(content) == content.size();
    }

    static bool version(const QString &root, const QString &id, const QByteArray &json)
    {
        return write(QDir(root).filePath(QStringLiteral("versions/%1/%1.json").arg(id)), json);
    }

private slots:
    void rejectsWrongAndBrokenDirectoriesWithoutSaving()
    {
        QTemporaryDir temp;ExternalGameCatalog catalog(temp.filePath("data"));
        QVERIFY(catalog.addRoot(temp.filePath("missing")).isEmpty());QVERIFY(catalog.error().contains("不存在"));
        QVERIFY(write(temp.filePath("a-file"),"file"));QVERIFY(catalog.addRoot(temp.filePath("a-file")).isEmpty());QVERIFY(catalog.error().contains("文件夹"));
        const auto empty=temp.filePath("empty/.minecraft");QVERIFY(QDir().mkpath(empty+"/versions"));
        QVERIFY(catalog.addRoot(empty).isEmpty());QVERIFY(catalog.error().contains("没有可识别"));
        const auto single=temp.filePath("instances/one");
        QVERIFY(write(single+"/instance.cfg","[General]\nname=One\n"));
        QVERIFY(write(single+"/mmc-pack.json",R"({"formatVersion":1,"components":[{"uid":"net.minecraft","version":"1.20.1"}]})"));
        QVERIFY(version(single+"/.minecraft","nested",R"({"id":"1.20.1"})"));
        QVERIFY(catalog.addRoot(single).isEmpty());QVERIFY(catalog.error().contains("单个实例"));QVERIFY(catalog.error().contains("上一级"));
        QVERIFY(write(single+"/mmc-pack.json","broken json"));
        QVERIFY(catalog.addRoot(temp.filePath("instances")).isEmpty());QVERIFY(catalog.error().contains("JSON"));
        QVERIFY(catalog.roots().isEmpty());QVERIFY(catalog.versions().isEmpty());
        QVERIFY(!QFileInfo::exists(temp.filePath("data/external-games.json")));
    }

    void importsAsynchronouslyAndRestoresCachedRows()
    {
        QTemporaryDir temp;const auto root=temp.filePath("中文/instances");
        for(int i=0;i<20;++i){const auto instance=root+"/"+QString::number(i);QVERIFY(write(instance+"/instance.cfg","[General]\nname=One\n"));QVERIFY(write(instance+"/mmc-pack.json",R"({"formatVersion":1,"components":[{"uid":"net.minecraft","version":"1.20.1"}]})"));}
        ExternalGameCatalog catalog(temp.filePath("data"));QSignalSpy finished(&catalog,&ExternalGameCatalog::importFinished);
        bool eventLoopAvailable=false;QTimer::singleShot(0,this,[&]{eventLoopAvailable=true;});
        catalog.addRootAsync(root);QVERIFY(catalog.scanning());QVERIFY(catalog.roots().isEmpty());
        QTRY_COMPARE(finished.size(),1);QVERIFY(eventLoopAvailable);QVERIFY(!catalog.scanning());
        QCOMPARE(catalog.versions().size(),20);QCOMPARE(catalog.roots().size(),1);
        ExternalGameCatalog restored(temp.filePath("data"));QCOMPARE(restored.roots().size(),1);QVERIFY(restored.versions().isEmpty());
        QTRY_COMPARE(restored.versions().size(),20);
        QSignalSpy errors(&catalog,&ExternalGameCatalog::importFailed);
        catalog.addRootAsync(temp.filePath("missing"));QTRY_COMPARE(errors.size(),1);
        catalog.addRootAsync(temp.filePath("missing"));QTRY_COMPARE(errors.size(),2);
        QCOMPARE(catalog.versions().size(),20);QCOMPARE(catalog.roots().size(),1);QVERIFY(!catalog.scanning());
        catalog.addRootAsync(root);QVERIFY(catalog.removeRoot(ExternalVersionResolver::rootId(root)));
        QTest::qWait(50);QVERIFY(catalog.roots().isEmpty());QVERIFY(catalog.versions().isEmpty());QVERIFY(!catalog.scanning());
    }

    void readsHmclComponentsAndPrismDirectories()
    {
        QTemporaryDir temp;
        const auto game=temp.filePath("中文/.minecraft");
        QVERIFY(version(game,"my-fabric",R"({"id":"my-fabric","mainClass":"net.fabricmc.loader.impl.launch.knot.KnotClient","patches":[{"id":"game","version":"1.17.1"},{"id":"fabric","version":"0.17.3"}],"libraries":[{"name":"net.fabricmc:fabric-loader:0.17.3"}]})"));
        auto row=ExternalVersionResolver::resolve(game,"my-fabric");
        QCOMPARE(row.value("version").toString(),QString("1.17.1"));
        QCOMPARE(row.value("loader").toString(),QString("Fabric 0.17.3"));
        const auto instances=temp.filePath("Prism/instances");
        QVERIFY(write(instances+"/同名/instance.cfg","[General]\nname=Sample\niconKey=grass\nUnknownSetting=keep\n"));
        QVERIFY(write(instances+"/同名/mmc-pack.json",R"({"formatVersion":1,"components":[{"uid":"net.minecraft","version":"1.20.1"},{"uid":"net.minecraftforge","version":"47.3.0"}]})"));
        QVERIFY(QDir().mkpath(instances+"/同名/.minecraft/saves"));
        auto prism=ExternalVersionResolver::scan(instances);
        QCOMPARE(prism.size(),1);auto p=prism.first().toMap();
        QCOMPARE(p.value("version").toString(),QString("1.20.1"));
        QCOMPARE(p.value("loader").toString(),QString("Forge 47.3.0"));
        QCOMPARE(p.value("gameDirectory").toString(),instances+"/同名/.minecraft");
        QCOMPARE(ExternalVersionResolver::normalizeRoot(temp.filePath("Prism")),instances);
        ExternalGameCatalog catalog(temp.filePath("data"));QVERIFY(!catalog.addRoot(instances).isEmpty());
        QFile original(instances+"/同名/instance.cfg");QVERIFY(original.open(QIODevice::ReadOnly));QVERIFY(original.readAll().contains("UnknownSetting=keep"));
    }
    void inheritsSharedResourcesAndArguments()
    {
        QTemporaryDir temp;
        QVERIFY(temp.isValid());
        const auto root = temp.filePath(QStringLiteral("中文/.minecraft"));
        QVERIFY(version(root, "base", R"({"id":"base","mainClass":"net.minecraft.client.main.Main","type":"release","arguments":{"game":["--username","${auth_player_name}"]},"libraries":[{"name":"a:b:1"},{"name":"c:d:1"}],"assetIndex":{"id":"test"}})"));
        QVERIFY(version(root, "fabric", R"({"id":"fabric","inheritsFrom":"base","mainClass":"net.fabricmc.loader.impl.launch.knot.KnotClient","arguments":{"game":["--demo"],"jvm":["-Dtest=true"]},"libraries":[{"name":"a:b:2"}]})"));
        QVERIFY(write(QDir(root).filePath("versions/base/base.jar"), "client"));
        auto result = ExternalVersionResolver::resolve(root, "fabric");
        QVERIFY(result.value("valid").toBool());
        QCOMPARE(result.value("gameDirectory").toString(), QDir::cleanPath(root));
        QCOMPARE(result.value("clientJar").toString(), QDir(root).filePath("versions/base/base.jar"));
        QCOMPARE(result.value("assetsDirectory").toString(), QDir(root).filePath("assets"));
        QCOMPARE(result.value("inheritance").toStringList(), QStringList({"base", "fabric"}));
        const auto json = QJsonObject::fromVariantMap(result.value("versionJson").toMap());
        QCOMPARE(json.value("libraries").toArray().size(), 2);
        QCOMPARE(json.value("arguments").toObject().value("game").toArray().size(), 3);
        QCOMPARE(json.value("mainClass").toString(), QString("net.fabricmc.loader.impl.launch.knot.KnotClient"));
        QCOMPARE(ExternalVersionResolver::normalizeRoot(temp.filePath(QStringLiteral("中文"))), QDir::cleanPath(root));
    }

    void rejectsCyclesAndTraversal()
    {
        QTemporaryDir temp;
        QVERIFY(version(temp.path(), "a", R"({"id":"a","inheritsFrom":"b"})"));
        QVERIFY(version(temp.path(), "b", R"({"id":"b","inheritsFrom":"a"})"));
        QVERIFY(!ExternalVersionResolver::resolve(temp.path(), "a").value("valid").toBool());
        QVERIFY(!ExternalVersionResolver::resolve(temp.path(), "../outside").value("valid").toBool());
        QVERIFY(version(temp.path(), "bad", R"({"id":"bad","inheritsFrom":"../outside"})"));
        QVERIFY(!ExternalVersionResolver::resolve(temp.path(), "bad").value("valid").toBool());
    }

    void pclIsolationDoesNotRewriteOriginal()
    {
        QTemporaryDir temp;
        QVERIFY(version(temp.path(), "base", R"({"id":"base","type":"release"})"));
        const auto settingsPath = temp.filePath("versions/base/PCL/Setup.ini");
        const QByteArray settings("VersionArgumentIndieV2=True\r\nUnknownKey=keep\\this\r\n");
        QVERIFY(write(settingsPath, settings));
        auto result = ExternalVersionResolver::resolve(temp.path(), "base");
        QCOMPARE(result.value("source").toString(), QString("PCL"));
        QCOMPARE(result.value("gameDirectory").toString(), temp.filePath("versions/base"));
        QFile file(settingsPath);
        QVERIFY(file.open(QIODevice::ReadOnly));
        QCOMPARE(file.readAll(), settings);
        file.close();
        QVERIFY(write(settingsPath, "VersionArgumentIndie=2\n"));
        QCOMPARE(ExternalVersionResolver::resolve(temp.path(), "base").value("gameDirectory").toString(), temp.path());
    }

    void pclGlobalAndDetectedIsolation()
    {
        QTemporaryDir temp;
        QVERIFY(version(temp.path(), "snapshot", R"({"id":"snapshot","type":"snapshot"})"));
        QVERIFY(write(temp.filePath("versions/snapshot/PCL/Setup.ini"), "VersionArgumentIndie=0\n"));
        QCOMPARE(ExternalVersionResolver::resolve(temp.path(), "snapshot", {{"pclIsolation", 0}}).value("gameDirectory").toString(), temp.path());
        QCOMPARE(ExternalVersionResolver::resolve(temp.path(), "snapshot", {{"pclIsolation", 2}}).value("gameDirectory").toString(), temp.filePath("versions/snapshot"));
        QVERIFY(write(temp.filePath("versions/snapshot/mods/test.jar"), "mod"));
        QCOMPARE(ExternalVersionResolver::resolve(temp.path(), "snapshot", {{"pclIsolation", 0}}).value("gameDirectory").toString(), temp.filePath("versions/snapshot"));
    }

    void hmclLegacyAndGlobalConfirmation()
    {
        QTemporaryDir temp;
        QVERIFY(version(temp.path(), "base", R"({"id":"base"})"));
        const auto cfg = temp.filePath("versions/base/hmclversion.cfg");
        QVERIFY(write(cfg, R"({"usesGlobal":false,"gameDirType":1})"));
        QCOMPARE(ExternalVersionResolver::resolve(temp.path(), "base").value("gameDirectory").toString(), temp.filePath("versions/base"));
        QVERIFY(write(cfg, R"({"usesGlobal":false,"gameDirType":"CUSTOM","gameDir":"custom game"})"));
        QCOMPARE(ExternalVersionResolver::resolve(temp.path(), "base").value("gameDirectory").toString(), temp.filePath("custom game"));
        QVERIFY(write(cfg, R"({"usesGlobal":true,"gameDirType":1})"));
        QVERIFY(!ExternalVersionResolver::resolve(temp.path(), "base").value("valid").toBool());
        QVariantMap options{{"hmclGlobalSettings", QVariantMap{{"gameDirType", "ROOT_FOLDER"}}}};
        QCOMPARE(ExternalVersionResolver::resolve(temp.path(), "base", options).value("gameDirectory").toString(), temp.path());
    }

    void hmclModernDirectoryOverride()
    {
        QTemporaryDir temp;
        QVERIFY(version(temp.path(), "base", R"({"id":"base"})"));
        const auto cfg = temp.filePath("versions/base/.hmcl/config/instance-game-settings.json");
        QVERIFY(write(cfg, R"({"parent":"a-preset","overrideProperties":["runningDirectory"],"runningDirectory":""})"));
        QCOMPARE(ExternalVersionResolver::resolve(temp.path(), "base").value("gameDirectory").toString(), temp.filePath("versions/base"));
        QVERIFY(write(cfg, R"({"parent":"a-preset","overrideProperties":[],"runningDirectory":"ignored"})"));
        QVERIFY(!ExternalVersionResolver::resolve(temp.path(), "base").value("valid").toBool());
        QCOMPARE(ExternalVersionResolver::resolve(temp.path(), "base", {{"hmclRunningDirectory", "confirmed"}}).value("gameDirectory").toString(), temp.filePath("confirmed"));
    }

    void catalogPersistsSeparatelyAndLocksSharedDirectory()
    {
        QTemporaryDir temp;
        const auto root = temp.filePath("game");
        const auto data = temp.filePath("data");
        QVERIFY(version(root, "a", R"({"id":"a"})"));
        QVERIFY(version(root, "b", R"({"id":"b"})"));
        ExternalGameCatalog catalog(data);
        const auto id = catalog.addRoot(root);
        QVERIFY(!id.isEmpty());
        QCOMPARE(catalog.roots().size(), 1);
        ExternalGameCatalog reopened(data);
        QCOMPARE(reopened.roots().size(), 1);
        const auto key = catalog.acquireLaunchLock(id, "a");
        QVERIFY(!key.isEmpty());
        QVERIFY(catalog.acquireLaunchLock(id, "b").isEmpty());
        QVERIFY(reopened.acquireLaunchLock(id, "a").isEmpty());
        catalog.releaseLaunchLock(key);
        const auto secondKey = reopened.acquireLaunchLock(id, "a");
        QVERIFY(!secondKey.isEmpty());
        reopened.releaseLaunchLock(secondKey);
        QVERIFY(catalog.removeRoot(id));
        QVERIFY(QFileInfo::exists(QDir(root).filePath("versions/a/a.json")));
        QVERIFY(!QFileInfo::exists(QDir(root).filePath("instance.cfg")));
    }
};

QTEST_GUILESS_MAIN(ExternalGameCatalogTest)
#include "ExternalGameCatalogTest.moc"

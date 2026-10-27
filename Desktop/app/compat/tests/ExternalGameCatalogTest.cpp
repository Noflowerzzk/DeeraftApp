#include "ExternalGameCatalog.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QTemporaryDir>
#include <QTest>

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

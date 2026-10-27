#include <QtTest>
#include <QTemporaryDir>
#include <QFile>
#include <QJsonDocument>
#include <QTcpServer>
#include <QTcpSocket>
#include "library/DesktopLibrary.h"
#include "compat/ExternalGameCatalog.h"
class DesktopLibraryTest:public QObject {
 Q_OBJECT
private slots:
 void persistsIndependentAssociations(){QTemporaryDir directory;Deeraft::ExternalGameCatalog catalog(directory.path()+"/external");
  {DesktopLibrary library(directory.path(),&catalog);QVERIFY(library.associate("community","external:root-a:same-version","mc.example.org:25566"));QVERIFY(library.setMetadata("external:root-a:same-version",{{"favorite",true},{"group","多人游戏"}}));QVERIFY(library.setMetadata("external:root-a:same-version",{{"favorite",false}}));QCOMPARE(library.metadata().value("external:root-a:same-version").toMap()["group"].toString(),QString("多人游戏"));}
  DesktopLibrary restored(directory.path(),&catalog);QCOMPARE(restored.links()["community"].toString(),QString("external:root-a:same-version"));QVERIFY(!restored.metadata().contains("external:root-b:same-version"));QCOMPARE(restored.addresses()["community"].toString(),QString("mc.example.org:25566"));
 }
 void invalidServerKeepsConfiguration(){QTemporaryDir directory;Deeraft::ExternalGameCatalog catalog(directory.path()+"/external");DesktopLibrary library(directory.path(),&catalog);QVERIFY(library.saveServer({},"bad","http://bad.example/path",{}).isEmpty());QVERIFY(library.servers().isEmpty());QVERIFY(!library.error().isEmpty());}
 void failedSaveDoesNotClaimSuccess(){QTemporaryDir directory;Deeraft::ExternalGameCatalog catalog(directory.path()+"/external");DesktopLibrary library(directory.path(),&catalog);QDir().mkdir(directory.path()+"/library.json");QVERIFY(!library.associate("community","native-instance"));QVERIFY(!library.links().contains("community"));}
 void closedPortIsOfflineRatherThanUnknown(){QTemporaryDir directory;Deeraft::ExternalGameCatalog catalog(directory.path()+"/external");DesktopLibrary library(directory.path(),&catalog);QTcpServer reserve;QVERIFY(reserve.listen(QHostAddress::LocalHost));auto port=reserve.serverPort();reserve.close();auto id=library.saveServer({},"Closed local server",QString("127.0.0.1:%1").arg(port),{});QVERIFY(!id.isEmpty());QTRY_COMPARE_WITH_TIMEOUT(library.servers().first().toMap()["status"].toMap()["state"].toString(),QString("offline"),15000);}
 void localStatusAndRemoval(){
  QTemporaryDir directory;Deeraft::ExternalGameCatalog catalog(directory.path()+"/external");DesktopLibrary library(directory.path(),&catalog);QTcpServer server;QVERIFY(server.listen(QHostAddress::LocalHost));
  auto varint=[](int value){QByteArray bytes;do{quint8 byte=value&127;value>>=7;if(value)byte|=128;bytes.append(char(byte));}while(value);return bytes;};
  connect(&server,&QTcpServer::newConnection,this,[&]{auto socket=server.nextPendingConnection();connect(socket,&QTcpSocket::readyRead,socket,[socket,varint]{socket->readAll();if(socket->property("sent").toBool())return;socket->setProperty("sent",true);QByteArray json=R"({"version":{"name":"Test 1.21.4","protocol":769},"players":{"online":3,"max":20},"description":{"text":"local test"}})";QByteArray body=QByteArray(1,char(0))+varint(json.size())+json;socket->write(varint(body.size())+body);});connect(socket,&QTcpSocket::disconnected,socket,&QObject::deleteLater);});
  auto id=library.saveServer({},"Local test",QString("127.0.0.1:%1").arg(server.serverPort()),"native-instance");QVERIFY(!id.isEmpty());
  QTRY_COMPARE_WITH_TIMEOUT(library.servers().first().toMap()["status"].toMap()["state"].toString(),QString("online"),15000);
  auto status=library.servers().first().toMap()["status"].toMap();QCOMPARE(status["online"].toInt(),3);QCOMPARE(status["max"].toInt(),20);QCOMPARE(status["version"].toString(),QString("Test 1.21.4"));
  QVERIFY(library.removeServer(id));QVERIFY(library.servers().isEmpty());QVERIFY(!library.links().contains(id));
 }
};
QTEST_GUILESS_MAIN(DesktopLibraryTest)
#include "DesktopLibraryTest.moc"

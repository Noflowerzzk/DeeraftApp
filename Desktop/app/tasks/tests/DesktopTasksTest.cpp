#include <QtTest>
#include <QNetworkAccessManager>
#include "tasks/ConcurrentTask.h"
#include "net/NetJob.h"
#include "qml_material/anim/spring_motion.hpp"
#include "download/ResourceReuseTask.h"
#include "net/HttpMetaCache.h"
#include "net/MetaCacheSink.h"
#include "net/ChecksumValidator.h"
#include "minecraft/AssetsUtils.h"
#include <QTemporaryDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <archive.h>
#include <archive_entry.h>
class WaitingTask final:public Task {
public:
 bool started=false;
 bool canAbort()const override{return true;}
 bool abort()override{if(isRunning())emitAborted();return true;}
protected:
 void executeTask()override{started=true;}
};
class DesktopTasksTest:public QObject {
 Q_OBJECT
private slots:
 void unsignedLibrariesRequireValidZipCrc(){
  QTemporaryDir dir;char bytes[4096];size_t used=0;
  auto zip=archive_write_new();archive_write_set_format_zip(zip);archive_write_set_options(zip,"zip:compression=store");QCOMPARE(archive_write_open_memory(zip,bytes,sizeof(bytes),&used),ARCHIVE_OK);
  auto entry=archive_entry_new();archive_entry_set_pathname(entry,"test.txt");archive_entry_set_size(entry,7);archive_entry_set_filetype(entry,AE_IFREG);archive_entry_set_perm(entry,0644);QCOMPARE(archive_write_header(zip,entry),ARCHIVE_OK);QCOMPARE(archive_write_data(zip,"payload",7),la_ssize_t(7));archive_entry_free(entry);archive_write_close(zip);archive_write_free(zip);
  QByteArray contents(bytes,used);QFile source(dir.filePath("source.jar"));QVERIFY(source.open(QIODevice::WriteOnly));source.write(contents);source.close();
  const auto target=dir.filePath("target.jar");QVariantList plan{QVariantMap{{"target",target},{"sources",QStringList{source.fileName()}},{"relative","target.jar"},{"sha1",""}}};auto cancel=std::make_shared<std::atomic_bool>(false);auto progress=std::make_shared<std::atomic_int>(0);
  auto run=[&]{return ResourceReuseTask::reuse(plan,"","","","",cancel,progress);};QCOMPARE(run()["reused"].toInt(),1);QFile::remove(target);
  const int payload=contents.indexOf("payload");QVERIFY(payload>=0);contents[payload]='X';QVERIFY(source.open(QIODevice::WriteOnly));source.write(contents);source.close();QCOMPARE(run()["missing"].toInt(),1);QVERIFY(!QFileInfo::exists(target));
 }
 void importedResourcesAreValidatedAndReused(){
  QTemporaryDir dir;auto put=[](const QString& path,const QByteArray& bytes){QDir().mkpath(QFileInfo(path).absolutePath());QFile file(path);if(file.open(QIODevice::WriteOnly))file.write(bytes);};
  const QByteArray library="complete library",object="sound bytes";auto sha=[](const QByteArray& bytes){return QString::fromLatin1(QCryptographicHash::hash(bytes,QCryptographicHash::Sha1).toHex());};
  const auto source=dir.path()+"/原目录",target=dir.path()+"/app-cache";put(source+"/libraries/a.jar",library);
  const auto objectHash=sha(object),relative="objects/"+objectHash.left(2)+"/"+objectHash;put(source+"/assets/"+relative,object);
  const auto index=QJsonDocument(QJsonObject{{"objects",QJsonObject{{"sound",QJsonObject{{"hash",objectHash},{"size",object.size()}}}}}}).toJson();put(source+"/assets/indexes/test.json",index);
  QVariantList plan{QVariantMap{{"target",target+"/libraries/a.jar"},{"sources",QStringList{source+"/libraries/a.jar"}},{"relative","a.jar"},{"sha1",sha(library)}}};
  auto cancelled=std::make_shared<std::atomic_bool>(false);auto progress=std::make_shared<std::atomic_int>(0);
  auto run=[&]{return ResourceReuseTask::reuse(plan,source+"/assets",target+"/assets","test",sha(index),cancelled,progress);};
  const auto first=run();QCOMPARE(first["reused"].toInt(),3);QCOMPARE(first["missing"].toInt(),0);
  const auto second=run();QCOMPARE(second["reused"].toInt(),0);QCOMPARE(second["missing"].toInt(),0);
  const auto legacy=ResourceReuseTask::reuse(plan,source+"/assets",target+"/assets","test","",cancelled,progress);QCOMPARE(legacy["reused"].toInt(),0);QCOMPARE(legacy["missing"].toInt(),0);
  HttpMetaCache cache(target+"/metacache");cache.addBase("libraries",target+"/libraries");cache.addBase("asset_indexes",target+"/assets/indexes");
  for(const auto& value:second["verified"].toList()){auto r=value.toMap();QVERIFY(r["valid"].toBool());auto entry=cache.resolveEntry(r["base"].toString(),r["relative"].toString());entry->setMD5Sum(QString::fromLatin1(r["md5"].toByteArray()));entry->setLocalChangedTimestamp(r["modified"].toLongLong());entry->makeEternal(true);entry->setStale(false);QVERIFY(cache.updateEntry(entry));QNetworkRequest request(QUrl("http://127.0.0.1:1/must-not-download"));Net::MetaCacheSink sink(entry,new Net::ChecksumValidator(QCryptographicHash::Md5),true);QCOMPARE(sink.init(request),Task::State::Succeeded);}
  // Same-sized corrupt assets must be scheduled for repair rather than accepted by size alone.
  put(target+"/assets/"+relative,QByteArray(object.size(),'x'));QFile::remove(source+"/assets/"+relative);
  const auto bad=run();QVERIFY(bad["badAssets"].toStringList().contains(target+"/assets/"+relative));
  AssetObject asset;asset.hash=objectHash;asset.size=object.size();QVERIFY(asset.getDownloadAction(true)!=nullptr);
  QFile original(source+"/libraries/a.jar");QVERIFY(original.open(QIODevice::ReadOnly));QCOMPARE(original.readAll(),library);
  *cancelled=true;QCOMPARE(run()["reused"].toInt(),0);
 }
 void springAdvancesWithoutAnExposedWindow(){qml_material::SpringMotion motion;motion.setSpec({800,.6});motion.snapTo(0);motion.setTargetValue(100);QTRY_VERIFY_WITH_TIMEOUT(motion.value()>0,500);QTRY_VERIFY_WITH_TIMEOUT(!motion.isRunning(),1500);QCOMPARE(motion.value(),100.);}
 void springCanReverseAndReduceMotion(){qml_material::SpringMotion motion;motion.setSpec({380,.8});motion.snapTo(0);motion.setTargetValue(100);QTRY_VERIFY_WITH_TIMEOUT(motion.value()>10,500);motion.setTargetValue(0);QTRY_VERIFY_WITH_TIMEOUT(!motion.isRunning(),1500);QCOMPARE(motion.value(),0.);motion.setTargetValue(100);motion.setEnabled(false);QCOMPARE(motion.value(),100.);QVERIFY(!motion.isRunning());}
 void emptyJobCancellationEndsItsState(){QNetworkAccessManager network;NetJob job("empty",&network);QSignalSpy success(&job,&Task::succeeded);job.start();QVERIFY(job.abort());QCOMPARE(job.getState(),Task::State::AbortedByUser);QCoreApplication::processEvents();QCOMPARE(success.size(),0);}
 void queuedWorkDoesNotStartAfterCancellation(){QNetworkAccessManager network;NetJob job("queued",&network);auto child=makeShared<WaitingTask>();job.addTask(child);job.start();QCoreApplication::sendPostedEvents(&job,QEvent::MetaCall);QVERIFY(job.abort());QCoreApplication::processEvents();QVERIFY(!child->started);QCOMPARE(job.getState(),Task::State::AbortedByUser);}
 void activeWorkIsAbortedWithoutRetry(){QNetworkAccessManager network;NetJob job("active",&network);auto child=makeShared<WaitingTask>();job.addTask(child);job.start();QTRY_VERIFY(child->started);QVERIFY(job.abort());QCOMPARE(child->getState(),Task::State::AbortedByUser);QCOMPARE(job.getState(),Task::State::AbortedByUser);QTest::qWait(30);QCOMPARE(job.getState(),Task::State::AbortedByUser);}
 void sequentialCancellationDoesNotReportSuccess(){ConcurrentTask task("parent",1);auto child=makeShared<WaitingTask>();task.addTask(child);QSignalSpy success(&task,&Task::succeeded);task.start();QVERIFY(task.abort());QCoreApplication::processEvents();QCOMPARE(task.getState(),Task::State::AbortedByUser);QCOMPARE(success.size(),0);QVERIFY(!child->started);}
};
QTEST_GUILESS_MAIN(DesktopTasksTest)
#include "DesktopTasksTest.moc"

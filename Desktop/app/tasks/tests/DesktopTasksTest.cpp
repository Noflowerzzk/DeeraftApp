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
#include "minecraft/Library.h"
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
 void externalResourcesStayInTheirOriginalDirectory(){
  QTemporaryDir dir;
  auto put=[](const QString& path,const QByteArray& bytes){QDir().mkpath(QFileInfo(path).absolutePath());QFile file(path);if(file.open(QIODevice::WriteOnly))file.write(bytes);};
  const auto assets=dir.filePath("original/assets"),library=dir.filePath("original/libraries/example.jar"),ledger=dir.filePath("app/cache/checks.json");
  const QByteArray bytes="installed artifact",sound="installed sound";
  const auto sha=[](const QByteArray& value){return QString::fromLatin1(QCryptographicHash::hash(value,QCryptographicHash::Sha1).toHex());};
  put(library,bytes);const auto hash=sha(sound),object=assets+"/objects/"+hash.left(2)+"/"+hash;
  put(object,sound);put(assets+"/indexes/test.json",QJsonDocument(QJsonObject{{"objects",QJsonObject{{"sound",QJsonObject{{"hash",hash},{"size",sound.size()}}}}}}).toJson());
  const auto modified=QFileInfo(object).lastModified();
  QVariantList files{QVariantMap{{"base","directory-libraries-test"},{"relative","example.jar"},{"target",library},{"sources",QStringList{library}},{"sha1",sha(bytes)}}};
  auto cancel=std::make_shared<std::atomic_bool>(false);auto progress=std::make_shared<std::atomic_int>(0);
  const auto run=[&]{return ResourceReuseTask::reuse(files,assets,assets,"test",QString(40,'0'),cancel,progress,ledger,true);};
  const auto complete=run();QCOMPARE(complete["reused"].toInt(),0);QCOMPARE(complete["readOnlyAssets"].toString(),assets);QCOMPARE(complete["referencedAssets"].toInt(),1);
  QCOMPARE(QFileInfo(object).lastModified(),modified);QVERIFY(!QFileInfo::exists(dir.filePath("app/assets")));QVERIFY(!QFileInfo::exists(dir.filePath("app/libraries")));
  QCOMPARE(run()["hashedFiles"].toInt(),0);
  // Missing resources remain in the external tree and are prepared for repair there.
  QVERIFY(QFile::remove(object));const auto missing=run();QVERIFY(missing["readOnlyAssets"].toString().isEmpty());QCOMPARE(missing["missing"].toInt(),1);
  AssetsIndex index;QVERIFY(AssetsUtils::loadAssetsIndexJson("test",assets+"/indexes/test.json",index));
  auto asset=index.objects.first();QCOMPARE(asset.getLocalPath(),object);QVERIFY(asset.getDownloadAction()!=nullptr);
  QVERIFY(!QFileInfo::exists(dir.filePath("app/assets")));
 }
 void externalLibraryAliasesUseTheExternalCacheBase(){
  QTemporaryDir dir;RuntimeContext context;context.librariesRoot=dir.filePath("original/libraries");context.librariesCacheBase="directory-libraries-test";
  const QString relative="org/lwjgl/lwjgl/3.3.1/lwjgl-3.3.1-natives-windows.jar";
  const auto path=QDir(context.librariesRoot).filePath(relative);QDir().mkpath(QFileInfo(path).absolutePath());QFile original(path);QVERIFY(original.open(QIODevice::WriteOnly));original.write("artifact");original.close();
  Library library("org.lwjgl:lwjgl-natives-windows:3.3.1");auto downloads=std::make_shared<MojangLibraryDownloadInfo>();downloads->artifact=std::make_shared<MojangDownloadInfo>();downloads->artifact->path=relative;downloads->artifact->url="https://libraries.minecraft.net/"+relative;library.setMojangDownloadInfo(downloads);
  QStringList jars,native,n32,n64;library.getApplicableFiles(context,jars,native,n32,n64,QString());QCOMPARE(jars,QStringList{path});
  HttpMetaCache cache(dir.filePath("app/cache"));cache.addBase(context.librariesCacheBase,context.librariesRoot);
  auto entry=cache.resolveEntry(context.librariesCacheBase,relative);entry->setStale(false);entry->setLocalChangedTimestamp(QFileInfo(path).lastModified().toMSecsSinceEpoch());entry->makeEternal(true);QVERIFY(cache.updateEntry(entry));QStringList failed;
  QVERIFY(library.getDownloads(context,&cache,failed,QString()).isEmpty());QVERIFY(failed.isEmpty());
  QCOMPARE(entry->getFullPath(),path);QVERIFY(!QFileInfo::exists(dir.filePath("app/libraries")));
  QVERIFY(cache.evictAll());QVERIFY(QFileInfo::exists(path));
 }
 void libraryReuseHonorsArtifactPaths(){
  Library library("org.lwjgl:lwjgl-natives-windows:3.3.1");auto downloads=std::make_shared<MojangLibraryDownloadInfo>();downloads->artifact=std::make_shared<MojangDownloadInfo>();
  const QString path="org/lwjgl/lwjgl/3.3.1/lwjgl-3.3.1-natives-windows.jar";downloads->artifact->path=path;downloads->artifact->url="https://libraries.minecraft.net/"+path;downloads->artifact->sha1=QString(40,'a');library.setMojangDownloadInfo(downloads);RuntimeContext context;
  QVERIFY(library.sourcePaths(context,"target.jar").contains(path));QCOMPARE(library.expectedSha1(context,"target.jar"),QString(40,'a'));
 }
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
  const auto first=run();QCOMPARE(first["reused"].toInt(),1);QCOMPARE(first["missing"].toInt(),0);QCOMPARE(first["referencedAssets"].toInt(),1);QCOMPARE(first["readOnlyAssets"].toString(),source+"/assets");QVERIFY(!QFileInfo::exists(target+"/assets/"+relative));
  const auto second=run();QCOMPARE(second["reused"].toInt(),0);QCOMPARE(second["missing"].toInt(),0);
  QCOMPARE(second["hashedFiles"].toInt(),0);
  const auto newer=ResourceReuseTask::reuse(plan,source+"/assets",target+"/assets","test",QString(40,'0'),cancelled,progress);QCOMPARE(newer["missing"].toInt(),0);
  const auto legacy=ResourceReuseTask::reuse(plan,source+"/assets",target+"/assets","test","",cancelled,progress);QCOMPARE(legacy["reused"].toInt(),0);QCOMPARE(legacy["missing"].toInt(),0);
  HttpMetaCache cache(target+"/metacache");cache.addBase("libraries",target+"/libraries");cache.addBase("asset_indexes",target+"/assets/indexes");
  for(const auto& value:second["verified"].toList()){auto r=value.toMap();QVERIFY(r["valid"].toBool());auto entry=cache.resolveEntry(r["base"].toString(),r["relative"].toString());entry->setMD5Sum(QString::fromLatin1(r["md5"].toByteArray()));entry->setLocalChangedTimestamp(r["modified"].toLongLong());entry->makeEternal(true);entry->setStale(false);QVERIFY(cache.updateEntry(entry));QNetworkRequest request(QUrl("http://127.0.0.1:1/must-not-download"));Net::MetaCacheSink sink(entry,new Net::ChecksumValidator(QCryptographicHash::Md5),true);QCOMPARE(sink.init(request),Task::State::Succeeded);}
  // Same-sized corrupt assets must be scheduled for repair rather than accepted by size alone.
  put(target+"/assets/"+relative,QByteArray(object.size(),'x'));QFile::remove(source+"/assets/"+relative);
  {QFile damaged(target+"/assets/"+relative);QVERIFY(damaged.open(QIODevice::ReadWrite));QVERIFY(damaged.setFileTime(QDateTime::currentDateTime().addSecs(1),QFileDevice::FileModificationTime));}
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

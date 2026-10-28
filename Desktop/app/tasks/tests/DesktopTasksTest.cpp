#include <QtTest>
#include <QNetworkAccessManager>
#include "tasks/ConcurrentTask.h"
#include "net/NetJob.h"
#include "qml_material/anim/spring_motion.hpp"
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
 void springAdvancesWithoutAnExposedWindow(){qml_material::SpringMotion motion;motion.setSpec({800,.6});motion.snapTo(0);motion.setTargetValue(100);QTRY_VERIFY_WITH_TIMEOUT(motion.value()>0,500);QTRY_VERIFY_WITH_TIMEOUT(!motion.isRunning(),1500);QCOMPARE(motion.value(),100.);}
 void springCanReverseAndReduceMotion(){qml_material::SpringMotion motion;motion.setSpec({380,.8});motion.snapTo(0);motion.setTargetValue(100);QTRY_VERIFY_WITH_TIMEOUT(motion.value()>10,500);motion.setTargetValue(0);QTRY_VERIFY_WITH_TIMEOUT(!motion.isRunning(),1500);QCOMPARE(motion.value(),0.);motion.setTargetValue(100);motion.setEnabled(false);QCOMPARE(motion.value(),100.);QVERIFY(!motion.isRunning());}
 void emptyJobCancellationEndsItsState(){QNetworkAccessManager network;NetJob job("empty",&network);QSignalSpy success(&job,&Task::succeeded);job.start();QVERIFY(job.abort());QCOMPARE(job.getState(),Task::State::AbortedByUser);QCoreApplication::processEvents();QCOMPARE(success.size(),0);}
 void queuedWorkDoesNotStartAfterCancellation(){QNetworkAccessManager network;NetJob job("queued",&network);auto child=makeShared<WaitingTask>();job.addTask(child);job.start();QCoreApplication::sendPostedEvents(&job,QEvent::MetaCall);QVERIFY(job.abort());QCoreApplication::processEvents();QVERIFY(!child->started);QCOMPARE(job.getState(),Task::State::AbortedByUser);}
 void activeWorkIsAbortedWithoutRetry(){QNetworkAccessManager network;NetJob job("active",&network);auto child=makeShared<WaitingTask>();job.addTask(child);job.start();QTRY_VERIFY(child->started);QVERIFY(job.abort());QCOMPARE(child->getState(),Task::State::AbortedByUser);QCOMPARE(job.getState(),Task::State::AbortedByUser);QTest::qWait(30);QCOMPARE(job.getState(),Task::State::AbortedByUser);}
 void sequentialCancellationDoesNotReportSuccess(){ConcurrentTask task("parent",1);auto child=makeShared<WaitingTask>();task.addTask(child);QSignalSpy success(&task,&Task::succeeded);task.start();QVERIFY(task.abort());QCoreApplication::processEvents();QCOMPARE(task.getState(),Task::State::AbortedByUser);QCOMPARE(success.size(),0);QVERIFY(!child->started);}
};
QTEST_GUILESS_MAIN(DesktopTasksTest)
#include "DesktopTasksTest.moc"

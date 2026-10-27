#include "../CommunityClient.h"
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

class CommunityClientTest : public QObject
{
    Q_OBJECT
private slots:
    void activitySnapshotsDoNotNotifyAndUpdatesDeduplicate()
    {
        QTemporaryDir dir;
        CommunityClient client(dir.path());
        QSignalSpy notices(&client,&CommunityClient::activityReceived);
        QJsonObject first{{"id",1},{"event_id","one"},{"player","A"},{"instance","World"}};
        QJsonObject second{{"id",2},{"event_id","two"},{"player","B"},{"instance","Other"}};
        client.mergeActivity(QJsonArray{first,second},true);
        QCOMPARE(notices.size(),0);
        QCOMPARE(client.activity().first().toMap().value("id").toInt(),2);
        QJsonObject third{{"id",3},{"event_id","three"},{"player","C"},{"instance","Latest"}};
        client.mergeActivity(QJsonArray{second,third},false);
        client.mergeActivity(QJsonArray{third},false);
        QCOMPARE(notices.size(),1);
        QCOMPARE(client.activity().size(),3);
        QCOMPARE(client.activity().first().toMap().value("id").toInt(),3);
        client.logout();
        QVERIFY(client.activity().isEmpty());
    }

    void preservesRepeatedMessagesWithoutIds()
    {
        QTemporaryDir dir;
        CommunityClient client(dir.path());
        QJsonObject row{{"time", "12:00"}, {"player", "Alex"}, {"message", "hello"}};
        client.mergeChat(QJsonArray{row, row}, true);
        client.mergeChat(QJsonArray{row, row, row}, false);
        QCOMPARE(client.chat().size(), 3);
    }

    void boundsHistoryAndDeduplicatesIds()
    {
        QTemporaryDir dir;
        CommunityClient client(dir.path());
        QJsonArray rows;
        for (int id = 1; id <= 350; ++id) rows.append(QJsonObject{{"id", id}, {"message", QString::number(id)}});
        client.mergeChat(rows, true);
        QCOMPARE(client.chat().size(), 300);
        QCOMPARE(client.chat().first().toMap().value("id").toInt(), 51);
        client.mergeChat(QJsonArray{QJsonObject{{"id", 340}}, QJsonObject{{"id", 351}}}, false);
        QCOMPARE(client.chat().size(), 300);
        QCOMPARE(client.chat().last().toMap().value("id").toInt(), 351);
    }

    void expiresBeforeTokenDeadline()
    {
        QTemporaryDir dir;
        CommunityClient client(dir.path());
        auto token = [](qint64 seconds) {
            const auto payload = QJsonDocument(QJsonObject{{"exp", double(seconds)}}).toJson(QJsonDocument::Compact)
                                     .toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
            return "header." + payload + ".signature";
        };
        client.m_accessToken = token(QDateTime::currentSecsSinceEpoch() + 30);
        QVERIFY(client.tokenExpiring());
        client.m_accessToken = token(QDateTime::currentSecsSinceEpoch() + 3600);
        QVERIFY(!client.tokenExpiring());
        client.m_accessToken = "broken";
        QVERIFY(client.tokenExpiring());
    }

    void rejectsInvalidLocalInputsWithoutNetwork()
    {
        QTemporaryDir dir;
        CommunityClient client(dir.path());
        QSignalSpy errors(&client, &CommunityClient::operationFailed);
        const auto date = client.dailyDate();
        client.loadDaily("2026-02-31");
        QCOMPARE(client.dailyDate(), date);
        client.uploadServer(QUrl::fromLocalFile(dir.filePath("missing.zip")), {}, true);
        client.login("", "");
        QCOMPARE(errors.size(), 3);
        QVERIFY(!client.busy());
        QVERIFY(!client.uploading());
    }

    void restrictsImageSchemes()
    {
        QTemporaryDir dir;
        CommunityClient client(dir.path());
        QCOMPARE(client.imageUrl("/api/v1/auth/avatars/a.png").host(), QStringLiteral("mc.ainfinitythecoder.cn"));
        QVERIFY(client.imageUrl("https://example.com/avatar.png").isValid());
        QVERIFY(client.imageUrl("file:///C:/secret").isEmpty());
        QVERIFY(client.imageUrl("http://elsewhere.invalid/avatar.png").isEmpty());
    }

    void logoutInvalidatesIdentityAndData()
    {
        QTemporaryDir dir;
        CommunityClient client(dir.path());
        client.m_authenticated = true;
        client.m_profile = {{"username", "Alex"}};
        client.m_accessToken = "access";
        client.m_chat = {QVariantMap{{"message", "hello"}}};
        client.m_uploading = true;
        const auto generation = client.m_generation;
        client.logout();
        QVERIFY(!client.authenticated());
        QVERIFY(!client.uploading());
        QVERIFY(client.profile().isEmpty());
        QVERIFY(client.chat().isEmpty());
        QVERIFY(client.m_accessToken.isEmpty());
        QVERIFY(client.m_generation > generation);
    }
};

QTEST_GUILESS_MAIN(CommunityClientTest)
#include "CommunityClientTest.moc"

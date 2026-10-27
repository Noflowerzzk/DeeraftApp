#pragma once
#include <QObject>
#include <QUrl>
class DownloadSources final: public QObject {
    Q_OBJECT
    Q_PROPERTY(int mode READ mode WRITE setMode NOTIFY changed)
public:
    explicit DownloadSources(const QString& dataDirectory,QObject* parent=nullptr);
    int mode()const;
    void setMode(int value);
    static QUrl mirror(const QUrl& original);
    static int currentMode();
signals:
    void changed();
private:
    static QString s_settingsPath;
};

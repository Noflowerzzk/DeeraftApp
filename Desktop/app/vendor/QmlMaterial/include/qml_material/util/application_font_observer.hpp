#pragma once
#include <QGuiApplication>
#include <QEvent>
#include <functional>
namespace {
class ApplicationFontObserver final : public QObject {
public:
    ApplicationFontObserver(std::function<void()> update, QObject* owner) : QObject(owner), m_update(std::move(update)) { qGuiApp->installEventFilter(this); }
protected:
    bool eventFilter(QObject*, QEvent* event) override {
        if(event->type()==QEvent::ApplicationFontChange) m_update();
        return false;
    }
private:
    std::function<void()> m_update;
};
}

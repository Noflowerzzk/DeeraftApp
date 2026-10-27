#pragma once
#include <QTranslator>
#include <QLocale>
#include <QHash>

class ChineseCatalog final : public QTranslator {
public:
    explicit ChineseCatalog(QObject* parent):QTranslator(parent){(void)load(":/deeraft/translations/mmc_zh.qm");}
    QString translate(const char* context,const char* source,const char* disambiguation=nullptr,int n=-1)const override{
        return QLocale().language()==QLocale::Chinese?QTranslator::translate(context,source,disambiguation,n):QString();
    }
};

// QmlMaterial and Qt platform buttons do not ship Chinese catalogs with this build.
class DesktopTranslations final : public QTranslator {
public:
    explicit DesktopTranslations(QObject* parent):QTranslator(parent){}
    bool isEmpty() const override{return false;}
    QString translate(const char*,const char* source,const char* =nullptr,int =-1) const override {
        if(QLocale().language()!=QLocale::Chinese)return {};
        static const QHash<QString,QString> text{
            {"Select date","选择日期"},{"Select date range","选择日期范围"},{"Date","日期"},{"Start date","开始日期"},{"End date","结束日期"},
            {"Enter a valid date","请输入有效日期"},{"End date must not precede start date","结束日期不能早于开始日期"},
            {"Cancel","取消"},{"OK","确定"},{"Close","关闭"},{"Save","保存"},{"Save All","全部保存"},{"Open","打开"},{"Apply","应用"},
            {"Yes","是"},{"No","否"},{"Yes to All","全部是"},{"No to All","全部否"},{"Retry","重试"},{"Ignore","忽略"},{"Abort","中止"},
            {"Help","帮助"},{"Reset","重置"},{"Restore Defaults","恢复默认"},{"Discard","放弃"},{"Settings","设置"},{"Settings - %1 %2","设置 - %1 %2"},{"Select a date","选择日期"},
            {"Switch to text input","输入日期"},{"Switch to calendar input","选择日期"},{"Next month","下个月"},{"Previous month","上个月"}
            ,{"Show time playing this instance","显示此实例的游玩时长"},{"Record time playing this instance","记录此实例的游玩时长"}
        };
        QString key=QString::fromUtf8(source);key.remove('&');return text.value(key);
    }
};

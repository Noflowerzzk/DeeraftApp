#pragma once
#include "tasks/Task.h"
#include <QVariantMap>
#include <atomic>
#include <memory>
class MinecraftInstance;
class ResourceReuseTask:public Task {
    Q_OBJECT
public:
    explicit ResourceReuseTask(MinecraftInstance* instance);
    ~ResourceReuseTask()override{*m_cancelled=true;}
    void executeTask()override;
    bool canAbort()const override{return true;}
    bool abort()override;
    // Pure filesystem worker, also used with isolated regression fixtures.
    static QVariantMap reuse(const QVariantList& files,const QString& assetSource,const QString& assetTarget,
                             const QString& indexId,const QString& indexSha,
                             const std::shared_ptr<std::atomic_bool>& cancelled,
                             const std::shared_ptr<std::atomic_int>& progress);
private:
    MinecraftInstance* m_instance;
    std::shared_ptr<std::atomic_bool> m_cancelled=std::make_shared<std::atomic_bool>(false);
};

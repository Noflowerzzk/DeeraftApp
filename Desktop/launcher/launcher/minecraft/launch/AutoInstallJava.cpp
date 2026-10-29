// SPDX-License-Identifier: GPL-3.0-only
/*
 *  Prism Launcher - Minecraft Launcher
 *  Copyright (c) 2023-2024 Trial97 <alexandru.tripon97@gmail.com>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, version 3.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * This file incorporates work covered by the following copyright and
 * permission notice:
 *
 *      Copyright 2013-2021 MultiMC Contributors
 *
 *      Licensed under the Apache License, Version 2.0 (the "License");
 *      you may not use this file except in compliance with the License.
 *      You may obtain a copy of the License at
 *
 *          http://www.apache.org/licenses/LICENSE-2.0
 *
 *      Unless required by applicable law or agreed to in writing, software
 *      distributed under the License is distributed on an "AS IS" BASIS,
 *      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *      See the License for the specific language governing permissions and
 *      limitations under the License.
 */

#include "AutoInstallJava.h"
#include "Application.h"
#include "MessageLevel.h"
#include "FileSystem.h"
#include "java/JavaInstall.h"
#include "java/JavaInstallList.h"
#include "minecraft/PackProfile.h"
#include <QFileInfo>
#include <QStandardPaths>

AutoInstallJava::AutoInstallJava(LaunchTask* parent)
    : LaunchStep(parent), m_instance(m_parent->instance()) {}

void AutoInstallJava::executeTask()
{
    auto settings = m_instance->settings();
    settings->set("IgnoreJavaCompatibility", true);
    const auto configured = FS::ResolveExecutable(settings->get("JavaPath").toString());
    if (!configured.isEmpty() && !QStandardPaths::findExecutable(configured).isEmpty() &&
        (settings->get("OverrideJavaLocation").toBool() || !APPLICATION->settings()->get("AutomaticJavaSwitch").toBool())) {
        emitSucceeded();
        return;
    }
    // Reuse Prism's local registry/environment/bundled-runtime discovery. Never download a JRE.
    auto javas = APPLICATION->javalist();
    auto select = [this, javas, configured] {
        if (!isRunning()) return;
        const auto preferred = m_instance->getPackProfile()->getProfile()->getCompatibleJavaMajors();
        JavaInstallPtr fallback;
        for (int i = 0; i < javas->count(); ++i) {
            auto java = std::dynamic_pointer_cast<JavaInstall>(javas->at(i));
            if (!java || !QFileInfo::exists(java->path)) continue;
            if (!fallback) fallback = java;
            if (preferred.contains(java->id.major())) { setJavaPath(java->path); return; }
        }
        // Version preferences help selection, but never block a locally installed Java.
        if (fallback) { setJavaPath(fallback->path); return; }
        if (!configured.isEmpty() && !QStandardPaths::findExecutable(configured).isEmpty()) { setJavaPath(configured); return; }
        emitFailed(tr("未找到可用的本机 Java，请在实例设置中选择 Java 路径；不会自动下载。"));
    };
    if (javas->isLoaded()) { select(); return; }
    m_current_task = javas->getLoadTask();
    if (!m_current_task) { select(); return; }
    connect(m_current_task.get(), &Task::finished, this, select);
    connect(m_current_task.get(), &Task::progress, this, &AutoInstallJava::setProgress);
    connect(m_current_task.get(), &Task::status, this, &AutoInstallJava::setStatus);
    emit progressReportingRequest();
}

void AutoInstallJava::setJavaPath(QString path)
{
    auto settings = m_instance->settings();
    settings->set("OverrideJavaLocation", true);
    settings->set("JavaPath", path);
    settings->set("AutomaticJava", true);
    emit logLine(tr("使用本机 Java：%1").arg(path), MessageLevel::Launcher);
    emitSucceeded();
}

bool AutoInstallJava::abort()
{
    // Detection is shared with the Java settings page; cancelling this launch must not cancel other consumers.
    if (m_current_task) disconnect(m_current_task.get(), nullptr, this, nullptr);
    emitAborted();
    return true;
}

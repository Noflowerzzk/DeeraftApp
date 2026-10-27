import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Pane {
    id: page; required property var app; padding: 24
    property string selectedId: ""
    property string rootId: ""
    ColumnLayout {
        anchors.fill: parent; spacing: 16
        RowLayout {
            Layout.fillWidth: true
            ActionButton { text: "添加实例"; highlighted: true; onClicked: desktop.action("actionAddInstance") }
            ActionButton { text: "关联目录"; onClicked: { var path = desktop.chooseDirectory(); if (path) { page.rootId = externalGames.addRoot(path); externalGames.scanRoot(page.rootId) } } }
            Item { Layout.fillWidth: true }
            ActionButton { text: "高级管理"; flat: true; onClicked: desktop.advanced() }
        }
        TabBar {
            id: sourceTab; Layout.fillWidth: true
            TabButton { text: "实例" }
            TabButton { text: "PCL / HMCL" }
        }
        ListView {
            id: instances; visible: sourceTab.currentIndex === 0
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 8; model: desktop.instances
            delegate: ItemDelegate {
                required property var modelData
                width: ListView.view.width; height: 96
                highlighted: page.selectedId === modelData.id
                onClicked: page.selectedId = modelData.id
                onDoubleClicked: desktop.action("actionLaunchInstance", modelData.id)
                contentItem: RowLayout {
                    spacing: 20
                    Image { source: "image://instances/" + modelData.icon; Layout.preferredWidth: 56; Layout.preferredHeight: 56; smooth: false }
                    ColumnLayout { Layout.fillWidth: true
                        Label { text: modelData.name; color: app.ink; font.pixelSize: 20; elide: Text.ElideRight; Layout.fillWidth: true }
                        Label { text: modelData.running ? "运行中" : modelData.description; color: app.muted; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                    ActionButton { text: "设置"; flat: true; onClicked: desktop.action("actionEditInstance", modelData.id) }
                    ActionButton { text: modelData.running ? "查看" : "启动"; highlighted: true; onClicked: desktop.action("actionLaunchInstance", modelData.id) }
                }
            }
            Label { anchors.centerIn: parent; visible: instances.count === 0; text: "添加 Minecraft 或导入整合包"; color: app.muted; font.pixelSize: 18 }
        }
        ColumnLayout {
            visible: sourceTab.currentIndex === 1; Layout.fillWidth: true; Layout.fillHeight: true
            RowLayout {
                Layout.fillWidth: true
                ComboBox {
                    id: roots; Layout.fillWidth: true; model: externalGames.roots; textRole: "path"; valueRole: "id"
                    onActivated: { page.rootId = currentValue; externalGames.scanRoot(page.rootId) }
                    onCountChanged: if (count > 0 && !page.rootId) { page.rootId = model[0].id; externalGames.scanRoot(page.rootId) }
                }
                ActionButton { text: "刷新"; onClicked: externalGames.scanRoot(page.rootId) }
                ActionButton { text: "移除关联"; onClicked: { externalGames.removeRoot(page.rootId); page.rootId = "" } }
            }
            Label { visible: externalGames.error.length > 0; text: externalGames.error; wrapMode: Text.Wrap; Layout.fillWidth: true; color: app.muted }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 8; model: externalGames.versions
                delegate: ItemDelegate {
                    required property var modelData
                    width: ListView.view.width; implicitHeight: 100
                    contentItem: RowLayout {
                        ColumnLayout { Layout.fillWidth: true
                            Label { text: modelData.id; font.pixelSize: 19; color: app.ink }
                            Label { text: modelData.gameDirectory || modelData.error || ""; elide: Text.ElideMiddle; Layout.fillWidth: true; color: app.muted }
                        }
                        ActionButton { text: "目录"; flat: true; onClicked: desktop.openPath(modelData.gameDirectory || modelData.root) }
                        ActionButton { text: "运行目录"; flat: true; onClicked: { var path = desktop.chooseDirectory(); if (path) { var options = {}; for (var i = 0; i < externalGames.roots.length; ++i) if (externalGames.roots[i].id === page.rootId) options = externalGames.roots[i].options || {}; var dirs = options.versionDirectories || {}; dirs[modelData.id] = path; externalGames.setRootOptions(page.rootId,{versionDirectories:dirs}); externalGames.scanRoot(page.rootId) } } }
                        ActionButton { text: "启动"; enabled: modelData.valid && !externalLauncher.running; highlighted: true; onClicked: desktop.launchExternal(page.rootId, modelData.id) }
                    }
                }
            }
            Label { visible: externalLauncher.error.length > 0; text: externalLauncher.error; wrapMode: Text.Wrap; Layout.fillWidth: true }
            Label { visible: desktop.error.length > 0; text: desktop.error; wrapMode: Text.Wrap; Layout.fillWidth: true }
            ActionButton { visible: externalLauncher.running; text: "结束游戏"; onClicked: externalLauncher.stop() }
        }
    }
}

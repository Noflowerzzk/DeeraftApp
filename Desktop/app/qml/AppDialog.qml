import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

Dialog {
    id: dialog
    Material.theme: desktop.dark ? Material.Dark : Material.Light
    Material.primary: desktop.dark ? "#84d6c3" : "#056b5b"
    Material.accent: desktop.dark ? "#84d6c3" : "#056b5b"
    Material.background: desktop.dark ? "#28312d" : "#e3eae6"
    Material.foreground: desktop.dark ? "#dce5df" : "#171d1b"
    enter: Transition { ParallelAnimation {
      NumberAnimation { property: "opacity"; from: 0; to: 1; duration: library.reducedMotion?0:150 }

    } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: library.reducedMotion?0:75 } }
    onOpened: {
        var labels = [[Dialog.Close,"关闭"],[Dialog.Ok,"确定"],[Dialog.Cancel,"取消"],[Dialog.Save,"保存"]]
        for (var i = 0; i < labels.length; ++i) {
            var button = dialog.standardButton(labels[i][0])
            if (button) button.text = labels[i][1]
        }
    }
}

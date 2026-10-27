import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

Dialog {
    id: dialog
    Material.theme: desktop.dark ? Material.Dark : Material.Light
    Material.primary: desktop.dark ? "#9ad4ab" : "#356b4a"
    Material.accent: desktop.dark ? "#9ad4ab" : "#356b4a"
    Material.background: desktop.dark ? "#1b261e" : "#f5faf4"
    Material.foreground: desktop.dark ? "#e1e9df" : "#18211a"
    onOpened: {
        var labels = [[Dialog.Close,"关闭"],[Dialog.Ok,"确定"],[Dialog.Cancel,"取消"],[Dialog.Save,"保存"]]
        for (var i = 0; i < labels.length; ++i) {
            var button = dialog.standardButton(labels[i][0])
            if (button) button.text = labels[i][1]
        }
    }
}

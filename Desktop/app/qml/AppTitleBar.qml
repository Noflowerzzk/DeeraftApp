import QtQuick
import QtQuick.Layouts
import Qcm.Material as MD

Rectangle {
    id:bar
    required property var app
    objectName:"appTitleBar"
    color:app.surface
    MouseArea {
        anchors.fill:parent
        acceptedButtons:Qt.LeftButton
        onPressed:windowChrome.beginMove()
        onDoubleClicked:windowChrome.toggleMaximize()
    }
    RowLayout {
        anchors.fill:parent;anchors.leftMargin:20;spacing:8
        Image {source:"qrc:/deeraft/assets/deeraft.png";Layout.preferredWidth:20;Layout.preferredHeight:20;sourceSize:Qt.size(40,40)}
        AppLabel {text:"DeeraftApp";color:app.muted;font.pixelSize:12}
        Item {Layout.fillWidth:true}
        Repeater {
            model:[{icon:"remove",label:"最小化"},{icon:windowChrome.maximized?"filter_none":"crop_square",label:windowChrome.maximized?"还原":"最大化"},{icon:"close",label:"关闭"}]
            delegate:IconButton {
                required property var modelData
                required property int index
                objectName:"windowControl_"+index
                symbol:modelData.icon;hint:modelData.label
                implicitWidth:46;implicitHeight:32
                ink:index===2&&mdState.interactions.hovered?app.colors.error:app.muted
                onClicked:{if(index===0)windowChrome.minimize();else if(index===1)windowChrome.toggleMaximize();else windowChrome.requestClose()}
            }
        }
    }
}

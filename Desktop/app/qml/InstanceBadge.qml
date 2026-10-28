import QtQuick
import Qcm.Material as MD
MD.Pane {
 id: badge
 required property string name
 property string version: ""
 property bool dark: false
 readonly property int colorIndex: {var hash=0;for(var i=0;i<name.length;i++)hash=(hash*31+name.charCodeAt(i))>>>0;return hash%6}
 readonly property var tones: dark?["#414b48","#474b59","#514753","#54493e","#47513e","#4e4a3c"]:["#d4e3dc","#dbe0ec","#e5dce8","#e9dfd2","#dce4d1","#e5e1ce"]
 readonly property string monogram: {var value=name.trim();var match=value.match(/^\d+\.\d+/);return match?match[0]:/^[A-Za-z]/.test(value)?value.slice(0,2).toUpperCase():value.slice(0,1)||"M"}
 implicitWidth:48;implicitHeight:48;radius:width<=40?12:16;backgroundColor:tones[colorIndex]
 AppLabel {anchors.centerIn:parent;text:badge.monogram;font.pixelSize:/^\d/.test(text)?15:20;font.weight:650;color:badge.dark?"#e2e7e4":"#35443d"}
 MD.ToolTip.text: name+(version?" · "+version:"")
}

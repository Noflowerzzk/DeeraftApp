import QtQuick
import QtQuick.Controls
Menu {
 implicitWidth: 250; padding: 8
 background: Rectangle { color: desktop.dark?"#28312d":"#e3eae6"; radius: 20 }
 enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: library.reducedMotion?0:150 } }
 exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: library.reducedMotion?0:75 } }
}

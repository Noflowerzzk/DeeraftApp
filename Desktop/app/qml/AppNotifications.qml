import QtQuick
import Qcm.Material as MD

MD.SnakeView {
 id: notices
 objectName:"appNotifications"
 spacing:12
 add:Transition {enabled:false}
 remove:Transition {NumberAnimation {property:"opacity";to:0;duration:library.reducedMotion?0:MD.Token.duration.short2;easing:MD.Token.easing.standard}}
 delegate:Item {
  id:entry
  objectName:"appNotification"
  required property var model
  width:ListView.view.width
  height:bar.implicitHeight
  readonly property real arrivalProgress:arrival.value
  property bool entered:false
  Component.onCompleted:entered=true
  MD.SpringMotion {id:arrival;objectName:"noticeArrival";targetValue:entry.entered?1:0;spec:MD.Token.motion.spring.expressive.defaultSpatial;enabled:!library.reducedMotion}
  MD.SnakeBar {
   id:bar
   x:Math.max(0,1-arrival.value)*32
   y:(1-arrival.value)*20
   width:entry.width
   radius:16+12*Math.max(0,1-arrival.value)
   opacity:Math.max(0,Math.min(1,arrival.value))
   text:entry.model.text
   snakeModel:notices.model
   snakeId:entry.model.sid
   presentationId:entry.model.presentationId
   showClose:true
   action:entry.model.action
   actionOnNewLine:entry.model.actionOnNewLine
  }
 }
}

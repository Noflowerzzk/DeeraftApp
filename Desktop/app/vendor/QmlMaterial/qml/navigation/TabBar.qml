import QtQuick
import Qcm.Material as MD

MD.TabBarBase {
    id: control

    property int type: MD.Enum.PrimaryTab
    property int radius: 0
    property real primaryIndicatorFraction: 0
    property bool animationsEnabled: true
    property MD.corners corners: MD.Util.corners(radius)
    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset, contentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset, contentHeight + topPadding + bottomPadding)

    spacing: 1
    clip: true

    contentItem: Flickable {
        id: m_view
        contentWidth: control.contentHost.width
        contentHeight: control.contentHost.height
        clip: true
        flickableDirection: Flickable.AutoFlickIfNeeded
        boundsBehavior: Flickable.StopAtBounds
        property bool _ready: false
        property bool _hasSelection: false
        property real indicatorTargetX: 0
        property real indicatorTargetWidth: 0
        MD.SpringMotion {id:indicatorPositionMotion;targetValue:m_view.indicatorTargetX;enabled:control.animationsEnabled&&m_view._hasSelection;spec:MD.Token.motion.spring.expressive.fastSpatial}
        MD.SpringMotion {id:indicatorWidthMotion;targetValue:m_view.indicatorTargetWidth;enabled:control.animationsEnabled&&m_view._hasSelection;spec:MD.Token.motion.spring.expressive.fastSpatial}
        function synchronizeCurrent() {
            if (!_ready)
                return;
            const item = control.currentItem;
            if (!item) {
                scrollAnimation.stop();
                _hasSelection = false;
                return;
            }
            const indicatorWidth = control.type === MD.Enum.PrimaryTab ? (control.primaryIndicatorFraction>0 ? item.width*control.primaryIndicatorFraction : Math.min(item.width, Math.max(24, item.implicitContentWidth))) : item.width;
            const indicatorX = item.mapToItem(m_view.contentItem,0,0).x + (item.width - indicatorWidth) / 2;
            const scrollX = Math.max(0, Math.min(Math.max(0, contentWidth - width), item.x + item.width / 2 - width / 2));
            if (!_hasSelection) {
                indicatorTargetX = indicatorX;
                indicatorTargetWidth = indicatorWidth;
                contentX = scrollX;
                _hasSelection = true;
                return;
            }
            indicatorTargetX=indicatorX;indicatorTargetWidth=indicatorWidth;
            if (!moving && !dragging && (!scrollAnimation.running || scrollAnimation.to !== scrollX)) {
                scrollAnimation.stop();
                scrollAnimation.to = scrollX;
                if (contentX !== scrollX)
                    scrollAnimation.start();
            }
        }
        Component.onCompleted: {
            _ready = true;
            Qt.callLater(synchronizeCurrent);
        }
        onContentWidthChanged: Qt.callLater(synchronizeCurrent)
        onWidthChanged: Qt.callLater(synchronizeCurrent)
        onMovementStarted: scrollAnimation.stop()
        NumberAnimation {
            id: scrollAnimation
            target: m_view
            property: "contentX"
            duration: MD.Token.duration.medium1
            easing: MD.Token.easing.standard
        }
        Binding {
            target: control.contentHost
            property: "parent"
            value: m_view.contentItem
        }
        Connections {
            target: control
            function onCurrentItemChanged() {
                Qt.callLater(m_view.synchronizeCurrent);
            }
            function onCurrentIndexChanged(){Qt.callLater(m_view.synchronizeCurrent);}
            function onTypeChanged() {
                Qt.callLater(m_view.synchronizeCurrent);
            }
        }
        Connections {
            target: control.currentItem
            function onXChanged() {
                Qt.callLater(m_view.synchronizeCurrent);
            }
            function onWidthChanged() {
                Qt.callLater(m_view.synchronizeCurrent);
            }
            function onImplicitContentWidthChanged() {
                Qt.callLater(m_view.synchronizeCurrent);
            }
        }
        Rectangle {
            id: m_indicator
            objectName: "tabSelectionIndicator"
            x:indicatorPositionMotion.value
            width:Math.max(0,indicatorWidthMotion.value)
            y: control.position === MD.TabBar.Footer ? 0 : m_view.height - height
            height: control.type == MD.Enum.PrimaryTab ? 3 : 2
            visible: control.currentItem !== null
            z: 2
            color: MD.Token.color.primary
            topLeftRadius: control.type === MD.Enum.PrimaryTab && control.position !== MD.TabBar.Footer ? 3 : 0
            topRightRadius: topLeftRadius
            bottomLeftRadius: control.type === MD.Enum.PrimaryTab && control.position === MD.TabBar.Footer ? 3 : 0
            bottomRightRadius: bottomLeftRadius
        }
    }

    background: MD.Rectangle {
        color: control.MD.MProp.backgroundColor
        corners: control.corners

        MD.AutoDivider {
            anchors.bottom: parent.bottom
        }
    }
}

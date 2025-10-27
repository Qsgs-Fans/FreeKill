import QtQuick

import Fk.Widgets as W

Item {
  id: root

  // 操作相关property
  property bool selectable: true
  property bool selected: false
  property bool draggable: false
  property alias dragging: drag.active
  property alias dragCenter: drag.centroid.position
  property alias hoverHandler: hover

  property bool enabled: true   // if false the card will be grey

  // 拖拽、动画相关property
  property int origX: 0
  property int origY: 0
  property int initialZ: 0
  property int maxZ: 0
  property real origOpacity: 1

  // 动画相关属性
  property alias goBackAnim: goBackAnimation
  property bool moveAborted: false
  property int goBackDuration: 500
  property bool autoBack: true
  property bool busy: false // whether there is a running emotion on the item

  signal clicked(var card)
  signal rightClicked()
  signal doubleClicked(var card)
  signal startDrag(var card)
  signal released(var card)
  signal moveFinished()
  signal hoverChanged(bool hovered)

  W.TapHandler {
    onTapped: (p, btn) => {
      if (btn === Qt.LeftButton || btn === Qt.NoButton) {
        parent.selected = parent.selectable ? !parent.selected : false;
        parent.clicked(root);
      } else if (btn === Qt.RightButton) {
        parent.rightClicked();
      }
    }

    onLongPressed: {
      parent.rightClicked();
    }

    onDoubleTapped: (p, btn) => {
      if (btn === Qt.LeftButton || btn === Qt.NoButton) {
        parent.doubleClicked(root);
      }
    }
  }

  DragHandler {
    id: drag
    enabled: parent.draggable
    grabPermissions: PointHandler.TakeOverForbidden
    xAxis.enabled: true
    yAxis.enabled: true

    onGrabChanged: (transtition, point) => {
      if (transtition === PointerDevice.GrabExclusive) {
        parent.startDrag(root);
      } else if (transtition === PointerDevice.UngrabExclusive) {
        parent.released(root);
        if (parent.autoBack) goBackAnimation.start();
      }
    }
  }

  HoverHandler {
    id: hover
    onHoveredChanged: {
      if (!parent.draggable) return;
      if (hovered) {
        root.z = root.maxZ ? root.maxZ + 1 : root.z + 1;
      } else {
        root.z = root.initialZ ? root.initialZ : root.z - 1
      }
      parent.hoverChanged(hovered);
    }
  }

  ParallelAnimation {
    id: goBackAnimation

    PropertyAnimation {
      target: root
      property: "x"
      to: root.origX
      easing.type: Easing.OutQuad
      duration: root.goBackDuration
    }

    PropertyAnimation {
      target: root
      property: "y"
      to: root.origY
      easing.type: Easing.OutQuad
      duration: root.goBackDuration
    }

    SequentialAnimation {
      PropertyAnimation {
        target: root
        property: "opacity"
        to: 1
        easing.type: Easing.OutQuad
        duration: root.goBackDuration * 0.8
      }

      PropertyAnimation {
        target: root
        property: "opacity"
        to: root.origOpacity
        easing.type: Easing.OutQuad
        duration: root.goBackDuration * 0.2
      }
    }

    onStopped: {
      if (!root.moveAborted)
        root.moveFinished();
    }
  }

  function goBack(animated) {
    if (dragging) {
      console.warn(this, "goBack when dragging", new Error().stack)
    }

    let useAnim = animated;
    if (origX === x && origY === y && origOpacity === opacity) {
      useAnim = false;
    } else if (origOpacity === opacity) {
      const dx = Math.abs(x - origX);
      const dy = Math.abs(y - origY);
      if (dx + dy <= 1) {
        useAnim = false;
      }
    }
    if (useAnim) {
      moveAborted = true;
      goBackAnimation.stop();
      moveAborted = false;
      goBackAnimation.start();
    } else {
      x = origX;
      y = origY;
      opacity = origOpacity;

      if (animated) {
        moveFinished();
      }
    }
  }

  function destroyOnStop() {
    moveFinished.connect(destroy);
  }
}

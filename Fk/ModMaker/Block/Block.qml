import QtQuick

Item {
  id: root
  property var parentBlock
  property var childBlocks: [] // nested blocks inside this block
  property var currentStack: [ root ] // the block stack that root is in
  property var workspace // workspace

  property bool draggable: false
  property alias dragging: drag.active
  property real startX // only available when dragging
  property real startY

  // TMP
  property int idx
  function toString() { return "Block #" + idx.toString(); }
  // TMP

  Rectangle {
    id: rect
    anchors.fill: parent
    color: drag.active ? "grey" : "snow"
    border.width: 1
    radius: 0
  }

  Text {
    text: idx
  }

  DragHandler {
    id: drag
    enabled: root.draggable
    grabPermissions: PointHandler.TakeOverForbidden
    xAxis.enabled: true
    yAxis.enabled: true
  }

  onDraggingChanged: {
    if (!dragging) {
      finishDrag();
    } else {
      startDrag();
    }
  }

  onXChanged: {
    if (dragging) {
      updateChildrenPos();
    }
  }

  onYChanged: {
    if (dragging) {
      updateChildrenPos();
    }
  }

  function getStackParent() {
    const idx = currentStack.indexOf(root);
    if (idx <= 0) {
      return null;
    }
    return currentStack[idx - 1];
  }

  function getStackChildren() {
    const idx = currentStack.indexOf(root);
    if (idx >= currentStack.length - 1) {
      return [];
    }
    return currentStack.slice(idx + 1);
  }

  function startDrag() {
    startX = x;
    startY = y;
    let children = getStackChildren();
    children.push(...childBlocks);
    children.forEach(b => {
      b.startX = b.x;
      b.startY = b.y;
    });
  }

  function updateChildrenPos() {
    const dx = root.x - root.startX;
    const dy = root.y - root.startY;
    let children = getStackChildren();
    children.push(...childBlocks);
    children.forEach(b => {
      b.x = b.startX + dx;
      b.y = b.startY + dy;
    });
  }

  function finishDrag() {
    if (currentStack[0] !== root) {
      tearFrom(getStackParent());
    }

    if (parentBlock) {
      tearFrom(parentBlock);
    }

    if (workspace) {
      workspace.arrangeBlock(root);
    }
  }

  function pasteTo(dest, asParent) {
    x = dest.x;
    y = dest.y + dest.height;
    updateChildrenPos();

    if (!asParent) {
      const stk = currentStack;
      dest.currentStack.push(...stk);

      const p = dest.parentBlock;
      let c = getStackChildren();
      c.push(root);
      c.forEach(cc => {
        cc.parentBlock = p;
        cc.currentStack = dest.currentStack;
      });
    } else {
      // TODO
    }
  }

  function tearFrom(dest) {
    const fromParent = dest === root.parentBlock;
    if (!fromParent) {
      const idx = currentStack.indexOf(root);
      const newStack = currentStack.slice(idx);
      let c = getStackChildren();

      currentStack.splice(idx);

      c.push(root);
      c.forEach(cc => {
        cc.parentBlock = null;
        cc.currentStack = newStack;
      });
    } else {
      // TODO
    }
  }

  Component.onCompleted: {
  }
}

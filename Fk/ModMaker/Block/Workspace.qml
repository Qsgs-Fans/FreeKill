import QtQuick
import QtQuick.Controls

Item {
  id: root
  property var blockComponent
  property var allBlocks: []

  // ====== TMP ======
  property int idx: 0
  Row {
    Button {
      text: "quit"
      onClicked: modStack.pop();
    }
    Button {
      text: "New"
      onClicked: newBlock();
    }
    Button {
      text: "Del"
      onClicked: rmFirstBlock_();
    }
  }

  function newBlock() {
    let obj = blockComponent.createObject(root, {
      width: 50, height: 50,
      x: Math.random() * root.width, y: Math.random() * root.height,
      workspace: root, draggable: true,
      idx: ++idx,
    });
    allBlocks.push(obj);
  }

  function rmFirstBlock_() {
    let obj = allBlocks[0];
    if (!obj) return;
    obj.destroy();
    allBlocks.splice(0,1);
  }
  // ====== TMP ======

  function getPasteBlock(block) {
    let ret;
    let min = Infinity;
    const x = block.x;
    const y = block.y;
    allBlocks.forEach(b => {
      if (b === block) return;
      let dx = Math.abs(b.x - x);
      let dy = y - b.y - b.height;
      let tot = dx + dy;
      if (dx < 60 && dy < 60 && dy > 0 && tot < 100) {
        if (min > tot) {
          if (!allBlocks.find(bb => bb.x === b.x && bb.y === b.y + b.height)) {
            ret = b;
            min = tot;
          }
        }
      }
    });
    return ret;
  }

  function showPasteBlock(block) {
  }

  function arrangeBlock(block) {
    let b = getPasteBlock(block);
    if (b) {
      block.pasteTo(b);
    }
  }

  Component.onCompleted: {
    blockComponent = Qt.createComponent('Block.qml');
  }
}

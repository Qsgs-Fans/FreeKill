import QtQuick

import Fk

Item {
  id: root
  width: 900
  height: 20
  visible: false
  property bool newTxtAvailable: true
  property var stashedTxt: []
  property int currentRunning: 0

  onNewTxtAvailableChanged: {
    if (!newTxtAvailable || stashedTxt.length === 0) {
      return;
    }
    const t = stashedTxt.splice(0, 1)[0];
    const obj = txtComponent.createObject(root, { text: t });
    obj.finished.connect(() => obj.destroy());
    obj.start();
  }

  onCurrentRunningChanged: {
    visible = !!currentRunning;
  }

  Rectangle {
    anchors.fill: parent
    color: "black"
    opacity: 0.7
  }

  Component {
    id: txtComponent
    Text {
      id: txt
      color: "white"
      font.pixelSize: 18
      font.family: Config.libianName
      textFormat: TextEdit.RichText
      y: -1
      property bool changedAvail: false
      signal finished()

      onXChanged: {
        if (root.width - x - 40 > width && !changedAvail) {
          root.newTxtAvailable = true;
          changedAvail = true;
        }
      }

      PropertyAnimation on x {
        id: txtAnim
        running: false
        from: root.width
        to: -txt.width
        duration: (root.width + txt.width) * 5

        onFinished: {
          root.currentRunning--;
          txt.finished();
        }
      }

      function start() {
        root.newTxtAvailable = false;
        root.currentRunning++;
        txtAnim.start();
      }
    }
  }

  function sendLog(txt) {
    root.stashedTxt.push(txt);
    if (root.newTxtAvailable) {
      root.newTxtAvailable = false;
      root.newTxtAvailable = true;
    }
  }
}

import QtQuick
import QtQuick.Controls
import Fk

// 你游的定制Popup 为了沟槽的缩放功能设计
// 本体的宽高从realMainWin计算

Popup {
  id: root

  property alias item: loader.item
  property alias source: loader.source
  property alias sourceComponent: loader.sourceComponent

  clip: true
  padding: 4 * Config.winScale

  background: Rectangle {
    color: "#FAFAFB"
    radius: 5
    border.color: "#E7E7E8"
    border.width: 1
  }

  Loader {
    id: loader
    anchors.centerIn: parent
    width: parent.width / Config.winScale
    height: parent.height / Config.winScale
    scale: Config.winScale
    clip: true
    onSourceChanged: {
      if (item === null) {
        return;
      }
      item.finish?.connect(() => {
        root.close();
      });
    }
    onSourceComponentChanged: sourceChanged();
  }
}

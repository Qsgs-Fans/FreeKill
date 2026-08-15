import QtQuick
import QtQuick.Controls

Item {
  id: root
  width: 100
  height: 50
  z: 999
  default property alias content: panel.data
  property alias rect: panel

  // 点击外部 → 关闭
  MouseArea {
    id: overlay
    parent: roomScene   // 提权到顶层（如 PageBase）
    anchors.fill: parent
    visible: panel.visible
    z: 10
    onClicked: panel.visible = false
  }

  // 弹框本体 — 可以用锚定定位
  Rectangle {
    id: panel
    visible: false
    width: root.width; height: root.height
    radius: 3
    color: "white"
    border.color: "#acbebc"
    z: 11

    // 内部内容通过 content 别名传入
  }
}
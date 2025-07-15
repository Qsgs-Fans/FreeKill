import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

AbstractButton {
  id: root

  // TODO icon

  contentItem: Text {
    anchors.centerIn: parent
    text: root.text
    color: root.enabled ? "black" : "#808082"
    font {
      family: root.font.family
      pixelSize: 16
      bold: true
    }
    Layout.preferredHeight: 18
    opacity: enabled ? 1.0 : 0.3
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }

  background: Rectangle {
    implicitHeight: 32
    implicitWidth: 120
    radius: 8
    color: {
      if (!root.enabled) return "#F0F0F1"
      return root.down ? "#BEBEC0" : "#E6E6E7"
    }
    Behavior on color {
      ColorAnimation {
        duration: 200
        easing.type: Easing.OutQuad
      }
    }
  }
}


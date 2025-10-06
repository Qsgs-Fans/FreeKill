import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

AbstractButton {
  id: root
  implicitWidth: 120
  implicitHeight: 40
  property color backgroundColor: "#E6E6E7"

  contentItem: RowLayout {
    anchors.fill: parent
    spacing: 8
    Item { Layout.fillWidth: true }
    Image {
      source: root.icon.source
      visible: source.toString() !== ""
      Layout.preferredWidth: 24
      Layout.preferredHeight: 24
      fillMode: Image.PreserveAspectFit
      sourceSize: Qt.size(240, 240)
      layer.enabled: !root.enabled
      layer.effect: ColorOverlay {
        color: "#CC808082"
      }
    }
    Text {
      text: root.text
      color: root.enabled ? "black" : "#808082"
      font {
        family: root.font.family
        pixelSize: 16 // root.font.pixelSize ?? 16
        bold: root.font.bold ?? true
      }
      Layout.preferredHeight: 18
      opacity: enabled ? 1.0 : 0.3
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }
    Item { Layout.fillWidth: true }
  }

  background: Rectangle {
    implicitHeight: 40
    implicitWidth: 120
    radius: 8
    color: {
      if (!root.enabled) return "#F0F0F1";
      if (root.down) return "#BEBEC0";
      if (root.hovered) return "#DCDCDE";
      return root.backgroundColor;
    }
    Behavior on color {
      ColorAnimation {
        duration: 200
        easing.type: Easing.OutQuad
      }
    }
  }
}


import QtQuick
import QtQuick.Layouts

ActionRow {
  id: root

  contentItem: Item {
    property real txtPadding: 8
    RowLayout {
      anchors.centerIn: parent

      // TODO 左边的按钮icon
      Text {
        text: root.title
        font {
          family: root.font.family
          pixelSize: 16
          bold: true
        }
        opacity: enabled ? 1.0 : 0.3
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      // TODO 右边的按钮icon
    }
  }
}

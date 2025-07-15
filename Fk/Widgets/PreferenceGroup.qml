import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: root

  property string title
  property string subTitle
  property Component suffixComponent: null

  spacing: 0

  Item {
    id: titleItem
    Layout.preferredHeight: title ? (subTitle ? 56 : 40) : 8
    ColumnLayout {
      x: 4
      anchors.verticalCenter: parent.verticalCenter
      Text {
        text: root.title
        font {
          pixelSize: 14
          bold: true
        }
        Layout.preferredHeight: 18
        opacity: enabled ? 1.0 : 0.3
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      Text {
        text: root.subTitle
        visible: root.title !== "" && root.subTitle !== ""
        font {
          pixelSize: 12
        }
        color: "grey"
        Layout.preferredHeight: 16
        opacity: enabled ? 1.0 : 0.3
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }
    }
  }

  onChildrenChanged: {
    for (let i = 0; i < children.length; i++) {
      if (children[i].Layout !== undefined) {
        children[i].Layout.fillWidth = true;
      }
    }
  }

  Component.onCompleted: {
  }
}

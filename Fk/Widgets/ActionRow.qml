import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

AbstractButton {
  id: root

  property string title
  property string subTitle
  property Component suffixComponent: null
  property alias suffixLoader: suffixLoader
  property real suffixMaximumWidth: width * 0.4
  property alias backgroundColor: bg.color
  property alias borderColor: bg.border.color
  implicitHeight: Math.max(60, contentItem ? contentItem.implicitHeight : 0)

  contentItem: Item {
    id: contentRoot

    property real txtPadding: 8
    property real textWidth: Math.max(20, width - titleLayout.x - txtPadding * 4 - suffixContainer.width)
    implicitHeight: titleLayout.implicitHeight + txtPadding * 2

    ColumnLayout {
      id: titleLayout
      x: parent.txtPadding * 2; y: parent.txtPadding
      anchors.verticalCenter: parent.verticalCenter
      Text {
        text: root.title
        font {
          family: root.font.family
          pixelSize: 18
        }
        Layout.preferredWidth: contentRoot.textWidth
        Layout.preferredHeight: 18
        opacity: enabled ? 1.0 : 0.3
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      Text {
        text: root.subTitle
        visible: root.subTitle !== ""
        font {
          family: root.font.family
          pixelSize: 16
        }
        color: "grey"
        opacity: enabled ? 1.0 : 0.3
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        lineHeight: 0.95
        Layout.preferredWidth: contentRoot.textWidth
        Layout.preferredHeight: implicitHeight
        Layout.alignment: Qt.AlignLeft
      }
    }

    Item {
      id: suffixContainer

      property real naturalWidth: suffixLoader.item ? suffixLoader.item.implicitWidth : 0

      width: Math.min(naturalWidth, root.suffixMaximumWidth)
      anchors.right: parent.right
      anchors.rightMargin: parent.txtPadding * 2
      anchors.verticalCenter: parent.verticalCenter
      height: suffixLoader.height
      Loader {
        id: suffixLoader
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width

        sourceComponent: root.suffixComponent
      }
    }
  }

  background: Rectangle {
    id: bg
    implicitHeight: root.implicitHeight
    //radius: 12
    color: root.down ? "#EFEFEF" : "#FEFFFE"
    Behavior on color {
      ColorAnimation {
        duration: 200
        easing.type: Easing.OutQuad
      }
    }
    border.color: root.visualFocus ? "#E81A62" : "#EBEBEB"
    border.width: root.visualFocus ? 2 : 1

    Rectangle {
      width: parent.width; height: parent.height
      x: 2; y: 2; z: -1
      color: "#3F000000"
    }
  }
}

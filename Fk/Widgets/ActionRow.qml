import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

AbstractButton {
  id: root

  property string title
  property string subTitle
  property Component suffixComponent: null
  property alias suffixLoader: suffixLoader

  contentItem: Item {
    property real txtPadding: 8
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
        Layout.preferredHeight: 18
        opacity: enabled ? 1.0 : 0.3
        horizontalAlignment: Text.AlignHCenter
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
        Layout.preferredHeight: 16
        opacity: enabled ? 1.0 : 0.3
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }
    }

    Item {
      width: parent.width - anchors.rightMargin - parent.txtPadding - titleLayout.width
      anchors.right: parent.right
      anchors.rightMargin: parent.txtPadding * 2
      anchors.verticalCenter: parent.verticalCenter
      height: suffixLoader.height
      Loader {
        id: suffixLoader
        anchors.right: parent.right

        sourceComponent: root.suffixComponent
      }
    }
  }

  background: Rectangle {
    implicitHeight: 60
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

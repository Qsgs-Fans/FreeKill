import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  property bool configOK: modConfig.userName !== "" && modConfig.email !== ""

  ToolBar {
    id: bar
    width: parent.width
    RowLayout {
      anchors.fill: parent
      ToolButton {
        icon.source: AppPath + "/image/modmaker/back"
        onClicked: mainStack.pop();
      }
      Label {
        text: qsTr("ModMaker")
        horizontalAlignment: Qt.AlignHCenter
        Layout.fillWidth: true
      }
      ToolButton {
        icon.source: AppPath + "/image/modmaker/menu"
      }
    }
  }

  Rectangle {
    width: parent.width
    height: parent.height - bar.height
    anchors.top: bar.bottom
    color: "snow"
    opacity: 0.75

    Text {
      anchors.centerIn: parent
      text: root.configOK ? "" : qsTr("config is incomplete")
    }
  }

  RoundButton {
    visible: root.configOK
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 40
    scale: 2
    icon.source: AppPath + "/image/modmaker/add"
  }
}

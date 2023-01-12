import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root

  ListModel {
    id: aboutModel
    ListElement { dest: "freekill" }
    ListElement { dest: "qt" }
    ListElement { dest: "lua" }
    ListElement { dest: "gplv3" }
    ListElement { dest: "sqlite" }
    ListElement { dest: "ossl" }
  }

  ColumnLayout {
    anchors.fill: parent

    SwipeView {
      id: swipe
      Layout.fillWidth: true
      Layout.fillHeight: true
      currentIndex: indicator.currentIndex
      Repeater {
        model: aboutModel
        Item {
          Rectangle {
            anchors.centerIn: parent
            color: "#88888888"
            radius: 2
            width: root.width * 0.8
            height: root.height * 0.8

            Image {
              id: logo
              anchors.left: parent.left
              anchors.leftMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              source: AppPath + "/image/logo/" + dest
              width: parent.width * 0.3
              fillMode: Image.PreserveAspectFit
            }

            Text {
              anchors.left: logo.right
              anchors.leftMargin: 16
              width: parent.width * 0.65
              text: Backend.translate("about_" + dest + "_description")
              wrapMode: Text.WordWrap
              textFormat: Text.RichText
              font.pixelSize: 18
            }
          }
        }
      }
    }

    PageIndicator {
      id: indicator

      count: swipe.count
      currentIndex: swipe.currentIndex
      interactive: true

      Layout.alignment: Qt.AlignHCenter
    }
  }

  Button {
    text: Backend.translate("Quit")
    anchors.right: parent.right
    onClicked: {
      swipe.opacity = 0;
      mainStack.pop();
    }
  }

}

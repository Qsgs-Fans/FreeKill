import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  anchors.fill: parent

  signal finished()

  TabBar {
    id: bar
    y: parent.height
    transformOrigin: Item.TopLeft
    rotation: -90
    width: root.height
    TabButton {
      text: Backend.translate("Package Settings")
    }
    TabButton {
      text: Backend.translate("General Settings")
    }
    Component.onCompleted: {
      currentIndex = count;
    }
  }

  SwipeView {
    width: root.width - bar.height - 16
    x: bar.height + 16
    height: root.height
    interactive: false
    orientation: Qt.Vertical
    currentIndex: bar.count - bar.currentIndex
    RoomGeneralSettings {}
    RoomPackageSettings {}
  }
}

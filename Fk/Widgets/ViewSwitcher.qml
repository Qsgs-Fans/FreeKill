import QtQuick

// https://gnome.pages.gitlab.gnome.org/libadwaita/doc/1-latest/class.ViewSwitcher.html

ListView {
  id: root

  interactive: false
  width: 400
  height: 40
  spacing: 0
  currentIndex: 0
  orientation: Qt.Horizontal
  highlight: Rectangle { color: "#C4C4C5"; radius: 8 }
  highlightMoveDuration: 200

  onModelChanged: {
    root.width = model.length * 100;
  }

  delegate: Item {
    width: 100
    height: 32
    y: 4

    Text {
      text: modelData
      anchors.centerIn: parent
      font.pixelSize: 16
      font.bold: true
    }

    TapHandler {
      onTapped: root.currentIndex = index
    }
  }
}

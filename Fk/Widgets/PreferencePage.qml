import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Flickable {
  id: root

  // TODO 键盘/手柄操作各个config的逻辑，以及焦点转换时滚动都在此实现

  property real groupWidth: width
  property alias layout: layout
  property alias spacing: layout.spacing
  default property alias children: layout.children

  property bool scrollBarVisible: true

  flickableDirection: Flickable.VerticalFlick
  clip: true

  contentHeight: layout.height + 32
  contentWidth: width

  ColumnLayout {
    id: layout

    y: 8
    width: root.groupWidth
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 12

    onChildrenChanged: {
      for (var i = 0; i < children.length; i++) {
        if (children[i].Layout !== undefined) {
          children[i].Layout.fillWidth = true
        }
      }
    }
  }

  ScrollBar.vertical: CommonScrollBar {
    visible: root.scrollBarVisible
  }
}

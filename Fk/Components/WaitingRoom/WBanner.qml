import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects

Item {
  id: root
  width: 100
  height: 35
  property string text: ""

  Shape {
    id: bannerShape
    anchors.fill:parent

    layer.enabled: true
    layer.effect: DropShadow {
      horizontalOffset: 2
      verticalOffset: 2
      radius: 4
      samples: 70
      color: "#40000000"
    }

    ShapePath {
      id: titlePolyShape
      strokeColor: '#89adb6'
      strokeWidth: 0
      fillColor: '#89adb6'
      startX: 0; startY: 0

      PathPolyline {
        path: [
          Qt.point(0, 0),
          Qt.point(root.width, 0),
          Qt.point(root.width - root.height, root.height),
          Qt.point(0, root.height),
        ]
      }
      PathLine { x: 0; y: 0 }  // 闭合回到起点
    }

  }

  Text {
    id: bannerText
    anchors.fill: parent
    anchors.rightMargin: root.height
    text: root.text
    font.bold: true
    font.pixelSize: 25
    color: '#dfe9e9'
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
  }
}
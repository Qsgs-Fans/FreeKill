import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects

Item {
  id: root
  width: titlePolyShape.len
  height: titlePolyShape.tall
  property string title: ""
  property string style: "indigo"
  Shape {
    anchors.fill:parent

    layer.enabled: true
    layer.effect: DropShadow {
      horizontalOffset: 2
      verticalOffset: 1
      radius: 4
      samples: 70
      color: "#40000000"
    }

    ShapePath {
      id: titlePolyShape
      strokeColor: styles[root.style][0]
      strokeWidth: 2
      fillColor: styles[root.style][1]
      startX: 0; startY: 0
      property real len: Math.min(Math.max(40, titleText.implicitWidth + 20), 100)
      property real tall: 14
      property var styles: {
        "yellow": ['#e7dc7b', '#d3c93b'],
        "red":    ['#e79a7b', '#d3403b'],
        "green":  ['#afc96a', '#78b12f'],
        "indigo": ['#7be7d5', '#32beb3'],
        "blue":   ['#7baae7', '#3b78d3'],
        "purple": ['#ad7be7', '#643bd3'],
        "pink":   ['#e0a1c6', '#d4579c'],
        "orange": ['#d3a36c', '#ce7f35'],
        "grey":   ['#cecccd', '#838383'],
      }
      PathPolyline {
        path: [
          Qt.point(0, 0),
          Qt.point(titlePolyShape.len, 0),
          Qt.point(titlePolyShape.len-(titlePolyShape.tall/2), titlePolyShape.tall/2),
          Qt.point(titlePolyShape.len, titlePolyShape.tall),
          Qt.point(0, titlePolyShape.tall),
          Qt.point(titlePolyShape.tall/2, titlePolyShape.tall/2)
        ]
      }
      PathLine { x: 0; y: 0 }  // 闭合回到起点
    }

  }
  Text {
    id: titleText
    height: parent.height
    width: implicitWidth
    anchors.horizontalCenter: parent.horizontalCenter
    text: root.title
    font.bold: true
    font.pixelSize: 10
    color: "snow"
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
}

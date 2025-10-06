// 割圆的例子
import QtQuick
import QtQuick.Layouts
import Fk.RoomElement

ColumnLayout {
  id: root
  anchors.fill: parent
  property var extra_data: ({ name: "", data: {
    all: [1, 2, 4, 6],
    ok: [1, 4],
  } })
  signal finish()

  BigGlowText {
    Layout.fillWidth: true
    Layout.preferredHeight: childrenRect.height + 4

    text: Lua.tr(extra_data.name)
  }

  PathView {
    id: pathView
    Layout.fillWidth: true
    Layout.fillHeight: true
    model: extra_data.data.all
    delegate: Rectangle{
      width: 42; height: 42
      color: extra_data.data.ok.includes(modelData) ? "yellow" : "#CCEEEEEE"
      radius: 2
      Text {
        anchors.centerIn: parent
        text: modelData
        font.pixelSize: 24
      }
    }
    path: Path {
      // 默认横屏了，应该没人用竖屏玩这游戏
      startX: pathView.width / 2
      startY: 40
      PathArc {
        x: pathView.width / 2
        y: pathView.height - 40
        radiusX: (pathView.height - 80) / 2
        radiusY: (pathView.height - 80) / 2
        direction: PathArc.Clockwise
      }
      PathArc {
        x: pathView.width / 2
        y: 40
        radiusX: (pathView.height - 80) / 2
        radiusY: (pathView.height - 80) / 2
        direction: PathArc.Clockwise
      }
    }
  }
}

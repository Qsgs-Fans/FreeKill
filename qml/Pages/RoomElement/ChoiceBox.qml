import QtQuick
import ".."

GraphicsBox {
  property var options: []
  property string skill_name: ""
  property int result

  id: root
  title.text: Backend.translate("$Choice").arg(Backend.translate(skill_name))
  width: Math.max(140, body.width + 20)
  height: body.height + title.height + 20

  Column {
    id: body
    x: 10
    y: title.height + 5
    spacing: 10

    Repeater {
      model: options

      MetroButton {
        text: Backend.translate(modelData)
        anchors.horizontalCenter: parent.horizontalCenter

        onClicked: {
          result = index;
          root.close();
        }
      }
    }
  }
}

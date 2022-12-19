import QtQuick
import ".."

GraphicsBox {
  property string winner: ""

  id: root
  title.text: Backend.translate("$GameOver")
  width: Math.max(140, body.width + 20)
  height: body.height + title.height + 20

  Column {
    id: body
    x: 10
    y: title.height + 5
    spacing: 10

    Text {
      text: Backend.translate("$Winner").arg(Backend.translate(winner))
      color: "#E4D5A0"
    }

    MetroButton {
      text: Backend.translate("Back To Lobby")
      anchors.horizontalCenter: parent.horizontalCenter

      onClicked: {
        ClientInstance.notifyServer("QuitRoom", "[]");
      }
    }
  }
}

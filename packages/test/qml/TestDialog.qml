import QtQuick
import "../../../qml/Pages/RoomElement"
import "../../../qml/Pages"

GraphicsBox {
  property string custom_string: ""

  id: root
  title.text: Backend.translate("Test")
  width: Math.max(140, body.width + 20)
  height: body.height + title.height + 20

  Column {
    id: body
    x: 10
    y: title.height + 5
    spacing: 10

    Text {
      text: root.custom_string
      color: "#E4D5A0"
    }

    MetroButton {
      text: Backend.translate("OKOK")
      anchors.horizontalCenter: parent.horizontalCenter

      onClicked: {
        close();
        ClientInstance.replyToServer("", "Hello from test dialog");
      }
    }
  }

  function loadData(data) {
    custom_string = data;
  }
}

import QtQuick
import "../RoomElement"
import QtQuick.Layouts
import QtQuick.Controls

GraphicsBox {
  property string custom_string: ""

  id: root
  title.text: Backend.translate("English")
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

    TextField {
        id: serverAddrEdit
        Layout.fillWidth: true
        placeholderText: qsTr("Word")
        text: ""
      }

    Button {
        Layout.fillWidth: true
        enabled: serverAddrEdit.text !== ""
        text: "OK"
        onClicked: {
          ClientInstance.replyToServer("", serverAddrEdit.text);
          finished();
        }
    }  
  }

  function loadData(data) {
    custom_string = data;
  }
}

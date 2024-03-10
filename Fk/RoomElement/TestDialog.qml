import QtQuick
import "../RoomElement"
import QtQuick.Layouts
import QtQuick.Controls

GraphicsBox {
  property string custom_string: ""

  id: root
  title.text: Backend.translate("en")
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
        color: "#E4D5A0"
        Keys.onPressed: {  
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {  
                // console.log("回车键被按下")  
                // 在这里添加你希望在按下回车键时执行的代码  
                ClientInstance.replyToServer("", serverAddrEdit.text);
                finished();
            }  
        }
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

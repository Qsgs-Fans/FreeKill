// 割圆的例子
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Fk.RoomElement

GraphicsBox {
  id: root
  height: 200; width: 300
ColumnLayout {
  Text {
    id: txt
    color: "white"
  }

  Button {
    text: "Btn 1"
    onClicked: {
      ClientInstance.notifyServer("PushRequest", "updatemini,B1")
    }
  }

  Button {
    text: "Btn 2"
    onClicked: {
      ClientInstance.notifyServer("PushRequest", "updatemini,B2")
    }
  }

  Button {
    text: "Reply"
    onClicked: {
      close();
      roomScene.state = "notactive";
      ClientInstance.replyToServer("", "Hello");
    }
  }
}

  function loadData(data) {
    txt.text = data[0]
  }

  function updateData(data) {
    txt.text = JSON.stringify(data) + " updated"
  }
}

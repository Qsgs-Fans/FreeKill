import QtQuick
import QtQuick.Controls

Item {
  id: root

  Frame {
    id: join_server
    anchors.centerIn: parent
    background: Rectangle {
      color: "#88888888"
      radius: 2
    }
    
    Column {
      spacing: 8
      TextField {
        id: server_addr
        text: "127.0.0.1"
      }
      TextField {
        id: screenNameEdit
        text: "player"
      }
      /*TextField {
        id: avatarEdit
        text: "liubei"
      }*/
      TextField {
        id: passwordEdit
        text: ""
        echoMode: TextInput.Password
        passwordCharacter: "*"
      }
      Button {
        text: "Join Server"
        onClicked: {
          config.screenName = screenNameEdit.text;
          config.password = passwordEdit.text;
          mainWindow.busy = true;
          Backend.joinServer(server_addr.text);
        }
      }
      Button {
        text: "Console start"
        onClicked: {
          config.screenName = screenNameEdit.text;
          config.password = passwordEdit.text;
          mainWindow.busy = true;
          Backend.startServer(9527);
          Backend.joinServer("127.0.0.1");
        }
      }
    }
  }
}

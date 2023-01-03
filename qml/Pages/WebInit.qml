import QtQuick
import QtQuick.Controls

Item {
  id: root
  scale: 2

  // Change this to your server's IP or domain name
  property string server_addr: "127.0.0.1:9530"

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
        id: screenNameEdit
        text: "player"
        onTextChanged: {
          passwordEdit.text = "";
          let data = config.savedPassword[server_addr.editText];
          if (data) {
            if (text === data.username) {
              passwordEdit.text = data.shorten_password;
            }
          }
        }
      }
      TextField {
        id: passwordEdit
        text: ""
        echoMode: TextInput.Password
        passwordCharacter: "*"
      }
      Button {
        text: "Login"
        enabled: passwordEdit.text !== ""
        onClicked: {
          config.serverAddr = server_addr;
          config.screenName = screenNameEdit.text;
          config.password = passwordEdit.text;
          mainWindow.busy = true;
          Backend.joinServer(server_addr);
        }
      }
    }
  }

  Component.onCompleted: {
    config.loadConf();

    let data = config.savedPassword[config.lastLoginServer];
    screenNameEdit.text = data.username;
    passwordEdit.text = data.shorten_password;
  }
}

import QtQuick
import QtQuick.Controls

Item {
  id: root

  Frame {
    id: join_server
    anchors.centerIn: parent
    scale: 1.5
    background: Rectangle {
      color: "#88888888"
      radius: 2
    }
    
    Column {
      spacing: 8
      ComboBox {
        id: server_addr
        model: []
        editable: true

        onEditTextChanged: {
          if (model.indexOf(editText) === -1) {
            passwordEdit.text = "";
          } else {
            let data = config.savedPassword[editText];
            screenNameEdit.text = data.username;
            passwordEdit.text = data.shorten_password;
          }
        }
      }
      TextField {
        id: screenNameEdit
        placeholderText: qsTr("Username")
        text: ""
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
      /*TextField {
        id: avatarEdit
        text: "liubei"
      }*/
      TextField {
        id: passwordEdit
        placeholderText: qsTr("Password")
        text: ""
        echoMode: TextInput.Password
        passwordCharacter: "*"
      }
      Button {
        text: qsTr("Join Server")
        enabled: passwordEdit.text !== ""
        onClicked: {
          config.serverAddr = server_addr.editText;
          config.screenName = screenNameEdit.text;
          config.password = passwordEdit.text;
          mainWindow.busy = true;
          Backend.joinServer(server_addr.editText);
        }
      }
      Button {
        text: qsTr("Console start")
        enabled: passwordEdit.text !== ""
        onClicked: {
          config.serverAddr = "127.0.0.1";
          config.screenName = screenNameEdit.text;
          config.password = passwordEdit.text;
          mainWindow.busy = true;
          Backend.startServer(9527);
          Backend.joinServer("127.0.0.1");
        }
      }
    }
  }

  Button {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    text: qsTr("PackageManage")
    onClicked: {
      mainStack.push(packageManage);
    }
  }

  Component.onCompleted: {
    config.loadConf();
    server_addr.model = Object.keys(config.savedPassword);
    server_addr.onModelChanged();
    server_addr.currentIndex = server_addr.model.indexOf(config.lastLoginServer);

    let data = config.savedPassword[config.lastLoginServer];
    screenNameEdit.text = data.username;
    passwordEdit.text = data.shorten_password;
  }
}

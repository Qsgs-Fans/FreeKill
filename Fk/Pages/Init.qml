// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
  id: root
  property alias serverDialog: serverDialogLoader

  Item {
    width: 960 * 0.8
    height: 540 * 0.8
    anchors.centerIn: parent

    Item {
      id: left
      width: 300
      height: parent.height

      Image {
        id: lady
        width: parent.width + 20
        height: parent.height
        fillMode: Image.PreserveAspectFit
      }

      Image {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        width: parent.width
        source: AppPath + "/image/widelogo"
      }
    }

    Rectangle {
      id: right
      anchors.left: left.right
      width: parent.width - left.width
      height: parent.height
      color: "#88EEEEEE"
      radius: 16

      ColumnLayout {
        width: parent.width * 0.8
        height: parent.height * 0.8
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 40
        //spacing

        Text {
          text: qsTr("Welcome back!")
          font.pixelSize: 28
          Layout.alignment: Qt.AlignHCenter
        }

        /*
        GridLayout {
          columns: 2
          rowSpacing: 20

          Text {
            text: qsTr("Server Addr")
          }
          ComboBox {
            id: server_addr
            Layout.fillWidth: true
            model: []
            editable: true

            onEditTextChanged: {
              if (model.indexOf(editText) === -1) {
                passwordEdit.text = "";
              } else {
                const data = config.savedPassword[editText];
                screenNameEdit.text = data.username;
                passwordEdit.text = data.shorten_password;
              }
            }
          }

          Text {
            text: qsTr("Username")
          }
          TextField {
            id: screenNameEdit
            maximumLength: 32
            Layout.fillWidth: true
            placeholderText: qsTr("Username")
            text: ""
            onTextChanged: {
              passwordEdit.text = "";
              const data = config.savedPassword[server_addr.editText];
              if (data) {
                if (text === data.username) {
                  passwordEdit.text = data.shorten_password;
                }
              }
            }
          }

          CheckBox {
            id: showPasswordCheck
            text: qsTr("Show Password")
          }
          TextField {
            id: passwordEdit
            maximumLength: 64
            Layout.fillWidth: true
            placeholderText: qsTr("Password")
            text: ""
            echoMode: showPasswordCheck.checked ? TextInput.Normal : TextInput.Password
            passwordCharacter: "*"
          }
        }

        Button {
          text: qsTr("Join Server")
          Layout.fillWidth: true
          display: AbstractButton.TextBesideIcon
          icon.name: "go-next"
          enabled: passwordEdit.text !== ""
          onClicked: {
            config.serverAddr = server_addr.editText;
            config.screenName = screenNameEdit.text;
            config.password = passwordEdit.text;
            mainWindow.busy = true;
            Backend.joinServer(server_addr.editText);
          }
        }
        */

       // RowLayout {
          Button {
            Layout.fillWidth: true
            text: qsTr("Console start")
            // enabled: passwordEdit.text !== ""
            onClicked: {
              config.serverAddr = "127.0.0.1";
              const serverCfg = config.savedPassword["127.0.0.1"] ?? {};
              config.screenName = serverCfg.username ?? "player";
              config.password = serverCfg.shorten_password ?? "1234";
              mainWindow.busy = true;
              Backend.startServer(9527);
              Backend.joinServer("127.0.0.1");
            }
          }

        Button {
          text: qsTr("Join Server")
          Layout.fillWidth: true
          display: AbstractButton.TextBesideIcon
          /*
          icon.name: "go-next"
          enabled: passwordEdit.text !== ""
          onClicked: {
            config.serverAddr = server_addr.editText;
            config.screenName = screenNameEdit.text;
            config.password = passwordEdit.text;
            mainWindow.busy = true;
            Backend.joinServer(server_addr.editText);
          }
          */
          onClicked: {
            serverDialog.show();
          }
        }

          Button {
            Layout.fillWidth: true
            text: qsTr("PackageManage")
            onClicked: {
              mainStack.push(packageManage);
            }
          }
        // }
      }

      Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.bottomMargin: 12
        text: qsTr("FreeKill") + " v" + FkVersion
        font.pixelSize: 16
        font.bold: true
      }

      Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 8
        anchors.bottomMargin: 8
        text: qsTr("FAQ")
        color: "blue"
        font.pixelSize: 24
        font.underline: true

        TapHandler {
          onTapped: {
            errDialog.txt = qsTr("$LoginFAQ");
            errDialog.open();
          }
        }
      }
    }
  }

  Item {
    id: serverDialog
    width: parent.width * 0.8
    height: parent.height * 0.9
    anchors.centerIn: parent
    visible: false

    Rectangle {
      anchors.fill: parent
      opacity: 0.9
      radius: 8
      color: "snow"
      border.color: "black"
    }

    MouseArea {
      anchors.fill: parent
    }

    Loader {
      id: serverDialogLoader
      anchors.fill: parent
      source: "JoinServer.qml"
    }

    PropertyAnimation on opacity {
      id: showAnim
      from: 0
      to: 1
      duration: 400
      running: false
      onStarted: {
        serverDialogLoader.item.loadConfig();
      }
    }

    PropertyAnimation on opacity {
      id: hideAnim
      from: 1
      to: 0
      duration: 400
      running: false
      onFinished: {
        serverDialog.visible = false;
      }
    }

    function show() {
      visible = true;
      showAnim.start();
    }

    function hide() {
      hideAnim.start();
    }
  }

  // Temp
  Button {
    text: qsTr("Making Mod")
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    visible: Debugging
    onClicked: {
      mainStack.push(modMaker);
    }
  }

  function downloadComplete() {
    toast.show(qsTr("updated packages for md5"));
  }

  Component.onCompleted: {
    config.loadConf();

    lady.source = config.ladyImg;

    /*
    server_addr.model = Object.keys(config.savedPassword);
    server_addr.onModelChanged();
    server_addr.currentIndex = server_addr.model.indexOf(config.lastLoginServer);

    const data = config.savedPassword[config.lastLoginServer];
    if (data) {
      screenNameEdit.text = data.username;
      passwordEdit.text = data.shorten_password;
    }
    */
  }
}

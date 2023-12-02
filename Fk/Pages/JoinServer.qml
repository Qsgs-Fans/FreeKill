// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
  id: root
  anchors.fill: parent

  Timer {
    id: opTimer
    interval: 5000
  }

  Component {
    id: serverDelegate

    Item {
      height: 64
      width: serverList.width - 48
      clip: true

      RowLayout {
        anchors.fill: parent
        spacing: 16

        Image {
          Layout.preferredHeight: 60
          Layout.preferredWidth: 60
          fillMode: Image.PreserveAspectFit
          source: favicon
        }

        ColumnLayout {
          Layout.fillWidth: true
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignLeft
            text: serverIP + " " + misMatchMsg
            font.bold: true
          }

          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignLeft
            text: description
            textFormat: TextEdit.RichText
          }
        }

        Text {
          text: online + "/" + capacity
          font.pixelSize: 30
        }
      }

      TapHandler {
        onTapped: {
          if (serverList.currentIndex === index) {
            serverList.currentIndex = -1;
          } else {
            serverList.currentIndex = index;
          }
        }
      }
    }
  }

  ListView {
    id: serverList
    height: parent.height - controlPanel.height - 30
    width: parent.width - 80
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 10
    contentHeight: serverDelegate.height * count
    model: ListModel {
      id: serverModel
    }
    delegate: serverDelegate
    ScrollBar.vertical: ScrollBar {}
    clip: true
    highlight: Rectangle {
      color: "#AA9ABFEF"; radius: 5
      // border.color: "black"; border.width: 2
    }
    // highlightMoveDuration: 0
    currentIndex: -1
  }

  GridLayout {
    id: controlPanel
    anchors.top: serverList.bottom
    anchors.topMargin: 10
    width: parent.width - 80
    anchors.horizontalCenter: parent.horizontalCenter
    height: joinButton.height * 2 + 10
    columns: 3

    Button {
      id: joinButton
      Layout.fillWidth: true
      enabled: serverList.currentIndex !== -1
      text: qsTr("Join Server")
      onClicked: {
        const item = serverModel.get(serverList.currentIndex);
        const serverCfg = config.savedPassword[item.serverIP];
        config.serverAddr = item.serverIP;
        config.screenName = serverCfg.username;
        config.password = serverCfg.shorten_password ?? serverCfg.password;
        mainWindow.busy = true;
        Backend.joinServer(item.serverIP);
      }
    }

    Button {
      Layout.fillWidth: true
      text: qsTr("Add New Server")
      onClicked: {
        drawerLoader.sourceComponent = newServerComponent;
        drawer.open();
      }
    }

    Button {
      Layout.fillWidth: true
      enabled: serverList.currentIndex !== -1
      text: qsTr("Edit Server")
      onClicked: {
        drawerLoader.sourceComponent = editServerComponent;
        drawer.open();
      }
    }

    Button {
      Layout.fillWidth: true
      text: qsTr("Refresh List")
      enabled: !opTimer.running
      onClicked: {
        opTimer.start();
        for (let i = 0; i < serverModel.count; i++) {
          const item = serverModel.get(i);
          Backend.getServerInfo(item.serverIP);
        }
      }
    }

    Button {
      Layout.fillWidth: true
      text: qsTr("Detect LAN")
      enabled: !opTimer.running
      onClicked: {
        opTimer.start();
        Backend.detectServer();
      }
    }

    Button {
      Layout.fillWidth: true
      text: qsTr("Go Back")
      onClicked: serverDialog.hide();
    }
  }

  Component {
    id: newServerComponent
    ColumnLayout {
      signal finished();

      Text {
        text: qsTr("@NewServer")
        font.pixelSize: 24
        font.bold: true
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
      }

      Text {
        text: qsTr("@NewServerHint")
        font.pixelSize: 16
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
      }

      TextField {
        id: serverAddrEdit
        Layout.fillWidth: true
        placeholderText: qsTr("Server Addr")
        text: ""
      }

      TextField {
        id: screenNameEdit
        maximumLength: 32
        Layout.fillWidth: true
        placeholderText: qsTr("Username")
        text: ""
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

      CheckBox {
        id: showPasswordCheck
        text: qsTr("Show Password")
      }

      Button {
        Layout.fillWidth: true
        enabled: serverAddrEdit.text !== "" && screenNameEdit.text !== "" && passwordEdit.text !== ""
        text: "OK"
        onClicked: {
          root.addNewServer(serverAddrEdit.text, screenNameEdit.text, passwordEdit.text);
          finished();
        }
      }
    }
  }

  Component {
    id: editServerComponent
    ColumnLayout {
      signal finished();

      Text {
        text: qsTr("@EditServer")
        font.pixelSize: 24
        font.bold: true
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
      }

      Text {
        text: qsTr("@EditServerHint")
        font.pixelSize: 16
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
      }

      TextField {
        id: screenNameEdit
        maximumLength: 32
        Layout.fillWidth: true
        placeholderText: qsTr("Username")
        text: ""
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

      CheckBox {
        id: showPasswordCheck
        text: qsTr("Show Password")
      }

      Button {
        Layout.fillWidth: true
        enabled: screenNameEdit.text !== "" && passwordEdit.text !== ""
        text: "OK"
        onClicked: {
          root.editCurrentServer(screenNameEdit.text, passwordEdit.text);
          finished();
        }
      }

      Button {
        Layout.fillWidth: true
        text: qsTr("Delete Server")
        onClicked: {
          root.deleteCurrentServer();
          finished();
        }
      }
    }
  }

  Drawer {
    id: drawer
    width: parent.width * 0.3 / mainWindow.scale
    height: parent.height / mainWindow.scale
    dim: false
    clip: true
    dragMargin: 0
    scale: mainWindow.scale
    transformOrigin: Item.TopLeft

    Loader {
      id: drawerLoader
      anchors.fill: parent
      anchors.margins: 16
      onSourceChanged: {
        if (item === null)
          return;
        item.finished.connect(() => {
          sourceComponent = undefined;
          drawer.close();
        });
      }
      onSourceComponentChanged: sourceChanged();
    }
  }

  function addNewServer(addr, name, password) {
    if (config.savedPassword[addr]) {
      return;
    }

    config.savedPassword[addr] = {
      username: name,
      password: password,
    };
    config.saveConf();

    serverModel.append({
      serverIP: addr,
      misMatchMsg: "",
      description: qsTr("Server not up"),
      online: "-",
      capacity: "-",
      favicon: "https://img1.imgtp.com/2023/07/01/DGUdj8eu.png",
    });
    Backend.getServerInfo(addr);
  }

  function editCurrentServer(name, password) {
    const addr = serverModel.get(serverList.currentIndex).serverIP;
    if (!config.savedPassword[addr]) {
      return;
    }

    config.savedPassword[addr] = {
      username: name,
      password: password,
      shorten_password: undefined,
      key: undefined,
    };
    config.saveConf();
  }

  function deleteCurrentServer() {
    const addr = serverModel.get(serverList.currentIndex).serverIP;
    if (!config.savedPassword[addr]) {
      return;
    }

    config.savedPassword[addr] = undefined;
    config.saveConf();

    serverModel.remove(serverList.currentIndex, 1);
    serverList.currentIndex = -1;
  }

  function updateServerDetail(addr, data) {
    const [ver, icon, desc, capacity, count] = data;
    for (let i = 0; i < serverModel.count; i++) {
      const item = serverModel.get(i);
      const ip = item.serverIP;
      if (addr.endsWith(ip)) { // endsWith是为了应付IPv6格式的ip
        item.misMatchMsg = FkVersion === ver ? "" : qsTr("@VersionMismatch").arg(ver);
        item.description = desc;
        item.favicon = icon;
        item.online = count.toString();
        item.capacity = capacity.toString();
      }
    }
  }

  function loadConfig() {
    if (serverModel.count > 0) {
      return;
    }
    for (let key in config.savedPassword) {
      serverModel.append({
        serverIP: key,
        misMatchMsg: "",
        description: qsTr("Server not up"),
        online: "-",
        capacity: "-",
        favicon: "",
      });
      Backend.getServerInfo(key);
    }
  }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Fk

Item {
  id: root
  anchors.fill: parent
  property var selectedServer: serverModel.get(serverList.currentIndex)

  Timer {
    id: opTimer
    interval: 5000
  }

  Component {
    id: serverDelegate

    Item {
      height: 64
      width: serverList.width / 2 - 4

      RowLayout {
        anchors.fill: parent
        spacing: 16

        Item {}

        Image {
          Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
          Layout.preferredHeight: 56
          Layout.preferredWidth: 56
          fillMode: Image.PreserveAspectFit
          source: {
            if (!favicon) return SkinBank.MISC_DIR + "server_icon";
            if (favicon === "default") return AppPath + "/image/icon.png";
            return favicon;
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignLeft
            text: {
              if (name) return name;
              let a = addr;
              if (a.includes(":")) { // IPv6
                a = `[${a}]`;
              }
              return `${a}:${port}`;
            }
            font.bold: true
            color: favicon ? "black" : "gray"
          }

          Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignLeft
            text: delay + " ms " + misMatchMsg
            textFormat: TextEdit.RichText
            color: {
              if (delay < 0) {
                return "gray";
              } else if (delay >= 0 && delay < 100) {
                return "green";
              } else if (delay >= 100 && delay < 500) {
                return "orange";
              } else {
                return "red";
              }
            }
          }
        }

        Text {
          text: online + "/<font size='1'>" + capacity + "</font>"
          font.pixelSize: 26
          color: favicon ? "black" : "gray"
        }
      }

      Item {}

      TapHandler {
        onTapped: {
          if (serverList.currentIndex === index) {
            serverList.currentIndex = -1;
          } else {
            serverList.currentIndex = index;
          }
        }
      }

      ColumnLayout {
        x: 6
        height: parent.height
        Item { Layout.fillHeight: true }
        Image {
          Layout.preferredWidth: 24; Layout.preferredHeight: 23
          source: SkinBank.MISC_DIR + "favorite"
          visible: favorite
        }
      }
    }
  }

  ColumnLayout {
    id: serverPanel
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 8
    height: parent.height - 16
    width: parent.width * 0.3
    TextField {
      id: addressEdit
      maximumLength: 64
      Layout.fillWidth: true
      placeholderText: "服务器地址"
      text: selectedServer?.addr ?? ""
    }
    TextField {
      id: portEdit
      maximumLength: 6
      Layout.fillWidth: true
      placeholderText: "端口"
      text: selectedServer?.port ?? ""
    }
    Flickable {
      Layout.fillHeight: true
      Layout.fillWidth: true
      contentHeight: descText.height
      clip: true
      Text {
        id: descText
        width: parent.width
        text: selectedServer?.description ?? ""
        wrapMode: Text.WrapAnywhere
        font.pixelSize: 18
      }
    }
    RowLayout {
      Layout.fillWidth: true
      TextField {
        id: usernameEdit
        maximumLength: 32
        Layout.fillWidth: true
        placeholderText: "用户名"
        text: selectedServer?.username ?? ""
      }
      TextField {
        id: passwordEdit
        maximumLength: 32
        Layout.fillWidth: true
        placeholderText: "密码"
        passwordCharacter: "*"
        echoMode: TextInput.Password
        text: selectedServer?.password ?? ""
      }
    }
    Button {
      text: "登录（首次登录自动注册）"
      Layout.fillWidth: true
      enabled: !!(addressEdit.text && portEdit.text &&
        usernameEdit.text && passwordEdit.text)
      onClicked: {
        const _addr = addressEdit.text;
        const _port = portEdit.text;
        const _username = usernameEdit.text;
        const _password = passwordEdit.text;
        config.screenName = _username;
        config.password = _password;
        mainWindow.busy = true;
        config.serverAddr = _addr;
        config.serverPort = _port;
        addFavorite(config.serverAddr, config.serverPort, name,
          config.screenName, config.password);
        Backend.joinServer(_addr, _port);
      }
    }
  }

  Text {
    id: serverListBar
    text: "已收藏服务器与公共服务器列表"
    font.pixelSize: 18
    font.bold: true
    x: 32; y: 8
  }

  GridView {
    id: serverList
    height: parent.height - 16 - serverListBar.height
    width: parent.width - 24 - serverPanel.width
    anchors.top: serverListBar.bottom
    anchors.left: parent.left
    anchors.margins: 8
    model: ListModel { id: serverModel }
    delegate: serverDelegate
    cellHeight: 64 + 8
    cellWidth: serverList.width / 2
    clip: true
    highlight: Rectangle {
      color: "#AA9ABFEF"; radius: 5
      // border.color: "black"; border.width: 2
    }
    currentIndex: -1
  }

  /*
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
  */

  function addFavorite(addr, port, name, username, password) {
    const newItem = config.addFavorite(addr, port, name, username, password);
    if (!newItem) return;
    serverModel.insert(0, {
      addr, port, name, username, password,
      misMatchMsg: "",
      description: qsTr("Server not up"),
      online: "?",
      capacity: "??",
      favicon: "",
      delayBegin: (new Date).getTime(),
      delay: -1,
      favorite: true,
    });
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

  function updateServerDetail(addr, port, data) {
    const [ver, icon, desc, capacity, count] = data;
    for (let i = 0; i < serverModel.count; i++) {
      const item = serverModel.get(i);
      const ip = item.addr;
      const itemPort = item.port;
      if (addr === ip && port == itemPort) {
        const ms = (new Date).getTime();
        item.misMatchMsg = "";
        if (FkVersion !== ver) {
          item.misMatchMsg = qsTr("@VersionMismatch").arg(ver);
        }

        item.delay = ms - item.delayBegin;
        item.delayBegin = ms;
        item.description = desc;
        item.favicon = icon;
        item.online = count.toString();
        item.capacity = capacity.toString();
      }
    }
  }

  function loadConfig() {
    if (serverModel.count > 0) { return; }
    const serverList = JSON.parse(Backend.getPublicServerList());
    serverList.unshift(...config.favoriteServers);
    for (const server of serverList) {
      let { addr, port, name, username, password } = server;
      name = name ?? "";
      username = username ?? "";
      password = password ?? "";
      if (port === -1) break;
      if (!password && config.findFavorite(addr, port)) continue;
      serverModel.append({
        addr, port, name, username, password,
        misMatchMsg: "",
        description: qsTr("Server not up"),
        online: "?",
        capacity: "??",
        favicon: "",
        delayBegin: (new Date).getTime(),
        delay: -1,
        favorite: !!password,
      });
      Backend.getServerInfo(addr, port);
    }
  }
}

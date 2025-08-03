// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Fk
import Fk.Widgets as W

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
              let p = port;
              if (p === 9527) p = 0;
              if (a.includes(":") && p) { // IPv6
                a = `[${a}]`;
              }
              if (p) {
                p = `:${p}`;
              } else {
                p = "";
              }
              return `${a}${p}`;
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

        Item {}
      }

      W.TapHandler {
        onTapped: {
          if (serverList.currentIndex === index) {
            serverList.currentIndex = -1;
          } else {
            serverList.currentIndex = index;
          }
        }
      }

      ToolButton {
        x: parent.width - 32
        y: parent.height / 2 - 8
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        visible: !!favorite
        text: "⋮"
        onClicked: {
          if (menu.visible){
            menu.close();
          } else {
            menu.open();
          }
        }

        Menu {
          id: menu
          MenuItem {
            text: qsTr("Remove from Favorites")
            onTriggered: {
              removeFavorite(addr, port);
            }
          }
        }
      }

      ColumnLayout {
        x: 6
        height: parent.height
        Item { Layout.fillHeight: true }
        Image {
          Layout.preferredWidth: 24; Layout.preferredHeight: 23
          source: SkinBank.MISC_DIR + "network_local"
          visible: lan
        }
        Image {
          Layout.preferredWidth: 24; Layout.preferredHeight: 23
          source: SkinBank.MISC_DIR + "favorite"
          visible: favorite
        }
      }
    }
  }

  RowLayout {
    id: serverListBar
    height: childrenRect.height
    width: serverList.width
    Text {
      text: qsTr("List of Favorites and Public Servers")
      font.pixelSize: 18
      x: 32; y: 8
    }
    Item { Layout.fillWidth: true }
    Button {
      text: qsTr("Refresh List")
      enabled: !opTimer.running
      onClicked: {
        opTimer.start();
        for (let i = 0; i < serverModel.count; i++) {
          const item = serverModel.get(i);
          if (!item.favorite && !item.lan) break;
          item.delayBegin = (new Date).getTime();
          Backend.getServerInfo(item.addr, item.port);
        }
      }
    }

    Button {
      text: qsTr("Detect LAN")
      enabled: !opTimer.running
      onClicked: {
        opTimer.start();
        Backend.detectServer();
      }
    }

    Button {
      text: qsTr("Go Back")
      onClicked: serverDialog.hide();
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
      placeholderText: qsTr("Server Address")
      text: selectedServer?.addr ?? ""
    }
    TextField {
      id: portEdit
      maximumLength: 6
      Layout.fillWidth: true
      placeholderText: qsTr("Port")
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
        placeholderText: qsTr("Username")
        text: selectedServer?.username ?? ""
      }
      TextField {
        id: passwordEdit
        maximumLength: 32
        Layout.fillWidth: true
        placeholderText: qsTr("Password")
        passwordCharacter: "*"
        echoMode: TextInput.Password
        text: selectedServer?.password ?? ""
      }
    }
    Button {
      text: qsTr("LOGIN (Auto-registration)")
      Layout.fillWidth: true
      enabled: !!(addressEdit.text && portEdit.text &&
        usernameEdit.text && passwordEdit.text)
      onClicked: {
        const _addr = addressEdit.text;
        const _port = parseInt(portEdit.text);
        const _username = usernameEdit.text;
        const _password = passwordEdit.text;
        config.screenName = _username;
        config.password = _password;
        mainWindow.busy = true;
        config.serverAddr = _addr;
        config.serverPort = _port;
        let name = selectedServer?.name;
        if (_addr !== selectedServer?.addr || _port !== selectedServer?.port) {
          name = "";
        }
        addFavorite(config.serverAddr, config.serverPort, name,
          config.screenName, config.password);

        Backend.joinServer(_addr, _port);
        ClientInstance.setLoginInfo(config.screenName, config.password);
      }
    }
    Button {
      text: qsTr("Remove from Favorites")
      Layout.fillWidth: true
      visible: false // !!(selectedServer?.favorite) // 暂时禁用
      onClicked: {
        removeFavorite(selectedServer.addr, selectedServer.port);
      }
    }
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

  function addFavorite(addr, port, name, username, password) {
    const newItem = config.addFavorite(addr, port, name, username, password);
    if (!newItem) {
      for (let i = 0; i < serverModel.count; i++) {
        const s = serverModel.get(i);
        if (s.addr === addr && s.port === port && s.favorite) {
          s.name = name;
          s.username = username;
          s.password = password;
          return;
        }
      }
    }
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
      lan: false,
    });
    Backend.getServerInfo(addr, port);
  }

  function removeFavorite(addr, port) {
    config.removeFavorite(addr, port);
    for (let i = 0; i < serverModel.count; i++) {
      const s = serverModel.get(i);
      if (s.addr === addr && s.port === port && s.favorite) {
        serverModel.remove(i);
        serverList.currentIndex = -1;
        return;
      }
    }
  }

  function addLANServer(addr) {
    const port = 9527;
    if (config.findFavorite(addr, port)) return;
    for (let i = 0; i < serverModel.count; i++) {
      const s = serverModel.get(i);
      if (s.addr === addr && s.port === port && s.lan) {
        s.delayBegin = (new Date).getTime();
        Backend.getServerInfo(addr, port);
        return;
      }
      if (!s.lan && !s.favorite) break;
    }
    serverModel.insert(0, {
      addr, port,
      name: "",
      username: "",
      password: "",
      misMatchMsg: "",
      description: qsTr("Server not up"),
      online: "?",
      capacity: "??",
      favicon: "",
      delayBegin: (new Date).getTime(),
      delay: -1,
      favorite: false,
      lan: true,
    });
    Backend.getServerInfo(addr, port);
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
        if (ver.endsWith("+")) {
          const [x, y, z] = FkVersion.split('.').map(Number);
          const requiredVersionClean = ver.slice(0, -1);
          const [x2, y2, z2] = requiredVersionClean.split('.').map(Number);

          // 离散数学这一块
          let ok = ((x > x2) || (x == x2 && y > y2) || (x == x2 && y == y2 && z >= z2));

          if (ok) {
            item.misMatchMsg = qsTr("@VersionMatch").arg(ver);
          } else {
            item.misMatchMsg = qsTr("@VersionMismatch").arg(ver);
          }
        } else if (FkVersion !== ver) {
          item.misMatchMsg = qsTr("@VersionMismatch").arg(ver);
        }

        item.delay = ms - item.delayBegin;
        item.description = desc;
        item.favicon = icon;
        item.online = count.toString();
        item.capacity = capacity.toString();
        return;
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
        lan: false,
      });
      Backend.getServerInfo(addr, port);
    }
  }
}

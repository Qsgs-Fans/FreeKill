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

      RowLayout {
        anchors.fill: parent
        spacing: 16

        Image {
          Layout.preferredHeight: 60
          Layout.preferredWidth: 60
          fillMode: Image.PreserveAspectFit
          source: favicon
        }

        Text {
          text: serverIP
        }

        Text {
          text: description
        }

        Text {
          text: online + "/" + capacity
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
      color: "transparent"; radius: 5
      border.color: "black"; border.width: 2
    }
    highlightMoveDuration: 0
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
        config.password = serverCfg.shorten_password;
        mainWindow.busy = true;
        Backend.joinServer(item.serverIP);
      }
    }

    Button {
      Layout.fillWidth: true
      text: qsTr("Add New Server")
    }

    Button {
      Layout.fillWidth: true
      enabled: serverList.currentIndex !== -1
      text: qsTr("Edit Server")
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

  function updateServerDetail(addr, data) {
    const [ver, icon, desc, capacity, count] = data;
    for (let i = 0; i < serverModel.count; i++) {
      const item = serverModel.get(i);
      if (addr.endsWith(item.serverIP)) { // endsWith是为了应付IPv6格式的ip
        item.description = FkVersion === ver ? desc : "Ver " + ver;
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
        description: qsTr("Server not up"),
        online: "-",
        capacity: "-",
        favicon: "https://img1.imgtp.com/2023/07/01/DGUdj8eu.png",
      });
      Backend.getServerInfo(key);
    }
  }
}

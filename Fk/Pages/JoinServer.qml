// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
  id: root
  anchors.fill: parent

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
    height: parent.height * 0.9
    width: parent.width * 0.95
    anchors.centerIn: parent
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
    currentIndex: -1
  }

  Button {
    text: "close"
    onClicked: serverDialog.hide();
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
    serverModel.clear();
    for (let key in config.savedPassword) {
      serverModel.append({
        serverIP: key,
        description: "Server not up",
        online: "-",
        capacity: "-",
        favicon: "https://img1.imgtp.com/2023/07/01/DGUdj8eu.png",
      });
      Backend.getServerInfo(key);
    }
  }
}

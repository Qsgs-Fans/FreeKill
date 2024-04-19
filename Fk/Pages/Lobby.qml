// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Layouts
import Fk.LobbyElement
import Fk.Common
import "Logic.js" as Logic

Item {
  id: root
  property alias roomModel: roomModel

  property string password

  Rectangle {
    width: parent.width / 2 - roomListLayout.width / 2 - 50
    height: parent.height * 0.7
    anchors.top: exitButton.bottom
    anchors.bottom: createRoomButton.top
    anchors.right: parent.right
    anchors.rightMargin: 20
    color: "#88EEEEEE"
    radius: 6

    Flickable {
      id: flickableContainer
      ScrollBar.vertical: ScrollBar {}
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: 10
      flickableDirection: Flickable.VerticalFlick
      width: parent.width - 10
      height: parent.height - 10
      contentHeight: bulletin_info.height
      clip: true

      Text {
        id: bulletin_info
        width: parent.width
        wrapMode: TextEdit.WordWrap
        textFormat: Text.MarkdownText
        text: config.serverMotd + "\n___\n" + luatr('Bulletin Info')
        onLinkActivated: Qt.openUrlExternally(link);
      }
    }
  }

  Component {
    id: roomDelegate

    Item {
      height: 48
      width: roomList.width

      RowLayout {
        anchors.fill: parent
        spacing: 16
        Text {
          text: roomId
          color: "grey"
        }

        Text {
          horizontalAlignment: Text.AlignLeft
          Layout.fillWidth: true
          text: {
            let ret = roomName;
            if (outdated) {
              ret = '<font color="grey"><del>' + ret + '</del></font>';
            }
            return ret;
          }
          font.pixelSize: 20
          elide: Label.ElideRight
        }

        Item {
          Layout.preferredWidth: 16
          Image {
            source: AppPath + "/image/button/skill/locked.png"
            visible: hasPassword
            anchors.centerIn: parent
            scale: 0.8
          }
        }

        Text {
          text: luatr(gameMode)
        }

        Text {
          color: (playerNum == capacity) ? "red" : "black"
          text: playerNum + "/" + capacity
          font.pixelSize: 20
          font.bold: true
        }

        Button {
          text: (playerNum < capacity) ? luatr("Enter") :
          luatr("Observe")

          enabled: !opTimer.running && !outdated

          onClicked: {
            opTimer.start();
            if (hasPassword) {
              lobby_dialog.sourceComponent = enterPassword;
              lobby_dialog.item.roomId = roomId;
              lobby_dialog.item.playerNum = playerNum;
              lobby_dialog.item.capacity = capacity;
              lobby_drawer.open();
            } else {
              enterRoom(roomId, playerNum, capacity, "");
            }
          }
        }
      }
    }
  }

  ListModel {
    id: roomModel
  }

  PersonalSettings {
  }

  Timer {
    id: opTimer
    interval: 1000
  }

  ColumnLayout {
    id: roomListLayout
    anchors.top: parent.top
    anchors.topMargin: 10
    anchors.horizontalCenter: parent.horizontalCenter
    width: root.width * 0.48
    height: root.height - 80
    Button {
      Layout.alignment: Qt.AlignRight
      text: luatr("Refresh Room List")
      enabled: !opTimer.running
      onClicked: {
        opTimer.start();
        ClientInstance.notifyServer("RefreshRoomList", "");
      }
    }
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Rectangle {
        anchors.fill: parent
        anchors.centerIn: parent
        color: "#88EEEEEE"
        radius: 16
        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: luatr("Room List").arg(roomModel.count)
        }
        ListView {
          id: roomList
          height: parent.height * 0.9
          width: parent.width * 0.95
          contentHeight: roomDelegate.height * count
          ScrollBar.vertical: ScrollBar {}
          anchors.centerIn: parent
          delegate: roomDelegate
          clip: true
          model: roomModel
        }
      }
    }
  }

  Button {
    id: createRoomButton
    anchors.bottom: buttonRow.top
    anchors.right: parent.right
    width: 120
    display: AbstractButton.TextUnderIcon
    icon.name: "media-playback-start"
    text: luatr("Create Room")
    onClicked: {
      lobby_dialog.sourceComponent =
        Qt.createComponent("../LobbyElement/CreateRoom.qml");
      lobby_drawer.open();
      config.observing = false;
      config.replaying = false;
    }
  }

  RowLayout {
    id: buttonRow
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    Button {
      text: luatr("Generals Overview")
      onClicked: {
        mainStack.push(mainWindow.generalsOverviewPage);
        mainStack.currentItem.loadPackages();
      }
    }
    Button {
      text: luatr("Cards Overview")
      onClicked: {
        mainStack.push(mainWindow.cardsOverviewPage);
        mainStack.currentItem.loadPackages();
      }
    }
    Button {
      text: luatr("Scenarios Overview")
      onClicked: {
        mainStack.push(mainWindow.modesOverviewPage);
      }
    }
    Button {
      text: luatr("Replay")
      onClicked: {
        mainStack.push(mainWindow.replayPage);
      }
    }
    Button {
      text: luatr("About")
      onClicked: {
        mainStack.push(mainWindow.aboutPage);
      }
    }
  }

  Button {
    id: exitButton
    anchors.right: parent.right
    text: luatr("Exit Lobby")
    display: AbstractButton.TextBesideIcon
    icon.name: "application-exit"
    onClicked: {
      toast.show("Goodbye.");
      mainStack.pop();
      config.saveConf();
      Backend.quitLobby();
    }
  }

  Popup {
    id: lobby_drawer
    width: realMainWin.width * 0.8
    height: realMainWin.height * 0.8
    anchors.centerIn: parent
    background: Rectangle {
      color: "#EEEEEEEE"
      radius: 5
      border.color: "#A6967A"
      border.width: 1
    }

    Loader {
      id: lobby_dialog
      anchors.centerIn: parent
      width: parent.width / mainWindow.scale
      height: parent.height / mainWindow.scale
      scale: mainWindow.scale
      clip: true
      onSourceChanged: {
        if (item === null)
          return;
        item.finished.connect(() => {
          sourceComponent = undefined;
          lobby_drawer.close();
        });
      }
      onSourceComponentChanged: sourceChanged();
    }
  }

  Component {
    id: enterPassword
    ColumnLayout {
      property int roomId
      property int playerNum
      property int capacity
      signal finished()
      anchors.fill: parent
      anchors.margins: 16

      Text {
        text: luatr("Please input room's password")
      }

      TextField {
        id: passwordEdit
        onTextChanged: root.password = text;
      }

      Button {
        text: "OK"
        onClicked: {
          enterRoom(roomId, playerNum, capacity, root.password);
          parent.finished();
        }
      }

      Component.onCompleted: {
        passwordEdit.text = "";
      }
    }
  }

  function enterRoom(roomId, playerNum, capacity, pw) {
    config.replaying = false;
    if (playerNum < capacity) {
      config.observing = false;
      lcall("SetObserving", false);
      mainWindow.busy = true;
      ClientInstance.notifyServer(
        "EnterRoom",
        JSON.stringify([roomId, pw])
      );
    } else {
      config.observing = true;
      lcall("SetObserving", true);
      mainWindow.busy = true;
      ClientInstance.notifyServer(
        "ObserveRoom",
        JSON.stringify([roomId, pw])
      );
    }
  }

  property int lobbyPlayerNum: 0
  property int serverPlayerNum: 0

  function updateOnlineInfo() {
  }

  onLobbyPlayerNumChanged: updateOnlineInfo();
  onServerPlayerNumChanged: updateOnlineInfo();

  Rectangle {
    id: info
    color: "#88EEEEEE"
    width: root.width * 0.23 // childrenRect.width + 8
    height: childrenRect.height + 4
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    radius: 4

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      x: 4; y: 2
      font.pixelSize: 16
      text: luatr("$OnlineInfo")
        .arg(lobbyPlayerNum).arg(serverPlayerNum) + "\n"
        + "Powered by FreeKill " + FkVersion
    }
  }

  ChatBox {
    id: lobbyChat
    anchors.bottom: info.top
    width: info.width
    height: root.height * 0.6
    isLobby: true
    color: "#88EEEEEE"
    radius: 4
  }

  Danmaku {
    id: danmaku
    width: parent.width
  }

  function addToChat(pid, raw, msg) {
    if (raw.type !== 1) return;
    msg = msg.replace(/\{emoji([0-9]+)\}/g,
      '<img src="../../image/emoji/$1.png" height="24" width="24" />');
    raw.msg = raw.msg.replace(/\{emoji([0-9]+)\}/g,
      '<img src="../../image/emoji/$1.png" height="24" width="24" />');
    lobbyChat.append(msg);
    danmaku.sendLog("<b>" + raw.userName + "</b>: " + raw.msg);
  }

  function sendDanmaku(msg) {
    danmaku.sendLog(msg);
    lobbyChat.append(msg);
  }

  Component.onCompleted: {
    toast.show(luatr("$WelcomeToLobby"));
  }
}

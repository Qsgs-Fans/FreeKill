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
  property var roomInfoCache: ({})

  property string password

  Component {
    id: roomDelegate

    Rectangle {
      radius: 8
      height: 124 - 8
      width: 124 - 8
      color: outdated ? "#E2E2E2" : "#DDDDDDDD"

      Text {
        id: roomNameText
        horizontalAlignment: Text.AlignLeft
        width: parent.width - 16
        height: contentHeight
        maximumLineCount: 2
        wrapMode: Text.WrapAnywhere
        textFormat: Text.PlainText
        text: roomName
        // color: outdated ? "gray" : "black"
        font.pixelSize: 16
        // elide: Label.ElideRight
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 8
      }

      Text {
        id: roomIdText
        text: luatr(gameMode) + ' #' + roomId
        anchors.top: roomNameText.bottom
        anchors.left: roomNameText.left
      }

      Image {
        source: AppPath + "/image/button/skill/locked.png"
        visible: hasPassword
        scale: 0.8
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: -4
      }

      Text {
        color: (playerNum == capacity) ? "red" : "black"
        text: playerNum + "/" + capacity
        font.pixelSize: 18
        font.bold: true
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 8
      }

      TapHandler {
        gesturePolicy: TapHandler.WithinBounds
        enabled: !opTimer.running && !outdated

        onTapped: {
          lobby_dialog.sourceComponent = roomDetailDialog;
          lobby_dialog.item.roomData = {
            roomId, roomName, gameMode, playerNum, capacity,
            hasPassword, outdated,
          };
          lobby_dialog.item.roomConfig = config.roomConfigCache?.[config.serverAddr]?.[roomId]
          lobby_drawer.open();
        }
      }
    }
  }

  Component {
    id: roomDetailDialog
    ColumnLayout {
      property var roomData: ({
        roomName: "",
        hasPassword: true,
      })
      property var roomConfig: undefined
      signal finished()
      anchors.fill: parent
      anchors.margins: 16

      Text {
        text: roomData.roomName
        font.pixelSize: 18
      }

      Text {
        font.pixelSize: 18
        text: {
          let ret = luatr(roomData.gameMode);
          ret += (' #' + roomData.roomId);
          ret += ('   ' + roomData.playerNum + '/' + roomData.capacity);
          return ret;
        }
      }

      Item { Layout.fillHeight: true }

      // Dummy
      Text {
        text: "在未来的版本中这一块区域将增加更多实用的功能，<br>"+
          "例如直接查看房间的各种配置信息<br>"+
          "以及更多与禁将有关的实用功能！"+
          "<font color='gray'>注：绿色按钮为试做型UI 后面优化</font>"
        font.pixelSize: 18
      }

      RowLayout {
        Layout.fillWidth: true
        Text {
          visible: roomData.hasPassword
          text: luatr("Please input room's password")
        }

        TextField {
          id: passwordEdit
          visible: roomData.hasPassword
          Layout.fillWidth: true
          onTextChanged: root.password = text;
        }

        Item {
          visible: !roomData.hasPassword
          Layout.fillWidth: true
        }

        Button {
          // text: "OK"
          text: (roomData.playerNum < roomData.capacity) ? luatr("Enter") : luatr("Observe")
          onClicked: {
            enterRoom(roomData.roomId, roomData.playerNum, roomData.capacity,
              roomData.hasPassword ? root.password : "");
            lobby_dialog.item.finished();
          }
        }
      }

      Component.onCompleted: {
        passwordEdit.text = "";
      }
    }
  }

  ListModel {
    id: roomModel
  }

  PersonalSettings {}

  Timer {
    id: opTimer
    interval: 1000
  }

  ColumnLayout {
    id: roomListLayout
    height: root.height - 72
    y: 16
    anchors.left: parent.left
    anchors.leftMargin: root.width * 0.03 + root.width * 0.94 * 0.8 % 128 / 2
    width: {
      let ret = root.width * 0.94 * 0.8;
      ret -= ret % 128;
      return ret;
    }
    clip: true

    RowLayout {
      Layout.fillWidth: true
      Item { Layout.fillWidth: true }
      Button {
        Layout.alignment: Qt.AlignRight
        text: luatr("Refresh Room List").arg(roomModel.count)
        enabled: !opTimer.running
        onClicked: {
          opTimer.start();
          ClientInstance.notifyServer("RefreshRoomList", "");
        }
      }
      Button {
        text: luatr("Create Room")
        onClicked: {
          lobby_dialog.sourceComponent =
            Qt.createComponent("../LobbyElement/CreateRoom.qml");
          lobby_drawer.open();
          config.observing = false;
          config.replaying = false;
        }
      }
    }

    GridView {
      id: roomList
      cellWidth: 128
      cellHeight: 128
      Layout.fillHeight: true
      Layout.fillWidth: true
      ScrollBar.vertical: ScrollBar {}
      delegate: roomDelegate
      clip: true
      model: roomModel
    }
  }

  Rectangle {
    id: serverInfoLayout
    height: root.height - 112
    y: 56
    width: root.width * 0.94 * 0.2
    anchors.right: parent.right
    anchors.rightMargin: root.width * 0.03
    // anchors.horizontalCenter: parent.horizontalCenter
    color: "#88EEEEEE"
    property bool chatShown: true

    Flickable {
      ScrollBar.vertical: ScrollBar {}
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: 10
      flickableDirection: Flickable.VerticalFlick
      width: parent.width - 10
      height: parent.height - 10 - (parent.chatShown ? 200 : 0)
      contentHeight: bulletin_info.height
      clip: true

      Text {
        id: bulletin_info
        width: parent.width
        wrapMode: TextEdit.WordWrap
        textFormat: Text.MarkdownText
        text: config.serverMotd + "\n\n___\n\n" + luatr('Bulletin Info')
        onLinkActivated: Qt.openUrlExternally(link);
      }
    }

    MetroButton {
      text: "🗨️" + (parent.chatShown ? "➖" : "➕")
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: lobbyChat.top
      onClicked: {
        parent.chatShown = !parent.chatShown
      }
    }

    ChatBox {
      id: lobbyChat
      width: parent.width
      height: parent.chatShown ? 200 : 0
      Behavior on height { NumberAnimation { duration: 200 } }
      anchors.bottom: parent.bottom
      isLobby: true
      color: "#88EEEEEE"
      clip: true
    }
  }

  RowLayout {
    id: buttonRow
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    width: parent.width

    Rectangle {
      Layout.fillHeight: true
      Layout.preferredWidth: childrenRect.width + 72

      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.8; color: "white" }
        GradientStop { position: 1.0; color: "transparent" }
      }
      Text {
        x: 16; y: 4
        font.pixelSize: 16
        text: luatr("$OnlineInfo")
          .arg(lobbyPlayerNum).arg(serverPlayerNum) + "\n"
          + "Powered by FreeKill " + FkVersion
      }
    }

    Item { Layout.fillWidth: true }
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

  /*
  function updateOnlineInfo() {
  }

  onLobbyPlayerNumChanged: updateOnlineInfo();
  onServerPlayerNumChanged: updateOnlineInfo();

  /*
  */

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

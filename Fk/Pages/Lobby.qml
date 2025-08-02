// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Layouts
import Fk.LobbyElement
import Fk.Common
import Fk.Widgets as W
import "Logic.js" as Logic

Item {
  id: root
  property alias roomModel: roomModel
  property var roomInfoCache: ({})

  property string password

  Component {
    id: roomDelegate

    Item {
      // radius: 8
      height: 84 - 8
      width: 280 - 4 - 8
      Rectangle {
        id: roomInfoRect
        width: childrenRect.width + 8
        height: childrenRect.height - 2 + 16
        radius: 6
        color: outdated ? "#CCCCCC" : "#D4E5F6"
        Text {
          x: 4; y: -1
          text: luatr(gameMode) + ' #' + roomId
          font.strikeout: outdated
        }
      }

      Rectangle {
        id: roomMainRect
        anchors.top: roomInfoRect.bottom
        anchors.topMargin: -16
        radius: 6
        width: parent.width
        height: parent.height - roomInfoRect.height - anchors.topMargin
        color: outdated ? "#CCCCCC" : "#D4E5F6"

        Text {
          id: roomNameText
          horizontalAlignment: Text.AlignLeft
          width: parent.width - 16
          height: contentHeight
          maximumLineCount: 1
          wrapMode: Text.WrapAnywhere
          textFormat: Text.PlainText
          text: roomName
          // color: outdated ? "gray" : "black"
          font.pixelSize: 16
          font.strikeout: outdated
          // elide: Label.ElideRight
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.leftMargin: 8
          anchors.topMargin: 4
        }

        Image {
          source: AppPath + "/image/button/skill/locked.png"
          visible: hasPassword
          scale: 0.8
          anchors.top: parent.top
          anchors.topMargin: -28
          anchors.right: parent.right
          anchors.rightMargin: -14
        }

        Text {
          id: capacityText
          color: (playerNum == capacity) ? "red" : "black"
          text: playerNum + "/" + capacity
          font.pixelSize: 18
          font.bold: true
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 4
          anchors.left: parent.left
          anchors.leftMargin: 8
        }

        TextField {
          id: passwordEdit
          visible: hasPassword && !outdated
          width: parent.width - capacityText.width - enterButton.width - 4
          height: capacityText.height + 8
          anchors.left: capacityText.right
          anchors.leftMargin: 2
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 0
          onTextChanged: root.password = text;
        }

        ToolButton {
          id: enterButton
          text: (playerNum < capacity) ? luatr("Enter") : luatr("Observe")
          enabled: !outdated && !opTimer.running
          font.pixelSize: 16
          font.bold: true
          anchors.bottom: parent.bottom
          anchors.right: parent.right
          //anchors.rightMargin: -4
          anchors.bottomMargin: -4
          onClicked: {
            opTimer.start();
            enterRoom(roomId, playerNum, capacity,
              hasPassword ? passwordEdit.text : "");
          }
        }
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

  property bool filtering: false // 筛选状态，用于刷新房间按钮

  ColumnLayout {
    id: roomListLayout
    height: root.height - 72
    y: 16
    anchors.left: parent.left
    anchors.leftMargin: root.width * 0.03 + root.width * 0.94 * 0.8 % roomList.cellWidth / 2
    width: {
      let ret = root.width * 0.94 * 0.8;
      ret -= ret % 128;
      return ret;
    }
    clip: true

    RowLayout {
      Layout.fillWidth: true
      Item { Layout.fillWidth: true }
      Rectangle {
        color: "#88EEEEEE"
        radius: 4
        Layout.preferredWidth: childrenRect.width + 2
        Layout.preferredHeight: childrenRect.height - 12
        CheckBox {
          anchors.centerIn: parent
          id: autoFilterRoomCheck
          checked: true
          text: luatr("Automatically Filter Room List")
        }
      }
      Button {
        Layout.alignment: Qt.AlignRight
        text: luatr("Refresh Room List").arg(roomModel.count)
        enabled: !opTimer.running
        onClicked: { // 刷新，筛选
          opTimer.start();
          filtering = autoFilterRoomCheck.checked;
          ClientInstance.notifyServer("RefreshRoomList", "");
        }
        // onPressAndHold: { // 取消筛选，刷新，但不清除筛选
        //   opTimer.start();
        //   ClientInstance.notifyServer("RefreshRoomList", "");
        // }
        // ToolTip {
        //   text: luatr("RefreshRoomHelp")
        //   visible: parent.hovered
        //   delay: 1000
        //   x: parent.width / 2 - 16
        //   y: parent.height - 16
        // }
      }
      Button {
        text: luatr("Filter")
        onClicked: { // 打开筛选框，在框内完成筛选，不刷新
          lobby_drawer.sourceComponent = Qt.createComponent("../LobbyElement/FilterRoom.qml"); //roomFilterDialog;
          lobby_drawer.open();
        }
        // onPressAndHold: { // 清除筛选，刷新（等于筛选框里的清除）
        //   config.preferredFilter = { // 清空
        //     name: "", // 房间名
        //     id: "", // 房间ID
        //     modes : [], // 游戏模式
        //     full : 2, // 满员，0满，1未满，2不限
        //     hasPassword : 2, // 密码，0有，1无，2不限
        //   };
        //   config.preferredFilterChanged();
        //   opTimer.start();
        //   ClientInstance.notifyServer("RefreshRoomList", "");
        // }
        // ToolTip {
        //   text: luatr("FilterHelp")
        //   visible: parent.hovered
        //   delay: 1000
        //   x: parent.width / 2 - 16
        //   y: parent.height - 16
        // }
      }
      Button {
        text: luatr("Create Room")
        onClicked: {
          lobby_drawer.sourceComponent =
            Qt.createComponent("../LobbyElement/CreateRoom.qml");
          lobby_drawer.open();
          config.observing = false;
          config.replaying = false;
        }
      }
    }

    GridView {
      id: roomList
      cellWidth: 280
      cellHeight: 88
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
      Behavior on height { NumberAnimation { duration: 200 } }
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
      text: luatr("Modes Overview")
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

  W.PopupLoader {
    id: lobby_drawer
    padding: 0
    width: realMainWin.width * 0.80
    height: realMainWin.height * 0.95
    anchors.centerIn: parent
  }

  function enterRoom(roomId, playerNum, capacity, pw) {
    config.replaying = false;
    if (playerNum < capacity) {
      config.observing = false;
      mainWindow.busy = true;
      ClientInstance.notifyServer(
        "EnterRoom",
        [roomId, pw]
      );
    } else {
      config.observing = true;
      mainWindow.busy = true;
      ClientInstance.notifyServer(
        "ObserveRoom",
        [roomId, pw]
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
      `<img src="${AppPath}/image/emoji/$1.png" height="24" width="24" />`);
    raw.msg = raw.msg.replace(/\{emoji([0-9]+)\}/g,
      `<img src="${AppPath}/image/emoji/$1.png" height="24" width="24" />`);
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

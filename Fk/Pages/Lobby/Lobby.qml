// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Layouts

import Fk
import Fk.Components.Lobby
import Fk.Components.Common
import Fk.Widgets as W

W.PageBase {
  id: root
  property alias roomModel: roomModel
  property var roomInfoCache: ({})

  property string password

  property int lobbyPlayerNum: 0
  property int serverPlayerNum: 0

  property bool filtering: false // 筛选状态，用于刷新房间按钮

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
          text: Lua.tr("Automatically Filter Room List")
        }
      }
      Button {
        Layout.alignment: Qt.AlignRight
        text: Lua.tr("Refresh Room List").arg(roomModel.count)
        enabled: !opTimer.running
        onClicked: { // 刷新，筛选
          opTimer.start();
          root.filtering = autoFilterRoomCheck.checked;
          Cpp.notifyServer("RefreshRoomList", "");
        }
        // onPressAndHold: { // 取消筛选，刷新，但不清除筛选
        //   opTimer.start();
        //   ClientInstance.notifyServer("RefreshRoomList", "");
        // }
        // ToolTip {
        //   text: Lua.tr("RefreshRoomHelp")
        //   visible: parent.hovered
        //   delay: 1000
        //   x: parent.width / 2 - 16
        //   y: parent.height - 16
        // }
      }
      Button {
        text: Lua.tr("Filter")
        onClicked: { // 打开筛选框，在框内完成筛选，不刷新
          lobby_drawer.sourceComponent = Qt.createComponent("FilterRoom.qml"); //roomFilterDialog;
          lobby_drawer.open();
        }
      }
      Button {
        text: Lua.tr("Create Room")
        onClicked: {
          lobby_drawer.sourceComponent =
            Qt.createComponent("CreateRoom.qml");
          lobby_drawer.open();
          Config.observing = false;
          Config.replaying = false;
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
      delegate: RoomDelegate {
        timer: opTimer
      }
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
        text: Config.serverMotd + "\n\n___\n\n" + Lua.tr('Bulletin Info')
        onLinkActivated: (link) => Qt.openUrlExternally(link);
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
        text: Lua.tr("$OnlineInfo")
          .arg(lobbyPlayerNum).arg(serverPlayerNum) + "\n"
          + "Powered by FreeKill " + FkVersion
      }
    }

    Item { Layout.fillWidth: true }
    Button {
      text: Lua.tr("Generals Overview")
      onClicked: {
        App.enterNewPage("Fk.Pages.Common", "GeneralsOverview");
      }
    }
    Button {
      text: Lua.tr("Cards Overview")
      onClicked: {
        App.enterNewPage("Fk.Pages.Common", "CardsOverview");
      }
    }
    Button {
      text: Lua.tr("Modes Overview")
      onClicked: {
        App.enterNewPage("Fk.Pages.Common", "ModesOverview");
      }
    }
    Button {
      text: Lua.tr("Replay")
      onClicked: {
        App.enterNewPage("Fk.Pages.Replay", "Replay");
      }
    }
    Button {
      text: Lua.tr("About")
      onClicked: {
        App.enterNewPage("Fk.Pages.Common", "About");
      }
    }
  }

  Button {
    id: exitButton
    anchors.right: parent.right
    text: Lua.tr("Exit Lobby")
    display: AbstractButton.TextBesideIcon
    icon.name: "application-exit"
    onClicked: {
      App.showToast("Goodbye.");
      App.quitPage();
      Config.saveConf();
      Cpp.quitLobby();
    }
  }

  W.PopupLoader {
    id: lobby_drawer
    padding: 0
    width: Config.winWidth * 0.80
    height: Config.winHeight * 0.95
    anchors.centerIn: parent
  }

  function enterRoom(roomId, playerNum, capacity, pw) {
    Config.replaying = false;
    if (playerNum < capacity) {
      Config.observing = false;
      App.setBusy(true);
      Cpp.notifyServer("EnterRoom", [roomId, pw]);
    } else {
      Config.observing = true;
      App.setBusy(true);
      Cpp.notifyServer("ObserveRoom", [roomId, pw]);
    }
  }

  Danmu {
    id: danmu
    width: parent.width
  }

  function addToChat(pid, raw: var, msg: var) {
    if (raw.type !== 1) return;
    msg = msg.replace(/\{emoji([0-9]+)\}/g,
      `<img src="${Cpp.path}/image/emoji/$1.png" height="24" width="24" />`);
    raw.msg = raw.msg.replace(/\{emoji([0-9]+)\}/g,
      `<img src="${Cpp.path}/image/emoji/$1.png" height="24" width="24" />`);
    lobbyChat.append(msg);
    danmu.sendLog("<b>" + raw.userName + "</b>: " + raw.msg);
  }

  function sendDanmu(msg) {
    danmu.sendLog(msg);
    lobbyChat.append(msg);
  }

  function updateRoomList(sender, data: var) {
    roomModel.clear();
    data.forEach(room => {
      const [roomId, roomName, gameMode, playerNum, capacity, hasPassword,
        outdated] = room;
      if (filtering) { // 筛选
        const f = Config.preferredFilter;
        if ((f.name !== '' && !roomName.includes(f.name))
          || (f.id !== '' && !roomId.toString().includes(f.id))
          || (f.modes.length > 0 && !f.modes.includes(Lua.tr(gameMode)))
          || (f.full !== 2 &&
            (f.full === 0 ? playerNum < capacity : playerNum >= capacity))
          || (f.hasPassword !== 2 &&
            (f.hasPassword === 0 ? !hasPassword : hasPassword))
          // || (capacityList.length > 0 && !capacityList.includes(capacity))
        ) return;
      }
      roomModel.append({
        roomId, roomName, gameMode, playerNum, capacity,
        hasPassword, outdated,
      });
    });
    filtering = false;
  }

  function updatePlayerNum(sender, data) {
    const l = data[0];
    const s = data[1];
    lobbyPlayerNum = l;
    serverPlayerNum = s;
  }

  function handleEnterRoom(sender, data) {
    // jsonData: int capacity, int timeout
    Config.roomCapacity = data[0];
    Config.roomTimeout = data[1] - 1;
    const roomSettings = data[2];
    Config.enableFreeAssign = roomSettings.enableFreeAssign;
    Config.heg = roomSettings.gameMode.includes('heg_mode');
    App.enterNewPage("Fk.Pages.Common", "RoomPage", {
      gameComponent: Qt.createComponent("Fk.Pages.Common", "WaitingRoom"),
    });
    App.setBusy(false);
  }

  Component.onCompleted: {
    addCallback(Command.UpdateRoomList, updateRoomList);
    addCallback(Command.UpdatePlayerNum, updatePlayerNum);

    addCallback(Command.EnterRoom, handleEnterRoom);

    App.showToast(Lua.tr("$WelcomeToLobby"));
  }
}

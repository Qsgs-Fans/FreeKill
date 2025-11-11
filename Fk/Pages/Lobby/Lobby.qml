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
      Layout.preferredHeight: 54
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

    Repeater {
      Layout.alignment: Qt.AlignVCenter
      model: ListModel {
        id: preferredButtonsModel
      }
      delegate: W.ButtonContent {
        text: Lua.tr(name)
        font.bold: true
        icon.source: iconUrl
        plainButton: false

        onClicked: root.handleClickButton(model)
      }
    }

    W.ButtonContent {
      Layout.alignment: Qt.AlignVCenter
      plainButton: false
      text: "更多..."
      font.bold: true
      icon.source: Cpp.path + "/image/symbolic/categories/emoji-symbols-symbolic.svg"
      onClicked: {
        morePagesDrawer.open();
      }
    }

    Item { Layout.preferredWidth: 2 }
  }

  Drawer {
    id: morePagesDrawer
    width: 0.6 * Config.winWidth
    height: Config.winHeight
    edge: Qt.RightEdge

    dim: false

    background: Rectangle {
      color: "#DDF1F1F2"
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.2; color: "#DDF1F1F2" }
      }
    }

    Item {
      // 经典Popup要套壳个Item 烂QML
      id: moreManager
      property bool isManageMode: false

      width: parent.width / Config.winScale
      height: parent.height / Config.winScale
      scale: Config.winScale
      anchors.centerIn: parent

      ColumnLayout {
        height: parent.height - 20
        width: parent.width * 0.8 - 80//- 40 - 40
        anchors.right: parent.right
        anchors.rightMargin: 40

        ListView {
          id: morePagesListView
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true

          spacing: 16

          model: ListModel {
            id: morePagesModel
          }

          delegate: ColumnLayout {
            id: morePagesItem
            width: morePagesListView.width

            Text {
              text: Lua.tr(pkname)
              font.pixelSize: 18
              // font.bold: true
              textFormat: Text.RichText
              wrapMode: Text.WrapAnywhere
              Layout.fillWidth: true
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 2
              color: "black"
              gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.4; color: "black" }
                GradientStop { position: 0.6; color: "transparent" }
              }
            }

            Item {
              Layout.preferredHeight: 4
            }

            Grid {
              rowSpacing: 8
              columnSpacing: 8
              columns: 3
              Layout.leftMargin: 2

              Repeater {
                model: pages
                delegate: W.ButtonContent {
                  text: Lua.tr(name)
                  font.bold: true
                  icon.source: iconUrl
                  width: morePagesItem.width / 3 - 8
                  plainButton: false

                  onClicked: {
                    if (moreManager.isManageMode) {
                      const idx = Config.preferredButtons.indexOf(name);
                      if (idx !== -1) {
                        Config.preferredButtons.splice(idx, 1);
                      } else {
                        Config.preferredButtons.unshift(name);
                        if (Config.preferredButtons.length > 5) {
                          Config.preferredButtons.pop();
                        }
                      }
                      Config.saveConf();
                      root.rearrangePreferred();
                    } else {
                      morePagesDrawer.close();
                      root.handleClickButton(model);
                    }
                  }

                  backgroundColor: {
                    if (moreManager.isManageMode && Config.preferredButtons.includes(name)) {
                      return "gold";
                    }
                    return "#E6E6E7";
                  }

                  Behavior on backgroundColor {
                    ColorAnimation { duration: 200 } }
                }
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 2
          color: "black"
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.4; color: "transparent" }
            GradientStop { position: 0.6; color: "black" }
          }
        }

        Item {
          Layout.preferredHeight: 4
        }

        W.ButtonContent {
          Layout.alignment: Qt.AlignRight
          Layout.preferredWidth: parent.width / 3 - 4
          text: moreManager.isManageMode ? "完成修改" : "添加到下方"
          font.bold: true
          icon.source: Cpp.path + "/image/symbolic/places/user-bookmarks-symbolic.svg"
          plainButton: false
          onClicked: {
            moreManager.isManageMode = !moreManager.isManageMode;
          }
        }
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
    Config.heg = roomSettings.gameMode.includes('heg_mode');

    let displayName = roomSettings.roomName;
    if (roomSettings.roomId !== undefined) {
      displayName += "[{id}]".replace("{id}", roomSettings.roomId);
    }
    Config.headerName = Lua.tr("Current room: %1").arg(displayName);
    App.enterNewPage("Fk.Pages.Common", "RoomPage", {
      gameComponent: Qt.createComponent("Fk.Pages.Common", "WaitingRoom"),
    });
    App.setBusy(false);
  }

  function handleClickButton(data) {
    const { popup, qml } = data;
    if (!popup) {
      if (qml.uri && qml.name) {
        App.enterNewPage(qml.uri, qml.name);
      } else {
        App.enterNewPage(Cpp.path + "/" + qml.url);
      }
    } else {
      let comp;
      if (qml.uri && qml.name) {
        comp = Qt.createComponent(qml.uri, qml.name);
      } else {
        comp = Qt.createComponent(Cpp.path + "/" + qml.url);
      }
      lobby_drawer.sourceComponent = comp;
      lobby_drawer.open();
    }
  }

  function rearrangePreferred(){
    const preferredOrder = [];
    preferredButtonsModel.clear();
    for (let i = 0; i < morePagesModel.count; i++) {
      const v = morePagesModel.get(i);
      for (let j = 0; j < v.pages.count; j++) {
        const vp = v.pages.get(j);
        const vi = Config.preferredButtons.indexOf(vp.name)
        if (vi !== -1) {
          preferredOrder[vi] = vp;
        }
      }
    }
    for (const vp of preferredOrder) {
      preferredButtonsModel.append(vp);
    }
  }

  Component.onCompleted: {
    addCallback(Command.UpdateRoomList, updateRoomList);
    addCallback(Command.UpdatePlayerNum, updatePlayerNum);

    addCallback(Command.EnterRoom, handleEnterRoom);

    const customPagesSpecs = Lua.fn(`function()
      local pkgs = table.map(table.filter(Fk.package_names, function(name)
        return Fk.packages[name].customPages ~= nil
      end), function(name)
        return {
          name = name,
          pages = Fk.packages[name].customPages
        }
      end)

      return pkgs
    end`)();

    customPagesSpecs.unshift({
      name: "default",
      pages: [
        {
          name: "Modes Overview",
          iconUrl: Cpp.path + "/image/symbolic/categories/applications-games-symbolic.svg",
          qml: {
            uri: "Fk.Pages.Common",
            name: "ModesOverview",
          }
        },
        {
          name: "Replay",
          iconUrl: Cpp.path + "/image/symbolic/categories/emoji-recent-symbolic.svg",
          qml: {
            uri: "Fk.Pages.Replay",
            name: "Replay",
          }
        },
        {
          name: "Settings",
          iconUrl: Cpp.path + "/image/symbolic/categories/applications-system-symbolic.svg",
          popup: true,
          qml: {
            uri: "Fk.Pages.Lobby",
            name: "EditProfile",
          }
        },
        {
          name: "About",
          iconUrl: Cpp.path + "/image/symbolic/actions/help-about-symbolic.svg",
          qml: {
            uri: "Fk.Pages.Common",
            name: "About",
          }
        },
      ],
    })

    for (const v of customPagesSpecs) {
      morePagesModel.append({
        pkname: v.name,
        pages: v.pages,
      });
    }
    // const preferredOrder = [];
    // for (const v of customPagesSpecs) {
    //   morePagesModel.append({
    //     pkname: v.name,
    //     pages: v.pages,
    //   });
    //   for (const vp of v.pages) {
    //     const vi = Config.preferredButtons.indexOf(vp.name)
    //     if (vi !== -1) {
    //       preferredOrder[vi] = vp;
    //     }
    //   }
    // }
    // for (const vp of preferredOrder) {
    //   preferredButtonsModel.append(vp);
    // }
    rearrangePreferred();

    Db.tryInitModeSettings();
    App.showToast(Lua.tr("$WelcomeToLobby"));
  }
}

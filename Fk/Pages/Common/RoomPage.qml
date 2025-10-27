import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import QtQuick.Dialogs

import Fk
import Fk.Components.Common
import Fk.Components.GameCommon
import Fk.Widgets as W
import Fk.Pages.Lobby as L

Item {
  id: root

  readonly property alias gameContent: gameLoader.item
  property alias gameComponent: gameLoader.sourceComponent

  property real replayerSpeed
  property int replayerElapsed
  property int replayerDuration

  Image {
    id: bg
    source: Config.lobbyBg
    anchors.fill: parent
    fillMode: Image.PreserveAspectCrop

    layer.enabled: true
    layer.effect: FastBlur {
      radius: 72
    }
  }

  Rectangle {
    id: bgRect
    anchors.fill: parent
    color: "#AFFFFFFF"
  }

  Rectangle {
    id: shadowRect
    color: "black"
    width: gameLoader.width
    height: gameLoader.height
    x: gameLoader.x
    y: gameLoader.y
    scale: gameLoader.scale

    layer.enabled: true
    layer.effect: DropShadow {
      transparentBorder: true
      radius: 12
      samples: 16
      color: "#000000"
    }
  }

  Item {
    id: topPanel
    height: parent.height * (0.5 - shadowRect.scale / 2)
    width: parent.width

    Text {
      anchors.centerIn: parent
      text: Config.headerName !== "" ? Config.headerName : Lua.tr("Click The Game Scene to back")
      font.pixelSize: 16
    }
  }

  Item {
    id: bottomPanel
    height: parent.height * (0.5 - shadowRect.scale / 2)
    width: parent.width
    anchors.bottom: parent.bottom

    Rectangle {
      id: replayControls
      visible: Config.replaying
      anchors.centerIn: bottomPanel
      width: childrenRect.width + 8
      height: childrenRect.height + 8

      // color: "#88EEEEEE"
      // radius: 4
      color: 'transparent'

      RowLayout {
        x: 4; y: 4
        Text {
          font.pixelSize: 20
          font.bold: true
          text: {
            function addZero(temp) {
              if (temp < 10) return "0" + temp;
              else return temp;
            }
            const elapsedMin = Math.floor(replayerElapsed / 60);
            const elapsedSec = addZero(replayerElapsed % 60);
            const totalMin = Math.floor(replayerDuration / 60);
            const totalSec = addZero(replayerDuration % 60);

            return elapsedMin.toString() + ":" + elapsedSec + "/" + totalMin
            + ":" + totalSec;
          }
        }

        Switch {
          text: Lua.tr("Show All Cards")
          checked: Config.replayingShowCards
          onCheckedChanged: Config.replayingShowCards = checked;
        }

        Switch {
          text: Lua.tr("Speed Resume")
          checked: false
          onCheckedChanged: Backend.controlReplayer("uniform");
        }

        W.ButtonContent {
          plainButton: false
          Layout.preferredWidth: 40
          // text: Lua.tr("Speed Down")
          icon.source: "http://175.178.66.93/symbolic/actions/media-seek-backward-symbolic.svg"
          onClicked: Backend.controlReplayer("slowdown");
        }

        Text {
          font.pixelSize: 20
          font.bold: true
          text: "x" + replayerSpeed;
        }

        W.ButtonContent {
          plainButton: false
          Layout.preferredWidth: 40
          // text: Lua.tr("Speed Up")
          icon.source: "http://175.178.66.93/symbolic/actions/media-seek-forward-symbolic.svg"
          onClicked: Backend.controlReplayer("speedup");
        }

        W.ButtonContent {
          plainButton: false
          property bool running: true
          Layout.preferredWidth: 40
          // text: Lua.tr(running ? "Pause" : "Resume")
          icon.source: running ?
            "http://175.178.66.93/symbolic/actions/media-playback-pause-symbolic.svg" :
            "http://175.178.66.93/symbolic/actions/media-playback-start-symbolic.svg"
          onClicked: {
            running = !running;
            Backend.controlReplayer("toggle");
          }
        }
      }
    }
  }

  ColumnLayout {
    anchors.right: parent.right
    anchors.rightMargin: 20
    anchors.top: parent.top
    anchors.topMargin: parent.height * 0.1
    spacing: 8
    width: parent.width - shadowRect.width * shadowRect.scale - 40 - 40
    height: shadowRect.height * shadowRect.scale

    W.ButtonContent {
      id: quitButton
      plainButton: false
      text: Lua.tr("Quit")
      icon.source: "http://175.178.66.93/symbolic/actions/application-exit-rtl-symbolic.svg"
      font.bold: true
      Layout.fillWidth: true
      onClicked: {
        root.tryQuitRoom();
      }
    }

    W.ButtonContent {
      id: volumeButton
      plainButton: false
      text: Lua.tr("Settings")
      icon.source: "http://175.178.66.93/symbolic/categories/applications-system-symbolic.svg"
      font.bold: true
      Layout.fillWidth: true
      onClicked: {
        settingsDialog.open();
      }
    }

    W.ButtonContent {
      id: banSchemaButton
      plainButton: false
      text: Lua.tr("Info")
      icon.source: "http://175.178.66.93/symbolic/mimetypes/x-office-document-symbolic.svg"
      font.bold: true
      Layout.fillWidth: true
      onClicked: {
        overviewLoader.overviewType = "GeneralPool";
        overviewDialog.open();
      }
    }

    W.ButtonContent {
      id: surrenderButton
      plainButton: false
      enabled: !Config.observing && !Config.replaying
      text: Lua.tr("Surrender")
      icon.source: Cpp.path + "/image/misc/surrender"
      font.bold: true
      Layout.fillWidth: true
      onClicked: {
        if (Lua.evaluate('not ClientInstance.gameStarted')) {
          return;
        }
        if (Lua.evaluate('Self.dead and (Self.rest <= 0)')) {
          return;
        }
        const surrenderCheck = Lua.call('CheckSurrenderAvailable');
        if (!surrenderCheck.length) {
          surrenderDialog.informativeText =
          Lua.tr('Surrender is disabled in this mode');
        } else {
          surrenderDialog.informativeText = surrenderCheck
          .map(str => `${Lua.tr(str.text)}（${str.passed ? '✓' : '✗'}）`)
          .join('<br>');
        }
        surrenderDialog.open();
      }
    }


    W.ButtonContent {
      id: generalButton
      plainButton: false
      text: Lua.tr("Generals Overview")
      icon.source: "http://175.178.66.93/symbolic/lunarltk/jiang.png"
      font.bold: true
      Layout.fillWidth: true
      onClicked: {
        overviewLoader.overviewType = "Generals";
        overviewDialog.open();
        overviewLoader.item.loadPackages();
      }
    }

    W.ButtonContent {
      id: cardslButton
      plainButton: false
      text: Lua.tr("Cards Overview")
      icon.source: "http://175.178.66.93/symbolic/lunarltk/cards.svg"
      font.bold: true
      Layout.fillWidth: true
      onClicked: {
        overviewLoader.overviewType = "Cards";
        overviewDialog.open();
        overviewLoader.item.loadPackages();
      }
    }

    W.ButtonContent {
      id: modesButton
      plainButton: false
      text: Lua.tr("Modes Overview")
      icon.source: "http://175.178.66.93/symbolic/categories/applications-games-symbolic.svg"
      font.bold: true
      Layout.fillWidth: true
      onClicked: {
        overviewLoader.overviewType = "Modes";
        overviewDialog.open();
      }
    }

    Item {
      Layout.fillHeight: true
    }

    W.ButtonContent {
      id: chatButton
      plainButton: false
      text: Lua.tr("Chat")
      icon.source: "http://175.178.66.93/symbolic/actions/chat-message-new-symbolic.svg"
      font.bold: true
      Layout.fillWidth: true
      onClicked: {
        roomDrawer.open();
      }
    }
  }

  MessageDialog {
    id: quitDialog
    title: Lua.tr("Quit")
    informativeText: Lua.tr("Are you sure to quit?")
    buttons: MessageDialog.Ok | MessageDialog.Cancel
    onButtonClicked: function (button) {
      switch (button) {
        case MessageDialog.Ok: {
          Cpp.notifyServer("QuitRoom", "[]");
          break;
        }
        case MessageDialog.Cancel: {
          quitDialog.close();
        }
      }
    }
  }

  MessageDialog {
    id: surrenderDialog
    title: Lua.tr("Surrender")
    informativeText: ''
    buttons: MessageDialog.Ok | MessageDialog.Cancel
    onButtonClicked: function (button, role) {
      switch (button) {
        case MessageDialog.Ok: {
          const surrenderCheck =
          Lua.call('CheckSurrenderAvailable');
          if (surrenderCheck.length &&
          !surrenderCheck.find(check => !check.passed)) {

            Cpp.notifyServer("PushRequest", [
              "surrender", true
            ].join(","));
          }
          surrenderDialog.close();
          break;
        }
        case MessageDialog.Cancel: {
          surrenderDialog.close();
        }
      }
    }
  }

  W.PopupLoader {
    id: overviewDialog
    width: Config.winWidth * 0.8
    height: Config.winHeight * 0.9
    anchors.centerIn: parent
    background: Rectangle {
      color: "#EEEEEEEE"
      radius: 5
      border.color: "#A6967A"
      border.width: 1
    }
    Loader {
      id: overviewLoader
      property string overviewType: "GeneralPool"
      anchors.centerIn: parent
      width: parent.width / Config.winScale
      height: parent.height / Config.winScale
      scale: Config.winScale
      source: "../Common/" + overviewType + "Overview.qml"
    }
  }

  W.PopupLoader {
    id: settingsDialog
    padding: 0
    width: Config.winWidth * 0.8
    height: Config.winHeight * 0.9
    anchors.centerIn: parent
    background: Rectangle {
      color: "#EEEEEEEE"
      radius: 5
      border.color: "#A6967A"
      border.width: 1
    }

    sourceComponent: RowLayout {
      W.SideBarSwitcher {
        id: settingBar
        Layout.preferredWidth: 200
        Layout.fillHeight: true
        model: ListModel {
          ListElement { name: "Audio Settings" }
          ListElement { name: "Control Settings" }
        }
      }

      SwipeView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        interactive: false
        orientation: Qt.Vertical
        currentIndex: settingBar.currentIndex
        clip: true
        L.AudioSetting {}
        L.ControlSetting {}
      }
    }
  }

  Loader {
    id: gameLoader
    width: parent.width
    height: parent.height
    clip: true

    Behavior on x { NumberAnimation { duration: 150 } }
    Behavior on y { NumberAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 150 } }

    // Image {
    //   source: Config.roomBg
    //   anchors.fill: parent
    //   fillMode: Image.PreserveAspectCrop
    // }

    MediaArea {
      source: Config.roomBg
      anchors.fill: parent
      fillMode: Image.PreserveAspectCrop
    }
  }

  RoomOverlay {
    id: overlay
    anchors.fill: parent
    gameContent: gameLoader
  }

  W.PopupLoader {
    id: roomDrawer
    width: Config.winWidth * 0.4
    height: Config.winHeight * 0.95
    x: Config.winHeight * 0.025
    y: Config.winHeight * 0.025

    property int rememberedIdx: 0

    background: Rectangle {
      radius: 12 * Config.winScale
      color: "#FAFAFB"
      opacity: 0.9
    }

    ColumnLayout {
      // anchors.fill: parent
      width: parent.width / Config.winScale
      height: parent.height / Config.winScale
      scale: Config.winScale
      transformOrigin: Item.TopLeft

      W.ViewSwitcher {
        id: drawerBar
        Layout.alignment: Qt.AlignHCenter
        model: [
          Lua.tr("Log"),
          Lua.tr("Chat"),
          Lua.tr("PlayerList"),
        ]
      }

      SwipeView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        interactive: false
        currentIndex: drawerBar.currentIndex
        clip: true

        Item {
          LogEdit {
            id: log
            anchors.fill: parent
          }
        }

        Item {
          visible: !Config.replaying
          AvatarChatBox {
            id: chat
            anchors.fill: parent
          }
        }

        ListView {
          id: playerList

          clip: true
          ScrollBar.vertical: ScrollBar {}
          model: ListModel {
            id: playerListModel
          }

          delegate: ItemDelegate {
            width: playerList.width
            height: 30
            text: {
              let ret = screenName;
              if (observing) {
                ret = '*旁观* ' + ret;
              }
              if (netState == 2) {
                ret = '<font color="blue">*托管*</font> ' + ret;
              } else if (netState == 3) {
                ret = '<font color="red">*逃跑*</font> ' + ret;
              } else if (netState == 5) {
                ret = '<font color="blue">*人机*</font> ' + ret;
              } else if (netState == 6) {
                ret = '<font color="gray">*离线*</font> ' + ret;
              }
              return ret;
            }
          }
        }
      }
    }

    onAboutToHide: {
      // 安卓下在聊天时关掉Popup会在下一次点开时完全卡死
      // 可能是Qt的bug 总之为了伺候安卓需要把聊天框赶走
      rememberedIdx = drawerBar.currentIndex;
      drawerBar.currentIndex = 0;
    }

    onAboutToShow: {
      drawerBar.currentIndex = rememberedIdx;
      playerListModel.clear();
      const ps = Lua.call("GetPlayersAndObservers");
      ps.forEach(p => {
        playerListModel.append({
          id: p.id,
          screenName: p.name,
          general: p.general ?? "",
          deputyGeneral: p.deputy ?? "",
          observing: p.observing,
          netState: p.state,
          avatar: p.avatar,
        });
      });
    }
  }

  Danmu {
    id: danmu
    width: parent.width
  }

  Shortcut {
    sequence: "T"
    onActivated: {
      roomDrawer.open();
    }
  }

  function canHandleCommand(cmd) {
    return gameContent.canHandleCommand(cmd) || overlay.canHandleCommand(cmd);
  }

  function handleCommand(sender, cmd, data) {
    if (gameContent.canHandleCommand(cmd)) {
      gameContent.handleCommand(sender, cmd, data);
    }
    if (overlay.canHandleCommand(cmd)) {
      overlay.handleCommand(sender, cmd, data);
    }
  }

  function enterLobby(sender, data) {
    App.quitPage();

    App.setBusy(false);
    Cpp.notifyServer("RefreshRoomList", "");
    Config.saveConf();
  }

  function specialChat(pid, data, msg) {
    // skill audio: %s%d[%s]
    // death audio: ~%s
    // something special: !%s:...

    const time = data.time;
    const userName = data.userName;
    const general = Lua.tr(data.general);
    const room = gameLoader.item;

    if (msg.startsWith("@")) { // 蛋花
      if (Config.hidePresents)
        return true;

      const splited = msg.split(":");
      const type = splited[0].slice(1);
      switch (type) {
        case "Egg":
        case "GiantEgg":
        case "Shoe":
        case "Wine":
        case "Flower": {
          const fromId = pid;
          const toId = parseInt(splited[1]);
          const component = Qt.createComponent("Fk.Components.LunarLTK.ChatAnim", type);
          if (component.status !== Component.Ready) {
            console.warn(component.errorString());
            return false;
          }

          const fromGetter = room.getPhotoOrDashboard || room.getPhoto || null;
          const toGetter = room.getPhoto || null;
          if (!fromGetter || !toGetter) return false;
          const fromItem = fromGetter(fromId);
          const fromPos = mapFromItem(fromItem, fromItem.width / 2,
                                      fromItem.height / 2);
          const toItem = toGetter(toId);
          const toPos = mapFromItem(toItem, toItem.width / 2,
                                    toItem.height / 2);
          const egg = component.createObject(room, { start: fromPos, end: toPos });
          egg.finished.connect(() => egg.destroy());
          egg.running = true;

          return true;
        }
        default:
          return false;
      }
    } else if (msg.startsWith("!") || msg.startsWith("~")) { // 胜利、阵亡
      const g = msg.slice(1);
      const extension = Lua.call("GetGeneralData", g).extension;
      if (!Config.disableMsgAudio) {
        const path = SkinBank.getAudio(g, extension, msg.startsWith("!") ? "win" : "death");
        Backend.playSound(path);
      }

      const m = Lua.tr(msg);
      data.msg = m;
    } else { // 技能
      const split = msg.split(":");
      if (split.length < 2) return false;
      const skill = split[0];
      const idx = parseInt(split[1]);
      const gene = split[2];

      if (!Config.disableMsgAudio) {
        let i = idx;
        let general = gene;

        // let extension = data.extension;
        let extension;
        let path;
        let dat;
        const tryPlaySound = (general) => {
          if (general) {
            const dat = Lua.call("GetGeneralData", general);
            const extension = dat.extension;
            const path = SkinBank.getAudio(skill + "_" + general, extension, "skill");
            if (path !== undefined) {
              Backend.playSound(path, i);
              return true;
            }
          }
          return false;
        };

        // Try main general first, then deputy general
        if (!tryPlaySound(general)) {
          // finally normal skill
          dat = Lua.call("GetSkillData", skill);
          extension = dat.extension;
          path = SkinBank.getAudio(skill, extension, "skill");
          Backend.playSound(path, i);
        }
      }

      const m = Lua.tr("$" + skill + (gene ? "_" + gene : "")
                          + (idx ? idx.toString() : ""));
      data.msg = m;
    }
  }

  function addToChat(pid, raw, msg) {
    if (raw.type === 1) return;
    const room = gameLoader.item;

    const photo = typeof room.getPhoto === 'function' ? room.getPhoto(pid) : null;
    if (!photo && Config.hideObserverChatter)
      return;

    msg = msg.replace(/\{emoji([0-9]+)\}/g,
      `<img src="${Cpp.path}/image/emoji/$1.png" height="16" width="16" />`);
    raw.msg = raw.msg.replace(/\{emoji([0-9]+)\}/g,
      `<img src="${Cpp.path}/image/emoji/$1.png" height="16" width="16" />`);

    if (raw.msg.startsWith("$")) {
      if (specialChat(pid, raw, raw.msg.slice(1))) return; // 蛋花、语音
    }

    chat.append(msg, raw);

    if (!photo) {
      const user = raw.userName;
      const m = raw.msg;
      danmu.sendLog(`${user}: ${m}`);
      return;
    } else if (photo.chat) {
      photo.chat(raw.msg);
    }
  }

  function sendDanmu(msg) {
    danmu.sendLog(msg);
    chat.append(null, {
      msg: msg,
      general: "__server", // FIXME: 基于默认读取貂蝉的数据
      userName: "",
      time: "Server",
    });
  }

  function addToLog(_, msg) {
    log.append({ logText: msg });
  }

  function replyToServer(sender, data) {
    ClientInstance.replyToServer("", data);
    gameContent.state = "notactive";
  }

  function changeRoomPage(_, data) {
    gameLoader.sourceComponent = data;
  }

  function resetRoomPage() {
    Lua.call("ResetClientLua");
    gameLoader.sourceComponent = Qt.createComponent("Fk.Pages.Common", "WaitingRoom");
    log.clear();
    chat.clear();
    Mediator.notify(this, Command.BackToRoom);
  }

  function tryQuitRoom() {
    if (Config.replaying) {
      App.quitPage();
      Backend.controlReplayer("shutdown");
    } else if (Config.observing || Lua.evaluate(`not ClientInstance.gameStarted`)) {
      Cpp.notifyServer("QuitRoom", "");
    } else {
      quitDialog.open();
    }
  }

  function trySaveRecord() {
    Lua.call("SaveRecord");
    App.showToast("OK.");
  }

  function tryBookmarkRecord() {
    Backend.saveBlobRecordToFile(ClientInstance.getMyGameData()[0].id); // 建立在自动保存录像基础上
    App.showToast("OK.");
  }

  function openChat() {
    roomDrawer.open();
  }

  Component.onCompleted: {
    overlay.addCallback(Command.EnterLobby, enterLobby);
    overlay.addCallback(Command.GameLog, addToLog);
    overlay.addCallback(Command.ReplyToServer, replyToServer);
    overlay.addCallback(Command.ChangeRoomPage, changeRoomPage);
    overlay.addCallback(Command.ResetRoomPage, resetRoomPage);

    overlay.addCallback(Command.IWantToQuitRoom, tryQuitRoom);
    overlay.addCallback(Command.IWantToSaveRecord, trySaveRecord);
    overlay.addCallback(Command.IWantToBookmarkRecord, trySaveRecord);
    overlay.addCallback(Command.IWantToChat, openChat);

    overlay.addCallback(Command.ReplayerDurationSet, (_, j) => {
      root.replayerDuration = parseInt(j);
    });
    overlay.addCallback(Command.ReplayerElapsedChange, (_, j) => {
      root.replayerElapsed = parseInt(j);
    });
    overlay.addCallback(Command.ReplayerSpeedChange, (_, j) => {
      root.replayerSpeed = parseFloat(j);
    });
  }
}

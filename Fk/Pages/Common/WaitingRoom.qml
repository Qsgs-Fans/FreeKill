// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import Fk.Components.Common
import Fk.Components.WaitingRoom
import Fk.Widgets as W

import LunarLtk

W.PageBase {
  id: roomScene

  property int playerNum: 0

  property bool isAllReady: false
  property bool canAddRobot: false
  property bool canChangeRoom: false
  property bool isOwner: false
  property bool isFull: false
  property bool isReady: false
  property bool canKickOwner: false
  property bool playersAltered: false // 有人加入或离开房间
  readonly property bool isRoomObserver: Config.observing

  property string bgColor: '#e1ffffff'
  property string borderColor: '#acbebc'

  property alias photoModel: photoModel
  property alias photos: photos
  property alias areaHandler: globalTapHandler
  property alias menuButton: menuButton
  signal menuButtonClicked()

  onPlayersAlteredChanged: {
    if (playersAltered) {
      checkCanAddRobot();
      playersAltered = false;
    }
  }

  onIsOwnerChanged: {
    if (isOwner && !isFull && !isRoomObserver) {
      addInitComputers();
    }
  }

  onIsAllReadyChanged: {
    if (!isAllReady) {
      canKickOwner = false;
      kickOwnerTimer.stop();
    } else {
      Backend.playSound("./audio/system/ready");
      kickOwnerTimer.start();
    }
  }

  Timer {
    id: opTimer
    interval: 1000
  }

  Timer {
    id: kickOwnerTimer
    interval: 15000
    onTriggered: {
      App.showToast(Lua.tr("$CanKickOwner"));
      canKickOwner = true;
    }
  }

  Rectangle {
    id: roomSettings

    x: 15
    y: 20

    color: roomScene.bgColor
    radius: 6
    width: 280
    height: parent.height - 40
    border.color: roomScene.borderColor
    border.width: 2

    property bool viewFalse: false

    Text {
      id: roomSettingsTitle
      width: parent.width
      height: 30
      y: 10
      text: Lua.tr("Room Settings")
      font.bold: true
      font.pixelSize: 20
      horizontalAlignment: Text.AlignHCenter
    }

    Rectangle {
      height: 2
      color: roomScene.borderColor
      width: parent.width - 4
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: roomSettingsTitle.bottom
    }

    Flickable {
      id: infoContainer
      ScrollBar.vertical: ScrollBar {
        parent: roomSettings
        anchors.top: infoContainer.top
        anchors.right: infoContainer.right
        anchors.rightMargin: -12
        anchors.bottom: infoContainer.bottom
        width: 8
      }
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: roomSettingsTitle.bottom
      anchors.topMargin: 10
      anchors.bottom: viewFalseCheck.top
      anchors.bottomMargin: 2
      height: parent.height - 20 - roomSettingsTitle.height - viewFalseCheck.height - 20
      flickableDirection: Flickable.VerticalFlick
      width: parent.width - 30
      contentHeight: roominfo.height
      clip: true
      property var settings: []

      Component.onCompleted: setDataList();

      function getSettingKey(prop, mainKey) {
        const data = Lua.client.settings;
        const value = data?.[mainKey]?.[prop['_settingsKey']];
        const key = prop.title;
        if (typeof value === "boolean") {
          const tr = Lua.hasTranslate("#" + key);
          const trNega = Lua.hasTranslate("#!" + key);
          if (tr) {
            return value ? [tr]: (trNega ? [trNega] : [Lua.tr(prop.title), Lua.tr(value)]);
          }
        }

        return [Lua.tr(prop.title), Lua.tr(value)];
      }

      function setDataList() {
        let _settings = [];
        const data = Lua.client.settings;
        let cardpack = Ltk.getAllCardPack();
        cardpack = cardpack.filter(p => !data.disabledPack.includes(p));
        const gameMode = data.gameMode;
        const boardgameSettingsData = Lua.getUIDataOfSettings(gameMode, data, true);
        const gameSettingsData = Lua.getUIDataOfSettings(gameMode, data, false);

        _settings.push([Lua.tr("GameMode"), Lua.tr(gameMode)]);
        _settings.push([Lua.tr("ResponseTime"), Config.roomTimeout]);
        for (const group of boardgameSettingsData) {
          for (const prop of group['_children']) {
            _settings.push(getSettingKey(prop, "_game"))
          }
        }
        for (const group of gameSettingsData) {
          for (const prop of group['_children']) {
            _settings.push(getSettingKey(prop, "_mode"))
          }
        }
        _settings.push([Lua.tr("General Pool"), "1"]);
        _settings.push([Lua.tr('CardPackages'), cardpack.map(e => {
          let ret = Lua.tr(e);
          // TODO: 这种东西最好还是变量名规范化= =
          if (ret.search(/特殊牌|衍生牌/) === -1) {
            ret = "<b>" + ret + "</b>";
          }
          return ret;
        }).join('，')]);
        settings = _settings
      }

      ColumnLayout {
        id: roominfo
        width: parent.width
        Repeater {
          model: infoContainer.settings

          Item {
            width: parent.width
            height: Math.max(30, ketText.height)
            required property var modelData
            visible: {
              if (roomSettings.viewFalse) return true;
              const value = modelData[1];
              return value !== "false" && value !== "" && value !== "否"; // 选项框出来直接是翻译过的
            }

            Text {
              id: titleText
              anchors.left: parent.left
              text: parent.modelData[0]
              color: '#5e5e5e'
              font.pixelSize: 14
            }

            Text {
              id: ketText
              anchors.right: parent.right
              anchors.left: titleText.right
              anchors.leftMargin: 2
              horizontalAlignment: Text.AlignRight
              visible: parent.modelData[0] !== Lua.tr("General Pool")
              text: {
                const str = parent.modelData[1];
                if (typeof str !== "string") return "";
                if (str === "true") return Lua.tr("True");
                if (str === "false") return Lua.tr("False");
                return str
              }
              color: '#222222'
              font.pixelSize: 14
              wrapMode: Text.WordWrap
            }

            WButton {
              id: generalButton
              visible: parent.modelData[0] === Lua.tr("General Pool")
              anchors.right: parent.right
              height: 20
              width: 40
              text: Lua.tr("View General Pool")
              textFont.pixelSize: 14
              title.color: '#e1f5f3'
              bg.radius: 10
              bg.color: '#8eb1ab'
              border.width: 0

              onClicked: {
                overviewLoader.overviewSource = "LunarLtk.Pages";
                overviewLoader.overviewType = "GeneralPool";
                overviewDialog.open();
              }
            }
          }
        }
      }
    }

    W.SwitchRow {
      id: viewFalseCheck
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      anchors.left: parent.left

      backgroundColor: roomScene.bgColor
      borderColor: roomScene.bgColor

      title: Lua.tr("View False Settings")

      checked: parent.viewFalse
      onCheckedChanged: parent.viewFalse = checked;
    }
  }

  ListModel {
    id: photoModel
  }

  ListModel {
    id: observerModel
  }

  W.PopupLoader {
    id: room_drawer
    padding: 0
    width: Config.winWidth * 0.80
    height: Config.winHeight * 0.95
    anchors.centerIn: parent
  }

  Rectangle {
    id: roomArea
    anchors.left: roomSettings.right
    anchors.leftMargin: 10
    anchors.right: observeArea.left
    anchors.rightMargin: 10
    y: 20
    height: roomScene.height - 40

    color: roomScene.bgColor
    radius: 6
    border.color: roomScene.borderColor
    border.width: 2

    Item {
      id: topArea
      width: parent.width
      height: 72
      Text {
        id: topAreaTitle
        text: Lua.tr(Lua.client.settings?.gameMode ?? "")
        color: '#252928'
        font.bold: true
        font.pixelSize: 30
        x: 12; y: 10
      }

      Rectangle {
        anchors.left: topAreaTitle.right
        anchors.leftMargin: 20
        y: 25
        color: roomScene.bgColor
        radius: 2
        border.width: 1
        border.color: roomScene.borderColor
        width: 93
        height: 20

        Row {
          height: parent.height
          spacing: 10
          x: 5
          property int realPlayerNum: {
            let ret = 0;
            for (let i = 0; i < photoModel.count; i++) {
              if (photos.itemAt(i).hasPlayer) ret += 1;
            }
            return ret
          }
          Text {
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            color: '#283030'
            text: `<font color='#609622'>${parent.realPlayerNum.toString()}</font>/${roomScene.playerNum.toString()}`
            textFormat: Text.RichText
            font.letterSpacing: 3
            font.bold: true
          }
          Text {
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            color: '#283030'
            text: roomScene.playerNum - parent.realPlayerNum === 0 ? "     已满" : `${roomScene.playerNum - parent.realPlayerNum}个空位`
            font.bold: true
          }
        }
      }

      WButton {
        id: menuButton
        anchors.right: parent.right
        anchors.rightMargin: 20
        y: 12
        height: 35
        width: 72
        text: Lua.tr("Menu")
        textFont.pixelSize: 20

        onClicked: roomScene.menuButtonClicked()
      }

      Rectangle {
        height: 2
        width: parent.width
        color: roomScene.borderColor
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
      }
    }

    Flow {
      anchors {
        fill: parent
        leftMargin: 20
        rightMargin: 20
        topMargin: 80
      }

      spacing: 15

      Repeater {
        id: photos
        model: photoModel

        AvatarCardItem {
          playerid: model.id
          avatar: model.avatar
          screenName: Config.hideScreenName ? (model.screenName ? Lua.tr("Player") + (index + 1) : null) : model.screenName
          isOwner: model.isOwner
          ready: model.ready
          opacity: model.sealed ? 0 : 1
          winGame: model.win
          runGame: model.run
          totalGame: model.total
          gameTime: model.gameTime
          enabled: hasPlayer
          // title: playerid > 0 ? "Notify" : ""
        }
      }
    }
  }

  RowLayout {
    anchors.right: observeArea.left
    anchors.bottom: parent.bottom
    anchors.rightMargin: 20
    anchors.bottomMargin: 35

    WButton {
      text: "添加旁观者"
      textFont.pixelSize: 20
      width: 120
      height: 35
      title.color: '#e1f5f3'
      bg.radius: 10
      bg.color: '#8eb1ab'
      border.width: 0
      visible: Cpp.quickStartMode !== ""
      onClicked: {
        roomScene.addObserver(null, [-observerModel.count - 11, "test", "huanggai"]);
      }
    }

    WButton {
      visible: roomScene.isRoomObserver && !isFull
      text: Lua.tr("Take Seat")
      textFont.pixelSize: 20
      width: 70
      height: 35
      title.color: '#e1f5f3'
      bg.radius: 10
      bg.color: '#8eb1ab'
      border.width: 0
      enabled: !isFull
      onClicked: if (enabled) Cpp.notifyServer("SwitchToPlayer", "")
    }

    WButton{
      visible: isOwner && canChangeRoom
      text: Lua.tr("Change Room Config")
      textFont.pixelSize: 20
      width: 100
      height: 35
      title.color: '#e1f5f3'
      bg.radius: 10
      bg.color: '#8eb1ab'
      border.width: 0
      onClicked: {
        room_drawer.sourceComponent =
        Qt.createComponent("../Lobby/CreateRoom.qml");
        room_drawer.item.isChangeRoom = true;
        room_drawer.open();
        Config.observing = false;
        Config.replaying = false;
      }
    }

    WButton {
      text: Lua.tr("Chat")
      textFont.pixelSize: 20
      width: 70
      height: 35
      title.color: '#e1f5f3'
      bg.radius: 10
      bg.color: '#8eb1ab'
      border.width: 0
      onClicked: Mediator.notify(this, Command.IWantToChat);
    }

    WButton {
      id: kickOwner
      text: Lua.tr("Kick Owner")
      textFont.pixelSize: 20
      width: 100
      height: 35
      title.color: '#e1f5f3'
      bg.radius: 10
      bg.color: '#8eb1ab'
      border.width: 0
      visible: canKickOwner && isFull && !isOwner && !roomScene.isRoomObserver
      onClicked: {
        for (let i = 0; i < playerNum; i++) {
          let item = photoModel.get(i);
          if (item.isOwner) {
            sendDanmu(Lua.tr("Owner %1 Kicked by %2").arg(item.screenName).arg(Self.screenName));
            // 傻逼qml喜欢加1.0
            Cpp.notifyServer("KickPlayer", Math.floor(item.id));
          }
        }
      }
    }

    Item {
      Layout.preferredWidth: childrenRect.width
      Layout.preferredHeight: childrenRect.height
      WButton {
        text: isReady ? Lua.tr("Cancel Ready") : Lua.tr("Ready")
        textFont.pixelSize: 20
        width: isReady ? 100 : 50
        height: 35
        title.color: '#e1f5f3'
        bg.radius: 10
        bg.color: '#8eb1ab'
        border.width: 0
        visible: !isOwner && !roomScene.isRoomObserver
        enabled: !opTimer.running
        onClicked: if (enabled) {
          opTimer.start();
          Cpp.notifyServer("Ready", "");
        }
      }

      WButton {
        text: Lua.tr("Add Robot")
        textFont.pixelSize: 20
        width: 120
        height: 35
        title.color: '#e1f5f3'
        bg.radius: 10
        bg.color: '#8eb1ab'
        border.width: 0
        visible: isOwner && !isFull
        enabled: Config.serverFeatures.includes("AddRobot") && canAddRobot
        onClicked: if (enabled) {
          Cpp.notifyServer("AddRobot", "");
        }
        onRightClicked: { // 长按以机器人补全
          for (let i = 0; i < playerNum; i++) {
            if (!canAddRobot) break;
            Cpp.notifyServer("AddRobot", "");
          }
        }
      }

      WButton {
        text: Lua.tr("Start Game")
        textFont.pixelSize: 20
        width: 100
        height: 35
        title.color: '#e1f5f3'
        bg.radius: 10
        bg.color: '#8eb1ab'
        border.width: 0
        visible: isOwner && isFull
        enabled: isAllReady
        onClicked: if (enabled) {
          Cpp.notifyServer("StartGame", "");
        }
      }
    }
  }

  Rectangle {
    id: observeArea
    width: 105
    anchors.right: parent.right
    anchors.rightMargin: 15
    y: 20
    height: roomScene.height - 40

    color: roomScene.bgColor
    radius: 6
    border.color: roomScene.borderColor
    border.width: 2

    Column {
      id: observerCol
      anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        topMargin: 5
      }
      spacing: 8
      Text {
        text: "旁观席"
        color: '#8fa19f'
        font.bold: true
        font.pixelSize: 20
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.right: parent.right
        height: 32

        Text {
          text: observerModel.count.toString()
          height: 26
          font.bold: true
          font.pixelSize: 21
          color: '#798b89'
          anchors.right: parent.right
          anchors.rightMargin: 7
          horizontalAlignment: Text.AlignRight
          verticalAlignment: Text.AlignBottom
        }
      }

      Flickable {
        id: observerFlickable
        anchors.right: parent.right
        width: 200
        contentHeight: observerListView.height + 15
        height: Math.min(observeArea.height - 98, contentHeight)
        clip: true
        ListView {
          id: observerListView
          model: observerModel
          anchors.right: parent.right
          anchors.rightMargin: 25
          width: 54
          y: 4
          height: model.count * (54 + spacing) - 5
          spacing: 15

          delegate: WAvatar {
            width: selected ? 64 : 54
            height: selected ? 64 : 54
            playerid: model.id
            avatar: model.avatar
            screenName: model.screenName
            visible: model.screenName !== ""
          }

          add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; easing.type: Easing.OutCubic; duration: 200 }
            NumberAnimation { property: "scale"; from: 0.5; to: 1; easing.type: Easing.OutBack; duration: 200 }
          }

          remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; easing.type: Easing.InCubic; duration: 200 }
          }

          move: Transition {
            NumberAnimation { properties: "y"; easing.type: Easing.OutCubic; duration: 200 }
          }

          displaced: Transition {
            NumberAnimation { properties: "y"; easing.type: Easing.OutCubic; duration: 200 }
          }
        }
      }
    }

    ObserveButton {
      id: observeBotton
      width: 62; height: 34
      anchors.horizontalCenter: parent.horizontalCenter
      y: 60 + Math.min(observerListView.height, parent.height - 106)
      visible: {
        if (roomScene.isRoomObserver) return false;
        let num = 0;
        for (let i = 0; i < photoModel.count; i++) {
          if (photos.itemAt(i).playerid > 0) {
            num+=1;
          }
        }
        return num > 1
      }
      onClicked: {
        Cpp.notifyServer("SwitchToObserver", "");
      }
    }
  }

  // 旁观者等待提示
  WBanner {
    id: observerHint
    width: 235
    anchors {
      left: roomArea.left
      bottom: roomArea.bottom
      bottomMargin: roomScene.isRoomObserver ? 15 : -200
    }
    text: Lua.tr("Waiting for game to start")

    Behavior on anchors.bottomMargin {
      NumberAnimation{ easing.type: Easing.OutCubic; duration: 300 }
    }
  }

  // 将池
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
      property string overviewSource: "LunarLtk.Pages"
      property string overviewType: "GeneralPool"
      anchors.centerIn: parent
      width: parent.width / Config.winScale
      height: parent.height / Config.winScale
      scale: Config.winScale
      sourceComponent: Qt.createComponent(overviewSource, overviewType + "Overview")
    }
  }

  // 全局点击监视
  MouseArea {
    id: globalTapHandler
    anchors.fill: parent
    visible: false
    z: 20
    property var tmpItem
    property var tmpZ
    property var tmpParent
    property var tmpX
    property var tmpY
    onClicked: closeItem()
    function show(item) {
      item?.show()
      tmpItem = item;
      tmpZ = item.z;
      tmpParent = item.parent;
      tmpX = item.x;
      tmpY = item.y;
      // 换 parent 前做坐标转换，保持屏幕位置不变
      const newPos = item.parent.mapToItem(roomScene, item.x, item.y);
      item.parent = roomScene;
      item.x = newPos.x;
      item.y = newPos.y;
      item.z = z + 1;
      visible = true;
    }
    function closeItem() {
      if (tmpItem) {
        tmpItem.parent = tmpParent;
        tmpItem.x = tmpX;
        tmpItem.y = tmpY;
        tmpItem.z = tmpZ;
        tmpItem?.close();
        tmpItem = null;
        tmpZ = null;
        tmpParent = null;
        tmpX = null;
        tmpY = null;
      }
      visible = false
    }
  }

  // 弹幕
  Danmu {
    id: danmu
    width: parent.width
  }

  function sendDanmu(msg) {
    danmu.sendLog(msg);
    ClientInstance.notifyServer(
      "Chat",
      {
        type: 2,
        msg: msg,
      }
    );
  }

  // TODO 扬了这玩意
  function givePresent(tp, pid) {
    ClientInstance.notifyServer(
    "Chat",
    {
      type: 2,
      msg: "$@" + tp + ":" + pid
    }
    );
  }

  function getPhotoModel(id) {
    for (let i = 0; i < playerNum; i++) {
      const item = photoModel.get(i);
      if (item.id === id) {
        return item;
      }
    }
    return undefined;
  }

  function getPhoto(id) {
    for (let i = 0; i < playerNum; i++) {
      const item = photoModel.get(i);
      if (item.id === id) {
        return photos.itemAt(i);
      }
    }
    return undefined;
  }

  function getPhotoOrObserver(id) {
    for (let i = 0; i < playerNum; i++) {
      const item = photoModel.get(i);
      if (item.id === id) {
        return photos.itemAt(i);
      }
    }
    for (let i = 0; i < observerModel.count; i++) {
      if (observerModel.get(i).id === id) {
        return observerListView.contentItem.children[i];
      }
    }
    return undefined;
  }

  function checkCanAddRobot() {
    if (Config.serverFeatures.includes("AddRobot")) {
      const num = Lua.getCompNum();
      canAddRobot = num.maxComp > num.curComp;
    }
  }

  function addInitComputers() {
    const num = Lua.getCompNum();
    const min = num.minComp;
    const cur = num.curComp;
    const robotsToAdd = Math.max(0, min - cur);
    for (let i = 0; i < robotsToAdd; i++) {
      Cpp.notifyServer("AddRobot", "");
    }
  }

  function checkAllReady() {
    let allReady = true;
    for (let i = 0; i < playerNum; i++) {
      const item = photoModel.get(i);
      if (!item.isOwner && !item.ready) {
        allReady = false;
        break;
      }
    }
    roomScene.isAllReady = allReady;

    if (allReady && roomScene.isOwner && !isRoomObserver && Cpp.quickStartMode) {
      Cpp.notifyServer("StartGame", "");
    }
  }

  function updateGameData(sender, data) {
    const id = data[0];
    const total = data[1];
    const win = data[2];
    const run = data[3];
    const photo = getPhotoModel(id);
    if (photo) {
      photo.total = total;
      photo.win = win;
      photo.run = run;
    }
  }

  function setRoomOwner(sender, data) {
    // jsonData: int uid of the owner
    const uid = data[0];

    roomScene.isOwner = (Self.id === uid);

    const model = getPhotoModel(uid);
    if (typeof(model) !== "undefined") {
      model.isOwner = true;
    }

    checkAllReady();
  }

  function readyChanged(sender, data) {
    const id = data[0];
    const ready = data[1];

    if (id === Self.id) {
      roomScene.isReady = !!ready;
    }

    const model = getPhotoModel(id);
    if (typeof(model) !== "undefined") {
      model.ready = ready ? true : false;
      checkAllReady();
    }
  }

  function addPlayer(sender, data) {
    // jsonData: int id, string screenName, string avatar, bool ready
    for (let i = 0; i < playerNum; i++) {
      const item = photoModel.get(i);
      if (item.id === -1) {
        const uid = data[0];
        const name = data[1];
        const avatar = data[2];
        const ready = data[3];
        const gameTime = data[4];

        item.id = uid;
        item.screenName = name;
        item.general = avatar;
        item.avatar = avatar;
        item.ready = ready;
        item.sealed = false;
        item.gameTime = gameTime;

        checkAllReady();

        if (getPhoto(-1)) {
          roomScene.isFull = false;
        } else {
          roomScene.isFull = true;
        }
        roomScene.playersAltered = true;

        return;
      }
    }
  }

  function removePlayer(sender, data) {
    // jsonData: int uid
    const uid = data[0];
    const model = getPhotoModel(uid);
    if (typeof(model) !== "undefined") {
      model.id = -1;
      model.screenName = "";
      model.avatar = "";
      model.general = "";
      model.isOwner = false;
      roomScene.isFull = false;
      roomScene.playersAltered = true;
    }
  }

  function resetPhotos() {
    photoModel.clear();
    if (roomScene.isRoomObserver) {
      // 旁观者不占座位
      for (let i = 0; i < 10; i++) {
        photoModel.append({
          id: -1,
          avatar: "",
          screenName: "",
          seatNumber: i + 1,
          kingdom: "unknown",
          isOwner: false,
          ready: false,
          sealed: i > playerNum - 1,
          win: 0,
          run: 0,
          total: 0,
          gameTime: 0
        });
      }
      // 把自己加入旁观列表
      addObserver(null, [Self.id, Self.screenName, Self.avatar]);
    } else {
      const gt = Lua.evaluate(`Self.player:getTotalGameTime()`);
      for (let i = 0; i < 10; i++) {
        photoModel.append({
          id: i ? -1 : Self.id,
          avatar: i ? "" : Self.avatar,
          screenName: i ? "" : Self.screenName,
          seatNumber: i + 1,
          kingdom: "unknown",
          isOwner: false,
          ready: false,
          sealed: i >= playerNum,
          win: 0,
          run: 0,
          total: 0,
          gameTime: i ? 0 : gt
        });
      }
    }

    checkCanAddRobot();
    checkAllReady();
    isFull = !getPhoto(-1);
  }

  function loadPlayerData(sender) {
    const datalist = Lua.evaluate(`table.map(ClientInstance.players, function(p)
    local cp = p.player
    local gameData = cp:getGameData()
    return {
      id = p.id,
      name = cp:getScreenName(),
      avatar = cp:getAvatar(),
      ready = p.ready,
      isOwner = p.owner,
      gameTime = cp:getTotalGameTime(),
      total = gameData:at(0),
      win = gameData:at(1),
      run = gameData:at(2),
    }
    end)`);

    const obdatalist = Lua.evaluate(`table.map(ClientInstance.observers, function(t)
    local cp = t[2]
    return {
      id = cp:getId(),
      name = cp:getScreenName(),
      avatar = cp:getAvatar(),
    }
    end)`);

    resetPhotos();

    for (const d of datalist) {
      if (d.id === Self.id) {
        roomScene.isOwner = d.isOwner;
      } else {
        addPlayer(null, [d.id, d.name, d.avatar, d.ready, d.gameTime]);
      }
      const model = getPhotoModel(d.id);
      model.ready = d.ready;
      model.isOwner = d.isOwner;
      model.total = d.total;
      model.win = d.win;
      model.run = d.run;
      model.gameTime = d.gameTime
    }

    for (const d of obdatalist) {
      addObserver(null, [d.id, d.name, d.avatar]);
    }

    checkAllReady();
  }

  function restartGame(sender) {
    loadPlayerData(sender);
    Cpp.notifyServer("StartGame", "");
  }

  function startGame() {
    canKickOwner = false;
    kickOwnerTimer.stop();
    Backend.playSound("./audio/system/gamestart");

    let data ;
    const boardgame = Lua.evaluate(`Fk:getBoardGame(ClientInstance.settings.gameMode).name`);
    const ui_config = Config.enabledUIPackages[boardgame];
    if (ui_config !== undefined && ui_config !== "default" && Lua.evaluate(`not not Fk:getUIPackage("${ui_config}")`)) {
      data = Lua.evaluate(`Fk.ui_packages["${ui_config}"].page`)
    } else {
      data = Lua.evaluate(`Fk:getBoardGame(ClientInstance.settings.gameMode).page`)
    }
    App.changeRoomPage(data);
  }

  function changeRoomConfig(_, data) {
    App.setBusy(false);

    Config.roomCapacity = data[0];
    Config.roomTimeout = data[1] - 1;
    const roomSettings = data[2];
    Config.heg = roomSettings.gameMode.includes('heg_mode');

    let displayName = roomSettings.roomName;
    if (roomSettings.roomId !== undefined) {
      displayName += "[{id}]".replace("{id}", roomSettings.roomId);
    }
    Config.headerName = Lua.tr("Current room: %1").arg(displayName);

    playerNum = Config.roomCapacity;
    for (let i = 0; i < 10; i++) {
      photoModel.get(i).sealed = i >= playerNum;
    }
    infoContainer.setDataList();

    checkAllReady();
    checkCanAddRobot();
    if (getPhoto(-1)) {
      isFull = false;
    } else {
      isFull = true;
    }

    App.showToast(Lua.tr("$RoomConfigChanged"));
  }

  function autoAddRobot() {
    const robotNum = playerNum - 1
    if (Cpp.quickStartMode !== "") {
      for (let i = 0; i < robotNum; i++) Cpp.notifyServer("AddRobot", "");
    }
  }

  function addObserver(sender, data) {
    const [id, name, avatar] = data;
    for (let i = 0; i < observerModel.count; i++) {
      if (observerModel.get(i).id === id) return;
    }
    observerModel.append({ id, screenName: name, avatar });
  }

  function removeObserver(sender, data) {
    const uid = data[0];
    for (let i = 0; i < observerModel.count; i++) {
      if (observerModel.get(i).id === uid) {
        observerModel.remove(i);
        return;
      }
    }
  }

  function handleSwitchToPlayer(_, data) {
    // TODO: 应该不能这么草率，下同，还没仔细思考
    const uid = data[0];
    const dat = { id: uid };
    for (let i = 0; i < observerModel.count; i++) {
      const model = observerModel.get(i);
      if (model.id === uid) {
        dat.screenName = model.screenName;
        dat.avatar = model.avatar;
        observerModel.remove(i);
        break;
      }
    }

    addPlayer(_, [ dat.id, dat.screenName, dat.avatar, false ]);

    if (uid == Cpp.self.id) {
      Config.observing = false;
    }
  }

  function handleSwitchToObserver(_, data) {
    const uid = data[0];
    const model = getPhotoModel(uid);
    if (typeof(model) !== "undefined") {
      addObserver(_, [ model.id, model.screenName, model.avatar ]);

      model.id = -1;
      model.screenName = "";
      model.avatar = "";
      model.general = "";
      model.isOwner = false;
      roomScene.isFull = false;
      roomScene.playersAltered = true;
    }

    if (uid == Cpp.self.id) {
      Config.observing = true;
    }
  }

  Component.onCompleted: {
    addCallback(Command.UpdateGameData, updateGameData);
    addCallback(Command.RoomOwner, setRoomOwner);

    addCallback(Command.ReadyChanged, readyChanged);
    addCallback(Command.AddPlayer, addPlayer);
    addCallback(Command.RemovePlayer, removePlayer);

    addCallback(Command.StartGame, startGame);
    addCallback(Command.BackToRoom, loadPlayerData);
    addCallback(Command.RestartGame, restartGame);

    addCallback(Command.ChangeRoom, changeRoomConfig);

    addCallback("SwitchToPlayer", handleSwitchToPlayer);
    addCallback("SwitchToObserver", handleSwitchToObserver);

    playerNum = Config.roomCapacity;
    canChangeRoom = Config.serverFeatures.includes("ChangeRoom");
    resetPhotos();
    autoAddRobot();

    if (roomScene.isRoomObserver) {
      App.showToast(Lua.tr("$EnterRoomObserve"));
      // 从EnterRoom数据中读取已有玩家列表(必须在resetPhotos之后)
      const playerList = Lua.client.settings._players;
      if (playerList) {
        for (const p of playerList) {
          addPlayer(null, [p[0], p[1], p[2], !!p[3], p[4]]);
          if (p[5]) setRoomOwner(null, [p[0]]);
        }
      }
      // 从EnterRoom数据中同步已有旁观者列表
      const observerList = Lua.client.settings._observers;
      if (observerList) {
        for (const o of observerList) {
          addObserver(null, [o[0], o[1], o[2]]);
        }
      }
    } else {
      App.showToast(Lua.tr("$EnterRoom"));
    }
  }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtMultimedia
import Fk
import Fk.Common
import Fk.RoomElement
import "RoomLogic.js" as Logic

Item {
  id: roomScene

  property int playerNum: 0
  // property var dashboardModel

  property bool isOwner: false
  property bool isStarted: false
  property bool isFull: false
  property bool isAllReady: false
  property bool isReady: false
  property bool canKickOwner: false

  property alias popupBox: popupBox
  property alias manualBox: manualBox
  property alias bigAnim: bigAnim
  property alias promptText: prompt.text
  property var currentPrompt
  property alias okCancel: okCancel
  property alias okButton: okButton
  property alias cancelButton: cancelButton
  property alias dynamicCardArea: dynamicCardArea
  property alias tableCards: tablePile.cards
  property alias dashboard: dashboard
  property alias drawPile: drawPile
  property alias skillInteraction: skillInteraction
  property alias miscStatus: miscStatus

  property var selected_targets: []
  property string responding_card
  property bool respond_play: false
  property bool autoPending: false
  property var extra_data: ({})
  property var skippedUseEventId: []

  property real replayerSpeed
  property int replayerElapsed
  property int replayerDuration

  Image {
    source: config.roomBg
    anchors.fill: parent
    fillMode: Image.PreserveAspectCrop
  }

  MediaPlayer {
    id: bgm
    source: config.bgmFile

    loops: MediaPlayer.Infinite
    onPlaybackStateChanged: {
      if (playbackState == MediaPlayer.StoppedState && roomScene.isStarted)
        play();
    }
    audioOutput: AudioOutput {
      volume: config.bgmVolume / 100
    }
  }

  onIsStartedChanged: {
    if (isStarted) {
      bgm.play();
      canKickOwner = false;
      kickOwnerTimer.stop();
    } else {
      // bgm.stop();
    }
  }

  // tmp
  Button {
    id: menuButton
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.rightMargin: 10
    text: Backend.translate("Menu")
    z: 2
    onClicked: {
      menuContainer.visible || menuContainer.open();
    }
  }

  Menu {
    id: menuContainer
    x: parent.width - menuButton.width - menuContainer.width - 17
    width: menuRow.width
    height: menuRow.height
    verticalPadding: 0
    spacing: 7
    z: 2

    Row {
      id: menuRow
      spacing: 7

      Button {
        id: surrenderButton
        enabled: !config.observing && !config.replaying
        text: Backend.translate("Surrender")
        onClicked: {
          if (isStarted && !getPhoto(Self.id).dead) {
            const surrenderCheck = JSON.parse(Backend.callLuaFunction('CheckSurrenderAvailable', [miscStatus.playedTime]));
            if (!surrenderCheck.length) {
              surrenderDialog.informativeText = Backend.translate('Surrender is disabled in this mode');
            } else {
              surrenderDialog.informativeText = surrenderCheck.map(str => `${Backend.translate(str.text)}（${str.passed ? '√' : '×'}）`).join('<br>');
            }
            surrenderDialog.open();
          }
        }
      }

      MessageDialog {
        id: surrenderDialog
        title: Backend.translate("Surrender")
        informativeText: ''
        buttons: MessageDialog.Ok | MessageDialog.Cancel
        onButtonClicked: function (button, role) {
          switch (button) {
            case MessageDialog.Ok: {
              const surrenderCheck = JSON.parse(Backend.callLuaFunction('CheckSurrenderAvailable', [miscStatus.playedTime]));
              if (surrenderCheck.length && !surrenderCheck.find(check => !check.passed)) {
                ClientInstance.notifyServer("PushRequest", [
                  "surrender", true
                ]);
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

      Button {
        id: quitButton
        text: Backend.translate("Quit")
        onClicked: {
          if (config.replaying) {
            Backend.controlReplayer("shutdown");
            mainStack.pop();
          } else if (config.observing) {
            ClientInstance.notifyServer("QuitRoom", "[]");
          } else {
            quitDialog.open();
          }
        }
      }

      MessageDialog {
        id: quitDialog
        title: Backend.translate("Quit")
        informativeText: Backend.translate("Are you sure to quit?")
        buttons: MessageDialog.Ok | MessageDialog.Cancel
        onButtonClicked: function (button) {
          switch (button) {
            case MessageDialog.Ok: {
              ClientInstance.notifyServer("QuitRoom", "[]");
              break;
            }
            case MessageDialog.Cancel: {
              quitDialog.close();
            }
          }
        }
      }
    }
  }

  Button {
    text: Backend.translate("Add Robot")
    visible: isOwner && !isStarted && !isFull
    anchors.centerIn: parent
    enabled: config.serverEnableBot
    onClicked: {
      ClientInstance.notifyServer("AddRobot", "[]");
    }
  }
  Button {
    text: Backend.translate("Start Game")
    visible: isOwner && !isStarted && isFull
    enabled: isAllReady
    anchors.centerIn: parent
    onClicked: {
      ClientInstance.notifyServer("StartGame", "[]");
    }
  }
  Timer {
    id: opTimer
    interval: 1000
  }
  Button {
    text: isReady ? Backend.translate("Cancel Ready") : Backend.translate("Ready")
    visible: !isOwner && !isStarted
    enabled: !opTimer.running
    anchors.centerIn: parent
    onClicked: {
      opTimer.start();
      ClientInstance.notifyServer("Ready", "");
    }
  }

  Button {
    id: kickOwner
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height / 2 + 30
    text: "踢出房主"
    visible: canKickOwner && !isStarted && isFull && !isOwner
    onClicked: {
      for (let i = 0; i < photoModel.count; i++) {
        let item = photoModel.get(i);
        if (item.isOwner) {
          ClientInstance.notifyServer("KickPlayer", item.id.toString());
        }
      }
    }
  }

  Timer {
    id: kickOwnerTimer
    interval: 15000
    onTriggered: {
      canKickOwner = true;
    }
  }

  onIsAllReadyChanged: {
    if (!isAllReady) {
      canKickOwner = false;
      kickOwnerTimer.stop();
    } else {
      kickOwnerTimer.start();
    }
  }

  Rectangle {
    x: parent.width / 2 + 60
    y: parent.height / 2 - 30
    color: "snow"
    opacity: 0.8
    radius: 6
    visible: !isStarted
    width: 280
    height: 280

    Flickable {
      id: flickableContainer
      ScrollBar.vertical: ScrollBar {}
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: 10
      flickableDirection: Flickable.VerticalFlick
      width: parent.width - 10
      height: parent.height - 10
      contentHeight: roominfo.height
      clip: true

      Text {
        id: roominfo
        font.pixelSize: 16
        width: parent.width
        wrapMode: TextEdit.WordWrap
        Component.onCompleted: {
          const data = JSON.parse(Backend.callLuaFunction("GetRoomConfig", []));
          let cardpack = JSON.parse(Backend.callLuaFunction("GetAllCardPack", []));
          cardpack = cardpack.filter(p => !data.disabledPack.includes(p));

          text = "游戏模式：" + Backend.translate(data.gameMode) + "<br />"
            + Backend.translate("LuckCardNum") + "<b>" + data.luckTime + "</b><br />"
            + Backend.translate("ResponseTime") + "<b>" + config.roomTimeout + "</b><br />"
            + Backend.translate("GeneralBoxNum") + "<b>" + data.generalNum + "</b>"
            + (data.enableFreeAssign ? "<br />" + Backend.translate("IncludeFreeAssign") : "")
            + (data.enableDeputy ? " " + Backend.translate("IncludeDeputy") : "")
            + '<br />使用牌堆：' + cardpack.map(e => {
              let ret = Backend.translate(e);
              if (ret.search(/特殊牌|衍生牌/) === -1) { // TODO: 这种东西最好还是变量名规范化= =
                ret = "<b>" + ret + "</b>";
              }
              return ret;
            }).join('，')
            //+ '<br /><b>禁包</b>：' + data.disabledPack.map(e => Backend.translate(e)).join('，')
            //+ '<br /><b>禁将</b>：' + data.disabledGenerals.map(e => Backend.translate(e)).join('，')
        }
      }
    }
  }

  states: [
    State { name: "notactive" }, // Normal status
    State { name: "playing" }, // Playing cards in playing phase
    State { name: "responding" }, // all requests need to operate dashboard
    State { name: "replying" } // requests only operate a popup window
  ]
  state: "notactive"
  transitions: [
    Transition {
      from: "*"; to: "notactive"
      ScriptAction {
        script: {
          skillInteraction.sourceComponent = undefined;
          promptText = "";
          currentPrompt = "";
          progress.visible = false;
          okCancel.visible = false;
          endPhaseButton.visible = false;
          respond_play = false;
          extra_data = {};
          mainWindow.pending_message = [];
          mainWindow.is_pending = false;

          if (dashboard.pending_skill !== "")
            dashboard.stopPending();
          dashboard.updateHandcards();
          dashboard.disableAllCards();
          dashboard.disableSkills();
          dashboard.retractAllPiles();
          selected_targets = [];
          autoPending = false;

          if (popupBox.item != null) {
            popupBox.item.finished();
          }
        }
      }
    },

    Transition {
      from: "*"; to: "playing"
      ScriptAction {
        script: {
          skillInteraction.sourceComponent = undefined;
          dashboard.updateHandcards();
          dashboard.enableCards();
          dashboard.enableSkills();
          progress.visible = true;
          okCancel.visible = true;
          autoPending = false;
          endPhaseButton.visible = true;
          respond_play = false;
        }
      }
    },

    Transition {
      from: "*"; to: "responding"
      ScriptAction {
        script: {
          skillInteraction.sourceComponent = undefined;
          dashboard.updateHandcards();
          dashboard.enableCards(responding_card);
          dashboard.enableSkills(responding_card, respond_play);
          autoPending = false;
          progress.visible = true;
          okCancel.visible = true;
        }
      }
    },

    Transition {
      from: "*"; to: "replying"
      ScriptAction {
        script: {
          skillInteraction.sourceComponent = undefined;
          dashboard.updateHandcards();
          dashboard.disableAllCards();
          dashboard.disableSkills();
          progress.visible = true;
          respond_play = false;
          autoPending = false;
          roomScene.okCancel.visible = false;
          roomScene.okButton.enabled = false;
          roomScene.cancelButton.enabled = false;
        }
      }
    }
  ]

  /* Layout:
   * +---------------------+
   * |   Photos, get more  |
   * | in arrangePhotos()  |
   * |      tablePile      |
   * | progress,prompt,btn |
   * +---------------------+
   * |      dashboard      |
   * +---------------------+
   */

  ListModel {
    id: photoModel
  }

  Item {
    id: roomArea
    width: roomScene.width
    height: roomScene.height - dashboard.height + 20

    Repeater {
      id: photos
      model: photoModel
      Photo {
        playerid: model.id
        general: model.general
        avatar: model.avatar
        deputyGeneral: model.deputyGeneral
        screenName: model.screenName
        role: model.role
        kingdom: model.kingdom
        netstate: model.netstate
        maxHp: model.maxHp
        hp: model.hp
        shield: model.shield
        seatNumber: model.seatNumber
        dead: model.dead
        dying: model.dying
        faceup: model.faceup
        chained: model.chained
        drank: model.drank
        isOwner: model.isOwner
        ready: model.ready
        surrendered: model.surrendered
        sealedSlots: JSON.parse(model.sealedSlots)

        onSelectedChanged: {
          Logic.updateSelectedTargets(playerid, selected);
        }

        Component.onCompleted: {
          if (index === 0) dashboard.self = this;
        }
      }
    }

    onWidthChanged: Logic.arrangePhotos();
    onHeightChanged: Logic.arrangePhotos();

    InvisibleCardArea {
      id: drawPile
      x: parent.width / 2
      y: roomScene.height / 2
    }

    TablePile {
      id: tablePile
      width: parent.width * 0.6
      height: 150
      x: parent.width * 0.2
      y: parent.height * 0.6 + 10
    }
  }

  Item {
    id: dashboardBtn
    width: childrenRect.width
    height: childrenRect.height
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 8
    anchors.left: parent.left
    anchors.leftMargin: 8
    ColumnLayout {
      MetroButton {
        text: Backend.translate("Choose one handcard")
        textFont.pixelSize: 28
        visible: {
          if (dashboard.handcardArea.length <= 15) {
            return false;
          }
          if (roomScene.state == "notactive" || roomScene.state == "replying") {
            return false;
          }
          return true;
        }
        onClicked: roomScene.startCheat("../RoomElement/ChooseHandcard");
      }
      MetroButton {
        text: Backend.translate("Revert Selection")
        textFont.pixelSize: 28
        enabled: dashboard.pending_skill !== ""
        onClicked: dashboard.revertSelection();
      }
      // MetroButton {
      //   text: Backend.translate("Trust")
      // }
      MetroButton {
        text: Backend.translate("Sort Cards")
        textFont.pixelSize: 28
        onClicked: Logic.resortHandcards();
      }
      MetroButton {
        text: Backend.translate("Chat")
        textFont.pixelSize: 28
        onClicked: roomDrawer.open();
      }
    }
  }

  Dashboard {
    id: dashboard
    width: roomScene.width - dashboardBtn.width
    anchors.top: roomArea.bottom
    anchors.left: dashboardBtn.right

    onCardSelected: function(card) {
      Logic.enableTargets(card);

      if (typeof card === "number" && card !== -1 && roomScene.state === "playing") {
        const skills = JSON.parse(Backend.callLuaFunction("GetCardSpecialSkills", [card]));
        if (JSON.parse(Backend.callLuaFunction("CanUseCard", [card, Self.id]))) {
          skills.unshift("_normal_use");
        }
        specialCardSkills.model = skills;
      } else {
        specialCardSkills.model = [];
      }
    }
  }

  GlowText {
    text: Backend.translate("Observing ...")
    visible: config.observing && !config.replaying
    color: "#4B83CD"
    font.family: fontLi2.name
    font.pixelSize: 48
  }

  Rectangle {
    id: replayControls
    visible: config.replaying
    anchors.bottom: dashboard.top
    anchors.bottomMargin: -60
    anchors.horizontalCenter: parent.horizontalCenter
    width: childrenRect.width + 8
    height: childrenRect.height + 8

    color: "#88EEEEEE"
    radius: 4

    RowLayout {
      x: 4; y: 4
      Text {
        font.pixelSize: 20
        font.bold: true
        text: {
          const elapsedMin = Math.floor(replayerElapsed / 60);
          const elapsedSec = replayerElapsed % 60;
          const totalMin = Math.floor(replayerDuration / 60);
          const totalSec = replayerDuration % 60;

          return elapsedMin.toString() + ":" + elapsedSec + "/" + totalMin + ":" + totalSec;
        }
      }

      Switch {
        text: Backend.translate("Speed Resume")
        checked: false
        onCheckedChanged: Backend.controlReplayer("uniform");
      }

      Button {
        text: Backend.translate("Speed Down")
        onClicked: Backend.controlReplayer("slowdown");
      }

      Text {
        font.pixelSize: 20
        font.bold: true
        text: "x" + replayerSpeed;
      }

      Button {
        text: Backend.translate("Speed Up")
        onClicked: Backend.controlReplayer("speedup");
      }

      Button {
        property bool running: true
        text: Backend.translate(running ? "Pause" : "Resume")
        onClicked: {
          running = !running;
          Backend.controlReplayer("toggle");
        }
      }
    }
  }

  Item {
    id: controls
    anchors.bottom: dashboard.top
    anchors.bottomMargin: -60
    width: roomScene.width

    Text {
      id: prompt
      visible: progress.visible
      anchors.bottom: progress.bottom
      z: 1
      color: "#F0E5DA"
      font.pixelSize: 16
      font.family: fontLibian.name
      style: Text.Outline
      styleColor: "#3D2D1C"
      textFormat: TextEdit.RichText
      anchors.horizontalCenter: progress.horizontalCenter
    }

    ProgressBar {
      id: progress
      width: parent.width * 0.6
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: okCancel.top
      anchors.bottomMargin: 4
      from: 0.0
      to: 100.0

      visible: false

      background: Rectangle {
        implicitWidth: 200
        implicitHeight: 12
        color: "black"
        radius: 6
      }

      contentItem: Item {
        implicitWidth: 196
        implicitHeight: 10

        Rectangle {
          width: progress.visualPosition * parent.width
          height: parent.height
          radius: 6
          gradient: Gradient {
            GradientStop { position: 0.0; color: "orange" }
            GradientStop { position: 0.3; color: "red" }
            GradientStop { position: 0.7; color: "red" }
            GradientStop { position: 1.0; color: "orange" }
          }
        }
      }

      NumberAnimation on value {
        running: progress.visible
        from: 100.0
        to: 0.0
        duration: config.roomTimeout * 1000

        onFinished: {
          roomScene.state = "notactive"
        }
      }
    }

    Rectangle {
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 8
      anchors.right: okCancel.left
      anchors.rightMargin: 20
      color: "#88EEEEEE"
      radius: 8
      visible: {
        if (roomScene.state !== "playing") {
          return false;
        }
        if (!specialCardSkills) {
          return false;
        }
        if (specialCardSkills.count > 1) {
          return true;
        }
        return (specialCardSkills.model ?? false)
            && specialCardSkills.model[0] !== "_normal_use"
      }
      width: childrenRect.width
      height: childrenRect.height - 20

      RowLayout {
        y: -10
        Repeater {
          id: specialCardSkills
          RadioButton {
            property string orig_text: modelData
            text: Backend.translate(modelData)
            checked: index === 0
            onCheckedChanged: {
              if (modelData === "_normal_use") {
                Logic.enableTargets(dashboard.selected_card);
              } else {
                Logic.enableTargets(JSON.stringify({
                  skill: modelData,
                  subcards: [dashboard.selected_card],
                }));
              }
            }
          }
        }
      }
    }

    Loader {
      id: skillInteraction
      visible: dashboard.pending_skill !== ""
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 8
      anchors.right: okCancel.left
      anchors.rightMargin: 20
    }

    Row {
      id: okCancel
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: progress.horizontalCenter
      spacing: 20
      visible: false

      Button {
        id: skipNullificationButton
        text: Backend.translate("SkipNullification")
        visible: !!extra_data.useEventId && !skippedUseEventId.find(id => id === extra_data.useEventId)
        onClicked: {
          skippedUseEventId.push(extra_data.useEventId);
          Logic.doCancelButton();
        }
      }

      Button {
        id: okButton
        text: Backend.translate("OK")
        onClicked: Logic.doOkButton();
      }

      Button {
        id: cancelButton
        text: Backend.translate("Cancel")
        onClicked: Logic.doCancelButton();
      }
    }

    Button {
      id: endPhaseButton
      text: Backend.translate("End")
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 40
      anchors.right: parent.right
      anchors.rightMargin: 30
      visible: false;
      onClicked: Logic.replyToServer("");
    }
  }

  // manualBox: same as popupBox, but must be closed manually
  Loader {
    id: manualBox
    z: 999
    onSourceChanged: {
      if (item === null)
        return;
      item.finished.connect(() => sourceComponent = undefined);
      item.widthChanged.connect(() => manualBox.moveToCenter());
      item.heightChanged.connect(() => manualBox.moveToCenter());
      moveToCenter();
    }
    onSourceComponentChanged: sourceChanged();

    function moveToCenter() {
      item.x = Math.round((roomArea.width - item.width) / 2);
      item.y = Math.round(roomArea.height * 0.67 - item.height / 2);
    }
  }

  Loader {
    id: popupBox
    z: 999
    onSourceChanged: {
      if (item === null)
        return;
      item.finished.connect(() => {
        sourceComponent = undefined;
      });
      item.widthChanged.connect(() => {
        popupBox.moveToCenter();
      });
      item.heightChanged.connect(() => {
        popupBox.moveToCenter();
      });
      moveToCenter();
    }
    onSourceComponentChanged: sourceChanged();

    function moveToCenter() {
      item.x = Math.round((roomArea.width - item.width) / 2);
      item.y = Math.round(roomArea.height * 0.67 - item.height / 2);
    }
  }

  Loader {
    id: bigAnim
    anchors.fill: parent
    z: 999
  }

  function activateSkill(skill_name, pressed) {
    if (pressed) {
      const data = JSON.parse(Backend.callLuaFunction("GetInteractionOfSkill", [skill_name]));
      if (data) {
        Backend.callLuaFunction("SetInteractionDataOfSkill", [skill_name, "null"]);
        switch (data.type) {
        case "combo":
          skillInteraction.sourceComponent = Qt.createComponent("../SkillInteraction/SkillCombo.qml");
          skillInteraction.item.skill = skill_name;
          skillInteraction.item.default_choice = data["default"];
          skillInteraction.item.choices = data.choices;
          skillInteraction.item.detailed = data.detailed;
          skillInteraction.item.all_choices = data.all_choices;
          // skillInteraction.item.clicked();
          break;
        case "spin":
          skillInteraction.sourceComponent = Qt.createComponent("../SkillInteraction/SkillSpin.qml");
          skillInteraction.item.skill = skill_name;
          skillInteraction.item.from = data.from;
          skillInteraction.item.to = data.to;
          break;
        default:
          skillInteraction.sourceComponent = undefined;
          break;
        }
      } else {
        skillInteraction.sourceComponent = undefined;
      }

      dashboard.startPending(skill_name);
      cancelButton.enabled = true;
    } else {
      skillInteraction.sourceComponent = undefined;
      Logic.doCancelButton();
    }
  }

  Drawer {
    id: roomDrawer
    width: parent.width * 0.3 / mainWindow.scale
    height: parent.height / mainWindow.scale
    dim: false
    clip: true
    dragMargin: 0
    scale: mainWindow.scale
    transformOrigin: Item.TopLeft

    ColumnLayout {
      anchors.fill: parent

      SwipeView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        interactive: false
        currentIndex: drawerBar.currentIndex
        Item {
          LogEdit {
            id: log
            anchors.fill: parent
          }
        }
        Item {
          visible: !config.replaying
          ChatBox {
            id: chat
            anchors.fill: parent
          }
        }
      }

      TabBar {
        id: drawerBar
        width: roomDrawer.width
        TabButton {
          width: roomDrawer.width / 2
          text: Backend.translate("Log")
        }
        TabButton {
          width: roomDrawer.width / 2
          text: Backend.translate("Chat")
        }
      }
    }
  }

  Drawer {
    id: cheatDrawer
    edge: Qt.RightEdge
    width: parent.width * 0.4 / mainWindow.scale
    height: parent.height / mainWindow.scale
    dim: false
    clip: true
    dragMargin: 0
    scale: mainWindow.scale
    transformOrigin: Item.TopRight

    Loader {
      id: cheatLoader
      anchors.fill: parent
      onSourceChanged: {
        if (item === null)
          return;
        item.finish.connect(() => {
          cheatDrawer.close();
        });
      }
      onSourceComponentChanged: sourceChanged();
    }
  }

  Item {
    id: dynamicCardArea
    anchors.fill: parent
  }

  Rectangle {
    id: easyChat
    width: parent.width
    height: 28
    anchors.bottom: parent.bottom
    visible: false
    color: "#040403"
    radius: 3
    border.width: 1
    border.color: "#A6967A"

    TextInput {
      id: easyChatEdit
      anchors.fill: parent
      anchors.margins: 6
      color: "white"
      clip: true
      font.pixelSize: 14

      onAccepted: {
        if (text != "") {
          ClientInstance.notifyServer(
            "Chat",
            JSON.stringify({
              type: 0,
              msg: text
            })
          );
          text = "";
          easyChat.visible = false;
          easyChatEdit.enabled = false;
        }
      }
    }
  }

  MiscStatus {
    id: miscStatus
    anchors.right: menuButton.left
    anchors.top: parent.top
    anchors.rightMargin: 16
    anchors.topMargin: 8
  }

  Danmaku {
    id: danmaku
    width: parent.width
  }

  Shortcut {
    sequence: "T"
    onActivated: {
      easyChat.visible = true;
      easyChatEdit.enabled = true;
      easyChatEdit.forceActiveFocus();
    }
  }

  Shortcut {
    sequence: "D"
    property bool show_distance: false
    onActivated: {
      show_distance = !show_distance;
      showDistance(show_distance);
    }
  }

  Shortcut {
    sequence: "Esc"
    onActivated: {
      easyChat.visible = false;
      easyChatEdit.enabled = false;
    }
  }

  Shortcut {
    sequence: "Return"
    enabled: okButton.enabled
    onActivated: Logic.doOkButton();
  }

  Shortcut {
    sequence: "Space"
    enabled: cancelButton.enabled
    onActivated: Logic.doCancelButton();
  }

  function getCurrentCardUseMethod() {
    if (specialCardSkills.count === 1 && specialCardSkills.model[0] !== "_normal_use") {
      return specialCardSkills.model[0];
    }

    for (let i = 1; i < specialCardSkills.count; i++) {
      const item = specialCardSkills.itemAt(i);
      if (item.checked) {
        const ret = item.orig_text;
        return ret;
      }
    }
  }

  function addToChat(pid, raw, msg) {
    if (raw.type === 1) return;

    msg = msg.replace(/\{emoji([0-9]+)\}/g, '<img src="../../image/emoji/$1.png" height="24" width="24" />');
    raw.msg = raw.msg.replace(/\{emoji([0-9]+)\}/g, '<img src="../../image/emoji/$1.png" height="24" width="24" />');

    if (raw.msg.startsWith("$")) {
      if (specialChat(pid, raw, raw.msg.slice(1))) return;
    }
    chat.append(msg);
    const photo = Logic.getPhoto(pid);
    if (photo === undefined) {
      const user = raw.userName;
      const m = raw.msg;
      danmaku.sendLog(`${user}: ${m}`);
      return;
    }
    photo.chat(raw.msg);
  }

  function specialChat(pid, data, msg) {
    // skill audio: %s%d[%s]
    // death audio: ~%s
    // something special: !%s:...

    const time = data.time;
    const userName = data.userName;
    const general = Backend.translate(data.general);

    if (msg.startsWith("!")) {
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
          const component = Qt.createComponent("../ChatAnim/" + type + ".qml");
          //if (component.status !== Component.Ready)
          //  return false;

          const fromItem = Logic.getPhotoOrDashboard(fromId);
          const fromPos = mapFromItem(fromItem, fromItem.width / 2, fromItem.height / 2);
          const toItem = Logic.getPhoto(toId);
          const toPos = mapFromItem(toItem, toItem.width / 2, toItem.height / 2);
          const egg = component.createObject(roomScene, { start: fromPos, end: toPos });
          egg.finished.connect(() => egg.destroy());
          egg.running = true;

          return true;
        }
        default:
          return false;
      }
    } else if (msg.startsWith("~")) {
      const g = msg.slice(1);
      const extension = JSON.parse(Backend.callLuaFunction("GetGeneralData", [g])).extension;
      if (!config.disableMsgAudio)
        Backend.playSound("./packages/" + extension + "/audio/death/" + g);

      const m = Backend.translate("~" + g);
      if (general === "")
        chat.append(`[${time}] ${userName}: ${m}`);
      else
        chat.append(`[${time}] ${userName}(${general}): ${m}`);

      const photo = Logic.getPhoto(pid);
      if (photo === undefined) {
        danmaku.sendLog(`${userName}: ${m}`);
        return true;
      }
      photo.chat(m);

      return true;
    } else {
      const splited = msg.split(":");
      if (splited.length < 2) return false;
      const skill = splited[0];
      const idx = parseInt(splited[1]);
      const gene = splited[2];

      try {
        callbacks["LogEvent"](JSON.stringify({
          type: "PlaySkillSound",
          name: skill,
          general: gene,
          i: idx,
        }));
      } catch (e) {}
      const m = Backend.translate("$" + skill + (gene ? "_" + gene : "") + (idx ? idx.toString() : ""));
      if (general === "")
        chat.append(`[${time}] ${userName}: ${m}`);
      else
        chat.append(`[${time}] ${userName}(${general}): ${m}`);

      const photo = Logic.getPhoto(pid);
      if (photo === undefined) {
        danmaku.sendLog(`${userName}: ${m}`);
        return true;
      }
      photo.chat(m);

      return true;
    }

    return false;
  }

  function addToLog(msg) {
    log.append(msg);
  }

  function sendDanmaku(msg) {
    danmaku.sendLog(msg);
    chat.append(msg);
  }

  function showDistance(show) {
    for (let i = 0; i < photoModel.count; i++) {
      const item = photos.itemAt(i);
      if (show) {
        const dis = Backend.callLuaFunction("DistanceTo",[Self.id, item.playerid]);
        item.distance = parseInt(dis);
      } else {
        item.distance = -1;
      }
    }
  }

  function startCheat(type, data) {
    cheatLoader.sourceComponent = Qt.createComponent(`../Cheat/${type}.qml`);
    cheatLoader.item.extra_data = data;
    cheatDrawer.open();
  }

  function resetToInit() {
    const datalist = [];
    for (let i = 0; i < photoModel.count; i++) {
      const item = photoModel.get(i);
      let gameData;
      try {
        gameData = JSON.parse(Backend.callLuaFunction("GetPlayerGameData", [item.id]));
      } catch (e) {
        console.log(e);
        gameData = [0, 0, 0];
      }
      if (item.id > 0) {
        datalist.push({
          id: item.id,
          avatar: item.avatar,
          name: item.screenName,
          isOwner: item.isOwner,
          ready: item.ready,
          gameData: gameData,
        });
      }
    }
    mainStack.pop();
    Backend.callLuaFunction("ResetClientLua", []);
    mainStack.push(room);
    mainStack.currentItem.loadPlayerData(datalist);
  }

  function setPrompt(text, iscur) {
    promptText = text;
    if (iscur) currentPrompt = text;
  }

  function resetPrompt() {
    promptText = currentPrompt;
  }

  function loadPlayerData(datalist) {
    datalist.forEach(d => {
      if (d.id == Self.id) {
        roomScene.isOwner = d.isOwner;
      } else {
        Backend.callLuaFunction("ResetAddPlayer", [JSON.stringify([d.id, d.name, d.avatar, d.ready])]);
      }
      Backend.callLuaFunction("SetPlayerGameData", [d.id, d.gameData]);
      Logic.getPhotoModel(d.id).isOwner = d.isOwner;
    });
  }

  function getPhoto(id) {
    return Logic.getPhoto(id);
  }

  Component.onCompleted: {
    toast.show(Backend.translate("$EnterRoom"));
    playerNum = config.roomCapacity;

    for (let i = 0; i < playerNum; i++) {
      photoModel.append({
        id: i ? -1 : Self.id,
        index: i,   // For animating seat swap
        general: i ? "" : Self.avatar,
        avatar: i ? "" : Self.avatar,
        deputyGeneral: "",
        screenName: i ? "" : Self.screenName,
        role: "unknown",
        kingdom: "unknown",
        netstate: "online",
        maxHp: 0,
        hp: 0,
        shield: 0,
        seatNumber: i + 1,
        dead: false,
        dying: false,
        faceup: true,
        chained: false,
        drank: 0,
        isOwner: false,
        ready: false,
        surrendered: false,
        sealedSlots: "[]",
      });
    }

    Logic.arrangePhotos();
  }
}

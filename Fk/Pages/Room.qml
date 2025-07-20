// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtMultimedia
import Fk
import Fk.Common
import Fk.RoomElement
import Fk.PhotoElement as PhotoElement
import Fk.Widgets as W
import Fk.LobbyElement as L
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
  property bool playersAltered: false // 有人加入或离开房间
  property bool canAddRobot: false

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
  property alias banner: banner

  // 权宜之计 后面全改
  property alias cheatDrawer: cheatLoader

  property var selected_targets: []
  property string responding_card
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
      Backend.playSound("./audio/system/gamestart");
      bgm.play();
      canKickOwner = false;
      kickOwnerTimer.stop();
    } else {
      bgm.stop();
    }
  }

  Button {
    id: menuButton
    anchors.top: parent.top
    anchors.topMargin: 12
    anchors.right: parent.right
    anchors.rightMargin: 12
    text: luatr("Menu")
    onClicked: {
      if (menuContainer.visible){
        menuContainer.close();
      } else {
        menuContainer.open();
      }
    }

    Menu {
      id: menuContainer
      y: menuButton.height - 12
      width: parent.width * 1.8

      MenuItem {
        id: quitButton
        text: luatr("Quit")
        icon.source: AppPath + "/image/modmaker/back"
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

      MenuItem {
        id: volumeButton
        text: luatr("Settings")
        icon.source: AppPath + "/image/button/tileicon/configure"
        onClicked: {
          settingsDialog.open();
        }
      }

      Menu {
        title: luatr("Overview")
        icon.source: AppPath + "/image/button/tileicon/rule_summary"
        icon.width: 24
        icon.height: 24
        icon.color: palette.windowText
        MenuItem {
          id: generalButton
          text: luatr("Generals Overview")
          icon.source: AppPath + "/image/button/tileicon/general_overview"
          onClicked: {
            overviewLoader.overviewType = "Generals";
            overviewDialog.open();
            overviewLoader.item.loadPackages();
          }
        }
        MenuItem {
          id: cardslButton
          text: luatr("Cards Overview")
          icon.source: AppPath + "/image/button/tileicon/card_overview"
          onClicked: {
            overviewLoader.overviewType = "Cards";
            overviewDialog.open();
            overviewLoader.item.loadPackages();
          }
        }
        MenuItem {
          id: modesButton
          text: luatr("Modes Overview")
          icon.source: AppPath + "/image/misc/paper"
          onClicked: {
            overviewLoader.overviewType = "Modes";
            overviewDialog.open();
          }
        }
      }
      MenuItem {
        id: banSchemaButton
        text: luatr("Ban List")
        icon.source: AppPath + "/image/button/tileicon/create_room"
        onClicked: {
          overviewLoader.overviewType = "GeneralPool";
          overviewDialog.open();
        }
      }

      MenuItem {
        id: surrenderButton
        enabled: !config.observing && !config.replaying && isStarted
        text: luatr("Surrender")
        icon.source: AppPath + "/image/misc/surrender"
        onClicked: {
          const photo = getPhoto(Self.id);
          if (isStarted && !(photo.dead && photo.rest <= 0)) {
            const surrenderCheck = lcall('CheckSurrenderAvailable', miscStatus.playedTime);
            if (!surrenderCheck.length) {
              surrenderDialog.informativeText =
                luatr('Surrender is disabled in this mode');
            } else {
              surrenderDialog.informativeText = surrenderCheck
                .map(str => `${luatr(str.text)}（${str.passed ? '✓' : '✗'}）`)
                .join('<br>');
            }
            surrenderDialog.open();
          }
        }
      }
    }
  }

  Button {
    text: luatr("Add Robot")
    visible: isOwner && !isStarted && !isFull
    anchors.centerIn: parent
    enabled: config.serverEnableBot && canAddRobot
    onClicked: {
      ClientInstance.notifyServer("AddRobot", "[]");
    }
  }
  onPlayersAlteredChanged: {
    if (playersAltered) {
      checkCanAddRobot();
      playersAltered = false;
    }
  }

  Button {
    text: luatr("Start Game")
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
    text: isReady ? luatr("Cancel Ready") : luatr("Ready")
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
    text: luatr("Kick Owner")
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
      Backend.playSound("./audio/system/ready");
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
          const data = lcall("GetRoomConfig");
          let cardpack = lcall("GetAllCardPack");
          cardpack = cardpack.filter(p => !data.disabledPack.includes(p));

          text = luatr("GameMode") + luatr(data.gameMode) + "<br />"
            + luatr("LuckCardNum") + "<b>" + data.luckTime + "</b><br />"
            + luatr("ResponseTime") + "<b>" + config.roomTimeout + "</b><br />"
            + luatr("GeneralBoxNum") + "<b>" + data.generalNum + "</b>"
            + (data.enableFreeAssign ? "<br />" + luatr("IncludeFreeAssign")
                                     : "")
            + (data.enableDeputy ? " " + luatr("IncludeDeputy") : "")
            + '<br />' + luatr('CardPackages') + cardpack.map(e => {
              let ret = luatr(e);
              // TODO: 这种东西最好还是变量名规范化= =
              if (ret.search(/特殊牌|衍生牌/) === -1) {
                ret = "<b>" + ret + "</b>";
              }
              return ret;
            }).join('，');
        }
      }
    }
  }

  states: [
    State { name: "notactive" },
    State { name: "active" }
  ]
  state: "notactive"
  transitions: [
    Transition {
      from: "*"; to: "notactive"
      ScriptAction {
        script: {
          skillInteraction.sourceComponent = undefined;
          promptText = "";
          okCancel.visible = false;
          okButton.enabled = false;
          cancelButton.enabled = false;
          endPhaseButton.visible = false;
          progress.visible = false;
          extra_data = {};

          dashboard.disableAllCards();
          dashboard.disableSkills();
          dashboard.pending_skill = "";
          // dashboard.retractAllPiles();

          for (let i = 0; i < photoModel.count; i++) {
            const item = photos.itemAt(i);
            item.state = "normal";
            item.selected = false;
            // item.selectable = false;
          }

          if (popupBox.item != null) {
            popupBox.item.finished();
          }

          lcall("FinishRequestUI");
          applyChange({});
        }
      }
    },

    Transition {
      from: "notactive"; to: "active"
      ScriptAction {
        script: {
          const dat = Backend.getRequestData();
          const total = dat["timeout"] * 1000;
          const now = Date.now(); // ms
          const elapsed = now - (dat["timestamp"] ?? now);

          if (total <= elapsed) {
            roomScene.state = "notactive";
          }

          progressAnim.from = (1 - elapsed / total) * 100.0;
          progressAnim.duration = total - elapsed;
          progress.visible = true;
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
        role_shown: model.role_shown
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
        rest: model.rest
        isOwner: model.isOwner
        ready: model.ready
        surrendered: model.surrendered
        sealedSlots: JSON.parse(model.sealedSlots)

        onSelectedChanged: {
          if ( state === "candidate" )
            lcall("UpdateRequestUI", "Photo", playerid, "click", { selected, autoTarget: config.autoTarget } );
        }

        onDoubleTappedChanged: {
          if (doubleTapped && enabled) {
            lcall("UpdateRequestUI", "Photo", playerid, "doubleClick", { selected, doubleClickUse: config.doubleClickUse, autoTarget: config.autoTarget } )
            doubleTapped = false;
          }
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
        text: luatr("Choose one handcard")
        textFont.pixelSize: 28
        visible: {
          if (roomScene.state === "notactive") return false;
          if (dashboard.handcardArea.length <= 15) {
            return false;
          }
          const cards = dashboard.handcardArea.cards;
          for (const card of cards) {
            if (card.selectable) return true;
          }
          return false;
        }
        onClicked: roomScene.startCheat("../RoomElement/ChooseHandcard");
      }
      MetroButton {
        id: revertSelectionBtn
        text: luatr("Revert Selection")
        textFont.pixelSize: 28
        enabled: dashboard.pending_skill !== ""
        onClicked: //dashboard.revertSelection();
        {
          lcall("RevertSelection");
        }
      }
      // MetroButton {
      //   text: luatr("Trust")
      // }
      MetroButton {
        id: sortBtn
        text: luatr("Sort Cards")
        textFont.pixelSize: 28
        enabled: dashboard.sortable// lcall("CanSortHandcards", Self.id)
        onClicked: {
          if (dashboard.sortable) {
            let sortMethods = [];
            for (let index = 0; index < sortMenuRepeater.count; index++) {
              var tCheckBox = sortMenuRepeater.itemAt(index)
              sortMethods.push(tCheckBox.checked)
            }
            Logic.sortHandcards(sortMethods);
          }
        }

        onRightClicked: {
          if (sortMenu.visible) {
            sortMenu.close();
          } else {
            sortMenu.open();
          }
        }

        ToolTip {
          id: sortTip
          x: 20
          y: -20
          visible: parent.hovered && !sortMenu.visible
          delay: 1500
          timeout: 6000
          text: luatr("Right click or long press to choose sort method")
          font.pixelSize: 20
        }

        /*
        MetroButton {
          id: sideSort
          anchors.left: parent.right
          height: parent.height
          text: "▶"
          visible: !sortMenu.visible && (hovered || parent.hovered)
          onClicked: {
            if (sortMenu.visible) {
              sortMenu.close();
            } else {
              sortMenu.open();
            }
          }
        }
        */

        Menu {
          id: sortMenu
          x: parent.width
          y: -25
          width: parent.width * 2
          background: Rectangle {
            color: "black"
            border.width: 3
            border.color: "white"
            opacity: 0.8
          }

          Repeater {
            id: sortMenuRepeater
            model: ["Sort by Type", "Sort by Number", "Sort by Suit"]

            CheckBox {
              id: control
              text: "<font color='white'>" + luatr(modelData) + "</font>"
              checked: modelData === "Sort by Type"
              font.pixelSize: 20

              indicator: Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                x: control.leftPadding
                y: control.height / 2 - height / 2
                radius: 3
                border.color: "white"

                Rectangle {
                  width: 14
                  height: 14
                  x: 6
                  y: 6
                  radius: 2
                  color: control.down ? "#17a81a" : "#21be2b"
                  visible: control.checked
                }
              }
            }
          }
        }
      }
      MetroButton {
        text: luatr("Chat")
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
          const elapsedSec = addZero(replayerElapsed % 60);
          const totalMin = Math.floor(replayerDuration / 60);
          const totalSec = addZero(replayerDuration % 60);

          return elapsedMin.toString() + ":" + elapsedSec + "/" + totalMin
               + ":" + totalSec;
        }
      }

      Switch {
        text: luatr("Show All Cards")
        checked: config.replayingShowCards
        onCheckedChanged: config.replayingShowCards = checked;
      }

      Switch {
        text: luatr("Speed Resume")
        checked: false
        onCheckedChanged: Backend.controlReplayer("uniform");
      }

      Button {
        text: luatr("Speed Down")
        onClicked: Backend.controlReplayer("slowdown");
      }

      Text {
        font.pixelSize: 20
        font.bold: true
        text: "x" + replayerSpeed;
      }

      Button {
        text: luatr("Speed Up")
        onClicked: Backend.controlReplayer("speedup");
      }

      Button {
        property bool running: true
        text: luatr(running ? "Pause" : "Resume")
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
        id: progressAnim
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
        if (roomScene.state !== "active") {
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
            text: luatr(modelData)
            checked: index === 0
            onCheckedChanged: {
              lcall("UpdateRequestUI", "SpecialSkills", "1", "click", modelData);
            }
          }
        }
      }
    }

    Loader {
      id: skillInteraction
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
        text: luatr("SkipNullification")
        visible: !!extra_data.useEventId
                 && !skippedUseEventId.find(id => id === extra_data.useEventId)
        onClicked: {
          skippedUseEventId.push(extra_data.useEventId);
          lcall("UpdateRequestUI", "Button", "Cancel");
        }
      }

      Button {
        id: okButton
        text: luatr("OK")
        onClicked: lcall("UpdateRequestUI", "Button", "OK");
      }

      Button {
        id: cancelButton
        text: luatr("Cancel")
        onClicked: lcall("UpdateRequestUI", "Button", "Cancel");
      }
    }

    Button {
      id: endPhaseButton
      text: luatr("End")
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 40
      anchors.right: parent.right
      anchors.rightMargin: 30
      visible: false;
      onClicked: lcall("UpdateRequestUI", "Button", "End");
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

  function activateSkill(skill_name, selected, action) {
    let data;
    if (action === "click") data = { selected, autoTarget: config.autoTarget };
    else if (action === "doubleClick") data = { selected, doubleClickUse: config.doubleClickUse, autoTarget: config.autoTarget };
    else data = { selected };
    lcall("UpdateRequestUI", "SkillButton", skill_name, action, data);
  }

  W.PopupLoader {
    id: roomDrawer
    width: realMainWin.width * 0.4
    height: realMainWin.height * 0.95
    x: realMainWin.height * 0.025
    y: realMainWin.height * 0.025

    property int rememberedIdx: 0

    background: Rectangle {
      radius: 12 * mainWindow.scale
      color: "#FAFAFB"
      opacity: 0.9
    }

    ColumnLayout {
      // anchors.fill: parent
      width: parent.width / mainWindow.scale
      height: parent.height / mainWindow.scale
      scale: mainWindow.scale
      transformOrigin: Item.TopLeft

      W.ViewSwitcher {
        id: drawerBar
        Layout.alignment: Qt.AlignHCenter
        model: [
          luatr("Log"),
          luatr("Chat"),
          luatr("PlayerList"),
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
          visible: !config.replaying
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
            text: screenName + (observing ? "  [" + luatr("Observe") +"]" : "")

            onClicked: {
              roomScene.startCheat("PlayerDetail", {
                avatar: avatar,
                id: id,
                screenName: screenName,
                general: general,
                deputyGeneral: deputyGeneral,
                observing: observing
              });
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
    }
  }

  W.PopupLoader {
    id: cheatLoader
    width: realMainWin.width * 0.60
    height: realMainWin.height * 0.8
    anchors.centerIn: parent
    background: Rectangle {
      color: "#CC2E2C27"
      radius: 5
      border.color: "#A6967A"
      border.width: 1
    }
  }

  Item {
    id: dynamicCardArea
    anchors.fill: parent
  }

  MessageDialog {
    id: quitDialog
    title: luatr("Quit")
    informativeText: luatr("Are you sure to quit?")
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

  MessageDialog {
    id: surrenderDialog
    title: luatr("Surrender")
    informativeText: ''
    buttons: MessageDialog.Ok | MessageDialog.Cancel
    onButtonClicked: function (button, role) {
      switch (button) {
        case MessageDialog.Ok: {
          const surrenderCheck =
            lcall('CheckSurrenderAvailable', miscStatus.playedTime);
          if (surrenderCheck.length &&
                !surrenderCheck.find(check => !check.passed)) {

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

  W.PopupLoader {
    id: settingsDialog
    padding: 0
    width: realMainWin.width * 0.6
    height: realMainWin.height * 0.6
    anchors.centerIn: parent
    background: Rectangle {
      color: "#EEEEEEEE"
      radius: 5
      border.color: "#A6967A"
      border.width: 1
    }

    W.SideBarSwitcher {
      id: settingBar
      width: 200
      height: parent.height
      model: ListModel {
        ListElement { name: "Audio Settings" }
        ListElement { name: "Control Settings" }
      }
    }

    SwipeView {
      width: settingsDialog.width - settingBar.width - 16
      x: settingBar.width + 16
      height: parent.height
      interactive: false
      orientation: Qt.Vertical
      currentIndex: settingBar.currentIndex
      clip: true
      L.AudioSetting {}
      L.ControlSetting {}
    }
  }

  W.PopupLoader {
    id: overviewDialog
    width: realMainWin.width * 0.75
    height: realMainWin.height * 0.75
    anchors.centerIn: parent
    background: Rectangle {
      color: "#EEEEEEEE"
      radius: 5
      border.color: "#A6967A"
      border.width: 1
    }
    Loader {
      id: overviewLoader
      property string overviewType: "Generals"
      anchors.centerIn: parent
      width: parent.width / mainWindow.scale
      height: parent.height / mainWindow.scale
      scale: mainWindow.scale
      source: overviewType + "Overview.qml"
    }
  }

  GlowText {
    anchors.centerIn: dashboard
    visible: Logic.getPhoto(Self.id).rest > 0 && !config.observing
    text: luatr("Resting, don't leave!")
    color: "#DBCC69"
    font.family: fontLibian.name
    font.pixelSize: 28
    glow.color: "#2E200F"
    glow.spread: 0.6
  }

  Rectangle {
    anchors.fill: dashboard
    visible: config.observing && !config.replaying
    color: "transparent"
    GlowText {
      anchors.centerIn: parent
      text: luatr("Observing ...")
      color: "#4B83CD"
      font.family: fontLi2.name
      font.pixelSize: 48
    }
  }

  MiscStatus {
    id: miscStatus
    anchors.right: menuButton.left
    anchors.top: parent.top
    anchors.rightMargin: 16
    anchors.topMargin: 8
  }

  PhotoElement.MarkArea {
    id: banner
    x: 12; y: 12
    width: (roomScene.width - 175 * 0.75 * 7) / 4 + 175 - 16
    transformOrigin: Item.TopLeft
    scale: 0.75
    bgColor: "#BB838AEA"
  }

  Danmaku {
    id: danmaku
    width: parent.width
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
    sequence: "T"
    onActivated: {
      roomDrawer.open();
    }
  }

  Shortcut {
    sequence: "Return"
    enabled: okButton.enabled
    onActivated: lcall("UpdateRequestUI", "Button", "OK");
  }

  Shortcut {
    sequence: "Space"
    enabled: cancelButton.enabled || endPhaseButton.visible;
    onActivated: if (cancelButton.enabled) {
      lcall("UpdateRequestUI", "Button", "Cancel");
    } else {
      Logic.replyToServer("");
    }
  }

  Shortcut {
    sequence: "Escape"
    onActivated: menuContainer.open();
  }

  Timer {
    id: statusSkillTimer
    interval: 200
    running: isStarted
    repeat: true
    onTriggered: {
      lcall("RefreshStatusSkills");
      // FIXME 本来可以用客户端notifyUI(AddObserver)刷旁观列表的
      // FIXME 但是由于重启智慧所以还是加入一秒0.2刷得了
      if (!roomDrawer.visible) {
        playerListModel.clear();
        const ps = lcall("GetPlayersAndObservers");
        ps.forEach(p => {
          playerListModel.append({
            id: p.id,
            screenName: p.name,
            general: p.general,
            deputyGeneral: p.deputy,
            observing: p.observing,
            avatar: p.avatar,
          });
        });
      }

      // 刷大家的明置手牌提示框
      for (let i = 0; i < photos.count; i++)
        photos.itemAt(i).handcardsChanged();
    }
  }

  onIsOwnerChanged: {
    if (isOwner && !isStarted && !isFull) {
      addInitComputers();
    }
  }

  function addToChat(pid, raw, msg) {
    if (raw.type === 1) return;
    const photo = Logic.getPhoto(pid);
    if (photo === undefined && config.hideObserverChatter)
      return;

    msg = msg.replace(/\{emoji([0-9]+)\}/g,
      `<img src="${AppPath}/image/emoji/$1.png" height="24" width="24" />`);
    raw.msg = raw.msg.replace(/\{emoji([0-9]+)\}/g,
      `<img src="${AppPath}/image/emoji/$1.png" height="24" width="24" />`);

    if (raw.msg.startsWith("$")) {
      if (specialChat(pid, raw, raw.msg.slice(1))) return; // 蛋花、语音
    }
    chat.append(msg, raw);

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
    const general = luatr(data.general);


    if (msg.startsWith("@")) { // 蛋花
      if (config.hidePresents)
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
          const component = Qt.createComponent("../ChatAnim/" + type + ".qml");
          //if (component.status !== Component.Ready)
          //  return false;

          const fromItem = Logic.getPhotoOrDashboard(fromId);
          const fromPos = mapFromItem(fromItem, fromItem.width / 2,
                                      fromItem.height / 2);
          const toItem = Logic.getPhoto(toId);
          const toPos = mapFromItem(toItem, toItem.width / 2,
                                    toItem.height / 2);
          const egg = component.createObject(roomScene, {
                                                 start: fromPos,
                                                 end: toPos
                                             });
          egg.finished.connect(() => egg.destroy());
          egg.running = true;

          return true;
        }
        default:
          return false;
      }
    } else if (msg.startsWith("!") || msg.startsWith("~")) { // 胜利、阵亡
      const g = msg.slice(1);
      const extension = lcall("GetGeneralData", g).extension;
      if (!config.disableMsgAudio) {
        const path = SkinBank.getAudio(g, extension, msg.startsWith("!") ? "win" : "death");
        Backend.playSound(path);
      }

      const m = luatr(msg);
      data.msg = m;
      if (general === "")
        chat.append(`[${time}] ${userName}: ${m}`, data);
      else
        chat.append(`[${time}] ${userName}(${general}): ${m}`, data);

      const photo = Logic.getPhoto(pid);
      if (photo === undefined) {
        danmaku.sendLog(`${userName}: ${m}`);
        return true;
      }
      photo.chat(m);

      return true;
    } else { // 技能
      const split = msg.split(":");
      if (split.length < 2) return false;
      const skill = split[0];
      const idx = parseInt(split[1]);
      const gene = split[2];
      if (!config.disableMsgAudio)
        try {
          callbacks["LogEvent"]({
            type: "PlaySkillSound",
            name: skill,
            general: gene,
            i: idx,
          });
        } catch (e) {}
      const m = luatr("$" + skill + (gene ? "_" + gene : "")
                          + (idx ? idx.toString() : ""));
      data.msg = m;
      if (general === "")
        chat.append(`[${time}] ${userName}: ${m}`, data);
      else
        chat.append(`[${time}] ${userName}(${general}): ${m}`, data)

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
    log.append({ logText: msg });
  }

  function sendDanmaku(msg) {
    danmaku.sendLog(msg);
    chat.append(null, {
      msg: msg,
      general: "__server", // FIXME: 基于默认读取貂蝉的数据
      userName: "",
      time: "Server",
    });
  }

  function showDistance(show) {
    for (let i = 0; i < photoModel.count; i++) {
      const item = photos.itemAt(i);
      if (show) {
        item.distance = lcall("DistanceTo", Self.id, item.playerid);
      } else {
        item.distance = -1;
      }
    }
  }

  function startCheat(type, data) {
    cheatLoader.sourceComponent = Qt.createComponent(`../Cheat/${type}.qml`);
    cheatLoader.item.extra_data = data;
    cheatLoader.open();
  }

  function startCheatByPath(path, data) {
    cheatLoader.sourceComponent = Qt.createComponent(`${AppPath}/${path}.qml`);
    cheatLoader.item.extra_data = data;
    cheatLoader.open();
  }

  function resetToInit() {
    const datalist = [];
    for (let i = 0; i < photoModel.count; i++) {
      const item = photoModel.get(i);
      let gameData;
      try {
        gameData = lcall("GetPlayerGameData", item.id);
      } catch (e) {
        console.log(e);
        gameData = [0, 0, 0, 0];
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
    lcall("ResetClientLua");
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
      if (d.id === Self.id) {
        roomScene.isOwner = d.isOwner;
      } else {
        lcall("ResetAddPlayer",
          [d.id, d.name, d.avatar, d.ready, d.gameData[3]]);
      }
      lcall("SetPlayerGameData", d.id, d.gameData);
      Logic.getPhotoModel(d.id).isOwner = d.isOwner;
    });
  }

  function getPhoto(id) {
    return Logic.getPhoto(id);
  }

  function activate() {
    if (state === "active") state = "notactive";
    state = "active";
  }

  function applyChange(uiUpdate) {
    const sskilldata = uiUpdate["SpecialSkills"]?.[0]
    if (sskilldata) {
      specialCardSkills.model = sskilldata?.skills ?? [];
    }

    dashboard.applyChange(uiUpdate);
    const pdatas = uiUpdate["Photo"];
    pdatas?.forEach(pdata => {
      const photo = Logic.getPhoto(pdata.id);
      photo.state = pdata.state;
      photo.selectable = pdata.enabled;
      photo.selected = pdata.selected;
    });
    for (let i = 0; i < photoModel.count; i++) {
      const item = photos.itemAt(i);
      item.targetTip = lcall("GetTargetTip", item.playerid);
    }

    const buttons = uiUpdate["Button"];
    if (buttons) {
      okCancel.visible = true;
    }
    buttons?.forEach(bdata => {
      switch (bdata.id) {
        case "OK":
          okButton.enabled = bdata.enabled;
          break;
        case "Cancel":
          cancelButton.enabled = bdata.enabled;
          break;
        case "End":
          endPhaseButton.enabled = bdata.enabled;
          endPhaseButton.visible = bdata.enabled;
          break;
      }
    })

    // Interaction最后上桌 太给脸了居然插结
    uiUpdate["_delete"]?.forEach(data => {
      if (data.type == "Interaction") {
        skillInteraction.sourceComponent = undefined;
        if (roomScene.popupBox.item)
          roomScene.popupBox.item.close();
      }
    });
    uiUpdate["_new"]?.forEach(dat => {
      if (dat.type == "Interaction") {
        const data = dat.data.spec;
        const skill_name = dat.data.skill_name;
        switch (data.type) {
        case "combo":
          skillInteraction.sourceComponent =
            Qt.createComponent("../SkillInteraction/SkillCombo.qml");
          skillInteraction.item.skill = skill_name;
          skillInteraction.item.default_choice = data["default"];
          skillInteraction.item.choices = data.choices;
          skillInteraction.item.detailed = data.detailed;
          skillInteraction.item.all_choices = data.all_choices;
          skillInteraction.item.clicked();
          break;
        case "spin":
          skillInteraction.sourceComponent =
            Qt.createComponent("../SkillInteraction/SkillSpin.qml");
          skillInteraction.item.skill = skill_name;
          skillInteraction.item.from = data.from;
          skillInteraction.item.to = data.to;
          skillInteraction.item?.clicked();
          break;
        case "custom":
          skillInteraction.sourceComponent =
            Qt.createComponent(AppPath + "/" + data.qml_path + ".qml");
          skillInteraction.item.skill = skill_name;
          skillInteraction.item.extra_data = data;
          skillInteraction.item?.clicked();
          break;
        default:
          skillInteraction.sourceComponent = undefined;
          break;
        }
      }
    });
  }

  function addInitComputers() {
    const num = lcall("GetCompNum");
    const min = num.minComp;
    const cur = num.curComp;
    const robotsToAdd = Math.max(0, min - cur);
    for (let i = 0; i < robotsToAdd; i++) {
      ClientInstance.notifyServer("AddRobot", "[]");
    }
  }

  function checkCanAddRobot() {
    if (config.serverEnableBot) {
      const num = lcall("GetCompNum");
      canAddRobot = num.maxComp > num.curComp;
    }
  }

  function addZero(temp) {
    if (temp < 10) return "0" + temp;
    else return temp;
  }

  Component.onCompleted: {
    toast.show(luatr("$EnterRoom"));
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
        role_shown: false,
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
        rest: 0,
        isOwner: false,
        ready: false,
        surrendered: false,
        sealedSlots: "[]",
      });
    }

    Logic.arrangePhotos();
    checkCanAddRobot();
  }
}

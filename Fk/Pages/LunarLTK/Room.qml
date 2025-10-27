// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

import Fk
import Fk.Components.Common
import Fk.Components.LunarLTK
import Fk.Components.LunarLTK.Photo as PhotoElement
import Fk.Widgets as W
import "RoomLogic.js" as Logic

W.PageBase {
  id: roomScene

  property int playerNum: 0
  property int dashboardId: 0

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

  MediaPlayer {
    id: bgm
    source: Config.bgmFile

    loops: MediaPlayer.Infinite
    onPlaybackStateChanged: {
      if (playbackState == MediaPlayer.StoppedState)
        play();
    }
    audioOutput: AudioOutput {
      volume: Config.bgmVolume / 100
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

          Lua.call("FinishRequestUI");
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
        surrendered: model.surrendered
        sealedSlots: JSON.parse(model.sealedSlots)

        onSelectedChanged: {
          if ( state === "candidate" )
            Lua.call("UpdateRequestUI", "Photo", playerid, "click", { selected, autoTarget: Config.autoTarget } );
        }

        onDoubleTappedChanged: {
          if (doubleTapped && enabled) {
            // Lua.call("UpdateRequestUI", "Photo", playerid, "doubleClick", { selected, doubleClickUse: Config.doubleClickUse, autoTarget: Config.autoTarget } )
            doubleTapped = false;
          }
        }

        Component.onCompleted: {
          if (index === 0) {
            dashboard.self = this;
            enableChangeSkin = true;
          }
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
      width: parent.width * 0.7
      height: 150
      x: parent.width * 0.15
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
        text: Lua.tr("Choose one handcard")
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
        onClicked: roomScene.startCheat("ChooseHandcard");
      }
      MetroButton {
        id: trustBtn
        text: Lua.tr("Trust")
        enabled: !Config.observing && !Config.replaying
        visible: !Config.observing && !Config.replaying
        textFont.pixelSize: 28
        onClicked: {
          Cpp.notifyServer("Trust", "");
          trustBtn.enabled = false;
        }
      }
      MetroButton {
        id: revertSelectionBtn
        text: Lua.tr("Revert Selection")
        textFont.pixelSize: 28
        enabled: dashboard.pending_skill !== ""
        onClicked: //dashboard.revertSelection();
        {
          Lua.call("RevertSelection");
        }
      }
      MetroButton {
        id: sortBtn
        text: Lua.tr("Sort Cards")
        textFont.pixelSize: 28
        enabled: dashboard.sortable// Lua.call("CanSortHandcards", Self.id)
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
          text: Lua.tr("Right click or long press to choose sort method")
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
              text: "<font color='white'>" + Lua.tr(modelData) + "</font>"
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
        text: Lua.tr("Chat")
        textFont.pixelSize: 28
        onClicked: Mediator.notify(this, Command.IWantToChat);
      }
    }
  }

  Dashboard {
    id: dashboard
    width: roomScene.width - dashboardBtn.width
    anchors.top: roomArea.bottom
    anchors.left: dashboardBtn.right
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
      font.family: Config.libianName
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
        duration: Config.roomTimeout * 1000

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
            text: Lua.tr(modelData)
            checked: index === 0
            onCheckedChanged: {
              Lua.call("UpdateRequestUI", "SpecialSkills", "1", "click", modelData);
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
        text: Lua.tr("SkipNullification")
        visible: !!extra_data.useEventId
                 && !skippedUseEventId.find(id => id === extra_data.useEventId)
        onClicked: {
          skippedUseEventId.push(extra_data.useEventId);
          Lua.call("UpdateRequestUI", "Button", "Cancel");
        }
      }

      Button {
        id: okButton
        enabled: false
        text: Lua.tr("OK")
        onClicked: Lua.call("UpdateRequestUI", "Button", "OK");
      }

      Button {
        id: cancelButton
        enabled: false
        text: Lua.tr("Cancel")
        onClicked: Lua.call("UpdateRequestUI", "Button", "Cancel");
      }
    }

    Button {
      id: endPhaseButton
      text: Lua.tr("End")
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 40
      anchors.right: parent.right
      anchors.rightMargin: 30
      visible: false;
      onClicked: Lua.call("UpdateRequestUI", "Button", "End");
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
    if (action === "click") data = { selected, autoTarget: Config.autoTarget };
    else if (action === "doubleClick") data = { selected, doubleClickUse: Config.doubleClickUse, autoTarget: Config.autoTarget };
    else data = { selected };
    Lua.call("UpdateRequestUI", "SkillButton", skill_name, action, data);
  }

  W.PopupLoader {
    id: cheatLoader
    width: Config.winWidth * 0.60
    height: Config.winHeight * 0.8
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

  GlowText {
    anchors.centerIn: dashboard
    visible: Logic.getPhoto(Self.id).rest > 0 && !Config.observing
    text: Lua.tr("Resting, don't leave!")
    color: "#DBCC69"
    font.family: Config.libianName
    font.pixelSize: 28
    glow.color: "#2E200F"
    glow.spread: 0.6
  }

  Rectangle {
    anchors.fill: dashboard
    visible: Config.observing && !Config.replaying
    color: "transparent"
    GlowText {
      anchors.centerIn: parent
      text: Lua.tr("Observing ...")
      color: "#4B83CD"
      font.family: Config.li2Name
      font.pixelSize: 48
    }
  }

  MiscStatus {
    id: miscStatus
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 108
    anchors.topMargin: 8
  }

  PhotoElement.MarkArea {
    id: banner
    x: 12; y: 12
    width: ((roomScene.width - 175 * 0.75 * 7) / 4 + 175 - 16) * 0.75
    transformOrigin: Item.TopLeft
    bgColor: "#BB838AEA"
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
    sequence: "Return"
    enabled: okButton.enabled
    onActivated: Lua.call("UpdateRequestUI", "Button", "OK");
  }

  Shortcut {
    sequence: "Space"
    enabled: cancelButton.enabled || endPhaseButton.visible;
    onActivated: if (cancelButton.enabled) {
      Lua.call("UpdateRequestUI", "Button", "Cancel");
    } else {
      Logic.replyToServer("");
    }
  }

  Timer {
    id: statusSkillTimer
    interval: 200
    running: true
    repeat: true
    onTriggered: {
      Lua.call("RefreshStatusSkills");
      // FIXME 本来可以用客户端notifyUI(AddObserver)刷旁观列表的
      // FIXME 但是由于重启智慧所以还是加入一秒0.2刷得了
      // 刷托管按钮
      trustBtn.enabled = true;
      // 刷大家的明置手牌提示框
      for (let i = 0; i < photos.count; i++)
        photos.itemAt(i).handcardsChanged();
    }
  }

  function showDistance(show) {
    for (let i = 0; i < photoModel.count; i++) {
      const item = photos.itemAt(i);
      if (show) {
        item.distance = Lua.call("DistanceTo", Self.id, item.playerid);
      } else {
        item.distance = -1;
      }
    }
  }

  function startCheat(type, data) {
    let component = Qt.createComponent(type);
    if (component.status !== Component.Ready) {
      component = Qt.createComponent("Fk.Components.LunarLTK.Cheat", type);
    }
    cheatLoader.sourceComponent = component;
    cheatLoader.item.extra_data = data;
    cheatLoader.open();
  }

  function startCheatByPath(path, data) {
    cheatLoader.sourceComponent = Qt.createComponent(`${Cpp.path}/${path}.qml`);
    cheatLoader.item.extra_data = data;
    cheatLoader.open();
  }

  function closeCheat() {
    cheatLoader.close();
  }

  function setPrompt(text, iscur) {
    promptText = text;
    if (iscur) currentPrompt = text;
  }

  function resetPrompt() {
    promptText = currentPrompt;
  }

  function getPhoto(id) {
    return Logic.getPhoto(id);
  }

  function getPhotoOrDashboard(id) {
    if (id === Self.id) return dashboard;
    return getPhoto(id);
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
      item.targetTip = Lua.call("GetTargetTip", item.playerid);
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
            Qt.createComponent("Fk.Components.LunarLTK.SkillInteraction", "SkillCombo");
          skillInteraction.item.skill = skill_name;
          skillInteraction.item.default_choice = data["default"];
          skillInteraction.item.choices = data.choices;
          skillInteraction.item.detailed = data.detailed;
          skillInteraction.item.all_choices = data.all_choices;
          skillInteraction.item.clicked();
          break;
        case "spin":
          skillInteraction.sourceComponent =
            Qt.createComponent("Fk.Components.LunarLTK.SkillInteraction", "SkillSpin");
          skillInteraction.item.skill = skill_name;
          skillInteraction.item.from = data.from;
          skillInteraction.item.to = data.to;
          skillInteraction.item.value = data.default;
          skillInteraction.item?.clicked();
          break;
        case "custom":
          skillInteraction.sourceComponent =
            Qt.createComponent(Cpp.path + "/" + data.qml_path + ".qml");
          skillInteraction.item.skill = skill_name;
          skillInteraction.item.extra_data = data;
          skillInteraction.item?.clicked();
          break;
        case "cardname":
          skillInteraction.sourceComponent =
            Qt.createComponent("Fk.Components.LunarLTK.SkillInteraction", "SkillCardName");
          skillInteraction.item.skill = skill_name;
          skillInteraction.item.extra_data = data;
          skillInteraction.item?.clicked();
          break;
        case "checkbox":
          skillInteraction.sourceComponent =
            Qt.createComponent("Fk.Components.LunarLTK.SkillInteraction", "SkillCheckBox");
          skillInteraction.item.skill = skill_name;
          skillInteraction.item.choices = data.choices;
          skillInteraction.item.detailed = data.detailed;
          skillInteraction.item.all_choices = data.all_choices;
          skillInteraction.item.min_num = data.min_num;
          skillInteraction.item.max_num = data.max_num;
          skillInteraction.item.cancelable = data.cancelable;
          skillInteraction.item.clicked();
          break;
        default:
          skillInteraction.sourceComponent = undefined;
          break;
        }
      }
    });
  }

  function netStateChanged(sender, data) {
    const id = data[0];
    let state = data[1];

    const model = Logic.getPhotoModel(id);
    if (!model) return;
    if (state === "run" && model.dead) {
      state = "leave";
    }
    model.netstate = state;
    if (state === "trust" && id === Self.id) {
      roomScene.state = "notactive";
    }
  }

  Component.onCompleted: {
    addCallback(Command.NetStateChanged, netStateChanged);

    // TODO 摆烂了 反正这些后面也是得重构 懒得搬砖了
    addCallback(Command.SetCardFootnote, Logic.callbacks["SetCardFootnote"]);
    addCallback(Command.SetCardVirtName, Logic.callbacks["SetCardVirtName"]);
    addCallback(Command.ShowVirtualCard, Logic.callbacks["ShowVirtualCard"]);
    addCallback(Command.DestroyTableCard, Logic.callbacks["DestroyTableCard"]);
    addCallback(Command.DestroyTableCardByEvent, Logic.callbacks["DestroyTableCardByEvent"]);
    addCallback(Command.MaxCard, Logic.callbacks["MaxCard"]);
    addCallback(Command.PropertyUpdate, Logic.callbacks["PropertyUpdate"]);
    addCallback(Command.UpdateHandcard, Logic.callbacks["UpdateHandcard"]);
    addCallback(Command.UpdateCard, Logic.callbacks["UpdateCard"]);
    addCallback(Command.UpdateSkill, Logic.callbacks["UpdateSkill"]);
    addCallback(Command.StartGame, Logic.callbacks["StartGame"]);
    addCallback(Command.ArrangeSeats, Logic.callbacks["ArrangeSeats"]);
    addCallback(Command.MoveFocus, Logic.callbacks["MoveFocus"]);
    addCallback(Command.PlayerRunned, Logic.callbacks["PlayerRunned"]);
    addCallback(Command.AskForGeneral, Logic.callbacks["AskForGeneral"]);
    addCallback(Command.AskForSkillInvoke, Logic.callbacks["AskForSkillInvoke"]);
    addCallback(Command.AskForArrangeCards, Logic.callbacks["AskForArrangeCards"]);
    addCallback(Command.AskForGuanxing, Logic.callbacks["AskForGuanxing"]);
    addCallback(Command.AskForExchange, Logic.callbacks["AskForExchange"]);
    addCallback(Command.AskForChoice, Logic.callbacks["AskForChoice"]);
    addCallback(Command.AskForChoices, Logic.callbacks["AskForChoices"]);
    addCallback(Command.AskForCardChosen, Logic.callbacks["AskForCardChosen"]);
    addCallback(Command.AskForCardsChosen, Logic.callbacks["AskForCardsChosen"]);
    addCallback(Command.AskForPoxi, Logic.callbacks["AskForPoxi"]);
    addCallback(Command.AskForMoveCardInBoard, Logic.callbacks["AskForMoveCardInBoard"]);
    addCallback(Command.AskForCardsAndChoice, Logic.callbacks["AskForCardsAndChoice"]);
    addCallback(Command.MoveCards, Logic.callbacks["MoveCards"]);
    addCallback(Command.PlayCard, Logic.callbacks["PlayCard"]);
    addCallback(Command.LoseSkill, Logic.callbacks["LoseSkill"]);
    addCallback(Command.AddSkill, Logic.callbacks["AddSkill"]);
    addCallback(Command.PrelightSkill, Logic.callbacks["PrelightSkill"]);
    addCallback(Command.AskForUseActiveSkill, Logic.callbacks["AskForUseActiveSkill"]);
    addCallback(Command.CancelRequest, Logic.callbacks["CancelRequest"]);
    addCallback(Command.AskForUseCard, Logic.callbacks["AskForUseCard"]);
    addCallback(Command.AskForResponseCard, Logic.callbacks["AskForResponseCard"]);
    addCallback(Command.SetPlayerMark, Logic.callbacks["SetPlayerMark"]);
    addCallback(Command.SetBanner, Logic.callbacks["SetBanner"]);
    addCallback(Command.Animate, Logic.callbacks["Animate"]);
    addCallback(Command.LogEvent, Logic.callbacks["LogEvent"]);
    addCallback(Command.GameOver, Logic.callbacks["GameOver"]);
    addCallback(Command.FillAG, Logic.callbacks["FillAG"]);
    addCallback(Command.AskForAG, Logic.callbacks["AskForAG"]);
    addCallback(Command.TakeAG, Logic.callbacks["TakeAG"]);
    addCallback(Command.CloseAG, Logic.callbacks["CloseAG"]);
    addCallback(Command.CustomDialog, Logic.callbacks["CustomDialog"]);
    addCallback(Command.MiniGame, Logic.callbacks["MiniGame"]);
    addCallback(Command.UpdateMiniGame, Logic.callbacks["UpdateMiniGame"]);
    addCallback(Command.EmptyRequest, Logic.callbacks["EmptyRequest"]);
    addCallback(Command.UpdateLimitSkill, Logic.callbacks["UpdateLimitSkill"]);
    addCallback(Command.UpdateDrawPile, Logic.callbacks["UpdateDrawPile"]);
    addCallback(Command.UpdateRoundNum, Logic.callbacks["UpdateRoundNum"]);
    addCallback(Command.ChangeSelf, Logic.callbacks["ChangeSelf"]);
    addCallback(Command.UpdateRequestUI, Logic.callbacks["UpdateRequestUI"]);
    addCallback(Command.GetPlayerHandcards, Logic.callbacks["GetPlayerHandcards"]);
    addCallback(Command.ReplyToServer, Logic.callbacks["ReplyToServer"]);
    addCallback(Command.ChangeSkin, Logic.callbacks["ChangeSkin"]);

    playerNum = Config.roomCapacity;
    bgm.play();

    const luaSelfIdx = Lua.evaluate('table.indexOf(ClientInstance.players, Self)') - 1;

    dashboardId = Self.id;
    for (let i = 0; i < playerNum; i++) {
      const state = Lua.evaluate(`ClientInstance.players[${(luaSelfIdx + i) % playerNum + 1}]:__toqml().prop`);
      const modelData = {
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
        surrendered: false,
        sealedSlots: "[]",
      };
      Object.assign(modelData, state);
      modelData.id = state.playerid;

      photoModel.append(modelData);
    }

    Logic.arrangePhotos();
  }
}

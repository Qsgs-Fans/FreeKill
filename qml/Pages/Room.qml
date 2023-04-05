import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import "Common"
import "RoomElement"
import "RoomLogic.js" as Logic
import "skin-bank.js" as SkinBank


Item {
  id: roomScene

  property int playerNum: 0
  property var dashboardModel

  property bool isOwner: false
  property bool isStarted: false

  property alias popupBox: popupBox
  property alias manualBox: manualBox
  property alias bigAnim: bigAnim
  property alias promptText: prompt.text
  property alias okCancel: okCancel
  property alias okButton: okButton
  property alias cancelButton: cancelButton
  property alias dynamicCardArea: dynamicCardArea
  property alias tableCards: tablePile.cards
  property alias dashboard: dashboard

  property var selected_targets: []
  property string responding_card
  property bool respond_play: false
  property var extra_data: ({})

  Image {
    source: config.roomBg
    anchors.fill: parent
    fillMode: Image.PreserveAspectCrop
  }

  MediaPlayer {
    id: bgm
    source: config.bgmFile

    // loops: MediaPlayer.Infinite
    onPlaybackStateChanged: {
      if (playbackState == MediaPlayer.StoppedState && roomScene.isStarted)
        play();
    }
    audioOutput: AudioOutput {}
  }

  onIsStartedChanged: {
    if (isStarted) {
      bgm.play();
    } else {
      // bgm.stop();
    }
  }

  // tmp
  Button {
    text: "quit"
    anchors.top: parent.top
    anchors.right: parent.right
    onClicked: {
      // ClientInstance.clearPlayers();
      ClientInstance.notifyServer("QuitRoom", "[]");
    }
  }
  Button {
    text: "add robot"
    visible: dashboardModel.isOwner && !isStarted
    anchors.centerIn: parent
    onClicked: {
      ClientInstance.notifyServer("AddRobot", "[]");
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
          skillInteraction.source = "";
          promptText = "";
          progress.visible = false;
          okCancel.visible = false;
          endPhaseButton.visible = false;
          respond_play = false;
          extra_data = {};

          if (dashboard.pending_skill !== "")
            dashboard.stopPending();
          dashboard.disableAllCards();
          dashboard.disableSkills();
          dashboard.retractAllPiles();
          selected_targets = [];

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
          skillInteraction.source = "";
          dashboard.enableCards();
          dashboard.enableSkills();
          progress.visible = true;
          okCancel.visible = true;
          endPhaseButton.visible = true;
          respond_play = false;
        }
      }
    },

    Transition {
      from: "*"; to: "responding"
      ScriptAction {
        script: {
          skillInteraction.source = "";
          dashboard.enableCards(responding_card);
          dashboard.enableSkills(responding_card);
          progress.visible = true;
          okCancel.visible = true;
        }
      }
    },

    Transition {
      from: "*"; to: "replying"
      ScriptAction {
        script: {
          skillInteraction.source = "";
          dashboard.disableAllCards();
          dashboard.disableSkills();
          progress.visible = true;
          respond_play = false;
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
        screenName: model.screenName
        role: model.role
        kingdom: model.kingdom
        netstate: model.netstate
        maxHp: model.maxHp
        hp: model.hp
        seatNumber: model.seatNumber
        dead: model.dead
        dying: model.dying
        faceup: model.faceup
        chained: model.chained
        drank: model.drank
        isOwner: model.isOwner

        onSelectedChanged: {
          Logic.updateSelectedTargets(playerid, selected);
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
    ColumnLayout {
      MetroButton {
        text: Backend.translate("Trust")
      }
      MetroButton {
        text: Backend.translate("Sort Cards")
      }
      MetroButton {
        text: Backend.translate("Chat")
        onClicked: roomDrawer.open();
      }
    }
  }

  Dashboard {
    id: dashboard
    width: roomScene.width - dashboardBtn.width
    anchors.top: roomArea.bottom
    anchors.left: dashboardBtn.right

    self.playerid: dashboardModel.id
    self.general: dashboardModel.general
    self.screenName: dashboardModel.screenName
    self.role: dashboardModel.role
    self.kingdom: dashboardModel.kingdom
    self.netstate: dashboardModel.netstate
    self.maxHp: dashboardModel.maxHp
    self.hp: dashboardModel.hp
    self.seatNumber: dashboardModel.seatNumber
    self.dead: dashboardModel.dead
    self.dying: dashboardModel.dying
    self.faceup: dashboardModel.faceup
    self.chained: dashboardModel.chained
    self.drank: dashboardModel.drank
    self.isOwner: dashboardModel.isOwner

    onSelectedChanged: {
      Logic.updateSelectedTargets(self.playerid, selected);
    }

    onCardSelected: function(card) {
      Logic.enableTargets(card);

      if (typeof card === "number" && card !== -1 && roomScene.state === "playing") {
        let skills = JSON.parse(Backend.callLuaFunction("GetCardSpecialSkills", [card]));
        skills.unshift("_normal_use");
        specialCardSkills.model = skills;
      } else {
        specialCardSkills.model = [];
      }
    }
  }

  GlowText {
    text: Backend.translate("Observing ...")
    visible: config.observing
    color: "#4B83CD"
    font.family: fontLi2.name
    font.pixelSize: 48
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
      visible: roomScene.state == "playing" && specialCardSkills.count > 1
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

  Loader {
    id: popupBox
    z: 999
    onSourceChanged: {
      if (item === null)
        return;
      item.finished.connect(function(){
        source = "";
      });
      item.widthChanged.connect(function(){
        popupBox.moveToCenter();
      });
      item.heightChanged.connect(function(){
        popupBox.moveToCenter();
      });
      moveToCenter();
    }

    function moveToCenter()
    {
      item.x = Math.round((roomArea.width - item.width) / 2);
      item.y = Math.round(roomArea.height * 0.67 - item.height / 2);
    }
  }

  // manualBox: same as popupBox, but must be closed manually
  Loader {
    id: manualBox
    z: 999
    onSourceChanged: {
      if (item === null)
        return;
      item.finished.connect(() => source = "");
      item.widthChanged.connect(() => manualBox.moveToCenter());
      item.heightChanged.connect(() => manualBox.moveToCenter());
      moveToCenter();
    }

    function moveToCenter()
    {
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
      let data = JSON.parse(Backend.callLuaFunction("GetInteractionOfSkill", [skill_name]));
      if (data) {
        Backend.callLuaFunction("SetInteractionDataOfSkill", [skill_name, "null"]);
        switch (data.type) {
        case "combo":
          skillInteraction.source = "RoomElement/SkillInteraction/SkillCombo.qml";
          skillInteraction.item.skill = skill_name;
          skillInteraction.item.default_choice = data["default"];
          skillInteraction.item.choices = data.choices;
          break;
        default:
          skillInteraction.source = "";
          break;
        }
      } else {
        skillInteraction.source = "";
      }

      dashboard.startPending(skill_name);
      cancelButton.enabled = true;
    } else {
      skillInteraction.source = "";
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
    for (let i = 1; i < specialCardSkills.count; i++) {
      let item = specialCardSkills.itemAt(i);
      if (item.checked) {
        let ret = item.orig_text;
        return ret;
      }
    }
  }

  function addToChat(pid, raw, msg) {
    if (raw.type === 1) return;
    chat.append(msg);
    let photo = Logic.getPhotoOrSelf(pid);
    if (photo === undefined)
      return;
    photo.chat(raw.msg);
  }

  function addToLog(msg) {
    log.append(msg);
  }

  function showDistance(show) {
    for (let i = 0; i < photoModel.count; i++) {
      let item = photos.itemAt(i);
      if (show) {
        let dis = Backend.callLuaFunction("DistanceTo",[Self.id, item.playerid]);
        item.distance = parseInt(dis);
      } else {
        item.distance = 0;
      }
    }
  }

  function startCheat(source, data) {
    cheatLoader.source = source;
    cheatLoader.item.extra_data = data;
    cheatDrawer.open();
  }

  Component.onCompleted: {
    toast.show(Backend.translate("$EnterRoom"));

    dashboardModel = {
      id: Self.id,
      general: Self.avatar,
      screenName: Self.screenName,
      role: "unknown",
      kingdom: "qun",
      netstate: "online",
      maxHp: 0,
      hp: 0,
      seatNumber: 1,
      dead: false,
      dying: false,
      faceup: true,
      chained: false,
      drank: 0,
      isOwner: false
    }

    playerNum = config.roomCapacity;

    let i;
    for (i = 1; i < playerNum; i++) {
      photoModel.append({
        id: -1,
        index: i - 1,   // For animating seat swap
        general: "",
        screenName: "",
        role: "unknown",
        kingdom: "qun",
        netstate: "online",
        maxHp: 0,
        hp: 0,
        seatNumber: i + 1,
        dead: false,
        dying: false,
        faceup: true,
        chained: false,
        drank: 0,
        isOwner: false
      });
    }

    Logic.arrangePhotos();
  }
}


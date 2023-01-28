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
  property alias promptText: prompt.text
  property alias okCancel: okCancel
  property alias okButton: okButton
  property alias cancelButton: cancelButton
  property alias dynamicCardArea: dynamicCardArea
  property alias tableCards: tablePile.cards

  property var selected_targets: []
  property string responding_card
  property bool respond_play: false
  property var extra_data: ({})

  Image {
    source: AppPath + "/image/gamebg"
    anchors.fill: parent
    fillMode: Image.PreserveAspectCrop
  }

  MediaPlayer {
    id: bgm
    source: AppPath + "/audio/system/bgm.mp3"
    
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
      anchors.top: progress.top
      anchors.topMargin: -2
      color: "white"
      z: 1
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
        implicitHeight: 14
        color: "black"
        radius: 3
      }

      contentItem: Item {
        implicitWidth: 200
        implicitHeight: 12

        Rectangle {
          width: progress.visualPosition * parent.width
          height: parent.height
          radius: 2
          color: "red"
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

  function activateSkill(skill_name, pressed) {
    if (pressed) {
      dashboard.startPending(skill_name);
      cancelButton.enabled = true;
    } else {
      Logic.doCancelButton();
    }
  }

  Drawer {
    id: roomDrawer
    width: parent.width * 0.3
    height: parent.height
    dim: false
    clip: true
    dragMargin: 0
    
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

  function addToChat(pid, raw, msg) {
    chat.append(msg);
    let photo = Logic.getPhoto(pid);
    if (photo === undefined)
      photo = dashboard.self;
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
      drank: false,
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
        drank: false,
        isOwner: false
      });
    }

    Logic.arrangePhotos();
  }
}


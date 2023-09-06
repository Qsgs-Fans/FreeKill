// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import Fk
import Fk.PhotoElement

Item {
  id: root
  width: 175
  height: 233
  scale: 0.75
  property int playerid: 0
  property string general: ""
  property string avatar: ""
  property string deputyGeneral: ""
  property string screenName: ""
  property string role: "unknown"
  property string kingdom: "qun"
  property string netstate: "online"
  property alias handcards: handcardAreaItem.length
  property int maxHp: 0
  property int hp: 0
  property int shield: 0
  property int seatNumber: 1
  property bool dead: false
  property bool dying: false
  property bool faceup: true
  property bool chained: false
  property int drank: 0
  property bool isOwner: false
  property bool ready: false
  property int winGame: 0
  property int runGame: 0
  property int totalGame: 0
  property list<string> sealedSlots: []

  property int distance: -1
  property string status: "normal"
  property int maxCard: 0

  property alias handcardArea: handcardAreaItem
  property alias equipArea: equipAreaItem
  property alias areasSealed: equipAreaItem
  property alias markArea: markAreaItem
  property alias picMarkArea: picMarkAreaItem
  property alias delayedTrickArea: delayedTrickAreaItem
  property alias specialArea: specialAreaItem

  property alias progressBar: progressBar
  property alias progressTip: progressTip.text

  property bool selectable: false
  property bool selected: false

  property bool playing: false
  property bool surrendered: false
  onPlayingChanged: {
    if (playing) {
      animPlaying.start();
    } else {
      animPlaying.stop();
    }
  }

  Behavior on x {
    NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
  }

  Behavior on y {
    NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
  }

  states: [
    State { name: "normal" },
    State { name: "candidate" }
    //State { name: "playing" }
    //State { name: "responding" },
    //State { name: "sos" }
  ]

  state: "normal"
  transitions: [
    Transition {
      from: "*"; to: "normal"
      ScriptAction {
        script: {
          animSelectable.stop();
          animSelected.stop();
        }
      }
    },

    Transition {
      from: "*"; to: "candidate"
      ScriptAction {
        script: {
          animSelectable.start();
          animSelected.start();
        }
      }
    }
  ]

  PixmapAnimation {
    id: animPlaying
    source: SkinBank.PIXANIM_DIR + "playing"
    anchors.centerIn: parent
    loop: true
    scale: 1.1
    visible: root.playing
  }

  PixmapAnimation {
    id: animSelected
    source: SkinBank.PIXANIM_DIR + "selected"
    anchors.centerIn: parent
    loop: true
    scale: 1.1
    visible: root.state === "candidate" && selected
  }

  Image {
    id: back
    source: SkinBank.getPhotoBack(root.kingdom)
  }

  Text {
    id: generalName
    x: 5
    y: 28
    font.family: fontLibian.name
    font.pixelSize: 22
    opacity: 0.9
    horizontalAlignment: Text.AlignHCenter
    lineHeight: 18
    lineHeightMode: Text.FixedHeight
    color: "white"
    width: 24
    wrapMode: Text.WrapAnywhere
    text: ""
  }

  Text {
    id: longGeneralName
    x: 5
    y: 6
    font.family: fontLibian.name
    font.pixelSize: 22
    rotation: 90
    transformOrigin: Item.BottomLeft
    opacity: 0.9
    horizontalAlignment: Text.AlignHCenter
    lineHeight: 18
    lineHeightMode: Text.FixedHeight
    color: "white"
    text: ""
  }

  HpBar {
    id: hp
    x: 8
    value: root.hp
    maxValue: root.maxHp
    shieldNum: root.shield
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 36
  }

  Item {
    width: 138
    height: 222
    visible: false
    id: generalImgItem

    Image {
      id: generalImage
      width: deputyGeneral ? parent.width / 2 : parent.width
      height: parent.height
      smooth: true
      fillMode: Image.PreserveAspectCrop
      source: {
        if (general === "") {
          return "";
        }
        if (deputyGeneral) {
          return SkinBank.getGeneralExtraPic(general, "dual/") ?? SkinBank.getGeneralPicture(general);
        } else {
          return SkinBank.getGeneralPicture(general)
        }
      }
    }

    Image {
      id: deputyGeneralImage
      anchors.left: generalImage.right
      width: parent.width / 2
      height: parent.height
      smooth: true
      fillMode: Image.PreserveAspectCrop
      source: {
        const general = deputyGeneral;
        if (deputyGeneral != "") {
          return SkinBank.getGeneralExtraPic(general, "dual/") ?? SkinBank.getGeneralPicture(general);
        } else {
          return "";
        }
      }
    }

    Image {
      id: deputySplit
      source: SkinBank.PHOTO_DIR + "deputy-split"
      opacity: deputyGeneral ? 1 : 0
    }

    Text {
      id: deputyGeneralName
      anchors.left: generalImage.right
      anchors.leftMargin: -14
      y: 23
      font.family: fontLibian.name
      font.pixelSize: 22
      opacity: 0.9
      horizontalAlignment: Text.AlignHCenter
      lineHeight: 18
      lineHeightMode: Text.FixedHeight
      color: "white"
      width: 24
      wrapMode: Text.WrapAnywhere
      text: Backend.translate(deputyGeneral)
      style: Text.Outline
    }
  }

  Rectangle {
    id: photoMask
    x: 31
    y: 5
    width: 138
    height: 222
    radius: 8
    visible: false
  }

  OpacityMask {
    anchors.fill: photoMask
    source: generalImgItem
    maskSource: photoMask
  }

  Colorize {
    anchors.fill: photoMask
    source: generalImgItem
    saturation: 0
    visible: root.dead || root.surrendered
  }

  Rectangle {
    x: 31
    y: 5
    width: 138
    height: 222
    radius: 8

    visible: root.drank > 0
    color: "red"
    opacity: 0.4 + Math.log(root.drank) * 0.12
  }

  Rectangle {
    id: winRateRect
    width: 138; x: 31
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 6
    height: childrenRect.height + 8
    color: "#CC3C3229"
    radius: 8
    border.color: "white"
    border.width: 1
    visible: screenName != "" && !roomScene.isStarted

    Text {
      y: 4
      anchors.horizontalCenter: parent.horizontalCenter
      font.pixelSize: 20
      font.family: fontLibian.name
      color: (totalGame > 0 && runGame / totalGame > 0.2) ? "red" : "white"
      style: Text.Outline
      text: {
        if (totalGame === 0) {
          return Backend.translate("Newbie");
        }
        const winRate = (winGame / totalGame) * 100;
        const runRate = (runGame / totalGame) * 100;
        return Backend.translate("Win=%1\nRun=%2\nTotal=%3")
          .arg(winRate.toFixed(2))
          .arg(runRate.toFixed(2))
          .arg(totalGame);
      }
    }
  }

  Image {
    anchors.bottom: winRateRect.top
    anchors.right: parent.right
    anchors.bottomMargin: -8
    anchors.rightMargin: 4
    source: SkinBank.PHOTO_DIR + (isOwner ? "owner" : (ready ? "ready" : "notready"))
    visible: screenName != "" && !roomScene.isStarted
  }

  Image {
    visible: equipAreaItem.length > 0
    source: SkinBank.PHOTO_DIR + "equipbg"
    x: 31
    y: 121
  }

  Image {
    source: root.status != "normal" ? SkinBank.STATUS_DIR + root.status : ""
    x: -6
  }

  Image {
    id: turnedOver
    visible: !root.faceup
    source: SkinBank.PHOTO_DIR + "faceturned" + (config.heg ? '-heg' : '')
    x: 29; y: 5
  }

  EquipArea {
    id: equipAreaItem

    x: 31
    y: 157
  }

  Item {
    id: specialAreaItem

    x: 31
    y: 139

    InvisibleCardArea {
      id: specialContainer
      // checkExisting: true
    }

    function updatePileInfo(areaName) {
      const data = JSON.parse(Backend.callLuaFunction("GetPile", [root.playerid, areaName]));
      if (data.length === 0) {
        root.markArea.removeMark(areaName);
      } else {
        root.markArea.setMark(areaName, data.length.toString());
      }
    }

    function add(inputs, areaName) {
      updatePileInfo(areaName);
      specialContainer.add(inputs);
    }

    function remove(inputs, areaName) {
      updatePileInfo(areaName);
      return specialContainer.remove(inputs);
    }

    function updateCardPosition(a) {
      specialContainer.updateCardPosition(a);
    }
  }

  MarkArea {
    id: markAreaItem

    anchors.bottom: equipAreaItem.top
    x: 31
  }

  Image {
    id: chain
    visible: root.chained
    source: SkinBank.PHOTO_DIR + "chain"
    anchors.horizontalCenter: parent.horizontalCenter
    y: 72
  }

  Image {
    // id: saveme
    visible: root.dead || root.dying || root.surrendered
    source: {
      if (root.dead) {
        return SkinBank.getRoleDeathPic(root.role);
      }
      return SkinBank.DEATH_DIR + (root.surrendered ? "surrender" : "saveme")
    }
    anchors.centerIn: photoMask
  }

  Image {
    id: netstat
    source: SkinBank.STATE_DIR + root.netstate
    x: photoMask.x
    y: photoMask.y
    scale: 0.9
    transformOrigin: Item.TopLeft
  }

  Image {
    id: handcardNum
    source: SkinBank.PHOTO_DIR + "handcard"
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -6
    x: -6

    Text {
      text: (root.maxCard === root.hp || root.hp < 0 ) ? (root.handcards) : (root.handcards + "/" + (root.maxCard < 900 ? root.maxCard : "∞"))
      font.family: fontLibian.name
      font.pixelSize: (root.maxCard === root.hp || root.hp < 0 ) ? 32 : 27
      //font.weight: 30
      color: "white"
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 4
      style: Text.Outline
    }

    TapHandler {
      enabled: (root.state != "candidate" || !root.selectable) && root.playerid !== Self.id
      onTapped: {
        const params = { name: "hand_card" };
        let data = JSON.parse(Backend.callLuaFunction("GetPlayerHandcards", [root.playerid]));
        data = data.filter((e) => e !== -1);
        if (data.length === 0)
          return;

        params.ids = data;

        // Just for using room's right drawer
        roomScene.startCheat("../RoomElement/ViewPile", params);
      }
    }
  }

  TapHandler {
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.NoButton
    gesturePolicy: TapHandler.WithinBounds

    onTapped: (p, btn) => {
      if (btn === Qt.LeftButton || btn === Qt.NoButton) {
        if (parent.state != "candidate" || !parent.selectable) {
          return;
        }
        parent.selected = !parent.selected;
      } else if (btn === Qt.RightButton) {
        parent.showDetail();
      }
    }

    onLongPressed: {
      parent.showDetail();
    }
  }

  RoleComboBox {
    id: role
    value: root.role
    anchors.top: parent.top
    anchors.topMargin: -4
    anchors.right: parent.right
    anchors.rightMargin: -4
  }

  LimitSkillArea {
    id: limitSkills
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: role.height + 2
    anchors.rightMargin: 30
  }

  GlowText {
    id: playerName
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 2

    font.pixelSize: 16
    text: screenName

    glow.radius: 8
  }

  Image {
    visible: root.state === "candidate" && !selectable && !selected
    source: SkinBank.PHOTO_DIR + "disable"
    x: 31; y: -21
  }

  GlowText {
    id: seatNum
    visible: !progressBar.visible
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -32
    property var seatChr: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "十一", "十二"]
    font.family: fontLi2.name
    font.pixelSize: 32
    text: seatChr[seatNumber - 1]

    glow.color: "brown"
    glow.spread: 0.2
    glow.radius: 8
    //glow.samples: 12
  }

  SequentialAnimation {
    id: trembleAnimation
    running: false
    PropertyAnimation {
      target: root
      property: "x"
      to: root.x - 20
      easing.type: Easing.InQuad
      duration: 100
    }
    PropertyAnimation {
      target: root
      property: "x"
      to: root.x
      easing.type: Easing.OutQuad
      duration: 100
    }
  }

  function tremble() {
    trembleAnimation.start()
  }

  ProgressBar {
    id: progressBar
    width: parent.width
    height: 4
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -4
    from: 0.0
    to: 100.0

    visible: false
    NumberAnimation on value {
      running: progressBar.visible
      from: 100.0
      to: 0.0
      duration: config.roomTimeout * 1000

      onFinished: {
        progressBar.visible = false;
        root.progressTip = "";
      }
    }
  }

  Image {
    anchors.top: progressBar.bottom
    anchors.topMargin: 1
    source: SkinBank.PHOTO_DIR + "control/tip"
    visible: progressTip.text != ""
    Text {
      id: progressTip
      font.family: fontLibian.name
      font.pixelSize: 18
      x: 18
      color: "white"
      text: ""
    }
  }

  PixmapAnimation {
    id: animSelectable
    source: SkinBank.PIXANIM_DIR + "selectable"
    anchors.centerIn: parent
    loop: true
    visible: root.state === "candidate" && selectable
  }

  InvisibleCardArea {
    id: handcardAreaItem
    anchors.centerIn: parent
  }

  DelayedTrickArea {
    id: delayedTrickAreaItem
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 8
  }

  PicMarkArea {
    id: picMarkAreaItem

    anchors.top: parent.bottom
    anchors.right: parent.right
    anchors.topMargin: -4
  }

  InvisibleCardArea {
    id: defaultArea
    anchors.centerIn: parent
  }

  Rectangle {
    id: chat
    color: "#F2ECD7"
    radius: 4
    opacity: 0
    width: parent.width
    height: childrenRect.height + 8
    property string text: ""
    visible: false
    Text {
      width: parent.width - 8
      x: 4
      y: 4
      text: parent.text
      wrapMode: Text.WrapAnywhere
      font.family: fontLibian.name
      font.pixelSize: 20
    }
    SequentialAnimation {
      id: chatAnim
      PropertyAnimation {
        target: chat
        property: "opacity"
        to: 0.9
        duration: 200
      }
      NumberAnimation {
        duration: 2500
      }
      PropertyAnimation {
        target: chat
        property: "opacity"
        to: 0
        duration: 150
      }
      onFinished: chat.visible = false;
    }
  }

  Rectangle {
    color: "white"
    height: 20
    width: 20
    visible: distance != -1
    Text {
      text: distance
      anchors.centerIn: parent
    }
  }

  onGeneralChanged: {
    if (!roomScene.isStarted) return;
    const text = Backend.translate(general);
    if (text.length > 6) {
      generalName.text = "";
      longGeneralName.text = text;
    } else {
      generalName.text = text;
      longGeneralName.text = "";
    }
    // let data = JSON.parse(Backend.callLuaFunction("GetGeneralData", [general]));
    // kingdom = data.kingdom;
  }

  function chat(msg) {
    chat.text = msg;
    chat.visible = true;
    chatAnim.restart();
  }

  function updateLimitSkill(skill, time) {
    limitSkills.update(skill, time);
  }

  function showDetail() {
    if (playerid === 0 || playerid === -1) {
      return;
    }

    roomScene.startCheat("PlayerDetail", { photo: this });
  }
}

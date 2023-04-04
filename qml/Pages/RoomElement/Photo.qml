import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import "PhotoElement"
import "../skin-bank.js" as SkinBank

Item {
  id: root
  width: 175
  height: 233
  scale: 0.75
  property int playerid
  property string general: ""
  property string screenName: ""
  property string role: "unknown"
  property string kingdom: "qun"
  property string netstate: "online"
  property alias handcards: handcardAreaItem.length
  property int maxHp: 0
  property int hp: 0
  property int seatNumber: 1
  property bool dead: false
  property bool dying: false
  property bool faceup: true
  property bool chained: false
  property int drank: 0
  property bool isOwner: false
  property int distance: 0
  property string status: "normal"

  property alias handcardArea: handcardAreaItem
  property alias equipArea: equipAreaItem
  property alias markArea: markAreaItem
  property alias delayedTrickArea: delayedTrickAreaItem
  property alias specialArea: specialAreaItem

  property alias progressBar: progressBar
  property alias progressTip: progressTip.text

  property bool selectable: false
  property bool selected: false

  property bool playing: false
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
    source: SkinBank.PHOTO_BACK_DIR + root.kingdom
  }

  Text {
    id: generalName
    x: 5
    y: 28
    font.family: fontLibian.name
    font.pixelSize: 22
    opacity: 0.7
    horizontalAlignment: Text.AlignHCenter
    lineHeight: 18
    lineHeightMode: Text.FixedHeight
    color: "white"
    width: 24
    wrapMode: Text.WordWrap
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
    opacity: 0.7
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
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 36
  }

  Image {
    id: generalImage
    width: 138
    height: 222
    smooth: true
    visible: false
    fillMode: Image.PreserveAspectCrop
    source: (general != "") ? SkinBank.getGeneralPicture(general) : ""

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
    source: generalImage
    maskSource: photoMask
  }

  Colorize {
    anchors.fill: photoMask
    source: generalImage
    saturation: 0
    visible: root.dead
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

  Image {
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.bottomMargin: 8
    anchors.rightMargin: 4
    source: SkinBank.PHOTO_DIR + (isOwner ? "owner" : "ready")
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
    source: SkinBank.PHOTO_DIR + "faceturned"
    x: 29; y: 5
  }

  EquipArea {
    id: equipAreaItem

    x: 31
    y: 139
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
      let data = JSON.parse(Backend.callLuaFunction("GetPile", [root.playerid, areaName]));
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
    anchors.bottomMargin: -18
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
    visible: root.dead || root.dying
    source: SkinBank.DEATH_DIR + (root.dead ? root.role : "saveme")
    anchors.centerIn: photoMask
  }

  Image {
    id: netstat
    source: SkinBank.STATE_DIR + root.netstate
    x: photoMask.x
    y: photoMask.y
  }

  Image {
    id: handcardNum
    source: SkinBank.PHOTO_DIR + "handcard"
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -6
    x: -6

    Text {
      text: root.handcards
      font.family: fontLibian.name
      font.pixelSize: 32
      //font.weight: 30
      color: "white"
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 4
      style: Text.Outline
    }
  }

  TapHandler {
    onTapped: {
      if (parent.state != "candidate" || !parent.selectable) {
        return;
      }
      parent.selected = !parent.selected;
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
    anchors.top: role.bottom
    anchors.left: role.left
    anchors.topMargin: 2
    anchors.leftMargin: -2
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
    property var seatChr: ["一", "二", "三", "四", "五", "六", "七", "八"]
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
    rows: 1
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 8
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
    visible: distance != 0
    Text {
      text: distance
      anchors.centerIn: parent
    }
  }

  onGeneralChanged: {
    if (!roomScene.isStarted) return;
    let text = Backend.translate(general);
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
}

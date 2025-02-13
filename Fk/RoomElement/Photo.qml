// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import QtQuick.Layouts
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
  property bool role_shown: false
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
  property int rest: 0
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

  property var targetTip: []
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
      Behavior on width { NumberAnimation { duration: 100 } }
      height: parent.height
      smooth: true
      fillMode: Image.PreserveAspectCrop
      source: {
        if (general === "") {
          return "";
        }
        if (deputyGeneral) {
          return SkinBank.getGeneralExtraPic(general, "dual/")
              ?? SkinBank.getGeneralPicture(general);
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
          return SkinBank.getGeneralExtraPic(general, "dual/")
              ?? SkinBank.getGeneralPicture(general);
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
      text: ""
      style: Text.Outline
    }

    Text {
      id: longDeputyGeneralName
      anchors.left: generalImage.right
      anchors.leftMargin: -14
      y: 23
      font.family: fontLibian.name
      font.pixelSize: 22
      rotation: 90
      transformOrigin: Item.BottomLeft
      opacity: 0.9
      horizontalAlignment: Text.AlignHCenter
      lineHeight: 18
      lineHeightMode: Text.FixedHeight
      color: "white"
      width: 24
      text: ""
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
    id: photoMaskEffect
    anchors.fill: photoMask
    source: generalImgItem
    maskSource: photoMask
  }

  Colorize {
    anchors.fill: photoMaskEffect
    source: photoMaskEffect
    saturation: 0
    opacity: (root.dead || root.surrendered) ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 300 } }
  }

  Rectangle {
    x: 31
    y: 5
    width: 138
    height: 222
    radius: 8

    // visible: root.drank > 0
    color: "red"
    opacity: (root.drank <= 0 ? 0 : 0.4) + Math.log(root.drank) * 0.12
    Behavior on opacity { NumberAnimation { duration: 300 } }
  }

  ColumnLayout {
    id: restRect
    anchors.centerIn: photoMask
    anchors.leftMargin: 20
    visible: root.rest > 0

    GlowText {
      Layout.alignment: Qt.AlignCenter
      text: luatr("resting...")
      font.family: fontLibian.name
      font.pixelSize: 40
      font.bold: true
      color: "#FEF7D6"
      glow.color: "#845422"
      glow.spread: 0.8
    }

    GlowText {
      Layout.alignment: Qt.AlignCenter
      visible: root.rest > 0 && root.rest < 999
      text: root.rest
      font.family: fontLibian.name
      font.pixelSize: 34
      font.bold: true
      color: "#DBCC69"
      glow.color: "#2E200F"
      glow.spread: 0.6
    }

    GlowText {
      Layout.alignment: Qt.AlignCenter
      visible: root.rest > 0 && root.rest < 999
      text: luatr("rest round num")
      font.family: fontLibian.name
      font.pixelSize: 28
      color: "#F0E5D6"
      glow.color: "#2E200F"
      glow.spread: 0.6
    }
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
          return luatr("Newbie");
        }
        const winRate = (winGame / totalGame) * 100;
        const runRate = (runGame / totalGame) * 100;
        return luatr("Win=%1\nRun=%2\nTotal=%3")
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
    source: SkinBank.PHOTO_DIR +
            (isOwner ? "owner" : (ready ? "ready" : "notready"))
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
      if (areaName.startsWith('#')) return;
      const data = lcall("GetPile", root.playerid, areaName);
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
    visible: (root.dead && !root.rest) || root.dying || root.surrendered
    source: {
      if (root.surrendered) {
        return SkinBank.DEATH_DIR + "surrender";
      } else if (root.dead) {
        return SkinBank.getRoleDeathPic(root.role);
      }
      return SkinBank.DEATH_DIR + "saveme";
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
      text: {
        let n = root.handcards;
        if (root.playerid === Self.id) {
          n = lcall("GetPlayerHandcards", Self.id).length; // 不计入expand_pile
        }
        if (root.maxCard === root.hp || root.hp < 0) {
          return n;
        } else {
          const maxCard = root.maxCard < 900 ? root.maxCard : "∞";
          return n + "/" + maxCard;
        }
      }
      font.family: fontLibian.name
      font.pixelSize: (root.maxCard === root.hp || root.hp < 0 ) ? 32 : 27
      //font.weight: 30
      color: "white"
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 4
      style: Text.Outline
    }

    TapHandler { // 手牌图标点击查看手牌
      enabled: {
        if (root.playerid === Self.id) return false;
        if (root.handcards === 0) return false; // 优先绑定再判buddy，否则不会更新
        if (!lcall("IsMyBuddy", Self.id, root.playerid) &&
          !lcall("HasVisibleCard", Self.id, root.playerid)) return false;
        return true;
      }
      onTapped: {
        const params = { name: "hand_card" };
        let data = lcall("GetPlayerHandcards", root.playerid);
        data = data.filter((e) => lcall("CardVisibility", e));

        params.ids = data;

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
    value: {
      if (root.role === "hidden") return "hidden";
      if (root.role_shown) return root.role;
      lcall("RoleVisibility", root.playerid) ? root.role : "unknown";
    }
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
    width: parent.width

    font.pixelSize: 16
    text: {
      let ret = screenName;
      if (config.blockedUsers?.includes(screenName))
        ret = luatr("<Blocked> ") + ret;
      return ret;
    }
    elide: root.playerid === Self.id ? Text.ElideNone : Text.ElideMiddle
    horizontalAlignment: Qt.AlignHCenter
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
    property var seatChr: [
      "一", "二", "三", "四", "五", "六",
      "七", "八", "九", "十", "十一", "十二",
    ]
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
    property int duration: config.roomTimeout * 1000

    visible: false
    NumberAnimation on value {
      running: progressBar.visible
      from: 100.0
      to: 0.0
      duration: progressBar.duration

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

  RowLayout {
    anchors.centerIn: parent
    spacing: 5

    Repeater {
      model: root.targetTip

      Item {
        // Layout.alignment: Qt.AlignHCenter
        width: modelData.type === "normal" ? 40 : 24

        GlowText {
          anchors.centerIn: parent
          visible: modelData.type === "normal"
          text: Util.processPrompt(modelData.content)
          font.family: fontLi2.name
          color: "#FEFE84"
          font.pixelSize: {
            if (text.length <= 3) return 36;
            else return 28;
          }
          //font.bold: true
          glow.color: "black"
          glow.spread: 0.3
          glow.radius: 5
          lineHeight: 0.85
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WrapAnywhere
          width: font.pixelSize + 4
        }

        Text {
          anchors.centerIn: parent
          visible: modelData.type === "warning"
          font.family: fontLibian.name
          font.pixelSize: 24
          opacity: 0.9
          horizontalAlignment: Text.AlignHCenter
          lineHeight: 24
          lineHeightMode: Text.FixedHeight
          //color: "#EAC28A"
          color: "snow"
          width: 24
          wrapMode: Text.WrapAnywhere
          style: Text.Outline
          //styleColor: "#83231F"
          styleColor: "red"
          text: Util.processPrompt(modelData.content)
        }
      }
    }
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

  Rectangle {
    color: "#CC2E2C27"
    radius: 6
    border.color: "#A6967A"
    border.width: 1
    width: 44
    height: 112
    /* 有点小问题，因为绝大部分都是手机玩家我还是无脑放左
    x: {
      const roomX = mapToItem(roomScene, root.x, root.y).x;
      if (roomX < 48) return 175;
      return -44;
    }
    */
    x: -44
    y: 128
    visible: {
      if (root.playerid === Self.id) return false;
      if (root.handcards === 0) return false; // 优先绑定再判buddy，否则不会更新
      if (!lcall("IsMyBuddy", Self.id, root.playerid) &&
        !lcall("HasVisibleCard", Self.id, root.playerid)) return false;
      return true;
    }

    Text {
      x: 2; y: 2
      width: 42
      text: {
        if (!parent.visible) return "";
        const unused = root.handcards; // 绑定
        const ids = lcall("GetPlayerHandcards", root.playerid);
        const txt = [];
        for (const cid of ids) {
          if (txt.length >= 4) {
            // txt.push("&nbsp;&nbsp;&nbsp;...");
            txt.push("...");
            break;
          }
          if (!lcall("CardVisibility", cid)) continue;
          const data = lcall("GetCardData", cid);
          let a = luatr(data.name);
          /* if (a.length === 1) {
            a = "&nbsp;&nbsp;" + a;
          } else  */
          if (a.length >= 2) {
            a = a.slice(0, 2);
          }
          txt.push(a);
        }

        if (txt.length < 5) {
          const unknownCards = ids.length - txt.length;
          for (let i = 0; i < unknownCards; i++) {
            if (txt.length >= 4) {
              txt.push("...");
              break;
            } else {
              txt.push("?");
            }
          }
        }

        return txt.join("<br>");
      }
      color: "#E4D5A0"
      font.family: fontLibian.name
      font.pixelSize: 18
      textFormat: Text.RichText
      horizontalAlignment: Text.AlignHCenter
    }

    TapHandler {
      onTapped: {
        const params = { name: "hand_card" };
        let data = lcall("GetPlayerHandcards", root.playerid);
        data = data.filter((e) => lcall("CardVisibility", e));

        params.ids = data;

        // Just for using room's right drawer
        roomScene.startCheat("../RoomElement/ViewPile", params);
      }
    }
  }

  onGeneralChanged: {
    if (!roomScene.isStarted) return;
    const text = luatr(general);
    if (text.replace(/<\/?[^>]+(>|$)/g, "").length > 6) {
      generalName.text = "";
      longGeneralName.text = text;
    } else {
      generalName.text = text;
      longGeneralName.text = "";
    }
  }

  onDeputyGeneralChanged: {
    if (!roomScene.isStarted) return;
    const text = luatr(deputyGeneral);
    if (text.replace(/<\/?[^>]+(>|$)/g, "").length > 6) {
      deputyGeneralName.text = "";
      longDeputyGeneralName.text = text;
    } else {
      deputyGeneralName.text = text;
      longDeputyGeneralName.text = "";
    }
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

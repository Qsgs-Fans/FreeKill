// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls

import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Components.Photo

PhotoBase {
  id: root

  required property PhotoModel dataModel
  onDataModelChanged: dataModel.photoItem = root;

  // TODO 这些目前写在PhotoBase，所以先手动绑定，之后大改房间等待页的时候杀之
  playerid: dataModel.playerid
  avatar: dataModel.avatar
  screenName: dataModel.screenName
  general: dataModel.general
  deputyGeneral: dataModel.deputyGeneral
  kingdom: dataModel.kingdom
  seatNumber: dataModel.seatNumber
  dead: dataModel.dead
  surrendered: dataModel.surrendered
  skinSource: dataModel.skin
  deputySkinSource: dataModel.deputySkin

  selectable: dataModel.selectable
  onSelectedChanged: dataModel.selected = selected;

  property alias areasSealed: equipAreaItem
  property alias markArea: markAreaItem
  property alias picMarkArea: picMarkAreaItem

  property alias progressBar: progressBar
  property alias progressTip: progressTip.text

  PixmapAnimation {
    id: animPlaying
    source: SkinBank.pixAnimDir + "playing"
    anchors.centerIn: parent
    loop: true
    scale: 0.825
    visible: root.dataModel.phase !== Ltk.Player.NotActive
    running: visible
  }

  PixmapAnimation {
    id: animSelected
    source: SkinBank.pixAnimDir + "selected"
    anchors.centerIn: parent
    loop: true
    scale: 0.825
    visible: root.dataModel.state === "candidate" && root.selected
    running: visible
  }

  PixmapAnimation {
    id: animSelectable
    source: SkinBank.pixAnimDir + "selectable"
    anchors.centerIn: parent
    loop: true
    visible: root.dataModel.state === "candidate" && root.selectable
    running: visible
    scale: 0.75
  }

  HpBar {
    id: hp
    x: 6
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 27

    dataModel: root.dataModel
  }

  Rectangle {
    anchors.fill: root.photoMask
    radius: 6

    // visible: root.dataModel.drank > 0
    color: "red"
    opacity: {
      const drank = root.dataModel.drank;
      if (drank <= 0) return 0;
      return Math.min(0.4 + Math.log(drank) * 0.12, 1);
    }
    Behavior on opacity { NumberAnimation { duration: 300 } }
  }

  RestIndicator {
    anchors.centerIn: root.photoMask
    anchors.leftMargin: 15

    dataModel: root.dataModel
  }

  Image {
    visible: equipAreaItem.length > 0
    source: SkinBank.photoDir + "equipbg"
    x: 23
    y: 91
    scale: 0.75
    transformOrigin: Item.TopLeft
  }

  Image {
    id: turnedOver
    visible: !root.dataModel.faceup
    source: SkinBank.photoDir + "faceturned" + (Config.heg ? '-heg' : '')
    x: 22; y: 4
    scale: 0.75
    transformOrigin: Item.TopLeft
  }

  EquipArea {
    id: equipAreaItem

    x: 23
    y: 118

    dataModel: root.dataModel
  }

  Item {
    id: specialAreaItem

    x: 23
    y: 104

    InvisibleCardArea {
      id: specialContainer
    }

    function updatePileInfo(areaName) {
      if (areaName.startsWith('#')) return;
      const data = root.dataModel.luaPlayer.getPile(areaName);
      Ltk.setMark(root.dataModel.marks, areaName, data.length, root.dataModel.playerid);
    }

    function add(inputs, areaName) {
      updatePileInfo(areaName);
      specialContainer.add(inputs);
    }

    function remove(outputs, areaName) {
      updatePileInfo(areaName);
      return specialContainer.remove(outputs);
    }

    function updateCardPosition(a) {
      specialContainer.updateCardPosition(a);
    }
  }

  MarkArea {
    id: markAreaItem

    anchors.bottom: equipAreaItem.top
    x: 23

    markModel: root.dataModel.marks

    enabled: root.dataModel.state != "candidate" || !root.selectable
  }

  Image {
    id: chain
    visible: root.dataModel.chained
    source: SkinBank.photoDir + "chain"
    anchors.horizontalCenter: parent.horizontalCenter
    scale: 0.75
    y: 54
  }

  Image {
    // id: saveme
    visible: (root.dead && !root.dataModel.rest) || root.dataModel.dying || root.surrendered
    source: {
      if (root.surrendered) {
        return SkinBank.deathDir + "surrender";
      } else if (root.dead && !root.dataModel.rest) {
        if (root.dataModel.role_shown)
        return SkinBank.getRoleDeathPic(root.dataModel.role);
        else
        return SkinBank.getRoleDeathPic("hidden");
      }
      return SkinBank.deathDir + "saveme";
    }
    anchors.centerIn: root.photoMask
    scale: 0.75
  }

  Image {
    id: netstat
    source: SkinBank.stateDir + root.dataModel.netstate
    x: root.photoMask.x
    y: root.photoMask.y
    scale: 0.9 * 0.75
    transformOrigin: Item.TopLeft
  }

  Image {
    id: handcardNum
    source: SkinBank.photoDir + "handcard"
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -5
    x: -5
    width: 40
    height: 30

    Text {
      text: {
        const n = root.dataModel.handcards.length;
        const max = root.dataModel.maxCard;
        if (max === root.dataModel.hp || root.dataModel.hp < 0) {
          return n;
        } else {
          const maxCard = max < 900 ? max : "∞";
          return n + "/" + maxCard;
        }
      }
      font.family: Config.libianName
      font.pixelSize: text.includes("/") ? 20 : 24
      //font.weight: 30
      color: "white"
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 4
      style: Text.Outline
    }
  }

  RoleComboBox {
    id: role
    value: {
      if (root.dataModel.role === "hidden") return "hidden";
      if (root.dataModel.role_shown) return root.dataModel.role;
      return "unknown";
    }
    anchors.top: parent.top
    anchors.topMargin: -4
    anchors.right: parent.right
    anchors.rightMargin: -4
  }

  LimitSkillArea {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: role.height + 2
    anchors.rightMargin: 22

    skillModel: root.dataModel.limitSkills
  }

  Image {
    visible: root.dataModel.state === "candidate" && !root.selectable && !root.selected
    source: SkinBank.photoDir + "disable"
    x: 23; y: -16
    scale: 0.75
    transformOrigin: Item.TopLeft
  }

  // 还原之前一直缺的单图流emotion 神杀智慧！
  Image {
    id: emotionItem
    anchors.centerIn: parent
    scale: 0.8
    opacity: 0
  }

  GlowText {
    id: seatNum
    visible: !progressBar.visible
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -24
    font.family: Config.li2Name
    font.pixelSize: 24
    text: {
      const seatChr = [
        "一", "二", "三", "四", "五", "六",
        "七", "八", "九", "十", "十一", "十二",
      ]
      return seatChr[root.seatNumber - 1];
    }

    glow.color: "brown"
    glow.spread: 0.2
    glow.radius: 6
    //glow.samples: 12
  }

  SequentialAnimation {
    id: trembleAnimation
    running: false
    PropertyAnimation {
      target: root
      property: "x"
      to: root.x - 15
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

  PropertyAnimation {
    id: permanentEmotionShowAnim
    target: emotionItem
    property: "opacity"
    from: 0.0
    to: 1.0
    duration: 500
  }

  PropertyAnimation {
    id: permanentEmotionHideAnim
    target: emotionItem
    property: "opacity"
    from: 1.0
    to: 0.0
    duration: 500
  }

  SequentialAnimation {
    id: shortEmotionAnim

    PropertyAnimation {
      target: emotionItem
      property: "opacity"
      from: 0.0
      to: 1.0
      duration: 500
    }

    PauseAnimation {
      duration: 1000
    }

    PropertyAnimation {
      target: emotionItem
      property: "opacity"
      from: 1.0
      to: 0.0
      duration: 500
    }
  }

  ProgressBar {
    id: progressBar
    width: parent.width
    height: 4
    anchors.bottom: parent.bottom
    anchors.bottomMargin: -4
    from: 0.0
    to: 100.0
    property int duration: Config.roomTimeout * 1000

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
    source: SkinBank.photoDir + "control/tip"
    visible: progressTip.text != ""
    scale: 0.75
    transformOrigin: Item.TopLeft
    Text {
      id: progressTip
      font.family: Config.libianName
      font.pixelSize: 18
      x: 18
      color: "white"
      text: ""
    }
  }

  TargetTip {
    anchors.centerIn: parent

    dataModel: root.dataModel
  }

  InvisibleCardArea {
    id: handcardAreaItem
    anchors.centerIn: parent
    onLengthChanged: root.dataModel.updateHandcards();
  }

  DelayedTrickArea {
    id: delayedTrickAreaItem
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 8

    dataModel: root.dataModel
  }

  PicMarkArea {
    id: picMarkAreaItem

    anchors.top: parent.bottom
    anchors.right: parent.right
    anchors.topMargin: -4

    markModel: root.dataModel.picMarks
  }

  Rectangle {
    color: "white"
    height: 15
    width: 15
    visible: root.dataModel.distance != -1
    Text {
      text: root.dataModel.distance
      anchors.centerIn: parent
    }
  }

  HandcardViewer {
    anchors.right: parent.left
    anchors.bottom: parent.bottom
    scale: 0.75
    transformOrigin: Item.BottomRight

    dataModel: root.dataModel
  }

  function handleMarkAreaUpdate(data) {
    if (data.visible !== undefined) {
      picMarkAreaItem.visible = data.visible;
      markAreaItem.visible = data.visible;
    }
  }

  function getAreaItem(area) {
    if (area === Ltk.Card.PlayerHand) {
      return handcardAreaItem;
    } else if (area === Ltk.Card.PlayerEquip) {
      return equipAreaItem;
    } else if (area === Ltk.Card.PlayerJudge) {
      return delayedTrickAreaItem;
    } else if (area === Ltk.Card.PlayerSpecial) {
      return specialAreaItem;
    }

    return null;
  }

  function tremble() {
    trembleAnimation.start()
  }

  function setEmotion(path, permanent) {
    emotionItem.source = path;
    if (permanent) {
      permanentEmotionShowAnim.start();
    } else {
      shortEmotionAnim.start();
    }
  }

  function hideEmotion() {
    permanentEmotionHideAnim.start();
  }
}

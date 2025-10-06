// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Components.Common
import Fk.Components.LunarLTK

Item {
  ListModel {
    id: equips
  }

  property int cid: 0
  property string name: ""
  property string suit: ""
  property int number: 0
  property bool sealed: false
  property string subtype

  property string icon: ""
  property alias text: textItem.text

  id: root

  Rectangle {
    anchors.fill: parent
    radius: 2
    visible: sealed
    color: "#CCC"
    opacity: 0.8
  }

  Image {
    id: iconItem
    anchors.verticalCenter: parent.verticalCenter
    x: 3

    source: {
      if (sealed)
        return SkinBank.equipIconDir + "sealed";
      return icon ? SkinBank.getEquipIcon(cid, icon) : "";
    }

    scale: 0.75
  }

  Image {
    id: suitItem
    anchors.right: parent.right
    source: (suit && !sealed) ? SkinBank.cardSuitDir + suit : ""
    width: implicitWidth / implicitHeight * height
    height: 12
  }

  GlowText {
    id: numberItem
    visible: !sealed && number > 0 && number < 14
    text: Util.convertNumber(number)
    color: "white"
    font.family: Config.libianName
    font.pixelSize: 12
    glow.color: "black"
    glow.spread: 0.75
    glow.radius: 2
    //glow.samples: 4
    x: parent.width - 24
    y: 1
  }

  Text {
    id: textItem
    font.family: Config.libianName
    color: sealed ? "black" : "white"
    font.pixelSize: 12
    anchors.left: iconItem.right
    anchors.leftMargin: -8
    verticalAlignment: Text.AlignVCenter
  }

  ParallelAnimation {
    id: showAnime

    NumberAnimation {
      target: root
      property: "x"
      duration: 200
      easing.type: Easing.InOutQuad
      from: 10
      to: 0
    }

    NumberAnimation {
      target: root
      property: "opacity"
      duration: 200
      easing.type: Easing.InOutQuad
      from: 0
      to: 1
    }
  }

  ParallelAnimation {
    id: hideAnime

    NumberAnimation {
      target: root
      property: "x"
      duration: 200
      easing.type: Easing.InOutQuad
      from: 0
      to: 10
    }

    NumberAnimation {
      target: root
      property: "opacity"
      duration: 200
      easing.type: Easing.InOutQuad
      from: 1
      to: 0
    }
  }

  function reset()
  {
    cid = 0;
    name = "";
    suit = "";
    number = 0;
    text = "";
    icon = "";
    if (sealed) {
      text = '  ' + Lua.tr(subtype + "_sealed");
    }
  }

  function setCard(card)
  {
    cid = card.cid;
    name = card.name;
    suit = card.suit;
    number = card.number;
    text = card.text;
    icon = card.icon;
  }

  function addCard(card) {
    let iconName = "";
    let displayText = "";
    if (card.subtype === "defensive_ride") {
      displayText = "+1";
      iconName = "horse";
    } else if (card.subtype === "offensive_ride") {
      displayText = "-1"
      iconName = "horse";
    } else {
      displayText = Lua.tr(card.name);
      iconName = card.name;
    }
    let newModel = {
      name: card.name,
      cid: card.cid,
      suit: card.suit,
      number: card.number,
      text: displayText,
      icon: iconName,
    }
    setCard(newModel);
    equips.append(newModel);
  }

  function removeCard(cid) {
    let find = false;
    for (let i = 0; i < equips.count; i++) {
      if (equips.get(i).cid === cid) {
        equips.remove(i);
        find = true;
        break;
      }
    }
    if (!find) {
      return;
    }
    if (equips.count === 0) {
      reset();
      hide();
    } else {
      const card = equips.get(0);
      setCard(card);
    }
  }

  function show() {
    if (!sealed) {
      showAnime.start();
    }
  }

  function hide() {
    if (!sealed) {
      hideAnime.start();
    }
  }

  onSealedChanged: {
    showAnime.stop();
    hideAnime.stop();
    x = 0;

    opacity = sealed ? 1 : 0;
    text = '  ' + Lua.tr(subtype + "_sealed")
  }
}

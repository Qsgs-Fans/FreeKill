// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Models

Item {
  id: root

  property list<CardModel> equips
  property string subtype
  property bool sealed: false

  readonly property string icon: {
    const model = equips[root.equips.length - 1];
    if (!model) return "";

    if (subtype === "defensive_ride" || subtype === "offensive_ride") {
      return "horse";
    } else {
      return model.name;
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: 2
    visible: root.sealed && root.equips.length === 0
    color: "#CCCCCC"
    opacity: 0.8
  }

  Image {
    id: iconItem
    anchors.verticalCenter: parent.verticalCenter
    x: 3

    source: {
      if (root.sealed && root.equips.length === 0)
        return SkinBank.equipIconDir + "sealed";

      const model = root.equips[root.equips.length - 1];
      return root.icon ? SkinBank.getEquipIcon(model?.cardId ?? -1, root.icon) : "";
    }

    scale: 0.75
  }

  Image {
    id: suitItem
    anchors.right: parent.right
    source: {
      const model = root.equips[root.equips.length - 1];
      if (!model) return "";
      return SkinBank.cardSuitDir + (model.suit === "nosuit" ? model.color : model.suit);
    }
    width: implicitWidth / implicitHeight * height
    height: 12
  }

  GlowText {
    id: numberItem
    visible: root.equips.length > 0
    text: {
      const model = root.equips[root.equips.length - 1];
      if (!model) return "";
      return Ltk.convertNumber(model.number);
    }
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
    color: (root.sealed && root.equips.length === 0) ? "black" : "white"
    font.pixelSize: 12
    anchors.left: iconItem.right
    anchors.leftMargin: -8
    verticalAlignment: Text.AlignVCenter

    text: {
      const model = root.equips[root.equips.length - 1];
      const subtype = root.subtype;
      if (!model) {
        if (root.sealed) {
          if (subtype.endsWith("_ride")) return Lua.tr("_sealed");
          return '  ' + Lua.tr(subtype + "_sealed");
        }
        return "";
      }

      return Ltk.getCardUIName(model.cardId, true);
    }
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

  function addCard(card) {
    equips.push(card);
  }

  function removeCard(cid) {
    const idx = equips.findIndex(model => model.cardId === cid);
    if (idx === -1) return;
    equips.splice(idx, 1);
    if (equips.length === 0) {
      hide();
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
  }
}

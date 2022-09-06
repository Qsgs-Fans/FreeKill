import QtQuick 2.15
import ".."
import "../../../util.js" as Utility
import "../../skin-bank.js" as SkinBank

Item {
  property int cid: 0
  property string name: ""
  property string suit: ""
  property int number: 0

  property string icon: ""
  property alias text: textItem.text

  id: root

  Image {
    id: iconItem
    anchors.verticalCenter: parent.verticalCenter
    x: 3

    source: icon ? SkinBank.EQUIP_ICON_DIR + icon : ""
  }

  Image {
    id: suitItem
    anchors.right: parent.right
    source: suit ? SkinBank.CARD_SUIT_DIR + suit : ""
    width: implicitWidth / implicitHeight * height
    height: 16
  }

  GlowText {
    id: numberItem
    visible: number > 0 && number < 14
    text: Utility.convertNumber(number)
    color: "white"
    font.family: fontLibian.name
    font.pixelSize: 16
    glow.color: "black"
    glow.spread: 0.75
    glow.radius: 2
    glow.samples: 4
    x: parent.width - 24
    y: 1
  }

  Text {
    id: textItem
    font.family: fontLibian.name
    color: "white"
    font.pixelSize: 18
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
  }

  function setCard(card)
  {
    cid = card.cid;
    name = card.name;
    suit = card.suit;
    number = card.number;
    if (card.subtype === "defensive_horse") {
      text = "+1";
      icon = "horse";
    } else if (card.subtype === "offensive_horse") {
      text = "-1"
      icon = "horse";
    } else {
      text = Backend.translate(name);
      icon = name;
    }
  }

  function show()
  {
    showAnime.start();
  }

  function hide()
  {
    hideAnime.start();
  }
}

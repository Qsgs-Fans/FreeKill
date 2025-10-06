import QtQuick

import Fk

BasicCard {
  id: root

  property string suit: "club"
  property int number: 7
  property string color: ""

  property real cardScale: 1

  Image {
    id: suitItem
    visible: parent.known
    source: (parent.suit !== "" && parent.suit !== "nosuit") ?
      SkinBank.searchBuiltinPic("/image/card/suit/", parent.suit) : ""
    x: 3 * root.cardScale
    y: 19 * root.cardScale
    width: 21 * root.cardScale
    height: 17 * root.cardScale
  }

  Image {
    id: numberItem
    visible: parent.known
    source: (parent.suit != "" && parent.number > 0) ?
      SkinBank.searchBuiltinPic(`/image/card/number/${parent.getColor()}/`, parent.number) : ""
    x: 0
    y: 0
    width: 27 * root.cardScale
    height: 28 * root.cardScale
  }

  Image {
    id: colorItem
    visible: parent.known && (parent.suit === "" || parent.suit === "nosuit")
      //  && number <= 0 // <- FIXME: 需要区分“黑色有点数”和“无色有点数”
    source: (visible && parent.color !== "") ? SkinBank.cardSuitDir + "/" + parent.color
                                      : ""
    x: 1 * root.cardScale
    width: sourceSize.width * root.cardScale
    height: sourceSize.height * root.cardScale
  }

  function getColor() {
    if (suit != "")
      return (suit == "heart" || suit == "diamond") ? "red" : "black";
    else return color;
  }
}

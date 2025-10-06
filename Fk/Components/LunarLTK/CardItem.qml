// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.GameCommon as Game

/* Layout of card:
 *      +--------+
 * num -|5       |
 * suit-|s       |
 *      |  img   |
 *      |        |
 *      |footnote|
 *      +--------+
 */

Game.PokerCard {
  id: root
  width: 93 * cardScale
  height: 130 * cardScale

  property string name: "slash"
  property string extension: ""
  property string virt_name: ""
  property int type: 0
  property string subtype: ""

  property string prohibitReason: ""

  property bool multiple_targets: false

  property var mark: ({})
  property bool markVisible: false

  // properties for animation and game system
  property int cid: 0
  property int virt_id: 0

  property bool showDetail: true

  property int holding_event_id: 0

  signal toggleDiscards()
  signal thrown()
  signal entered()
  signal exited()
  signal generalChanged()   // For choose general freely

  onRightClicked: {
    if (!showDetail || !known) return;
    roomScene.startCheat("CardDetail", { card: this });
  }

  cardFrontSource: SkinBank.getCardPicture(cid || name)
  cardBackSource: SkinBank.searchBuiltinPic("/image/card/", "card-back")

  Rectangle {
    id: virt_rect
    visible: known && root.virt_name !== "" && root.virt_name !== root.name
    width: parent.width
    height: 20 * root.cardScale
    y: 40 * root.cardScale
    color: "snow"
    opacity: 0.8
    radius: 4 * root.cardScale
    border.color: "black"
    border.width: 1
  }

  Text {
    visible: virt_rect.visible
    anchors.centerIn: virt_rect
    font.pixelSize: Math.floor(16 * root.cardScale)
    font.family: Config.libianName
    font.letterSpacing: -0.6
    text: Lua.tr(root.virt_name)
  }

  Component {
    id: cardMarkDelegate
    Item {
      visible : markVisible || modelData.k.includes("-public")
      width: root.width / 2 * root.cardScale
      height: 16 * root.cardScale
      Rectangle {
        id: mark_rect
        width: mark_text.width + 12
        height: 16 * root.cardScale
        // color: "#A50330"
        radius: 4 * root.cardScale
        // border.color: "snow"
        // border.width: 1
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.7; color: "#A50330" }
          GradientStop { position: 1.0; color: "transparent" }
        }
      }
      Text {
        id: mark_text
        x: 2
        font.pixelSize: Math.floor(16 * root.cardScale)
        font.family: Config.libianName
        font.letterSpacing: -0.6
        text: {
          let ret = Lua.tr(modelData.k);
          if (!modelData.k.startsWith("@@")) {
            ret += modelData.v.toString();
          }
          return ret;
        }
        color: "white"
        style: Text.Outline
        styleColor: "purple"
      }
    }
  }

  GridLayout {
    width: root.width
    y: 60 * root.cardScale
    columns: 2
    rowSpacing: root.cardScale
    columnSpacing: 0
    visible: known
    Repeater {
      model: mark
      delegate: cardMarkDelegate
    }
  }

  Text {
    id: prohibitText
    visible: !root.selectable && root.known
    anchors.centerIn: parent
    font.family: Config.libianName
    font.pixelSize: Math.floor(18 * root.cardScale)
    opacity: 0.9
    horizontalAlignment: Text.AlignHCenter
    lineHeight: 18 * root.cardScale
    lineHeightMode: Text.FixedHeight
    color: "snow"
    width: 20 * root.cardScale
    wrapMode: Text.WrapAnywhere
    style: Text.Outline
    styleColor: "red"
    text: prohibitReason
  }

  function setData(data) {
    cid = data.cid;
    virt_id = data.virt_id ?? 0;
    name = data.name;
    suit = data.suit;
    number = data.number;
    color = data.color;
    type = data.type ? data.type : 0
    subtype = data.subtype ? data.subtype : "";
    virt_name = data.virt_name ? data.virt_name : "";
    mark = data.mark ?? {};
    if (data.markVisible) {
      markVisible = true;
    }
  }

  function toData() {
    const data = {
      cid: cid,
      virt_id: virt_id,
      name: name,
      suit: suit,
      number: number,
      color: color,
      type: type,
      subtype: subtype,
      virt_name: virt_name,
      mark: mark,
    };
    return data;
  }
}

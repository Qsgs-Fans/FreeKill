// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Fk

/* Layout of card:
 *      +--------+
 * num -|5       |
 * suit-|s       |
 *      |  img   |
 *      |        |
 *      |footnote|
 *      +--------+
 */

Item {
  id: root
  width: 93
  height: 130

  // properties for the view
  property string suit: "club"
  property int number: 7
  property string name: "slash"
  property string extension: ""
  property string virt_name: ""
  property int type: 0
  property string subtype: ""
  property string color: ""  // only use when suit is empty
  property string footnote: ""  // footnote, e.g. "A use card to B"
  property bool footnoteVisible: false
  property bool known: true     // if false it only show a card back
  property bool enabled: true   // if false the card will be grey
  property alias card: cardItem
  property alias glow: glowItem
  property var mark: ({})

  function getColor() {
    if (suit != "")
      return (suit == "heart" || suit == "diamond") ? "red" : "black";
    else return color;
  }

  // properties for animation and game system
  property int cid: 0
  property bool selectable: true
  property bool selected: false
  property bool draggable: false
  property bool autoBack: true
  property bool showDetail: false
  property int origX: 0
  property int origY: 0
  property int initialZ: 0
  property int maxZ: 0
  property real origOpacity: 1
  // property bool isClicked: false
  property bool moveAborted: false
  property alias goBackAnim: goBackAnimation
  property int goBackDuration: 500
  property bool busy: false // whether there is a running emotion on the card

  signal toggleDiscards()
  signal clicked()
  signal rightClicked()
  signal doubleClicked()
  signal thrown()
  signal released()
  signal entered()
  signal exited()
  signal moveFinished()
  signal generalChanged()   // For choose general freely
  signal hoverChanged(bool enter)

  onRightClicked: {
    if (!showDetail) return;
    roomScene.startCheat("CardDetail", { card: this });
  }

  RectangularGlow {
    id: glowItem
    anchors.fill: parent
    glowRadius: 8
    spread: 0
    color: "#88FFFFFF"
    cornerRadius: 8
    visible: false
  }

  Image {
    id: cardItem
    source: known ? SkinBank.getCardPicture(cid || name)
            : (SkinBank.CARD_DIR + "card-back")
    anchors.fill: parent
    fillMode: Image.PreserveAspectCrop
  }

  Image {
    id: suitItem
    visible: known
    source: (suit !== "" && suit !== "nosuit") ? SkinBank.CARD_SUIT_DIR + suit : ""
    x: 3
    y: 19
    width: 21
    height: 17
  }

  Image {
    id: numberItem
    visible: known
    source: (suit != "" && number > 0) ? SkinBank.CARD_DIR
      + "number/" + root.getColor() + "/" + number : ""
    x: 0
    y: 0
    width: 27
    height: 28
  }

  Image {
    id: colorItem
    visible: known && (suit === "" || suit === "nosuit")
    source: (visible && color !== "") ? SkinBank.CARD_SUIT_DIR + "/" + color : ""
    x: 1
  }

  Rectangle {
    id: virt_rect
    visible: root.virt_name !== ""
    width: parent.width
    height: 20
    y: 40
    color: "snow"
    opacity: 0.8
    radius: 4
    border.color: "black"
    border.width: 1
  }

  Text {
    visible: virt_rect.visible
    anchors.centerIn: virt_rect
    font.pixelSize: 16
    font.family: fontLibian.name
    font.letterSpacing: -0.6
    text: Backend.translate(root.virt_name)
  }

  Text {
    id: footnoteItem
    text: footnote
    x: 0
    y: parent.height - height - 10
    width: root.width - x * 2
    color: "#E4D5A0"
    // color: "white"
    visible: footnoteVisible
    style: Text.Outline
    wrapMode: Text.WrapAnywhere
    horizontalAlignment: Text.AlignHCenter
    font.family: fontLibian.name
    font.pixelSize: 14
    // glow.color: "black"
    // glow.spread: 1
    // glow.radius: 1
    //glow.samples: 12
  }

  Component {
    id: cardMarkDelegate
    Item {
      width: root.width / 2
      height: 16
      Rectangle {
        id: mark_rect
        width: mark_text.width + 12
        height: 16
        // color: "#A50330"
        radius: 4
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
        font.pixelSize: 16
        font.family: fontLibian.name
        font.letterSpacing: -0.6
        text: {
          let ret = Backend.translate(modelData.k);
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
    y: 60
    columns: 2
    rowSpacing: 1
    columnSpacing: 0
    Repeater {
      model: mark
      delegate: cardMarkDelegate
    }
  }

  Rectangle {
    visible: !root.selectable
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.5)
    opacity: 0.7
  }

  TapHandler {
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.NoButton
    gesturePolicy: TapHandler.WithinBounds

    onTapped: (p, btn) => {
      if (btn === Qt.LeftButton || btn === Qt.NoButton) {
        selected = selectable ? !selected : false;
        parent.clicked();
      } else if (btn === Qt.RightButton) {
        parent.rightClicked();
      }
    }

    onLongPressed: {
      parent.rightClicked();
    }
  }

  DragHandler {
    enabled: draggable
    grabPermissions: PointHandler.TakeOverForbidden
    xAxis.enabled: true
    yAxis.enabled: true

    onGrabChanged: (transtition, point) => {
      if (transtition !== PointerDevice.UngrabExclusive) return;
      parent.released();
      if (autoBack)
        goBackAnimation.start();
    }
  }

  HoverHandler {
    id: hover
    onHoveredChanged: {
      if (!draggable) return;
      if (hovered) {
        glow.visible = true;

        root.z = root.maxZ ? root.maxZ + 1 : root.z + 1;
      } else {
        glow.visible = false;

        root.z = root.initialZ ? root.initialZ : root.z - 1
      }
    }
  }

  ParallelAnimation {
    id: goBackAnimation

    PropertyAnimation {
      target: root
      property: "x"
      to: origX
      easing.type: Easing.OutQuad
      duration: goBackDuration
    }

    PropertyAnimation {
      target: root
      property: "y"
      to: origY
      easing.type: Easing.OutQuad
      duration: goBackDuration
    }

    SequentialAnimation {
      PropertyAnimation {
        target: root
        property: "opacity"
        to: 1
        easing.type: Easing.OutQuad
        duration: goBackDuration * 0.8
      }

      PropertyAnimation {
        target: root
        property: "opacity"
        to: origOpacity
        easing.type: Easing.OutQuad
        duration: goBackDuration * 0.2
      }
    }

    onStopped: {
      if (!moveAborted)
        root.moveFinished();
    }
  }

  function setData(data)
  {
    cid = data.cid;
    name = data.name;
    suit = data.suit;
    number = data.number;
    color = data.color;
    type = data.type ? data.type : 0
    subtype = data.subtype ? data.subtype : "";
    virt_name = data.virt_name ? data.virt_name : "";
    mark = data.mark ?? {};
  }

  function toData()
  {
    const data = {
      cid: cid,
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

  function goBack(animated)
  {
    if (animated) {
      moveAborted = true;
      goBackAnimation.stop();
      moveAborted = false;
      goBackAnimation.start();
    } else {
      x = origX;
      y = origY;
      opacity = origOpacity;
    }
  }

  function destroyOnStop()
  {
    root.moveFinished.connect(function(){
      root.destroy();
    });
  }
}

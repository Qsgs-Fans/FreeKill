import QtQuick
import Qt5Compat.GraphicalEffects

import Fk
import Fk.Components.Common
import Fk.Components.GameCommon as Game
import Fk.Widgets as W
import Fk.Components.LunarLTK.Photo

// 这个是简化版Photo，用于神鲁肃之类的选人框

Game.BasicItem {
  id: root
  width: 131
  height: 174

  property int playerid: 0
  property string avatar: ""
  property string screenName: ""
  property string general: ""
  property string deputyGeneral: ""
  property string kingdom: "qun"
  property int seatNumber: 1
  property alias skinSource: skin.source
  property alias deputySkinSource: deputySkin.source
  property alias changeSkinTimer: cooldownTimer
  property bool enableChangeSkin: false

  property bool dead: false
  property bool surrendered: false

  property alias photoMask: photoMask

  state: "normal"

  Image {
    id: back
    source: SkinBank.getPhotoBack(root.kingdom)
    scale: 0.75
    anchors.centerIn: parent
  }

  Text {
    id: generalName
    x: 5
    y: 21
    font.family: Config.libianName
    font.pixelSize: 16
    opacity: 0.9
    horizontalAlignment: Text.AlignHCenter
    lineHeight: 14
    lineHeightMode: Text.FixedHeight
    color: "white"
    width: 18
    wrapMode: Text.WrapAnywhere
    text: Lua.tr(root.general)
  }

  Item {
    width: photoMask.width
    height: photoMask.height
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

      onSourceChanged: {
        root.skinSource = root.getConfigSkin(root.general);
      }
    }

    SkinArea {
      id: skin
      width: deputyGeneral ? parent.width / 2 : parent.width
      Behavior on width { NumberAnimation { duration: 100 } }
      height: parent.height
      hasDeputy: !!deputyGeneral
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

      onSourceChanged: {
        root.deputySkinSource = root.getConfigSkin(root.deputyGeneral);
      }
    }

    SkinArea {
      id: deputySkin
      anchors.left: generalImage.right
      width: parent.width / 2
      height: parent.height
      hasDeputy: !!deputyGeneral
    }

    Image {
      id: deputySplit
      source: SkinBank.photoDir + "deputy-split"
      opacity: deputyGeneral ? 1 : 0
      scale: 0.75
      anchors.centerIn: parent
    }

    Text {
      id: deputyGeneralName
      anchors.left: generalImage.right
      anchors.leftMargin: -10
      y: 21
      font.family: Config.libianName
      font.pixelSize: 16
      opacity: 0.9
      horizontalAlignment: Text.AlignHCenter
      lineHeight: 14
      lineHeightMode: Text.FixedHeight
      color: "white"
      width: 18
      wrapMode: Text.WrapAnywhere
      text: Lua.tr(root.deputyGeneral)
      style: Text.Outline
    }
  }

  Rectangle {
    id: photoMask
    x: 31 * 0.75
    y: 5 * 0.75
    width: 103
    height: 166
    radius: 6
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

  Behavior on x {
    NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
  }

  Behavior on y {
    NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
  }

  GlowText {
    id: playerName
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 2
    width: parent.width

    font.pixelSize: 12
    text: {
      let ret = screenName;
      if (Config.blockedUsers?.includes(screenName))
        ret = Lua.tr("<Blocked> ") + ret;
      return ret;
    }
    elide: root.playerid === Self.id ? Text.ElideNone : Text.ElideMiddle
    horizontalAlignment: Qt.AlignHCenter
    glow.radius: 6
  }

  Game.ChatBubble {
    id: chat
    width: parent.width
    z: 9
  }

  Image {
    id: skinIcon
    width: 22
    height: 22
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 10
    anchors.topMargin: 100
    source: "https://images.icon-icons.com/1526/PNG/512/dress_106586.png"
    visible: false

    W.TapHandler {
      onTapped: {
        roomScene.startCheat("SkinsDetail", {
          skins: root.getSkinsByName(root.general),
          deputy_skins: root.getSkinsByName(root.deputyGeneral),
          orig_general: root.general,
          orig_deputy: root.deputyGeneral,
        });
      }
    }

    HoverHandler {
      cursorShape: Qt.PointingHandCursor
    }

    Timer {
      id: cooldownTimer
      interval: 5000
      running: false
    }
  }

  HoverHandler {
    id: hover
    onHoveredChanged: {
      if (hovered && root.enableChangeSkin && !Config.observing && !cooldownTimer.running && (root.getSkinsByName(root.general).length > 0 || root.getSkinsByName(root.deputyGeneral).length > 0)) {
        skinIcon.visible = true;
      } else {
        skinIcon.visible = false;
      }
    }
  }

  function chat(msg) {
    chat.text = msg;
    chat.visible = true;
    chat.show();
  }

  function getSkinsByName(general) {
    let arr = Lua.evaluate(`(function()
      return Fk:getSkinsByGeneral("${general}") or {}
    end)()`);
    return arr
  }

  function getConfigSkin(general) {
    const enabledSkins = Config.enabledSkins ?? {}
    if (enabledSkins[general] !== undefined) {
      return enabledSkins[general]
    }
    return ""
  }
}

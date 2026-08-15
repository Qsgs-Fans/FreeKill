import QtQuick
import Qt5Compat.GraphicalEffects

import Fk
import Fk.Components.Common
import Fk.Components.GameCommon as Game
import Fk.Widgets as W
import LunarLtk
import LunarLtk.Components.Photo

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
  property var skinSource: ({})
  property var deputySkinSource: ({})
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
        root.refreshSkins()
      }
    }

    SkinArea {
      id: skin
      source: root.skinSource.name ? Ltk.getFullSkinPath(root.general, root.skinSource.name) : ""
      width: generalImage.width
      Behavior on width { NumberAnimation { duration: 100 } }
      height: parent.height
      hasDeputy: !!root.deputyGeneral
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
        root.refreshSkins()
      }
    }

    SkinArea {
      id: deputySkin
      source: root.deputySkinSource.name ? Ltk.getFullSkinPath(root.deputyGeneral ?? "", root.deputySkinSource.name) : ""
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
    visible: !Config.hideScreenName
    elide: root.playerid === Cpp.self.id ? Text.ElideNone : Text.ElideMiddle
    horizontalAlignment: Qt.AlignHCenter
    glow.radius: 6
  }

  Game.ChatBubble {
    id: chat
    width: parent.width
    z: 9
  }

  MetroButton {
    id: skinIcon
    width: 40
    height: 22
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 10
    anchors.topMargin: 100
    text: Lua.tr("Change Skin")
    textFont.pixelSize: 12
    visible: false

    onClicked: {
      roomScene.showInfoPopup(Qt.createComponent("LunarLtk.Pages.InfoPopups", "SkinsDetail"), {
        skins: Ltk.getSkinNamesByGeneral(root.general),
        deputy_skins: Ltk.getSkinNamesByGeneral(root.deputyGeneral),
        orig_general: root.general,
        orig_deputy: root.deputyGeneral,
      });
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
      if (hovered && root.enableChangeSkin && (roomScene.dataModel?.dashboardId === root.playerid) && !Config.observing && !cooldownTimer.running && (Ltk.getSkinNamesByGeneral(root.general).length > 0 || Ltk.getSkinNamesByGeneral(root.deputyGeneral).length > 0)) {
        skinIcon.visible = true;
      } else {
        skinIcon.visible = false;
      }
    }
  }

  function refreshSkins() {
    if (root.playerid === roomScene.dataModel?.dashboardId && !Config.observing) {
      let command = "changeskin,";
      const source = root.getConfigSkin(root.general);
      command = command + source + ","
      const deputySource = root.getConfigSkin(root.deputyGeneral);
      command = command + deputySource

      Cpp.notifyServer("PushRequest", command)
    }
  }

  function chat(msg) {
    chat.text = msg;
    chat.visible = true;
    chat.show();

  }
  function getConfigSkin(general) {
    const enabledSkins = Config.enabledSkins ?? {}
    if (enabledSkins[general] !== undefined) {
      return enabledSkins[general]
    }
    return ""
  }
}

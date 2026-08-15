import QtQuick
import Qt5Compat.GraphicalEffects

import Fk
import Fk.Components.GameCommon

BasicItem {
  id: root
  height: 64
  width: 64

  property int playerid: 0
  property string avatar: ""
  property string screenName: ""
  property real radius: 10

  Rectangle {
    width: root.width; height: root.height
    x: Math.round(width/7); y: 3
    rotation: 5
    radius: root.radius - 3
    color: '#889b9a'
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: -3
    radius: root.radius
    color: avatarImg.color
  }

  Rectangle {
    id: avatarImg
    anchors.fill: parent
    radius: root.radius - 3
    color: '#94b3be'

    Image {
      id: img
      anchors.fill: parent
      source: SkinBank.getGeneralExtraPic(root.avatar, "avatar/")
      ?? SkinBank.getGeneralPicture(root.avatar)
      sourceClipRect: !!SkinBank.getGeneralExtraPic(root.avatar, "avatar/") ? undefined : Qt.rect(61, 20, 128, 128)
      clip: true
      visible: false
    }
    OpacityMask {
      anchors.fill: img
      source: img
      maskSource: parent
    }

    Rectangle {
      width: 28
      height: 14
      radius: 1
      x: 1; y: 1
      color: '#dfc324'
      border.width: 1
      border.color: '#c2a216'
      visible: Self.id === root.playerid
      Text {
        text: "自己"
        color: '#fffadf'
        font.bold: true
        font.pixelSize: 11
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        anchors.fill: parent
      }
    }

    Rectangle {
      height: 16
      anchors.verticalCenter: parent.verticalCenter
      width: ((Config.blockedUsers ?? []).includes(root.screenName) && !root.selected) ? parent.width : 0
      color: '#922b2b'
      clip: true
      Text {
        text: "已屏蔽"
        font.bold: true
        font.pixelSize: 11
        font.letterSpacing: 3
        color: '#e8eee5'
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        anchors.fill: parent
      }
      Behavior on width {
        NumberAnimation{ easing.type: Easing.OutCubic; duration: 100 }
      }
    }
  }

  Item {
    width: parent.width
    height: Math.round(0.25 * root.height)
    anchors.bottom: parent.bottom
    clip: true

    Rectangle {
      width: parent.width
      height: parent.height + radius
      y: -radius
      radius: root.radius - 3
      color: "black"
      opacity: 0.5
    }
  }

  Text {
    text: root.screenName
    visible: !Config.hideScreenName
    color: "white"
    width: root.width
    anchors.bottom: parent.bottom
    horizontalAlignment: Text.AlignHCenter
    font.family: Config.libianName
    font.bold: true
  }

  Item {
    id: panel
    Rectangle {
      id: panelRect
      width: 0
      height: 200
      radius: 4
      color: "white"
      border.color: "#acbebc"
      x: -width - 5
      visible: width !== 0

      Flow {
        width: Math.max(parent.width - 6, 0)
        x: (parent.width - width)/2
        y: 5
        // spacing: 3
        WButton {
          id: flowerButton
          width: parent.width/2
          height: 52
          text: Lua.tr("Give Flower")
          title.anchors.topMargin: 20
          bg.radius: 0
          Image {
            anchors.horizontalCenter: parent.title.horizontalCenter
            y: 6
            width: 24; height: 24
            source: SkinBank.pixAnimDir + "/flower/egg3"
          }
          onClicked: {
            if (!enabled) return;
            enabled = false;
            roomScene.givePresent("Flower", root.playerid);
            roomScene.areaHandler.closeItem();
          }
        }

        WButton {
          id: eggButton
          width: parent.width/2
          height: 52
          text: Lua.tr("Give Egg")
          title.anchors.topMargin: 20
          bg.radius: 0
          Image {
            anchors.horizontalCenter: parent.title.horizontalCenter
            y: 6
            width: 18; height: 22
            source: SkinBank.pixAnimDir + "/egg/egg"
          }
          onClicked: {
            if (!enabled) return;
            enabled = false;
            if (Math.random() < 0.03) {
              roomScene.givePresent("GiantEgg", root.playerid);
            } else {
              roomScene.givePresent("Egg", root.playerid);
            }
            roomScene.areaHandler.closeItem();
          }
        }

        WButton {
          id: wineButton
          width: parent.width/2
          height: 52
          text: Lua.tr("Give Wine")
          title.anchors.topMargin: 20
          bg.radius: 0
          Image {
            anchors.horizontalCenter: parent.title.horizontalCenter
            y: 6
            width: 21; height: 21
            source: SkinBank.pixAnimDir + "/wine/shoe"
          }
          onClicked: {
            if (!enabled) return;
            enabled = false;
            roomScene.givePresent("Wine", root.playerid);
            roomScene.areaHandler.closeItem();
          }
        }

        WButton {
          id: shoeButton
          width: parent.width/2
          height: 52
          text: Lua.tr("Give Shoe")
          title.anchors.topMargin: 20
          bg.radius: 0
          Image {
            anchors.horizontalCenter: parent.title.horizontalCenter
            y: 6
            width: 17; height: 23
            source: SkinBank.pixAnimDir + "/shoe/shoe"
          }
          onClicked: {
            if (!enabled) return;
            enabled = false;
            roomScene.givePresent("Shoe", root.playerid);
            roomScene.areaHandler.closeItem();
          }
        }
        WButton {
          width: parent.width
          height: 42
          text: {
            const name = root.screenName;
            const blocked = !Config.blockedUsers.includes(name);
            return blocked ? Lua.tr("Block Chatter") : Lua.tr("Unblock Chatter");
          }
          textFont.pixelSize: 21
          textFont.letterSpacing: 2
          clip: true
          bg.radius: 3
          z: panel.z
          enabled: root.playerid !== Self.id && root.playerid > 0 // 旁观屏蔽不了正在被旁观的人
          onClicked: {
            if (!enabled) return;
            const name = root.screenName;
            const idx = Config.blockedUsers.indexOf(name);
            if (idx === -1) {
              if (name === "") return;
              Config.blockedUsers.push(name);
            } else {
              Config.blockedUsers.splice(idx, 1);
            }
            Config.blockedUsersChanged();
            roomScene.areaHandler.closeItem()
          }
        }
        WButton {
          width: parent.width
          height: 40
          text: Lua.tr("Kick From Room")
          title.color: 'snow'
          textFont.pixelSize: 21
          textFont.letterSpacing: 2
          bg.color: "#a40000"
          bg.radius: 3
          border.color: '#800c0c'
          clip: true
          z: panel.z
          enabled: roomScene.isOwner
          onClicked: {
            if (!enabled) return;
            Cpp.notifyServer("KickPlayer", Math.floor(root.playerid));
            roomScene.sendDanmu(Lua.tr("Player %1 Kicked by %2").arg(root.screenName).arg(Self.screenName));
            roomScene.areaHandler.closeItem()
          }
        }
      }

      Behavior on width {
        NumberAnimation{ easing.type: Easing.OutCubic; duration: 200 }
      }
    }
    function show() {
      root.selected = true;
      flowerButton.enabled = true;
      eggButton.enabled = true;
      wineButton.enabled = Math.random() < 0.3;
      shoeButton.enabled = Math.random() < 0.3;
      panelRect.width = 150;
    }

    function close() {
      root.selected = false;
      panelRect.width = 0
    }
  }

  onClicked: {
    if (enabled) roomScene.areaHandler.show(panel);
  }

  onRightClicked: {
    roomScene.areaHandler.closeItem();
    if (enabled) roomScene.areaHandler.show(panel);
  }

  Behavior on width {
    NumberAnimation{ easing.type: Easing.OutCubic; duration: 150 }
  }
  Behavior on height {
    NumberAnimation{ easing.type: Easing.OutCubic; duration: 150 }
  }
}

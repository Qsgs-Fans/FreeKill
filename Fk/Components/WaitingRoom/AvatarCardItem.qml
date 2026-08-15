import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import Fk
import Fk.Components.GameCommon
import Fk.Components.Common

BasicItem {
  id: root

  width: 170
  height: 115

  property string screenName: ""
  property string avatar: "caocao"
  property string title: ""
  property bool ready: false
  property real winGame: 0
  property real runGame: 0
  property real totalGame: 0
  property real gameTime: 0

  property real winRate: (winGame / (totalGame ? totalGame : 1) * 100).toFixed(1)
  property real escapeRate: (runGame / (totalGame ? totalGame : 1) * 100).toFixed(1)

  property bool isOwner: false
  property int playerid: 0

  readonly property bool hasPlayer: screenName && playerid !== 0

  Rectangle {
    id: backRotateRect
    anchors.fill: parent
    color: '#e8bad8c9'
    radius: 10
    rotation: root.hasPlayer ? 5 : 0
    Behavior on rotation {
      NumberAnimation{ easing.type: Easing.OutCubic; duration: 300 }
    }
  }

  Rectangle {
    id: bg
    anchors.fill: parent
    color: '#efe9e9e6'
    border.width: root.hasPlayer ? 1 : 0
    border.color: '#4e7963'
    radius: 10
    clip: true

    Rectangle {
      width: root.hasPlayer ? parent.width - 2 : 0
      height: 17
      x: 1; y: 9
      color: '#efced5dd'
      Behavior on width {
        NumberAnimation{ easing.type: Easing.OutCubic; duration: 300 }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: '#008165'
      opacity: root.hasPlayer ? 0 : 0.15
      radius: 10
      Behavior on opacity {
        NumberAnimation{ easing.type: Easing.OutCubic; duration: 200 }
      }
    }
  }

  Rectangle {
    anchors.fill: avatarImg
    anchors.margins: avatarImg.visible ? -2 : 0
    color: avatarImg.visible ? '#7c918d' : '#ceddda'
    radius: 6
    // visible: avatarImg.visible
  }

  Rectangle {
    height: 15
    width: parent.width
    color: '#ceddda'
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 15
    visible: !root.hasPlayer
  }

  Rectangle {
    id: avatarImg
    height: 58
    width: 58
    radius: 5
    color: "white"
    visible: root.hasPlayer
    anchors {
      left: parent.left
      top: parent.top
      margins: 10
    }

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
      visible: Self?.id === root.playerid
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
      width: (Config.blockedUsers ?? []).includes(root.screenName) ? parent.width + 2 : 0
      x: -1
      visible: width !== 0
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

  Text {
    id: screenNameText
    text: root.screenName
    // visible: !Config.hideScreenName
    font.pixelSize: 14
    font.family: "Arial"
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignTop
    anchors {
      left: avatarImg.right
      top: avatarImg.top
      right: parent.right
      leftMargin: 10
      rightMargin: 10
    }
  }

  Column {
    anchors {
      top: screenNameText.bottom
      left: avatarImg.right
      right: parent.right
      margins: 10
      topMargin: 5
    }
    height: implicitHeight
    spacing: 4

    Rectangle {
      width: root.ready ? 30 : 40
      height: 16
      anchors.horizontalCenter: parent.horizontalCenter
      radius: 3
      color: root.ready ? '#81aa65' : '#555555'
      visible: root.hasPlayer && !root.isOwner
      Text {
        text: root.ready ? "准备" : "未准备"
        font.bold: true
        anchors.fill: parent
        color: "white"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: 10
      }
      Behavior on width {
        NumberAnimation{ easing.type: Easing.OutCubic; duration: 300 }
      }
    }

    Rectangle {
      width: 30
      height: 16
      anchors.horizontalCenter: parent.horizontalCenter
      radius: 3
      color: '#920707'
      visible: root.isOwner
      Text {
        text: "房主"
        font.bold: true
        anchors.fill: parent
        color: "white"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: 10
      }
    }

    TitleItem {
      id: playerTitle
      anchors.horizontalCenter: parent.horizontalCenter
      visible: root.hasPlayer && root.title
      title: root.title
      style: "orange"
    }
  }

  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 1
    width: parent.width - 10
    height: 40
    clip: true
    color: "transparent"
    visible: root.hasPlayer
    Column {
      width: parent.width

      WChatBubble {
        id: chatBubble
        width: parent.width
        z: 9
      }

      Grid {
        width: 75 * 2 + 4
        anchors.horizontalCenter: parent.horizontalCenter
        columns: 2
        columnSpacing: 4
        rowSpacing: -2

        RowLayout {
          width: 73
          Text {
            text: "胜:"
            font.pixelSize: 12
            font.bold: true
            color: '#585858'
          }
          Text {
            text: root.winRate.toString() + "%"
            font.pixelSize: 12
            font.bold: true
            color: '#212627'
          }
        }

        RowLayout {
          width: 77
          Text {
            text: "局:"
            font.pixelSize: 12
            font.bold: true
            color: '#585858'
          }
          Text {
            text: root.totalGame.toString()
            font.pixelSize: 12
            font.bold: true
            color: '#212627'
          }
        }

        RowLayout {
          width: 73
          Text {
            text: "逃:"
            font.pixelSize: 12
            font.bold: true
            color: '#585858'
          }
          Text {
            text: root.escapeRate.toString() + "%"
            font.pixelSize: 12
            font.bold: true
            color: root.escapeRate > 30 ? "#a40000" : '#212627'
          }
        }


        RowLayout {
          width: 77
          Text {
            text: "时:"
            font.pixelSize: 12
            font.bold: true
            color: '#585858'
          }
          Text {
            text: {
              const gameTime = root.gameTime;
              // if (gameTime > 10000) return "1万+ h"
              // if (gameTime > 1000) return gameTime.toFixed(0).toString() + "h"
              // return (root.gameTime / 3600).toFixed(1).toString() + "h"
              const h = (gameTime / 3600).toFixed(2);
              const m = Math.floor(gameTime / 60);
              if (m < 100) {
                return ("%1 min").arg(m);
              } else {
                return ("%1 h").arg(h);
              }
            }
            font.pixelSize: 12
            font.bold: true
            color: '#212627'
          }
        }

      }
    }
  }

  Rectangle {
    id: panel
    width: 100
    height: 0
    x: 70
    color: '#e9e9e6'
    border.width: root.hasPlayer ? 1 : 0
    border.color: '#4e7963'
    visible: height > 10 && root.hasPlayer
    clip: true

    Flow {
      id: buttonFlow
      width: parent.width

      WButton {
        id: flowerButton
        width: parent.width/2
        height: 50
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
        height: 50
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
        height: 50
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
        height: 50
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
        text: {
          const name = root.screenName;
          const blocked = !Config.blockedUsers.includes(name);
          return blocked ? Lua.tr("Block Chatter") : Lua.tr("Unblock Chatter");
        }
        enabled: root.playerid !== Self?.id && root.playerid > 0
        width: parent.width
        textFont.pixelSize: 18
        height: 35
        bg.radius: 0
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
          roomScene.areaHandler.closeItem();
        }
      }

      WButton {
        text: Lua.tr("Kick From Room")
        visible: {
          if (!roomScene.isOwner) return false;
          if (root.playerid === Self.id) return false;
          if (root.playerid < -1) {
            const { minComp, curComp } = Lua.getCompNum();
            return curComp > minComp;
          }
          return true;
        }
        width: parent.width
        title.color: 'snow'
        textFont.pixelSize: 18
        height: 35
        bg.color: "#a40000"
        bg.radius: 0
        border.color: '#800c0c'
        onClicked: {
          if (!enabled) return;
          Cpp.notifyServer("KickPlayer", Math.floor(root.playerid));
          roomScene.sendDanmu(Lua.tr("Player %1 Kicked by %2").arg(root.screenName).arg(Self.screenName));
          roomScene.areaHandler.closeItem();
        }
      }
    }

    function show() {
      flowerButton.enabled = true;
      eggButton.enabled = true;
      wineButton.enabled = Math.random() < 0.3;
      shoeButton.enabled = Math.random() < 0.3;
      height = buttonFlow.height;
    }

    function close() {
      height = 0;
    }

    Behavior on height {
      NumberAnimation{ easing.type: Easing.OutCubic; duration: 200 }
    }
  }

  onClicked: {
    if (enabled) roomScene.areaHandler.show(panel);
  }

  onRightClicked: {
    roomScene.areaHandler.closeItem();
    if (enabled) roomScene.areaHandler.show(panel);
  }

  function chat(msg) {
    chatBubble.text = msg;
    chatBubble.show();
  }
}

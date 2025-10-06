// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.Common
import Fk.Widgets as W

Item {
  id: root
  width: bg.width
  height: bg.height

  Rectangle {
    x: 84; y: 31.6
    height: 20
    width: childrenRect.width + 48

    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.7; color: "#AA3598E8" }
      GradientStop { position: 1.0; color: "transparent" }
    }
    Text {
      text: {
        Config.totalTime;
        const gamedata = Lua.call("GetPlayerGameData", Self.id);
        const totalTime = gamedata[3];
        const h = (totalTime / 3600).toFixed(2);
        const m = Math.floor(totalTime / 60);
        if (m < 100) {
          return Lua.tr("TotalGameTime: %1 min").arg(m);
        } else {
          return Lua.tr("TotalGameTime: %1 h").arg(h);
        }
      }
      x: 12; y: 1
      font.family: Config.libianName
      font.pixelSize: 16
      color: "white"
      //style: Text.Outline
    }
  }

  Image {
    id: bg
    x: -32
    height: 69
    source: SkinBank.lobbyImgDir + "profile"
    fillMode: Image.PreserveAspectFit
  }

  RowLayout {
    Item { Layout.preferredWidth: 16 }

    Avatar {
      Layout.preferredWidth: 64
      Layout.preferredHeight: 64
      general: Self.avatar
    }

    Item { Layout.preferredWidth: 8 }

    Text {
      Layout.alignment: Qt.AlignTop
      text: Self.screenName
      font.pixelSize: 22
      font.family: Config.libianName
      color: "#F0DFAF"
      style: Text.Outline
    }
  }

  W.TapHandler {
    gesturePolicy: TapHandler.WithinBounds

    onTapped: {
      // TODO 解耦
      lobby_drawer.sourceComponent = Qt.createComponent("Fk.Pages.Lobby", "EditProfile");
      lobby_drawer.open();
    }
  }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Fk
import Fk.Common

Item {
  id: root
  width: bg.width
  height: bg.height

  Image {
    id: bg
    x: -32
    height: 69
    source: SkinBank.LOBBY_IMG_DIR + "profile"
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
      font.family: fontLibian.name
      color: "#F0DFAF"
      style: Text.Outline
    }
  }

  TapHandler {
    gesturePolicy: TapHandler.WithinBounds

    onTapped: {
      lobby_dialog.sourceComponent = Qt.createComponent("EditProfile.qml");
      lobby_drawer.open();
    }
  }
}

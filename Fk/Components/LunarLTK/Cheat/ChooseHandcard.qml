// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.LunarLTK

ColumnLayout {
  id: root
  anchors.fill: parent
  property var extra_data: ({}) // unused
  signal finish()
  property var cards: []

  Text {
    text: Lua.tr("Handcard selector")
    Layout.fillWidth: true
    horizontalAlignment: Text.AlignHCenter
    font.pixelSize: 18
    color: "#E4D5A0"
  }

  GridView {
    id: cardsList
    cellWidth: 93 * 0.9 + 4
    cellHeight: 130 * 0.9 + 4
    Layout.preferredWidth: root.width - root.width % 88
    Layout.fillHeight: true
    Layout.alignment: Qt.AlignHCenter
    clip: true

    model: cards

    delegate: CardItem {
      width: 93 * 0.9
      height: 130 * 0.9
      chosenInBox: modelData.chosen
      onClicked: {
        const clist = roomScene.dashboard.handcardArea.cards;
        for (let cd of clist) {
          if (cd.cid == cid) {
            cd.selected = !cd.selected;
            cd.clicked(cd);
            finish();
          }
        }
      }
      Component.onCompleted: {
        setData(Lua.call("GetCardData", modelData.cid));
      }
    }
  }

  Component.onCompleted: {
    cards = roomScene.dashboard.handcardArea.cards
      .filter(c => c.selectable)
      .map(c => { return { cid: c.cid, chosen: c.selected }; });
  }
}


// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Item {
  id: root
  anchors.fill: parent
  property var extra_data: ({}) // unused
  signal finish()
  property var cards: []

  Text {
    text: Backend.translate("Handcard selector")
    width: parent.width
    anchors.topMargin: 6
    horizontalAlignment: Text.AlignHCenter
    font.pixelSize: 16
  }

  Flickable {
    id: flickableContainer
    ScrollBar.vertical: ScrollBar {}
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 40
    flickableDirection: Flickable.VerticalFlick
    width: parent.width - 20
    height: parent.height - 40
    contentWidth: cardsList.width
    contentHeight: cardsList.height
    clip: true

    GridLayout {
      id: cardsList
      columns: Math.floor(flickableContainer.width / 90)

      Repeater {
        model: cards

        CardItem {
          width: 93 * 0.9
          height: 130 * 0.9
          chosenInBox: modelData.chosen
          onClicked: {
            const clist = roomScene.dashboard.handcardArea.cards;
            for (let cd of clist) {
              if (cd.cid == cid) {
                cd.selected = !cd.selected;
                cd.clicked();
                finish();
              }
            }
          }
          Component.onCompleted: {
            setData(JSON.parse(Backend.callLuaFunction("GetCardData", [modelData.cid])));
          }
        }
      }
    }
  }

  Component.onCompleted: {
    cards = roomScene.dashboard.handcardArea.cards
      .filter(c => c.selectable)
      .map(c => { return { cid: c.cid, chosen: c.selected }; });
  }
}


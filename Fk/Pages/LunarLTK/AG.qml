// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import Fk
import Fk.Components.LunarLTK

GraphicsBox {
  property int spacing: 5
  property string currentPlayerName: ""
  property bool interactive: false

  id: root
  title.text: Lua.tr("Please choose cards")
  width: cards.count * 100 + spacing * (cards.count - 1) + 25
  height: 180

  ListModel {
    id: cards
  }

  Row {
    x: 20
    y: 35
    spacing: root.spacing

    Repeater {
      model: cards

      CardItem {
        cid: model.cid
        name: model.name
        suit: model.suit
        number: model.number
        autoBack: false
        selectable: model.selectable
        footnote: model.footnote
        footnoteVisible: true
        onClicked: {
          if (root.interactive && selectable) {
            root.interactive = false;
            roomScene.state = "notactive";
            ClientInstance.replyToServer("", cid);
          }
        }
      }
    }
  }

  function addIds(ids) {
    ids.forEach((id) => {
      let data = Lua.call("GetCardData", id);
      data.selectable = true;
      data.footnote = "";
      cards.append(data);
    });
  }

  function takeAG(g, cid) {
    for (let i = 0; i < cards.count; i++) {
      const item = cards.get(i);
      if (item.cid !== cid) continue;
      item.footnote = g;
      item.selectable = false;
      break;
    }
  }
}

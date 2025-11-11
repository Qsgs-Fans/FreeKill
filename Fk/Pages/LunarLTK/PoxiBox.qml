// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.Common
import Fk.Components.LunarLTK

GraphicsBox {
  id: root

  title.text: Util.processPrompt(Lua.call("PoxiPrompt", poxi_type, card_data, extra_data))

  // TODO: Adjust the UI design in case there are more than 7 cards
  width: 70 + 700
  height: 64 + Math.min(cardView.contentHeight, 400) + 30

  signal cardSelected(int cid)
  signal cardsSelected(var ids)
  property var selected_ids: []
  property string poxi_type
  property var card_data
  property bool cancelable: true
  property var extra_data
  property var allCardItems: []

  ListModel {
    id: cardModel
  }

  ListView {
    id: cardView
    anchors.fill: parent
    anchors.topMargin: 40
    anchors.leftMargin: 20
    anchors.rightMargin: 20
    anchors.bottomMargin: 30
    spacing: 20
    model: cardModel
    clip: true

    delegate: RowLayout {
      spacing: 15
      // visible: areaCards.count > 0

      Rectangle {
        border.color: "#A6967A"
        radius: 5
        color: "transparent"
        width: 18
        height: 130
        Layout.alignment: Qt.AlignTop

        Text {
          color: "#E4D5A0"
          text: Lua.tr(areaName)
          anchors.fill: parent
          wrapMode: Text.WrapAnywhere
          verticalAlignment: Text.AlignVCenter
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 15
        }
      }

      GridLayout {
        columns: 7
        Repeater {
          model: areaCards

          CardItem {
            cid: model.cid
            name: model.name || ""
            suit: model.suit || ""
            number: model.number || 0
            autoBack: false
            known: {
              const visible_data = extra_data?.visible_data ?? {};
              if (visible_data[cid.toString()] == false) return false;
              return true;
            }
            selectable: chosenInBox ||
              Lua.call("PoxiFilter", root.poxi_type, model.cid, root.selected_ids,
                    root.card_data, root.extra_data);

            onSelectedChanged: {
              if (selected) {
                chosenInBox = true;
                root.selected_ids.push(cid);
              } else {
                chosenInBox = false;
                root.selected_ids.splice(root.selected_ids.indexOf(cid), 1);
              }
              root.selected_idsChanged();
              refreshPrompt();
            }
            Component.onCompleted: {
              root.allCardItems.push(this);
            }
          }
        }
      }
    }
  }

  Row {
    anchors.margins: 8
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 32

    MetroButton {
      width: 120
      height: 35
      text: Lua.tr("OK")
      enabled: Lua.call("PoxiFeasible", root.poxi_type, root.selected_ids,
                     root.card_data, root.extra_data);
      onClicked: {
        shuffleInvisibleOutput();
      }
    }

    MetroButton {
      width: 120
      height: 35
      text: Lua.tr("Cancel")
      visible: root.cancelable
      onClicked: root.cardsSelected([])
    }

    MetroButton {
      text: Lua.tr("Revert Selection")
      onClicked: {
        let old_selected = root.selected_ids.slice();
        for (let i = 0; i < old_selected.length; i++) {
          let cid = old_selected[i];
          let item = findCardItem(cid);
          item.selected = false;
        }
        for (let i = 0; i < cardModel.count; i++) {
          let cards = cardModel.get(i).areaCards;
          for (let j = 0; j < cards.count; j++) {
            let card = cards.get(j);
            if (old_selected.indexOf(card.cid) === -1 && Lua.call("PoxiFilter", root.poxi_type, card.cid, root.selected_ids,
              root.card_data, root.extra_data)) {
              let item = findCardItem(card.cid);
              item.selected = true;
            }
          }
        }
        root.selected_idsChanged();
        refreshPrompt();
      }
    }

  }


  onCardSelected: finished();

  function findAreaModel(name) {
    let ret;
    for (let i = 0; i < cardModel.count; i++) {
      let item = cardModel.get(i);
      if (item.areaName === name) {
        ret = item;
        break;
      }
    }
    if (!ret) {
      ret = {
        areaName: name,
        areaCards: [],
      }
      cardModel.append(ret);
      ret = findAreaModel(name);
    }
    return ret;
  }


  function addCustomCards(name, cards) {
    let area = findAreaModel(name).areaCards;
    if (cards instanceof Array) {
      for (let i = 0; i < cards.length; i++)
        area.append(cards[i]);
    } else {
      area.append(cards);
    }
  }

  function refreshPrompt() {
    root.title.text = Util.processPrompt(Lua.call("PoxiPrompt", poxi_type, card_data, extra_data))
  }

  function findCardItem(cid) {
    for (let i = 0; i < root.allCardItems.length; i++) {
      let item = root.allCardItems[i];
      if (item.cid === cid) {
        return item;
      }
    }
    return null;
  }

  function shuffleInvisibleOutput() {
    let output = root.selected_ids.slice();
    const visible_data = extra_data?.visible_data ?? {};

    for (let h = 0; h < cardModel.count; h++) {
      let cards = cardModel.get(h).areaCards;
      let invisible = [];
      let chosenInvisible = [];
      for (let j = 0; j < cards.count; j++) {
        let cid = cards.get(j).cid;
        if (visible_data[cid.toString()] == false) {
          invisible.push(cid);
          let k = output.indexOf(cid)
          if (k !== -1) {
            chosenInvisible.push(k);
          }
        }
      }
      if (!chosenInvisible.length) continue;
      for (let i = 0; i < chosenInvisible.length; i++) {
        const randomIndex = Math.floor(Math.random() * invisible.length);
        let newCid = invisible.splice(randomIndex, 1)[0];
        output[chosenInvisible[i]] = newCid;
      }

    }
    root.cardsSelected(output);
  }

}

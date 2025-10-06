// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.Common
import Fk.Components.LunarLTK

GraphicsBox {
  id: root
  property string prompt

  title.text: prompt === "" ?
                (root.multiChoose ?
                   Lua.tr("$ChooseCards").arg(root.min).arg(root.max)
                   : Lua.tr("$ChooseCard"))
                : Util.processPrompt(prompt)

  // TODO: Adjust the UI design in case there are more than 7 cards
  width: 70 + 700
  height: 64 + Math.min(cardView.contentHeight, 400) + (multiChoose ? 20 : 0)

  signal cardSelected(int cid)
  signal cardsSelected(var ids)
  property bool multiChoose: false
  property int min: 0
  property int max: 1
  property var selected_ids: []
  property var visible_data: ({})

  ListModel {
    id: cardModel
  }

  ListView {
    id: cardView
    anchors.fill: parent
    anchors.topMargin: 40
    anchors.leftMargin: 20
    anchors.rightMargin: 20
    anchors.bottomMargin: 20
    spacing: 20
    model: cardModel
    clip: true

    delegate: RowLayout {
      spacing: 15
      visible: areaCards.count > 0

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
            virt_name: model.virt_name || ''
            autoBack: false
            known: {
              if (visible_data[cid.toString()] == false) return false;
              return true;
            }
            selectable: true
            onClicked: {
              if (!root.multiChoose) {
                shuffleInvisibleOutput(cid);
              }
            }
            onSelectedChanged: {
              if (selected) {
                chosenInBox = true;
                root.selected_ids.push(cid);
              } else {
                chosenInBox = false;
                root.selected_ids.splice(root.selected_ids.indexOf(cid), 1);
              }
              root.selected_ids = root.selected_ids;
            }
          }
        }
      }
    }
  }

  MetroButton {
    anchors.bottom: parent.bottom
    text: Lua.tr("OK")
    visible: root.multiChoose
    enabled: root.selected_ids.length <= root.max
             && root.selected_ids.length >= root.min
    onClicked: root.cardsSelected(root.selected_ids)
  }

  onCardSelected: finished();

  function findAreaModel(name) {
    let ret;
    for (let i = 0; i < cardModel.count; i++) {
      let item = cardModel.get(i);
      if (item.areaName == name) {
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

  // only for single card output. because multichoose should use poxiBox
  function shuffleInvisibleOutput(cid) {
    const visible_data = extra_data?.visible_data ?? {};
    for (let h = 0; h < cardModel.count; h++) {
      let cards = cardModel.get(h).areaCards;
      let invisible = [];
      for (let j = 0; j < cards.count; j++) {
        let _cid = cards.get(j).cid;
        if (visible_data[_cid.toString()] == false) {
          invisible.push(_cid);
        }
      }
      if (invisible.indexOf(cid) !== -1) {
        const randomIndex = Math.floor(Math.random() * invisible.length);
        let newCid = invisible.splice(randomIndex, 1)[0];
        root.cardSelected(newCid);
        return;
      }
    }
    root.cardSelected(cid);
  }
}

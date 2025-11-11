// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Fk
import Fk.Components.Common
import Fk.Components.LunarLTK

GraphicsBox {
  id: root

  property var selected_ids: []
  property var ok_options: []
  property var cards: []
  property var disable_cards: []
  property string filter_skel: ""
  property string prompt
  property int min
  property int max
  property var cancel_options: []
  property var extra_data

  title.text: prompt !== "" ? Util.processPrompt(prompt) : Lua.tr("$ChooseCard")
  // TODO: Adjust the UI design in case there are more than 7 cards
  width: 40 + Math.min(8.5, Math.max(4, cards.length)) * 100
  height: 260

  Component {
    id: cardDelegate
    CardItem {
      Component.onCompleted: {
        setData(modelData);
      }
      autoBack: false
      showDetail: true
      selectable: !disable_cards.includes(cid)
      onSelectedChanged: {
        // if (ok_options.length == 0) return;

        if (selected) {
          origY = origY - 20;
          root.selected_ids.push(cid);
        } else {
          origY = origY + 20;
          root.selected_ids.splice(root.selected_ids.indexOf(cid), 1);
        }
        origX = x;
        goBack(true);
        root.selected_idsChanged();

        root.updateCardSelectable();
      }
    }
  }

  Rectangle {
    id: cardbox
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.fill: parent
    anchors.topMargin: 40
    anchors.leftMargin: 15
    anchors.rightMargin: 15
    anchors.bottomMargin: 50

    color: "#1D1E19"
    radius: 10

    Flickable {
      id: flickableContainer
      ScrollBar.horizontal: ScrollBar {}

      flickableDirection: Flickable.HorizontalFlick
      anchors.fill: parent
      anchors.topMargin: 0
      anchors.leftMargin: 5
      anchors.rightMargin: 5
      anchors.bottomMargin: 10

      contentWidth: cardsList.width
      contentHeight: cardsList.height
      clip: true

      ColumnLayout {
        id: cardsList
        anchors.top: parent.top
        anchors.topMargin: 25

        Row {
          spacing: 5
          Repeater {
            id: to_select
            model: cards
            delegate: cardDelegate
          }
        }
      }
    }
  }

  Item {
    id: buttonArea
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    height: 40

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      spacing: 8

      Repeater {
        model: ok_options

        MetroButton {
          Layout.fillWidth: true
          text: Util.processPrompt(modelData)
          enabled: {
            const cards = root.selected_ids;
            if (!(cards && cards.length >= root.min && cards.length <= root.max)) return false;
            if (index === 0) return true;
            if (filter_skel != "") {
              const func = `Fk.skill_skels["${filter_skel}"].extra.choiceFilter({${cards}}, "${modelData}", json.decode('${JSON.stringify(extra_data)}'))`;
              // console.log(func);
              return Lua.evaluate(func);
            }
            return true;
          }

          onClicked: {
            const reply = (
              {
                cards: root.selected_ids,
                choice: modelData,
              }
            );
            ClientInstance.replyToServer("", reply);
            close();
            roomScene.state = "notactive";
          }
        }
      }

      Repeater {
        model: cancel_options

        MetroButton {
          Layout.fillWidth: true
          text: Util.processPrompt(modelData)
          enabled: true

          onClicked: {
            const reply = (
              {
                cards: [],
                choice: modelData,
              }
            );
            ClientInstance.replyToServer("", reply);
            close();
            roomScene.state = "notactive";
          }
        }
      }
    }
  }

  function updateCardSelectable() {
    if (selected_ids.length > max) {
      let item;
      for (let i = 0; i < to_select.count; i++) {
        item = to_select.itemAt(i);
        if (item.cid == selected_ids[0]) {
          item.selected = false;
          break;
        }
      }
    }
  }
}

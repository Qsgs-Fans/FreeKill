// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import Fk
import Fk.Components.Common
import Fk.Components.LunarLTK

GraphicsBox {
  property string prompt: ""
  property alias generalList: generalList
  property var generals: []
  property int choiceNum: 1
  property bool convertDisabled: false
  property string rule_type: ""
  property var extra_data
  property bool hegemony: false
  property var choices: []
  property var selectedItem: []
  property bool loaded: false

  ListModel {
    id: generalList
  }

  id: root
  title.text: prompt !== "" ? prompt : Lua.tr("$ChooseGeneral").arg(choiceNum) +
    (Config.enableFreeAssign ? "(" + Lua.tr("Enable free assign") + ")" : "")
  width: generalArea.width + body.anchors.leftMargin + body.anchors.rightMargin
  height: body.implicitHeight + body.anchors.topMargin +
          body.anchors.bottomMargin

  Column {
    id: body
    anchors.fill: parent
    anchors.margins: 40
    anchors.bottomMargin: 20

    Item {
      id: generalArea
      width: (generalList.count > 8 ? Math.ceil(generalList.count / 2)
                                    : Math.max(3, generalList.count)) * 97
      height: generalList.count > 8 ? 290 : 150
      z: 1

      Repeater {
        id: generalMagnetList
        model: generalList.count

        Item {
          width: 93
          height: 130
          x: {
            const count = generalList.count;
            let columns = generalList.count;
            if (columns > 8) {
              columns = Math.ceil(columns / 2);
            }

            let ret = (index % columns) * 98;
            if (count > 8 && index > count / 2 && count % 2 == 1)
              ret += 50;
            return ret;
          }
          y: {
            if (generalList.count <= 8)
              return 0;
            return index < generalList.count / 2 ? 0 : 135;
          }
        }
      }
    }

    Item {
      id: splitLine
      width: parent.width - 80
      height: 6
      anchors.horizontalCenter: parent.horizontalCenter
      clip: true
    }

    Item {
      width: parent.width
      height: 165

      Row {
        id: resultArea
        anchors.centerIn: parent
        spacing: 10

        Repeater {
          id: resultList
          model: choiceNum

          Rectangle {
            color: "#1D1E19"
            radius: 3
            width: 93
            height: 130
          }
        }
      }
    }

    Item {
      id: buttonArea
      width: parent.width
      height: 40

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        spacing: 8

        MetroButton {
          id: convertBtn
          visible: !convertDisabled
          text: Lua.tr("Same General Convert")
          onClicked: {
            roomScene.startCheat("SameConvert", { cards: generalList, choices: choices });
          }
        }

        MetroButton {
          id: fightButton
          text: Lua.tr("OK")
          width: 120
          height: 35
          enabled: false

          onClicked: close();
        }

        MetroButton {
          id: detailBtn
          enabled: choices.length > 0
          text: Lua.tr("Show General Detail")
          onClicked: roomScene.startCheat(
            "GeneralDetail",
            { generals: choices }
          );
        }
      }
    }
  }

  Repeater {
    id: generalCardList
    model: generalList

    GeneralCardItem {
      name: model.name
      selectable: true
      draggable: true

      onClicked: {
        if (!selectable) return;
        let toSelect = true;
        for (let i = 0; i < selectedItem.length; i++) {
          if (selectedItem[i] === this) {
            toSelect = false;
            selectedItem.splice(i, 1);
            break;
          }
        }
        if (toSelect && selectedItem.length < choiceNum)
          selectedItem.push(this);
        updatePosition();
      }

      onRightClicked: {
        if (selectedItem.indexOf(this) === -1 && Config.enableFreeAssign)
          roomScene.startCheat("FreeAssign", { card: this });
      }

      onReleased: {
        arrangeCards();
      }
    }
  }

  function arrangeCards()
  {
    let item, i;

    selectedItem = [];
    for (i = 0; i < generalList.count; i++) {
      item = generalCardList.itemAt(i);
      if (item.y > splitLine.y && item.selectable)
        selectedItem.push(item);
    }

    selectedItem.sort((a, b) => a.x - b.x);

    if (selectedItem.length > choiceNum)
      selectedItem.splice(choiceNum, selectedItem.length - choiceNum);

    updatePosition();
  }

  function updateCompanion(gcard1, gcard2, overwrite) {
    if (Lua.call("IsCompanionWith", gcard1.name, gcard2.name)) {
      gcard1.hasCompanions = true;
    } else if (overwrite) {
      gcard1.hasCompanions = false;
    }
  }

  function updatePosition()
  {
    choices = [];
    let item, magnet, pos, i;
    for (i = 0; i < selectedItem.length && i < resultList.count; i++) {
      item = selectedItem[i];
      choices.push(item.name);
      magnet = resultList.itemAt(i);
      pos = root.mapFromItem(resultArea, magnet.x, magnet.y);
      if (item.origX !== pos.x || item.origY !== item.y) {
        item.origX = pos.x;
        item.origY = pos.y;
        item.goBack(true);
      }
    }
    root.choicesChanged();

    fightButton.enabled = Lua.call("ChooseGeneralFeasible", root.rule_type, root.choices,
                                root.generals, root.extra_data);

    for (i = 0; i < generalCardList.count; i++) {
      item = generalCardList.itemAt(i);
      item.selectable = choices.includes(item.name) ||
              Lua.call("ChooseGeneralFilter", root.rule_type, item.name, root.choices,
                    root.generals, root.extra_data);
      if (hegemony) { // 珠联璧合相关
        item.inPosition = 0;
        if (selectedItem[0]) {
          if (selectedItem[1]) {
            if (selectedItem[0] === item) {
              updateCompanion(item, selectedItem[1], true);
            } else if (selectedItem[1] === item) {
              updateCompanion(item, selectedItem[0], true);
            } else {
              item.hasCompanions = false;
            }
          } else {
            if (selectedItem[0] !== item) {
              updateCompanion(item, selectedItem[0], true);
            } else {
              for (let j = 0; j < generalList.count; j++) {
                updateCompanion(item, generalList.get(j), false);
              }
            }
          }
        } else {
          for (let j = 0; j < generalList.count; j++) {
            updateCompanion(item, generalList.get(j), false);
          }
        }
      }
      if (selectedItem.indexOf(item) != -1)
        continue;

      magnet = generalMagnetList.itemAt(i);
      pos = root.mapFromItem(generalMagnetList.parent, magnet.x, magnet.y);
      if (item.origX !== pos.x || item.origY !== item.y) {
        item.origX = pos.x;
        item.origY = pos.y;
        item.goBack(true);
      }
    }

    if (hegemony) { // 主副将调整阴阳鱼
      if (selectedItem[0]) {
        if (selectedItem[0].mainMaxHp < 0) {
          selectedItem[0].inPosition = 1;
        } else if (selectedItem[0].deputyMaxHp < 0) {
          selectedItem[0].inPosition = -1;
        }
        if (selectedItem[1]) {
          if (selectedItem[1].mainMaxHp < 0) {
            selectedItem[1].inPosition = -1;
          } else if (selectedItem[1].deputyMaxHp < 0) {
            selectedItem[1].inPosition = 1;
          }
        }
      }
    }

    for (let i = 0; i < generalList.count; i++) {
      if (Lua.call("GetSameGenerals", generalList.get(i).name).length > 0) {
        convertBtn.enabled = true;
        return;
      }
    }
    convertBtn.enabled = false;
  }

  function refreshPrompt() {
    prompt = Util.processPrompt(Lua.call("ChooseGeneralPrompt", rule_type, generals, extra_data))
  }
}

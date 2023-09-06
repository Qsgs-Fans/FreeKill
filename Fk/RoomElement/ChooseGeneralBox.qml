// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Pages

GraphicsBox {
  property alias generalList: generalList
  // property var generalList: []
  property int choiceNum: 1
  property var choices: []
  property var selectedItem: []
  property bool loaded: false
  property bool convertDisabled: false
  property bool needSameKingdom: false

  ListModel {
    id: generalList
  }

  id: root
  title.text: Backend.translate("$ChooseGeneral").arg(choiceNum) +
    (config.enableFreeAssign ? "(" + Backend.translate("Enable free assign") + ")" : "")
  width: generalArea.width + body.anchors.leftMargin + body.anchors.rightMargin
  height: body.implicitHeight + body.anchors.topMargin + body.anchors.bottomMargin

  Column {
    id: body
    anchors.fill: parent
    anchors.margins: 40
    anchors.bottomMargin: 20

    Item {
      id: generalArea
      width: (generalList.count > 8 ? Math.ceil(generalList.count / 2) : Math.max(3, generalList.count)) * 97
      height: generalList.count > 8 ? 290 : 150
      z: 1

      Repeater {
        id: generalMagnetList
        model: generalList.count

        Item {
          width: 93
          height: 130
          x: (index % Math.ceil(generalList.count / (generalList.count > 8 ? 2 : 1))) * 98 + (generalList.count > 8 && index > generalList.count / 2 && generalList.count % 2 == 1 ? 50 : 0)
          y: generalList.count <= 8 ? 0 : (index < generalList.count / 2 ? 0 : 135)
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
          text: Backend.translate("Same General Convert")
          onClicked: roomScene.startCheat("SameConvert", { cards: generalList });
        }

        MetroButton {
          id: fightButton
          text: Backend.translate("Fight")
          width: 120
          height: 35
          enabled: false

          onClicked: close();
        }

        MetroButton {
          id: detailBtn
          enabled: choices.length > 0
          text: Backend.translate("Show General Detail")
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
      //enabled: //!(choices[0] && choices[0].kingdom !== this.kingdom)
      selectable: !(selectedItem[0] && selectedItem[0].kingdom !== kingdom)
      draggable: true

      onClicked: {
        if (!selectable) return;
        let toSelect = true;
        for (let i = 0; i < selectedItem.length; i++) {
          if (selectedItem[i] === this) {
            toSelect = false;
            selectedItem.splice(i, 1);
          }
        }
        if (toSelect && selectedItem.length < choiceNum)
          selectedItem.push(this);
        updatePosition();
      }

      onRightClicked: {
        if (selectedItem.indexOf(this) === -1 && config.enableFreeAssign)
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

  /*
    主副将的主势力和副势力至少有一个相同；
    副将不可野 主将可野
   */
  function isHegPair(gcard1, gcard2) {
    if (!gcard1 || gcard1 === gcard2) {
      return true;
    }

    if (gcard2.kingdom == "wild") {
      return false;
    }

    if (gcard1.kingdom == "wild") {
      return true;
    }

    const k1 = gcard1.kingdom;
    const k2 = gcard2.kingdom;
    const sub1 = gcard1.subkingdom;
    const sub2 = gcard2.subkingdom;

    if (k1 == k2) {
      return true;
    }

    if (sub1 && (sub1 == k2 || sub1 == sub2)) {
      return true;
    }

    if (sub2 && sub2 == k1) {
      return true;
    }

    return false;
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

    fightButton.enabled = (choices.length == choiceNum);

    for (i = 0; i < generalCardList.count; i++) {
      item = generalCardList.itemAt(i);
      item.selectable = needSameKingdom ? isHegPair(selectedItem[0], item) : true;
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

    for (let i = 0; i < generalList.count; i++) {
      if (JSON.parse(Backend.callLuaFunction(
        "GetSameGenerals", [generalList.get(i).name])
      ).length > 0) {
        convertBtn.enabled = true;
        return;
      }
    }
    convertBtn.enabled = false;
  }
}

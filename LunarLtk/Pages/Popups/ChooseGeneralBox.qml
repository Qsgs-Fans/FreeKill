// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Components
import LunarLtk.Models.Popups

pragma ComponentBehavior: Bound

GraphicsBox {
  id: root

  required property ChooseGeneralModel dataModel

  property alias generalCardList: generalCardList

  property var draggingCard: null

  onShown: arrangeCards();

  Connections {
    target: root.dataModel
    function onGeneralChanged(idx, newName) {
      const item = generalCardList.itemAt(idx);
      item.dataModel = root.dataModel.generalDict[idx];
      arrangeCards();
    }
  }

  title.text: dataModel.promptText
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
      width: {
        const count = root.dataModel.generals.length;
        return (count > 8 ? Math.ceil(count / 2) : Math.max(3, count)) * 97;
      }
      height: root.dataModel.generals.length > 8 ? 290 : 150
      z: 1

      Repeater {
        id: generalMagnetList
        model: root.dataModel.generals.length

        Item {
          required property int index
          width: 93
          height: 130
          x: {
            const count = root.dataModel.generals.length;
            let columns = count;
            if (columns > 8) {
              columns = Math.ceil(columns / 2);
            }

            let ret = (index % columns) * 98;
            if (count > 8 && index > count / 2 && count % 2 == 1)
              ret += 50;
            return ret;
          }
          y: {
            const count = root.dataModel.generals.length;
            if (count <= 8)
              return 0;
            return index < count / 2 ? 0 : 135;
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
          model: root.dataModel.choiceNum

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
          visible: !root.dataModel.convertDisabled
          enabled: root.dataModel.canConvert
          text: Lua.tr("Same General Convert")
          onClicked: {
            roomScene.showInfoPopup(
              Qt.createComponent("LunarLtk.Pages.InfoPopups", "SameConvert"),
              { dataModel: root.dataModel }
            );
          }
        }

        MetroButton {
          id: fightButton
          text: Lua.tr("OK")
          width: 120
          height: 35
          enabled: root.dataModel.feasible;

          onClicked: root.dataModel.accepted();
        }

        MetroButton {
          id: detailBtn
          enabled: root.dataModel.result?.length > 0
          text: Lua.tr("Show General Detail")
          onClicked: roomScene.showInfoPopup(
            Qt.createComponent("LunarLtk.Pages.InfoPopups", "GeneralDetail"),
            { generals: root.dataModel.result }
          );
        }
      }
    }
  }

  Repeater {
    id: generalCardList
    model: root.dataModel.generals

    GeneralCardItem {
      required property string modelData
      required property int index
      dataModel: root.dataModel.generalDict[index]
      selectable: {
        const result = root.dataModel.resultInt?.map(e => Number(e));
        if (result) {
          return result.includes(index) || root.dataModel.generalFilter(index);
        }
        return false;
      }
      draggable: !root.draggingCard || root.draggingCard === this

      onClicked: {
        if (!selectable) return;
        root.dataModel.selectGeneralCard(index);
        root.arrangeCards();
      }

      onRightClicked: {
        if (Lua.client.getSettings("enableFreeAssign")) {
          roomScene.showInfoPopup(Qt.createComponent("LunarLtk.Pages.InfoPopups", "FreeAssign"),
            { dataModel: root.dataModel, index: index });
        }
      }

      opacity: dragging ? 0.5 : 1
      onDraggingChanged: {
        if (dragging) root.draggingCard = this;
      }
      onXChanged : {
        if (!dragging) return;
        root.arrangeCards();
      }
      onYChanged : {
        if (!dragging) return;
        root.arrangeCards();
      }
      onReleased: {
        root.updateCardDragging(index);
        root.draggingCard = null;
        root.arrangeCards();
      }
    }
  }

  function updateCardDragging(index) {
    const item = generalCardList.itemAt(index);
    if (item.y > splitLine.y && item.selectable) {
      let i, magnet, pos, itemdiff;
      let diff = 17308, idx = -1;
      for (i = 0; i < resultList.count; i++) {
        magnet = resultList.itemAt(i);
        pos = root.mapFromItem(resultArea, magnet.x, magnet.y);
        itemdiff = Math.max(Math.abs(pos.x - item.x), Math.abs(pos.y - item.y));
        if (itemdiff < diff) {
          diff = itemdiff;
          idx = i;
        };
      }
      if (diff < 50) {
        root.dataModel.moveGeneral(index, true, idx);
      } else {
        root.dataModel.moveGeneral(index, false);
      }
    } else {
      root.dataModel.moveGeneral(index, false);
    }
  }

  function arrangeCards() {
    if (!root.dataModel) return;
    let item, magnet, pos, i;
    magnet = resultList.itemAt(i);
    pos = root.mapFromItem(resultArea, magnet.x, magnet.y);

    for (i = 0; i < generalMagnetList.count; i++) {
      item = generalCardList.itemAt(i);
      if (!item) break;
      if (item.dragging) {
        item.z = 999;
        continue;
      }
      const resultIdx = root.dataModel.resultInt.findIndex(e => Number(e) === i);
      if (resultIdx !== -1) {
        magnet = resultList.itemAt(resultIdx);
        pos = root.mapFromItem(resultArea, magnet.x, magnet.y);
      } else {
        magnet = generalMagnetList.itemAt(i);
        pos = root.mapFromItem(generalMagnetList.parent, magnet.x, magnet.y);
      }
      item.origX = pos.x;
      item.origY = pos.y;
      item.goBack(true);
    }

    setHegemonyData();
  }

  function updateCompanion(gcard1, gcard2, overwrite) {
    if (Ltk.isCompanionWith(gcard1.modelData, gcard2.modelData)) {
      gcard1.dataModel.hasCompanion = true;
    } else if (overwrite) {
      gcard1.dataModel.hasCompanion = false;
    }
  }

  function setHegemonyData(){
    if (!root.dataModel || !root.dataModel.hegemony) return;

    let item, i;

    // 国战小标记
    const result = root.dataModel.resultInt ?? [];
    const selectedItem = result.slice(0, 2).map(idx => root.dataModel.generalDict[idx]?.dataModel);

    // 主副将认定
    for (i = 0; i < generalCardList.count; i++) {
      item = generalCardList.itemAt(i);
      item.dataModel.inPosition = 0;
    }
    if (selectedItem[0]) {
      if (selectedItem[0].dataModel.mainMaxHp !== 0) {
        selectedItem[0].dataModel.inPosition = 1;
      } else if (selectedItem[0].dataModel.deputyMaxHp !== 0) {
        selectedItem[0].dataModel.inPosition = -1;
      }
      if (selectedItem[1]) {
        if (selectedItem[1].dataModel.mainMaxHp !== 0) {
          selectedItem[1].dataModel.inPosition = -1;
        } else if (selectedItem[1].dataModel.deputyMaxHp !== 0) {
          selectedItem[1].dataModel.inPosition = 1;
        }
      }
    }

    // 珠联璧合
    for (i = 0; i < generalCardList.count; i++) {
      item = generalCardList.itemAt(i);

      if (selectedItem[0]) { // 有主将
        if (selectedItem[1]) { // 有副将
          if (selectedItem[0] === item) {
            updateCompanion(item, selectedItem[1], true);
          } else if (selectedItem[1] === item) {
            updateCompanion(item, selectedItem[0], true);
          } else {
            item.dataModel.hasCompanion = false;
          }
        } else {
          if (selectedItem[0] !== item) {
            updateCompanion(item, selectedItem[0], true);
          } else {
            for (let j = 0; j < generalCardList.count; j++) {
              updateCompanion(item, generalCardList.itemAt(j), false);
            }
          }
        }
      } else {
        for (let j = 0; j < generalCardList.count; j++) {
          updateCompanion(item, generalCardList.itemAt(j), false);
        }
      }
    }
  }
}

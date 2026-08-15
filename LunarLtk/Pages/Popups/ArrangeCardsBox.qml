// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Components
import LunarLtk.Models.Popups

GraphicsBox {
  id: root

  required property ArrangeCardsModel dataModel

  property var draggingCard: null
  property int draggingToArea: -1
  property int draggingToIndex: -1
  property bool draggingNeedReplace: false
  property int padding: 25

  title.text: dataModel.promptText
  width: body.width + padding * 2
  height: title.height + body.height + padding * 2

  onShown: arrangeCards();

  ColumnLayout {
    id: body
    x: root.padding
    y: parent.height - root.padding - height
    spacing: 10

    Repeater {
      id: areaRepeater
      model: root.dataModel.areaCapacities

      Row {
        id: areaRow
        spacing: 7

        required property int index
        required property int modelData

        PoxiLabel {
          anchors.verticalCenter: parent.verticalCenter
          text: qsTr(Lua.tr(root.dataModel.areaNames[parent.index] ?? ""))
        }

        Repeater {
          id: cardRepeater
          model: (root.dataModel.size === 0) ? parent.modelData : 1

          Rectangle {
            color: root.draggingToArea === areaRow.index ? "#5D5E59" : "#1D1E19"
            width: (root.dataModel.size === 0) ? 93 : root.dataModel.size * 100 - 7
            height: 130
          }
        }

        property alias cardRepeater: cardRepeater
      }
    }

    Row {
      Layout.alignment: Qt.AlignHCenter
      spacing: 32

      MetroButton {
        width: 120
        height: 35
        text: Lua.tr("OK")
        enabled: root.dataModel.feasible
        onClicked: root.dataModel.accepted()
      }

      MetroButton {
        width: 120
        height: 35
        text: Lua.tr("Cancel")
        visible: root.dataModel.cancelable
        onClicked: root.dataModel.rejected()
      }
    }
  }

  Repeater {
    id: cardItem
    model: {
      const ret = [];
      for (const cardIds of root.dataModel.origCards) {
        ret.push(...cardIds);
      }
      return ret;
    }

    CardItem {
      required property int modelData
      dataModel: root.dataModel.cardModels[modelData]

      readonly property int areaIdx: {
        const ret = root.dataModel.result;
        for (let i = 0; i < ret.length; i++) {
          if (ret[i].includes(modelData)) return i;
        }
        return -1;
      }

      draggable: !root.draggingCard || root.draggingCard === this
      opacity: dragging ? 0.5 : 1
      onDraggingChanged: {
        if (dragging) root.draggingCard = this;
      }
      onXChanged : {
        if (!dragging) return;
        root.updateCardDragging(this);
        root.arrangeCards();
      }
      onYChanged : {
        if (!dragging) return;
        root.updateCardDragging(this);
        root.arrangeCards();
      }
      onReleased: {
        root.updateCardReleased(this);
        root.arrangeCards();
      }
      onSelectedChanged : {
        root.updateCardSelected(this);
        root.arrangeCards();
      }
    }
  }

  // ========================

  // 根据卡牌y坐标算出落在哪个Area
  function findTargetArea(card) {
    const result = root.dataModel.result;
    for (let j = 0; j < result.length; j++) {
      const pile = areaRepeater.itemAt(j);
      if (pile.y === 0) pile.y = j * 140;

      const box = pile.cardRepeater.itemAt(0);
      const pos = mapFromItem(pile, box.x, box.y);

      if (Math.abs(pos.y - card.y) < box.height / 2) return j;
    }
    return -1;
  }

  // 知道卡牌以及目标area后，根据x坐标与已有卡牌算出应该插到哪个index
  // 其中第0个area受到freeAssign制约（何意味啊）
  function findTargetIndex(card, areaIdx) {
    const result = root.dataModel.result;
    const pileCards = result[areaIdx];

    for (let i = 0; i < pileCards.length; i++) {
      const c = root.dataModel.cardModels[pileCards[i]].cardItem;
      if (c.dragging) continue;

      if (c.x > card.x) return i;
    }

    return pileCards.length;
  }

  function updateCardDragging(card) {
    const toAreaIdx = findTargetArea(card);
    if (toAreaIdx === -1) return;

    if (!root.dataModel.isMoveAllowed(card, toAreaIdx)) return;

    const toCardsIdx = findTargetIndex(card, toAreaIdx);

    draggingToArea = toAreaIdx;
    draggingToIndex = toCardsIdx;
    draggingNeedReplace = (card.areaIdx !== toAreaIdx &&
      dataModel.result[toAreaIdx].length + 1 > dataModel.areaCapacities[toAreaIdx]);
  }

  function updateCardReleased(card) {
    draggingCard = null;
    draggingToArea = -1;
    draggingToIndex = -1;

    const toAreaIdx = findTargetArea(card);
    if (toAreaIdx === -1) return;

    if (!root.dataModel.isMoveAllowed(card, toAreaIdx)) return;

    const toCardsIdx = findTargetIndex(card, toAreaIdx);

    root.dataModel.moveCard(card.dataModel.cardId, toCardsIdx, card.areaIdx, toAreaIdx);
  }

  function updateCardSelected(card) {
    const result = root.dataModel.result;
    const areaCapacities = root.dataModel.areaCapacities;

    const cardId = card.dataModel.cardId;
    const i = result[0].indexOf(cardId);
    if (i === -1) {
      if (root.dataModel.isMoveAllowed(card, 0)) {
        root.dataModel.moveCard(cardId, result[0].length, card.areaIdx, 0);
      }
    } else {
      for (let j = 1; j < result.length; j++) {
        if (root.dataModel.isMoveAllowed(card, j)) {
          root.dataModel.moveCard(cardId, result[j].length, 0, j);
          break;
        }
      }
    }
  }

  // 将card们都按result记载的那样排列，如果有拖动中的卡，就挤开两边的
  // 正在拖动的卡本身状态不应变化
  function arrangeCards() {
    const result = root.dataModel.result;
    const size = root.dataModel.size;

    for (let areaIdx = 0; areaIdx < result.length; areaIdx++) {
      const pile = areaRepeater.itemAt(areaIdx);
      const box = pile.cardRepeater.itemAt(0);
      if (pile.y === 0) pile.y = areaIdx * 140;

      const ids = result[areaIdx];
      let areaLen = ids.length;
      const spacing = (size > 0 && areaLen > size) ? ((size - 1) * 96 / (areaLen - 1)) : 96;

      let b = 0;
      for (let i = 0; i < ids.length; i++) {
        const card = root.dataModel.cardModels[ids[i]].cardItem;
        // 正在拖动的卡不管他
        if (card.dragging) {
          card.z = 999;
          card.opacity = 0.8;
          // 替换牌时，给原始位置留下空位
          if (draggingNeedReplace) b++;
          continue;
        }

        // 剩下的逻辑取决于被拖动的卡牌。
        // 拖动分为重新排序和替换，若重新排序则将此牌及其后面的右移
        // 若为替换，则显示“已选”
        const pos = mapFromItem(pile, box.x, box.y);
        card.glow.visible = false;
        card.chosenInBox = false;
        card.origX = pos.x + b * spacing;
        card.origY = pos.y;
        if (draggingToArea === areaIdx) {
          if (!draggingNeedReplace) {
            if (draggingToIndex <= i) {
              card.origX += 60;
            }
          } else if (draggingToIndex === i) {
            // card.origY += 20 * (areaIdx > draggingCard.areaIdx ? -1 : 1);
            card.chosenInBox = true;
          }
        }
        card.opacity = 1;
        card.z = i + 1;
        card.initialZ = i + 1;

        // 为什么这个排布卡牌的地方有个这样的逻辑？
        if (root.dataModel.poxiType !== "") {
          card.selectable = Ltk.poxiFilter(root.dataModel.poxiType, card.dataModel.cardId, 
            [draggingCard?.dataModel.cardId], result, root.dataModel.origCards);
        } else if (root.dataModel.pattern !== ".") {
          card.selectable = Ltk.cardFitPattern(card.dataModel.cardId, root.dataModel.pattern);
        } else {
          card.selectable = true;
        }

        card.goBack(true);
        b++;
      }
    }
  }
}

import QtQuick
import Fk
import LunarLtk

QtObject {
  id: root

  property string prompt

  property var cards: []

  property list<var> areaNames: [] // string[] 每个area的名字
  property list<var> origCards: [] // 数组元素为int[] 卡牌id数组
  property list<var> areaCapacities: [] // int[] 每个area的格子数
  property list<var> areaLimits: [] // int[] 每个area最多放多少个 只影响feasible判断

  property bool freeArrange: true
  property bool cancelable: false
  property string poxiType: ""
  property string pattern: "."
  property int size: 0

  property var result: [] // 同origCards 移动后的结果

  readonly property string promptText: {
    const raw = prompt ? Ltk.processPrompt(prompt) : "Please arrange cards";
    return Lua.tr(raw);
  }

  readonly property var cardModels: {
    const dict = {};

    for (const tab of origCards) {
      for (const cardId of tab) {
        dict[cardId] = Ltk.createCardModel(cardId);
      }
    }
    return dict;
  }

  readonly property bool feasible: {
    for (let i = 0; i < result.length; i++) {
      if (result[i].length < areaLimits[i]) {
        return false;
      }
    }
    if (poxiType && result.length > 0) {
      return Ltk.poxiFeasible(poxiType, [], result, origCards);
    }
    return true;
  }

  // 是否允许拖动到area中:
  // * 若为第0个area且card本来就在其中，不可freeAssign时不可
  // * 无法选中者不可
  function isMoveAllowed(card, areaIdx) {
    if (result[areaIdx].includes(card.dataModel.cardId)) {
      if (areaIdx === 0 && !freeArrange) return false;
    // 超过limit时为替换牌，因此可
    // } else if (result[areaIdx].length >= areaCapacities[areaIdx]) {
    //   return false;
    } else if (!card.selectable) {
      return false;
    }
    return true;
  }

  // 将cardId从fromAreaIdx中移动到toAreaIdx，且插入在toIdx的位置
  function moveCard(cardId, toIdx, fromAreaIdx, toAreaIdx) {
    const fromArea = result[fromAreaIdx];
    const toArea = result[toAreaIdx];

    const needReplace = (fromAreaIdx !== toAreaIdx &&
      toArea.length + 1 > areaCapacities[toAreaIdx]);

    const fromIdx = fromArea.indexOf(cardId);
    if (fromIdx === -1) return;
    fromArea.splice(fromIdx, 1);

    if (fromAreaIdx === toAreaIdx && fromIdx < toIdx) toIdx--;
    if (toIdx < 0) {
      toIdx = 0;
    } else if (toIdx > toArea.length) {
      toIdx = toArea.length;
    }
    // toIdx最多是areaCapacities（上限值），然后数组下标需要减1。
    toIdx = Math.min(toIdx, areaCapacities[toAreaIdx] - 1);

    toArea.splice(toIdx, 0, cardId);

    if (needReplace) {
      fromArea.splice(fromIdx, 0, toArea.splice(toIdx + 1, 1)[0]);
    }

    resultChanged();
  }

  signal accepted()
  signal rejected()

  function initializeCards() {
    result = [];
    for (const t of origCards) {
      result.push([...t]);
    }

    resultChanged();
  }

  function initialize() {
    this.initializeCards();
  }
}

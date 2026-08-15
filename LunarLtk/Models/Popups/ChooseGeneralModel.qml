import QtQuick
import Fk
import LunarLtk

QtObject {
  id: root

  property var generals: [] // 初始武将，只有位置是有意义的 string[]
  property int choiceNum: 1
  property bool convertDisabled: false
  property bool cancelable: false
  property string skillName
  property string prompt: ""
  property bool detailed
  property string ruleType: "askForGeneralsChosen"
  property var extraData: ({ n: choiceNum }) // 额外数据，传给Lua的chooseGeneralFilter函数
  property bool hegemony: false

  // 已选择的武将
  property list<int> resultInt: [] // int[]

  property var generalDict: ([]) // 武将名到GeneralModel的映射

  signal generalChanged(int idx, string newname)

  signal accepted()
  signal rejected()

  readonly property list<string> result: resultInt.map(e => generals[e]) // 真正要传过去的结果

  readonly property string promptText: {
    if (prompt !== "") return Ltk.processPrompt(prompt);
    const pre_prompt = Ltk.processPrompt(Ltk.chooseGeneralPrompt(ruleType, generals, extraData));
    if (pre_prompt !== "") return pre_prompt;
    const suffix = Lua.client.getSettings("enableFreeAssign") ? `(${Lua.tr("Enable free assign")})` : "";
    const ret = Lua.tr("$ChooseGeneral").arg(choiceNum) + suffix;
    return ret;
  }

  readonly property bool feasible: choiceNum === resultInt.length && Ltk.chooseGeneralFeasible(ruleType, result, generals, extraData);

  readonly property bool canConvert: {
    for (const name of generals) {
      if (Ltk.getSameGenerals(name).length > 0) return true;
    }
    return false;
  }

  function generalFilter(choice) {
    const len = resultInt.length;
    const luaResult = resultInt.map(e => generals[Number(e)]);
    return choiceNum > len && Ltk.chooseGeneralFilter(ruleType, generals[choice], luaResult,
        generals, extraData);
  }

  function selectGeneralCard(index) {
    if (resultInt.findIndex(e => Number(e) === index) >= 0) {
      moveGeneral(index, false);
    } else if (generalFilter(index)) {
      moveGeneral(index, true, resultInt.length);
    }
  }

  function moveGeneral(generalIndex, toSelect, toIndex) {
    const idx = resultInt.findIndex(e => Number(e) === generalIndex);
    if (idx !== -1) resultInt.splice(idx, 1);
    if (!toSelect) return;

    if (!generalFilter(generalIndex)) return;

    toIndex = Math.min(resultInt.length, toIndex);

    if (idx !== toIndex) {
      const to_pos = toIndex ?? (choiceNum - 1)
      resultInt[to_pos] = generalIndex;
    }
  }

  // 武将牌变更（自选或者同名替换）
  function changeGeneral(idx, newModel) {
    const numberfiedIdx = Number(idx);
    const newName = newModel.name;
    generalDict[numberfiedIdx] = newModel;
    generals[numberfiedIdx] = newName;

    resultInt = resultInt;
    const origIdx = resultInt.findIndex(e => Number(e) === numberfiedIdx);
    if (origIdx >= 0) {
      moveGeneral(numberfiedIdx, false);
      if (generalFilter(numberfiedIdx)) {
        moveGeneral(numberfiedIdx, true, origIdx);
      }
    }
    generalChanged(numberfiedIdx, newName);
  }

  function initGeneralModels() {
    generalDict = [];

    for (const name of generals) {
      const model = Ltk.createGeneralCardModel(name);
      generalDict.push(model);
    }
  }

  function initialize() {
    this.initGeneralModels();
  }
}

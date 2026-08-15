import QtQuick
import Fk
import LunarLtk

// 继承自ChooseGeneralModel

ChooseGeneralModel {
  id: root

  property string lordGeneral: ""
  property string lordDeputy: ""
  property string lordRole: ""
  property string selfRole: ""
  property bool hideRole: false
  property list<string> enabledKingdoms: []

  property string selectedKingdom: ""
  readonly property list<string> generalResult: resultInt.map(e => generals[e])
  readonly property list<string> kingdoms: {
    if (generalResult.length > 0) {
      if (hegemony) {
        const arr = Ltk.getKingdomInHegemony(generalResult[0], generalResult[1] ?? "", enabledKingdoms);
        if (arr.length > 1) {
          return arr
        } else return [];
      }
      return Ltk.getEnableKingdoms(generalResult[0]);
    }
    return []
  }
  readonly property bool newFeasible: choiceNum === resultInt.length && (kingdoms.length == 0 || selectedKingdom !== "")

  result: [generalResult, ["kingdom", selectedKingdom]]

  onResultIntChanged: {
    if (hegemony) refreshHegemonyData();
  }

  function generalFilter(choice) {
    const len = resultInt.length;
    const luaResult = resultInt.map(e => generals[Number(e)]);
    let heg_allowed = false;
    if (luaResult.length > 0) {
      if (Ltk.canMatchInHegemony(luaResult[0], generals[choice], enabledKingdoms)) {
        heg_allowed = true;
      }
    } else heg_allowed = true;
    return choiceNum > len && (!hegemony || heg_allowed);
  }

  function selectGeneralCard(index) {
    if (resultInt.indexOf(index) !== -1) {
      return resultInt.splice(resultInt.indexOf(index), 1)
    } else {
      if (resultInt.length >= choiceNum) {
        resultInt.splice(0, resultInt.length - choiceNum + 1)
      }
      resultInt.push(index)
    }
  }

  function refreshHegemonyData() {
    if (!hegemony) return;
    const selectedModels = resultInt.map(e => generalDict[e])
    for (let i = 0; i < generalDict.length; i++) {
      const model = generalDict[i];
      const idx = resultInt.indexOf(i);

      // 加减血
      if (idx !== -1) {
        if (idx === 0) { // 主将
          if (model.mainMaxHp !== 0) {
            model.inPosition = 1;
          } else if (model.deputyMaxHp !== 0) {
            model.inPosition = -1;
          }
        } else { // 副将
          if (model.mainMaxHp !== 0) {
            model.inPosition = -1;
          } else if (model.deputyMaxHp !== 0) {
            model.inPosition = 1;
          }
        }
      } else {
        model.inPosition = 0;
      }

      // 珠联璧合
      if (resultInt.length === 0) {
        const companions = hasCompanionInGenerals(i);
        model.hasCompanion = companions.length > 0; // 对用函数的只判断一端的，只显示一端（如贾南风）
      } else {
        const selectedGeneral = selectedModels[0].name
        if (idx === 0) {
          const companions = hasCompanionInGenerals(i);
          model.hasCompanion = companions.length > 0;
        } else {
          model.hasCompanion = Ltk.isCompanionWith(model.name, selectedGeneral) ||
            Ltk.isCompanionWith(selectedGeneral, model.name); // 只判断和主将
        }
      }
    }
  }

  function hasCompanionInGenerals(idx) {
    let arr = [];
    const general = generalDict[idx].name;
    for (let i = 0; i < generalDict.length; i++) {
      const model = generalDict[i];
      if (Ltk.isCompanionWith(general, model.name)) {
        arr.push(i); // 现在来看没有用，后面再说
      }
    }
    return arr
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
    if (hegemony) refreshHegemonyData();
  }

  function initGeneralModels() {
    generalDict = [];

    for (const name of generals) {
      const model = Ltk.createGeneralCardModel(name);
      generalDict.push(model);
    }

    refreshHegemonyData()
  }

  function initialize() {

    this.initGeneralModels();

  }

}

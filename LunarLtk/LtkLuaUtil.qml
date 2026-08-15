// SPDX-License-Identifier: GPL-3.0-or-later

pragma Singleton
import QtQuick
import Fk

QtObject {

  // 遵循Lua里面那样，把相关枚举全堆到这里
  enum General {
    Male = 1,
    Female = 2,
    Bigender = 3,
    Agender = 4
  }

  enum Player {
    RoundStart = 1,
    Start = 2,
    Judge = 3,
    Draw = 4,
    Play = 5,
    Discard = 6,
    Finish = 7,
    NotActive = 8,
    PhaseNone = 9
  }

  enum Card {
    Spade = 1,
    Club = 2,
    Heart = 3,
    Diamond = 4,
    NoSuit = 5,

    Black = 1,
    Red = 2,
    NoColor = 3,

    Unknown = 0,
    PlayerHand = 1,
    PlayerEquip = 2,
    PlayerJudge = 3,
    PlayerSpecial = 4,
    Processing = 5,
    DrawPile = 6,
    DiscardPile = 7,
    Void = 8
  }

  readonly property var _L: Lua.createProxy(`require "packages.freekill-core.ltk.client.util"`)
  property var roomScene
  property var roomModel

  function getPlayer(id) {
    return Lua.evaluate(`ClientInstance:getPlayerById(${id})`);
  }

  function getCard(id) {
    return Lua.evaluate(`Fk:getCardById(${id})`);
  }

  function getGeneral(name) {
    return Lua.evaluate(`Fk.generals['${name}']`);
  }

  function getSkill(name) {
    return Lua.evaluate(`Fk.skills['${name}']`);
  }

  function getGeneralData(name) {
    return _L.getGeneralData(name);
  }

  function getGeneralDetail(name) {
    return _L.getGeneralDetail(name);
  }

  function getSameGenerals(name) {
    return _L.getSameGenerals(name);
  }

  function canMatchInHegemony(general, deputy, enabled_kingdoms) {
    return _L.canMatchInHegemony(general, deputy, enabled_kingdoms)
  }

  function isCompanionWith(general, general2) {
    return _L.isCompanionWith(general, general2);
  }

  function getCardData(id, filterCard) {
    return _L.getCardData(id, filterCard);
  }

  function getCardExtensionByName(cardName) {
    return _L.getCardExtensionByName(cardName);
  }

  function getAllGeneralPack() {
    return _L.getAllGeneralPack();
  }

  function getAllProperties() {
    return _L.getAllProperties();
  }

  function getGenerals(pack_name) {
    return _L.getGenerals(pack_name);
  }

  function searchAllGenerals(word) {
    return _L.searchAllGenerals(word);
  }

  function searchGenerals(pack_name, word) {
    return _L.searchGenerals(pack_name, word);
  }

  function filterAllGenerals(filter) {
    return _L.filterAllGenerals(filter);
  }

  function updatePackageEnable(pkg, enabled) {
    return _L.updatePackageEnable(pkg, enabled);
  }

  function getAvailableGeneralsNum() {
    return _L.getAvailableGeneralsNum();
  }

  function getAllCardPack() {
    return _L.getAllCardPack();
  }

  function getCards(pack_name) {
    return _L.getCards(pack_name);
  }

  function getPlayerSkills(id) {
    return _L.getPlayerSkills(id);
  }

  function getCardDescription(id) {
    return _L.getCardDescription(id);
  }

  function getCardName(id, filterCard) {
    return _L.getCardName(id, filterCard);
  }

  function getCardUIName(id, filterCard) {
    return _L.getCardUIName(id, filterCard);
  }

  function getEnableKingdoms(general) {
    return _L.getEnableKingdoms(general)
  }

  function getKingdomInHegemony(general, deputy, enabled_kingdoms) {
    return _L.getKingdomInHegemony(general, deputy, enabled_kingdoms)
  }

  function getSkillData(skill_name) {
    return _L.getSkillData(skill_name);
  }

  function cardFitPattern(card_name, pattern) {
    return _L.cardFitPattern(card_name, pattern);
  }

  function getVirtualEquipData(playerid, cid) {
    return _L.getVirtualEquipData(playerid, cid);
  }

  function getSkinNamesByGeneral(general) {
    return _L.getSkinNamesByGeneral(general);
  }

  function getSkinByName(general, name) {
    return _L.getSkinByName(general, name);
  }

  function findMosts() {
    return _L.findMosts();
  }

  function entitle(data, seat, winner) {
    return _L.entitle(data, seat, winner);
  }

  function getCardProhibitReason(cid) {
    return _L.getCardProhibitReason(cid);
  }

  function getCardTip(cid) {
    return _L.getCardTip(cid);
  }

  function getTargetTip(pid) {
    return _L.getTargetTip(pid);
  }

  function canSortHandcards(pid) {
    return _L.canSortHandcards(pid);
  }

  function chooseGeneralPrompt(rule_name, data, extra_data) {
    return _L.chooseGeneralPrompt(rule_name, data, extra_data);
  }

  function chooseGeneralFilter(rule_name, to_select, selected, data, extra_data) {
    return _L.chooseGeneralFilter(rule_name, to_select, selected, data, extra_data);
  }

  function chooseGeneralFeasible(rule_name, selected, data, extra_data) {
    return _L.chooseGeneralFeasible(rule_name, selected, data, extra_data);
  }

  function poxiPrompt(poxi_type, data, extra_data) {
    return _L.poxiPrompt(poxi_type, data, extra_data);
  }

  function poxiFilter(poxi_type, to_select, selected, data, extra_data) {
    return _L.poxiFilter(poxi_type, to_select, selected, data, extra_data);
  }

  function poxiFeasible(poxi_type, selected, data, extra_data) {
    return _L.poxiFeasible(poxi_type, selected, data, extra_data);
  }

  function getMiniGame(gtype, p, data) {
    return _L.getMiniGame(gtype, p, data);
  }

  function revertSelection() {
    return _L.revertSelection();
  }

  function hasVisibleCard(me, other, special_name) {
    return _L.hasVisibleCard(me, other, special_name);
  }

  function refreshStatusSkills() {
    return _L.refreshStatusSkills();
  }

  // 以下为QML常用函数
  function convertNumber(number) {
    if (number === 1)
    return "A";
    if (number >= 2 && number <= 10)
    return number.toString();
    if (number >= 11 && number <= 13) {
      const strs = ["J", "Q", "K"];
      return strs[number - 11];
    }
    return "";
  }

  function getPlayerStr(playerid) {
    const player = getPlayer(playerid);
    const general = player.general;
    const deputy = player.deputyGeneral;
    const seatNumber = player.seat;

    let ret;
    if (general === "anjiang" && (deputy === "anjiang" || !deputy)) {
      ret = Lua.tr("seat#" + player.seat);
    } else {
      ret = Lua.tr(general);
      if (deputy && deputy !== "") {
        ret = ret + "/" + Lua.tr(deputy);
      }
    }
    const hasSameName = Lua.fn(`function(player)
    local ret = false
    for _, p2 in ipairs(Fk:currentRoom().players) do
    if p2 ~= player and p2.general == player.general and p2.deputyGeneral == player.deputyGeneral then
    ret = true
    break
    end
    end
    return ret
    end`)(player);
    if (hasSameName) {
      ret = ret + ("[") + player.seat + ("]");
    }
    if (playerid == Cpp.self.id) {
      ret = ret + Lua.tr("playerstr_self");
    }
    return ret;
  }

  function processPrompt(prompt) {
    const data = prompt.split(":");
    let raw = Lua.tr(data[0]);
    const src = parseInt(data[1]);
    const dest = parseInt(data[2]);
    if (raw.match("%src"))
    raw = raw.replace(/%src/g, getPlayerStr(src));
    if (raw.match("%dest"))
    raw = raw.replace(/%dest/g, getPlayerStr(dest));

    if (data.length > 3) {
      for (let i = 4; i < data.length; i++) {
        raw = raw.replace(new RegExp("%arg" + (i - 2), "g"), Lua.tr(data[i]));
      }

      raw = raw.replace(new RegExp("%arg", "g"), Lua.tr(data[3]));
    }
    return raw;
  }

  function setMark(marks, mark, rawValue, playerid) {
    const elemIdx = marks.findIndex(e => e.origName === mark);
    const elem = marks[elemIdx];
    if (rawValue === 0) {
      if (elemIdx !== -1) marks.splice(elemIdx, 1);
      return;
    }

    let value = rawValue;
    if (mark.startsWith("@@")) {
      value = "";
    } else if (rawValue instanceof ArrayBuffer) {
      // cbor的情况
      value = Lua.toUIString(rawValue);
    } else if (!(rawValue instanceof Object)) {
      value = rawValue.toString();
    }

    let textValue = "";
    let qmlComponentSpec = {
      uri: "LunarLtk.Pages.InfoPopups",
    };
    let qmlData = { name: mark };

    if (!mark.startsWith("@")) {
      // Lua不会把不可见mark传来的，所以这部分肯定是玩家pile
      const pile = Ltk.getPlayer(playerid).getPile(mark);
      if (pile.length === 0) return;
      const visibleIds = pile.filter(e => Lua.selfPlayer.cardVisible(e));

      textValue = pile.length.toString();
      if (visibleIds.length > 0) {
        qmlComponentSpec.name = "ViewPile";
        qmlData.ids = visibleIds;
        qmlComponentSpec.prop = qmlData;
      }
    } else if (mark.startsWith("@$")) {
      // 游戏牌名列表 但也可能是游戏牌id列表呢
      textValue = value.length.toString();
      qmlComponentSpec.name = "ViewPile";
      if (typeof value[0] === "number") {
        qmlData.ids = value;
      } else {
        qmlData.cardNames = value;
      }
      qmlComponentSpec.prop = qmlData;
    } else if (mark.startsWith("@&")) {
      // 武将牌名列表
      textValue = value.length.toString();
      qmlComponentSpec.name = "ViewGeneralPile";
      qmlData.cardNames = value;
      qmlComponentSpec.prop = qmlData;
    } else if (mark.startsWith("@[")) {
      const close_br = mark.indexOf(']');
      if (close_br !== -1) {
        const mark_type = mark.slice(2, close_br);
        const data = Lua.getQmlMark(mark_type, mark, playerid);
        if (data) {
          qmlComponentSpec = typeof data.qml == "object" ? data.qml : {};
          let propObj;
          if (qmlComponentSpec.prop) {
            propObj = qmlComponentSpec.prop;
          } else if (qmlComponentSpec.model?.prop) {
            propObj = qmlComponentSpec.model.prop;
          }
          if (propObj) {
            propObj.name = mark;
            // 由于对应组件必须提供prop包含的属性，所以先不写owner了
          }
          textValue = data.text;
        }
      }
    } else {
      textValue = value instanceof Array
      ? value.map((markText) => Lua.tr(markText)).join(' ')
      : Lua.tr(value);
    }

    // @!! 追加翻译标记名和描述
    let desc;
    if (mark.startsWith('@!!')) {
      desc = `<b>${Lua.tr(mark)}</b><br>` +
      `${Lua.tr(":" + mark)}${textValue && "<br>" + textValue}`;
    }

    if (!("name" in qmlComponentSpec || "url" in qmlComponentSpec)) {
      qmlComponentSpec = null;
    }

    if (elem) {
      elem.value = textValue;
      elem.origValue = value;
      elem.qml = qmlComponentSpec;
      elem.desc = desc;
    } else {
      marks.push({
        name: Lua.tr(mark),
        value: textValue,
        origName: mark,
        origValue: value,
        qml: qmlComponentSpec,
        desc,
      });
    }
  }

  function createCardModel(cardId, additionalProp) {
    const component = Qt.createComponent("LunarLtk.Models", "CardModel");
    const data = Ltk.getCardData(cardId);
    const { name, extension, number, suit, color, type, subtype } = data;
    const prop = {
      cardId: data.cid,
      marks: [],
      name, extension, number, suit, color, type, subtype,
      picName: data.pic_name,
    };

    for (const {k, v} of data.mark) {
      Ltk.setMark(prop.marks, k, v);
    }

    if (additionalProp instanceof Object) Object.assign(prop, additionalProp);
    return component.createObject(null, prop);
  }

  function createCardModelFromName(cardName, additionalProp) {
    const component = Qt.createComponent("LunarLtk.Models", "CardModel");
    const dataGetter = Lua.fn(`function(name)
    local cd = Fk.all_card_types[name]
    return {
      name = cd.name,
      extension = cd.package.extensionName,
    }
    end`)

    const data = dataGetter(cardName);
    const prop = {
      name: data.name, extension: data.extension,
      number: 0, suit: "",
    }

    if (additionalProp instanceof Object) Object.assign(prop, additionalProp);
    return component.createObject(null, prop);
  }

  function createCardModelFromLuaValue(cardVal, additionalProp) {
    const data = Lua.toQml(cardVal);
    if (additionalProp instanceof Object) Object.assign(data.model.prop, additionalProp);
    return Lua.createQmlObject(data.model);
  }

  function createGeneralCardModel(name, additionalProp) {
    const component = Qt.createComponent("LunarLtk.Models", "GeneralCardModel");
    const data = Ltk.getGeneralData(name);
    const { kingdom, subkingdom, hp, maxHp } = data;
    const prop = {
      name,
      prefix: Lua.tr(data.prefix),
      kingdom,
      subkingdom: subkingdom || "",
      hp, maxHp,
      shieldNum: data.shield,
      mainMaxHp: data.mainMaxHpAdjustedValue,
      deputyMaxHp: data.deputyMaxHpAdjustedValue,
    };
    if (additionalProp instanceof Object) Object.assign(prop, additionalProp);
    return component.createObject(null, prop);
  }

  function createSkillModel(skillName, additionalProp) {
    const component = Qt.createComponent("LunarLtk.Models", "SkillModel");
    const data = Ltk.getSkillData(skillName);
    // 有品 赶紧杀了getSkillData罢
    const prop = {
      name: data.skill,
      origName: data.orig_skill,
      isActive: data.freq === "active"||additionalProp?.isActive == true,
      frequency: data.frequency ?? "",
      extension: data.extension,
      enabled: additionalProp?.enabled === true,
    };
    return component.createObject(null, prop);
  }

  // 获得完整的皮肤地址，如果为远程链接则下载到assets文件夹
  function getFullSkinPath(general, name) {
    let skin = getSkinByName(general, name)
    if (!skin) return SkinBank.getGeneralPicture(general);

    if (skin.path.startsWith("http")) {
      const hash = urlToBase62(skin.path)
      if (Fs.resolveFile(`${Cpp.path}/assets/lunarltk/skins/${hash}/${skin.name}`)) {
        return `${Cpp.path}/assets/lunarltk/skins/${hash}/${skin.name}`
      }
      Fs.downloadFileToAssets(
      skin.path + skin.name,
      `lunarltk/skins/${hash}/${skin.name}`
      )
      return skin.path + skin.name
    }

    return Cpp.path + "/" + skin.path + skin.name
  }

  // 将某一地址的资源根据地址hash值统一存放
  function urlToBase62(url) {
    // 先生成 32 位十六进制哈希（FNV-1a）
    let h = 0x811c9dc5;
    for (let i = 0; i < url.length; i++) {
      h ^= url.charCodeAt(i);
      h = (h * 0x01000193) >>> 0;  // 32 位溢出
    }

    // 再转 base62
    const chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    let result = "";
    let n = h;
    do {
      result = chars[n % 62] + result;
      n = Math.floor(n / 62);
    } while (n > 0);
    return result;
  }
}

// SPDX-License-Identifier: GPL-3.0-or-later

pragma Singleton
import QtQuick
import Fk

QtObject {
  ///////////////// 施工中 //////////////////////
  // 把client_util.lua公式化转了一遍。还没剔除
  ///////////////// 施工中 //////////////////////

  function getGeneralData(name) {
    return Lua.call("GetGeneralData", name);
  }

  function getGeneralDetail(name) {
    return Lua.call("GetGeneralDetail", name);
  }

  function getSameGenerals(name) {
    return Lua.call("GetSameGenerals", name);
  }

  function isCompanionWith(general, general2) {
    return Lua.call("IsCompanionWith", general, general2);
  }

  function getCardData(id, filterCard) {
    return Lua.call("GetCardData", id, filterCard);
  }

  function getCardExtensionByName(cardName) {
    return Lua.call("GetCardExtensionByName", cardName);
  }

  function getAllMods() {
    return Lua.call("GetAllMods");
  }

  function getAllModNames() {
    return Lua.call("GetAllModNames");
  }

  function getAllGeneralPack() {
    return Lua.call("GetAllGeneralPack");
  }

  function getAllProperties() {
    return Lua.call("GetAllProperties");
  }

  function getGenerals(pack_name) {
    return Lua.call("GetGenerals", pack_name);
  }

  function searchAllGenerals(word) {
    return Lua.call("SearchAllGenerals", word);
  }

  function searchGenerals(pack_name, word) {
    return Lua.call("SearchGenerals", pack_name, word);
  }

  function filterAllGenerals(filter) {
    return Lua.call("FilterAllGenerals", filter);
  }

  function updatePackageEnable(pkg, enabled) {
    return Lua.call("UpdatePackageEnable", pkg, enabled);
  }

  function getAvailableGeneralsNum() {
    return Lua.call("GetAvailableGeneralsNum");
  }

  function getAllCardPack() {
    return Lua.call("GetAllCardPack");
  }

  function getCards(pack_name) {
    return Lua.call("GetCards", pack_name);
  }

  function getCardSkill(cid) {
    return Lua.call("GetCardSkill", cid);
  }

  function getCardSpecialSkills(cid) {
    return Lua.call("GetCardSpecialSkills", cid);
  }

  function distanceTo(from, to) {
    return Lua.call("DistanceTo", from, to);
  }

  function getPile(id, name) {
    return Lua.call("GetPile", id, name);
  }

  function getAllPiles(id) {
    return Lua.call("GetAllPiles", id);
  }

  function getMySkills() {
    return Lua.call("GetMySkills");
  }

  function getPlayerSkills(id) {
    return Lua.call("GetPlayerSkills", id);
  }

  function getSkillData(skill_name) {
    return Lua.call("GetSkillData", skill_name);
  }

  function getSkillStatus(skill_name) {
    return Lua.call("GetSkillStatus", skill_name);
  }

  function cardFitPattern(card_name, pattern) {
    return Lua.call("CardFitPattern", card_name, pattern);
  }

  function getVirtualEquipData(playerid, cid) {
    return Lua.call("GetVirtualEquipData", playerid, cid);
  }

  function getGameModes() {
    return Lua.call("GetGameModes");
  }

  function getPlayerHandcards(pid) {
    return Lua.call("GetPlayerHandcards", pid);
  }

  function getPlayerEquips(pid) {
    return Lua.call("GetPlayerEquips", pid);
  }

  function getPlayerJudges(pid) {
    return Lua.call("GetPlayerJudges", pid);
  }

  function resetClientLua() {
    return Lua.call("ResetClientLua");
  }

  function getRoomConfig() {
    return Lua.call("GetRoomConfig");
  }

  function getCompNum() {
    return Lua.call("GetCompNum");
  }

  function getPlayerGameData(pid) {
    return Lua.call("GetPlayerGameData", pid);
  }

  function setPlayerGameData(pid, data) {
    return Lua.call("SetPlayerGameData", pid, data);
  }

  function filterMyHandcards() {
    return Lua.call("FilterMyHandcards");
  }

  function setObserving(o) {
    return Lua.call("SetObserving", o);
  }

  function setReplaying(o) {
    return Lua.call("SetReplaying", o);
  }

  function setReplayingShowCards(o) {
    return Lua.call("SetReplayingShowCards", o);
  }

  function checkSurrenderAvailable() {
    return Lua.call("CheckSurrenderAvailable");
  }

  function findMosts() {
    return Lua.call("FindMosts");
  }

  function entitle(data, seat, winner) {
    return Lua.call("Entitle", data, seat, winner);
  }

  function saveRecord() {
    return Lua.call("SaveRecord");
  }

  function getCardProhibitReason(cid) {
    return Lua.call("GetCardProhibitReason", cid);
  }

  function getTargetTip(pid) {
    return Lua.call("GetTargetTip", pid);
  }

  function canSortHandcards(pid) {
    return Lua.call("CanSortHandcards", pid);
  }

  function chooseGeneralPrompt(rule_name, data, extra_data) {
    return Lua.call("ChooseGeneralPrompt", rule_name, data, extra_data);
  }

  function chooseGeneralFilter(rule_name, to_select, selected, data, extra_data) {
    return Lua.call("ChooseGeneralFilter", rule_name, to_select, selected, data, extra_data);
  }

  function chooseGeneralFeasible(rule_name, selected, data, extra_data) {
    return Lua.call("ChooseGeneralFeasible", rule_name, selected, data, extra_data);
  }

  function poxiPrompt(poxi_type, data, extra_data) {
    return Lua.call("PoxiPrompt", poxi_type, data, extra_data);
  }

  function poxiFilter(poxi_type, to_select, selected, data, extra_data) {
    return Lua.call("PoxiFilter", poxi_type, to_select, selected, data, extra_data);
  }

  function poxiFeasible(poxi_type, selected, data, extra_data) {
    return Lua.call("PoxiFeasible", poxi_type, selected, data, extra_data);
  }

  function getQmlMark(mtype, name, p) {
    return Lua.call("GetQmlMark", mtype, name, p);
  }

  function getMiniGame(gtype, p, data) {
    return Lua.call("GetMiniGame", gtype, p, data);
  }

  function reloadPackage(path) {
    return Lua.call("ReloadPackage", path);
  }

  function getPendingSkill() {
    return Lua.call("GetPendingSkill");
  }

  function revertSelection() {
    return Lua.call("RevertSelection");
  }

  function updateRequestUI(elemType, id, action, data) {
    return Lua.call("UpdateRequestUI", elemType, id, action, data);
  }

  function finishRequestUI() {
    return Lua.call("FinishRequestUI");
  }

  function cardVisibility(cardId) {
    return Lua.call("CardVisibility", cardId);
  }

  function roleVisibility(targetId) {
    return Lua.call("RoleVisibility", targetId);
  }

  function isMyBuddy(me, other) {
    return Lua.call("IsMyBuddy", me, other);
  }

  function hasVisibleCard(me, other, special_name) {
    return Lua.call("HasVisibleCard", me, other, special_name);
  }

  function refreshStatusSkills() {
    return Lua.call("RefreshStatusSkills");
  }

  function getPlayersAndObservers() {
    return Lua.call("GetPlayersAndObservers");
  }

  function toUIString(v) {
    return Lua.call("ToUIString", v);
  }
}

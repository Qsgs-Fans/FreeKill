//var AppPath = "file:///home/notify/develop/FreeKill";
var PHOTO_BACK_DIR = AppPath + "/image/photo/back/";
var PHOTO_DIR = AppPath + "/image/photo/";
var GENERAL_DIR = AppPath + "/image/generals/";
var GENERALCARD_DIR = AppPath + "/image/card/general/";
var STATE_DIR = AppPath + "/image/photo/state/";
var STATUS_DIR = AppPath + "/image/photo/status/";
var ROLE_DIR = AppPath + "/image/photo/role/";
var DEATH_DIR = AppPath + "/image/photo/death/";
var MAGATAMA_DIR = AppPath + "/image/photo/magatama/";
var LIMIT_SKILL_DIR = AppPath + "/image/photo/skill/";
var CARD_DIR = AppPath + "/image/card/";
var CARD_SUIT_DIR = AppPath + "/image/card/suit/";
var DELAYED_TRICK_DIR = AppPath + "/image/card/delayedTrick/";
var EQUIP_ICON_DIR = AppPath + "/image/card/equipIcon/";
var PIXANIM_DIR = AppPath + "/image/anim/"
var TILE_ICON_DIR = AppPath + "/image/button/tileicon/"
var LOBBY_IMG_DIR = AppPath + "/image/lobby/";

function getGeneralPicture(name) {
  let data = JSON.parse(Backend.callLuaFunction("GetGeneralData", [name]));
  let extension = data.extension;
  let path = AppPath + "/packages/" + extension + "/image/generals/" + name + ".jpg";
  if (Backend.exists(path)) {
    return path;
  }
  return GENERAL_DIR + "0.jpg";
}

function getCardPicture(cid) {
  let data = JSON.parse(Backend.callLuaFunction("GetCardData", [cid]));
  let extension = data.extension;
  let name = data.name;
  let path = AppPath + "/packages/" + extension + "/image/card/" + name + ".png";
  if (Backend.exists(path)) {
    return path;
  } else {
    for (let dir of Backend.ls(AppPath + "/packages/")) {
      path = AppPath + "/packages/" + dir + "/image/card/" + name + ".png";
      if (Backend.exists(path)) return path;
    }
  }
  return CARD_DIR + "unknown.png";
}

function getEquipIcon(cid, icon) {
  let data = JSON.parse(Backend.callLuaFunction("GetCardData", [cid]));
  let extension = data.extension;
  let name = icon || data.name;
  let path = AppPath + "/packages/" + extension + "/image/card/equipIcon/" + name + ".png";
  if (Backend.exists(path)) {
    return path;
  } else {
    for (let dir of Backend.ls(AppPath + "/packages/")) {
      path = AppPath + "/packages/" + dir + "/image/card/equipIcon/" + name + ".png";
      if (Backend.exists(path)) return path;
    }
  }
  return EQUIP_ICON_DIR + "unknown.png";
}

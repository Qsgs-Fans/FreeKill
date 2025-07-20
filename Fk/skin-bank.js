// SPDX-License-Identifier: GPL-3.0-or-later

// TODO 这排var都得不能让外部直接调用了 改成基于函数调用
// SkinBank.getSystemPic(PHOTO_DIR, path)之类的
// 这样美化包就可以把path拐到resource_pak/xxx/packages/freekill-core/...下面
// 由于要全改SkinBank.XXX 留给后来人
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
var MISC_DIR = AppPath + "/image/misc/";

const searchPkgResource = function (path, name, suffix) {
  suffix = suffix ?? ".png";
  const dirs = Backend.ls(AppPath + "/packages/").filter(dir =>
    !Pacman.getDisabledPacks().includes(dir) &&
    !dir.endsWith(".disabled")
  );
  if (typeof config !== "undefined" && config.enabledResourcePacks) {
    for (const packName of config.enabledResourcePacks) {
      for (const dir of dirs) {
        const resPath = AppPath + "/resource_pak/" + packName + "/packages/" + dir + path + name + suffix;
        if (Backend.exists(resPath)) return resPath;
      }
    }
  }

  let ret;
  for (const dir of dirs) {
    ret = AppPath + "/packages/" + dir + path + name + suffix;
    if (Backend.exists(ret)) return ret;
  }
}

const searchPkgResourceWithExtension = function (extension, path, name, suffix) {
  suffix = suffix ?? ".png";
  if (typeof config !== "undefined" && config.enabledResourcePacks) {
    for (const packName of config.enabledResourcePacks) {
      const resPath = AppPath + "/resource_pak/" + packName + "/packages/" + extension + path + name + suffix;
      if (Backend.exists(resPath)) return resPath;
    }
  }

  const ret = AppPath + "/packages/" + extension + path + name + suffix;
  if (Backend.exists(ret)) return ret;
}

// 尝试在资源包中查找武将技能语音
const searchAudioResourceWithExtension = function (extension, path, name, suffix = ".mp3") {
  if (typeof config !== "undefined" && config.enabledResourcePacks) {
    for (const packName of config.enabledResourcePacks) {
      const resPath = `${AppPath}/resource_pak/${packName}/packages/${extension}${path}${name}${suffix}`;
      if (Backend.exists(resPath)) {
        return `./resource_pak/${packName}/packages/${extension}${path}${name}`;
      }
    }
  }

  const retPath = `${AppPath}/packages/${extension}${path}${name}${suffix}`;
  if (Backend.exists(retPath)) {
    return `./packages/${extension}${path}${name}`;
  }
}

// 尝试在资源包中根据路径查找音效
const searchAudioResourceByPath = function (path) {
  if (typeof config !== "undefined" && config.enabledResourcePacks) {
    for (const packName of config.enabledResourcePacks) {
      const resPath = `${AppPath}/resource_pak/${packName}${path}`;
      if (Backend.exists(resPath)) {
        return `./resource_pak/${packName}${path}`;
      }
    }
  }

  const retPath = `${AppPath}/${path}`;
  if (Backend.exists(retPath)) {
    return path;
  }
}

function searchBuiltinPic(path, name, suffix) {
  suffix = suffix ?? ".png";
  if (typeof config !== "undefined" && config.enabledResourcePacks) {
    for (const packName of config.enabledResourcePacks) {
      const resPath = AppPath + "/resource_pak/" + packName + path + name + suffix;
      if (Backend.exists(resPath)) return resPath;
    }
  }
  let ret = AppPath + path + name + suffix;
  if (Backend.exists(ret)) return ret;
}

function getGeneralExtraPic(name, extra) {
  const data = lcall("GetGeneralData", name);
  const extension = data.extension;
  const ret = searchPkgResourceWithExtension(extension, "/image/generals/" + extra, name, ".jpg");
  return ret;
}

function getGeneralPicture(name) {
  const data = lcall("GetGeneralData", name);
  const extension = data.extension;
  const ret = searchPkgResourceWithExtension(extension, "/image/generals/", name, ".jpg");

  if (ret) return ret;
  return searchBuiltinPic("/image/generals/", "0", ".jpg");
}

function getCardPicture(cidOrName) {
  let extension = "";
  let name = "unknown";
  if (typeof cidOrName === 'string') {
    name = cidOrName;
    extension = lcall("GetCardExtensionByName", cidOrName);
  } else {
    const data = lcall("GetCardData", cidOrName);
    extension = data.extension;
    name = data.name;
  }

  let ret = searchPkgResourceWithExtension(extension, "/image/card/", name);
  if (!ret) {
    ret = searchPkgResource("/image/card/", name);
  }

  if (ret) return ret;
  return searchBuiltinPic("/image/card/", "unknown");
}

function getDelayedTrickPicture(name) {
  const extension = lcall("GetCardExtensionByName", name);
  let ret = searchPkgResourceWithExtension(extension, "/image/card/delayedTrick/", name);
  if (!ret) {
    ret = searchPkgResource("/image/card/delayedTrick/", name);
  }

  if (ret) return ret;
  return searchBuiltinPic("/image/card/delayedTrick/", "unknown");
}


function getEquipIcon(cid, icon) {
  const data = lcall("GetCardData", cid);
  const extension = data.extension;
  const name = icon || data.name;
  let ret = searchPkgResourceWithExtension(extension, "/image/card/equipIcon/", name);
  if (!ret) {
    ret = searchPkgResource("/image/card/equipIcon/", name);
  }

  if (ret) return ret;
  return searchBuiltinPic("/image/card/equipIcon/", "unknown");
}

function getPhotoBack(kingdom) {
  let path = searchBuiltinPic("/image/photo/back/", kingdom);
  if (!path) {
    let ret = searchPkgResource("/image/kingdom/", kingdom, "-back.png");
    if (ret) return ret;
  } else {
    return path;
  }
  return searchBuiltinPic("/image/photo/back/", "unknown");
}

function getGeneralCardDir(kingdom) {
  let path = searchBuiltinPic("/image/card/general/", kingdom);
  if (!path) {
    let ret = searchPkgResource("/image/kingdom/", kingdom, "-back.png");
    if (ret) return ret.slice(0, ret.lastIndexOf('/')) + "/";
  } else {
    return path.slice(0, path.lastIndexOf('/')) + "/";
  }
}

function getRolePic(role) {
  let path = searchBuiltinPic("/image/photo/role/", role);
  if (path) {
    return path;
  } else {
    let ret = searchPkgResource("/image/role/", role);
    if (ret) return ret;
  }
  return searchBuiltinPic("/image/photo/role/", "unknown");
}

function getRoleDeathPic(role) {
  let path = searchBuiltinPic("/image/photo/death/", role);
  if (path) {
    return path;
  } else {
    let ret = searchPkgResource("/image/role/death/", role);
    if (ret) return ret;
  }
  return searchBuiltinPic("/image/photo/death/", "hidden");
}

function getMarkPic(mark) {
  let ret = searchPkgResource("/image/mark/", mark);
  if (ret) return ret;
  return "";
}

function removeMp3Suffix(path) {
  return path.replace(/(1)?\.mp3$/i, "");
}

// 武将技能语音
function getAudio(name, extension, audiotype) {
  const basePath = "/audio/" + audiotype + "/";
  const tryPaths = [
    [extension, basePath, name, ".mp3"],
    [extension, basePath, name, "1.mp3"]
  ];

  for (const args of tryPaths) {
    const ret = searchAudioResourceWithExtension(...args);
    if (ret) {
      return ret;
    }
  }
}

// 非技能的卡牌和其他语音
function getAudioByPath(path) {
  const ret = searchAudioResourceByPath(path + ".mp3")
  if (ret) {
    return removeMp3Suffix(ret);
  }
}

function getAudioRealPath(name, extension, audiotype) {
  const ret = searchPkgResourceWithExtension(extension, "/audio/" + audiotype + "/", name, ".mp3");
  if (Backend.exists(ret)) {
    return ret;
  }
}

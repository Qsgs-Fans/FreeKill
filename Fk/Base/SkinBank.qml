// SPDX-License-Identifier: GPL-3.0-or-later

pragma Singleton
import QtQuick

// TODO 这排var都得不能让外部直接调用了 改成基于函数调用
// SkinBank.getSystemPic(photoDir, path)之类的
// 这样美化包就可以把path拐到resource_pak/xxx/packages/freekill-core/...下面
// 由于要全改SkinBank.XXX 留给后来人

QtObject {
  readonly property var photoBackDir: Cpp.path + "/image/photo/back/";
  readonly property var photoDir: Cpp.path + "/image/photo/";
  readonly property var generalDir: Cpp.path + "/image/generals/";
  readonly property var generalCardDir: Cpp.path + "/image/card/general/";
  readonly property var stateDir: Cpp.path + "/image/photo/state/";
  readonly property var statusDir: Cpp.path + "/image/photo/status/";
  readonly property var roleDir: Cpp.path + "/image/photo/role/";
  readonly property var deathDir: Cpp.path + "/image/photo/death/";
  readonly property var magatamaDir: Cpp.path + "/image/photo/magatama/";
  readonly property var limitSkillDir: Cpp.path + "/image/photo/skill/";
  readonly property var cardDir: Cpp.path + "/image/card/";
  readonly property var cardSuitDir: Cpp.path + "/image/card/suit/";
  readonly property var delayedTrickDir: Cpp.path + "/image/card/delayedTrick/";
  readonly property var equipIconDir: Cpp.path + "/image/card/equipIcon/";
  readonly property var pixAnimDir: Cpp.path + "/image/anim/"
  readonly property var tileIconDir: Cpp.path + "/image/button/tileicon/"
  readonly property var lobbyImgDir: Cpp.path + "/image/lobby/";
  readonly property var miscDir: Cpp.path + "/image/misc/";

  function searchPkgResource(path, name, suffix) {
    suffix = suffix ?? ".png";
    const dirs = Backend.ls(Cpp.path + "/packages/").filter(dir => {
      return !Pacman.getDisabledPacks().includes(dir) &&
      !dir.endsWith(".disabled")
    });
    if (typeof Config !== "undefined" && Config.enabledResourcePacks) {
      for (const packName of Config.enabledResourcePacks) {
        for (const dir of dirs) {
          const resPath = Cpp.path + "/resource_pak/" + packName + "/packages/" + dir + path + name + suffix;
          if (Backend.exists(resPath)) return resPath;
        }
      }
    }

    let ret;
    for (const dir of dirs) {
      ret = Cpp.path + "/packages/" + dir + path + name + suffix;
      if (Backend.exists(ret)) return ret;
    }
  }

  function searchPkgResourceWithExtension(extension, path, name, suffix) {
    suffix = suffix ?? ".png";
    if (typeof Config !== "undefined" && Config.enabledResourcePacks) {
      for (const packName of Config.enabledResourcePacks) {
        const resPath = Cpp.path + "/resource_pak/" + packName + "/packages/" + extension + path + name + suffix;
        if (Backend.exists(resPath)) return resPath;
      }
    }

    const ret = Cpp.path + "/packages/" + extension + path + name + suffix;
    if (Backend.exists(ret)) return ret;
  }

  // 尝试在资源包中查找武将技能语音
  function searchAudioResourceWithExtension(extension, path, name, suffix = ".mp3") {
    if (typeof Config !== "undefined" && Config.enabledResourcePacks) {
      for (const packName of Config.enabledResourcePacks) {
        const resPath = `${Cpp.path}/resource_pak/${packName}/packages/${extension}${path}${name}${suffix}`;
        if (Backend.exists(resPath)) {
          return `./resource_pak/${packName}/packages/${extension}${path}${name}`;
        }
      }
    }

    const retPath = `${Cpp.path}/packages/${extension}${path}${name}${suffix}`;
    if (Backend.exists(retPath)) {
      return `./packages/${extension}${path}${name}`;
    }
  }

  // 尝试在资源包中根据路径查找音效
  function searchAudioResourceByPath(path) {
    if (typeof Config !== "undefined" && Config.enabledResourcePacks) {
      for (const packName of Config.enabledResourcePacks) {
        const resPath = `${Cpp.path}/resource_pak/${packName}${path}`;
        if (Backend.exists(resPath)) {
          return `./resource_pak/${packName}${path}`;
        }
      }
    }

    const retPath = `${Cpp.path}/${path}`;
    if (Backend.exists(retPath)) {
      return path;
    }
  }

  function searchBuiltinPic(path, name, suffix) {
    suffix = suffix ?? ".png";
    if (typeof Config !== "undefined" && Config.enabledResourcePacks) {
      for (const packName of Config.enabledResourcePacks) {
        const resPath = Cpp.path + "/resource_pak/" + packName + path + name + suffix;
        if (Backend.exists(resPath)) return resPath;
      }
    }
    let ret = Cpp.path + path + name + suffix;
    if (Backend.exists(ret)) return ret;
  }

  function getGeneralExtraPic(name, extra) {
    const data = Lua.call("GetGeneralData", name);
    const extension = data.extension;
    const ret = searchPkgResourceWithExtension(extension, "/image/generals/" + extra, name, ".jpg");
    return ret;
  }

  function getGeneralPicture(name) {
    const data = Lua.call("GetGeneralData", name);
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
      extension = Lua.call("GetCardExtensionByName", cidOrName);
    } else {
      const data = Lua.call("GetCardData", cidOrName);
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
    const extension = Lua.call("GetCardExtensionByName", name);
    let ret = searchPkgResourceWithExtension(extension, "/image/card/delayedTrick/", name);
    if (!ret) {
      ret = searchPkgResource("/image/card/delayedTrick/", name);
    }

    if (ret) return ret;
    return searchBuiltinPic("/image/card/delayedTrick/", "unknown");
  }


  function getEquipIcon(cid, icon) {
    let data = Lua.call("GetVirtualEquipData", 0, cid);
    if (!data)
      data = Lua.call("GetCardData", cid, true);

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
}

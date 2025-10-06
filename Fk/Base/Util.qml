// SPDX-License-Identifier: GPL-3.0-or-later

pragma Singleton
import QtQuick

QtObject {
  function convertNumber(number) {
    if (number === 1)
    return "A";
    if (number >= 2 && number <= 10)
    return number;
    if (number >= 11 && number <= 13) {
      const strs = ["J", "Q", "K"];
      return strs[number - 11];
    }
    return "";
  }

  function getPlayerStr(playerid) {
    const photo = Lua.evaluate(`(function(id)
      local p = ClientInstance:getPlayerById(id)
      return {
        general = p.general,
        deputyGeneral = p.deputyGeneral,
        seatNumber = p.seat,
      }
    end)(${playerid})`)
    if (photo.general === "anjiang" && (photo.deputyGeneral === "anjiang" || !photo.deputyGeneral)) {
      let ret = Lua.tr("seat#" + photo.seatNumber);
      if (playerid == Self.id) {
        ret = ret + Lua.tr("playerstr_self")
      }
      return Lua.tr(ret);
    }

    let ret = photo.general;
    ret = Lua.tr(ret);
    if (photo.deputyGeneral && photo.deputyGeneral !== "") {
      ret = ret + "/" + Lua.tr(photo.deputyGeneral);
    }
    if (playerid == Self.id) {
      ret = ret + Lua.tr("playerstr_self")
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
}

// SPDX-License-Identifier: GPL-3.0-or-later

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
  const photo = getPhoto(playerid);
  if (photo.general === "anjiang" && (photo.deputyGeneral === "anjiang" || !p.deputyGeneral)) {
    return luatr("seat#" + photo.seatNumber);
  }

  let ret = photo.general;
  ret = luatr(ret);
  if (photo.deputyGeneral && photo.deputyGeneral !== "") {
    ret = ret + "/" + luatr(photo.deputyGeneral);
  }
  return ret;
}

function processPrompt(prompt) {
  const data = prompt.split(":");
  let raw = luatr(data[0]);
  const src = parseInt(data[1]);
  const dest = parseInt(data[2]);
  if (raw.match("%src"))
    raw = raw.replace(/%src/g, getPlayerStr(src));
  if (raw.match("%dest"))
    raw = raw.replace(/%dest/g, getPlayerStr(dest));
  if (raw.match("%arg2"))
    raw = raw.replace(/%arg2/g, luatr(data[4]));
  if (raw.match("%arg"))
    raw = raw.replace(/%arg/g, luatr(data[3]));
  return raw;
}

Array.prototype.prepend = function() {
  this.splice(0, 0, ...arguments);
}

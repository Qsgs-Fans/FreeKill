// SPDX-License-Identifier: GPL-3.0-or-later

.pragma library

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

Array.prototype.contains = function(element) {
  return this.indexOf(element) != -1;
}

Array.prototype.prepend = function() {
  this.splice(0, 0, ...arguments);
}

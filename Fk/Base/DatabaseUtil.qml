// SPDX-License-Identifier: GPL-3.0-or-later

pragma Singleton
import QtQuick

QtObject {
  function checkString(sv) {
    const exp = /['";#* /\\?<>|]+|(--)|(\/\*)|(\*\/)|(--\+)/;
    return !exp.test(sv);
  }

  // function stringToHex(str) {
  //   return encodeURIComponent(str)
  //     .replace(/%([0-9A-Fa-f]{2})/g, (_, hex) => hex)
  //     .split('')
  //     .map(ch => ch.charCodeAt(0).toString(16).padStart(2, '0'))
  //     .join('');
  // }

  function tryInitModeSettings() {
    Cpp.sqlquery(`CREATE TABLE IF NOT EXISTS gameModeSettings (
      key TEXT PRIMARY KEY NOT NULL,
      value BLOB NOT NULL
    );`);
  }

  function getModeSettings(name) {
    if (!checkString(name)) {
      return {};
    }
    const raw = Cpp.sqlquery(`SELECT value FROM gameModeSettings WHERE key = '${name}';`);
    if (raw.length === 0) return {};
    return JSON.parse(raw[0].value);
  }

  function saveModeSettings(name, data) {
    if (!checkString(name)) {
      return;
    }

    const raw = JSON.stringify(data);
    // const hex = stringToHex(raw);

    const query = `REPLACE INTO gameModeSettings (key, value) VALUES ('${name}', '${raw.replace(/'/g, "''")}');`;
    Cpp.sqlquery(query);
  }
}

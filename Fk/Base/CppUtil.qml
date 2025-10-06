// SPDX-License-Identifier: GPL-3.0-or-later

pragma Singleton
import QtQuick

QtObject {
  readonly property string version: typeof FkVersion !== 'undefined' ? FkVersion : 'qml-test';
  readonly property string os: typeof OS !== 'undefined' ? OS : 'linux';
  readonly property string path: typeof AppPath !== 'undefined' ? AppPath : '/';
  readonly property string locale: typeof SysLocale !== 'undefined' ? SysLocale : 'zh_CN';
  readonly property bool debug: typeof Debugging !== 'undefined' ? Debugging : true;

  function notifyServer(command, data) {
    ClientInstance.notifyServer(command, data);
  }

  function replyToServer(data) {
    ClientInstance.replyToServer("", data);
  }

  function showDialog(type, log, data) {
    Backend.showDialog(type, log, data);
  }

  function quitLobby(v) {
    Backend.quitLobby(v);
  }

  function loadTips() {
    const tips = Backend.loadTips();
    return tips.trim().split("\n");
  }

  function loadConf() {
    return Backend.loadConf();
  }

  function saveConf(s) {
    Backend.saveConf(s);
  }

  function setVolume(v) {
    Backend.volume = v;
  }

  function volume() {
    return Backend.volume;
  }

  function sqlquery(s) {
    return ClientInstance.execSql(s);
  }
}

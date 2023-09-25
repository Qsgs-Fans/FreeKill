// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

QtObject {
  // Client configuration
  property real winX
  property real winY
  property real winWidth
  property real winHeight
  property var conf: ({})
  property string lastLoginServer
  property var savedPassword: ({})
  property string lobbyBg
  property string roomBg
  property string bgmFile
  property string language
  property list<string> disabledPack: []
  property string preferedMode
  property int preferedPlayerNum
  property int preferredGeneralNum
  property string ladyImg
  property real bgmVolume
  property bool disableMsgAudio
  property bool hideUseless
  property list<string> disabledGenerals: []
  property list<var> disableGeneralSchemes: []
  property int disableSchemeIdx: 0

  property int preferredTimeout
  property int preferredLuckTime

  // Player property of client
  property string serverAddr
  property string screenName: ""
  property string password: ""
  property string cipherText
  property string aeskey

  // Client data
  property string serverMotd: ""
  property list<string> serverHiddenPacks: []
  property bool serverEnableBot: true
  property int roomCapacity: 0
  property int roomTimeout: 0
  property bool heg: false
  property bool enableFreeAssign: false
  property bool observing: false
  property bool replaying: false
  property list<string> blockedUsers: []

  onDisabledGeneralsChanged: {
    disableGeneralSchemes[disableSchemeIdx] = disabledGenerals;
  }

  function loadConf() {
    conf = JSON.parse(Backend.loadConf());
    winX = conf.winX ?? 100;
    winY = conf.winY ?? 100;
    winWidth = conf.winWidth ?? 960;
    winHeight = conf.winHeight ?? 540;
    lastLoginServer = conf.lastLoginServer ?? "127.0.0.1";
    savedPassword = conf.savedPassword ?? {};
    lobbyBg = conf.lobbyBg ?? AppPath + "/image/background";
    roomBg = conf.roomBg ?? AppPath + "/image/gamebg";
    bgmFile = conf.bgmFile ?? AppPath + "/audio/system/bgm.mp3";
    language = conf.language ?? (() => {
      let ret = SysLocale;
      if (['zh_CN', 'en_US'].includes(ret)) {
        return ret;
      }
      return 'zh_CN';
    })();
    disabledPack = conf.disabledPack ?? [ "test_p_0" ];
    preferedMode = conf.preferedMode ?? "aaa_role_mode";
    preferedPlayerNum = conf.preferedPlayerNum ?? 2;
    preferredGeneralNum = conf.preferredGeneralNum ?? 3;
    ladyImg = conf.ladyImg ?? AppPath + "/image/lady";
    Backend.volume = conf.effectVolume ?? 50.;
    bgmVolume = conf.bgmVolume ?? 50.;
    disableMsgAudio = conf.disableMsgAudio ?? false;
    hideUseless = conf.hideUseless ?? false;
    preferredTimeout = conf.preferredTimeout ?? 15;
    preferredLuckTime = conf.preferredLuckTime ?? 0;
    disabledGenerals = conf.disabledGenerals ?? [];
    disableGeneralSchemes = conf.disableGeneralSchemes ?? [ disabledGenerals ];
    disableSchemeIdx = conf.disableSchemeIdx ?? 0;
  }

  function saveConf() {
    conf.winX = realMainWin.x;
    conf.winY = realMainWin.y;
    conf.winWidth = realMainWin.width;
    conf.winHeight = realMainWin.height;
    conf.lastLoginServer = lastLoginServer;
    conf.savedPassword = savedPassword;
    conf.lobbyBg = lobbyBg;
    conf.roomBg = roomBg;
    conf.bgmFile = bgmFile;
    conf.language = language;
    conf.disabledPack = disabledPack;
    conf.preferedMode = preferedMode;
    conf.preferedPlayerNum = preferedPlayerNum;
    conf.ladyImg = ladyImg;
    conf.preferredGeneralNum = preferredGeneralNum;
    conf.effectVolume = Backend.volume;
    conf.bgmVolume = bgmVolume;
    conf.disableMsgAudio = disableMsgAudio;
    conf.hideUseless = hideUseless;
    conf.preferredTimeout = preferredTimeout;
    conf.preferredLuckTime = preferredLuckTime;
    conf.disabledGenerals = disabledGenerals;
    conf.disableGeneralSchemes = disableGeneralSchemes;
    conf.disableSchemeIdx = disableSchemeIdx;

    Backend.saveConf(JSON.stringify(conf, undefined, 2));
  }
}

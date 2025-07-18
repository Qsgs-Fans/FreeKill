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
  //property var savedPassword: ({})
  property var favoriteServers: []
  property string lobbyBg
  property string roomBg
  property string bgmFile
  property string language
  // property list<string> disabledPack: []
  property string preferedMode
  property int preferedPlayerNum
  property int preferredGeneralNum
  property var preferredFilter
  property string ladyImg
  property real bgmVolume
  property bool disableMsgAudio
  property bool disableGameOverAudio
  property bool hideUseless
  property bool hideObserverChatter
  property bool rotateTableCard
  property bool hidePresents
  property bool autoTarget
  property bool doubleClickUse
  property bool noSelfNullification
  // property list<string> disabledGenerals: []
  // property list<var> disableGeneralSchemes: []
  // property int disableSchemeIdx: 0
  property list<var> disableSchemes: []
  property int currentDisableIdx: 0
  property var curScheme
  property list<string> shownPkg: []
  property list<string> favoriteGenerals: []
  property list<string> enabledResourcePacks: []

  property int preferredTimeout
  property int preferredLuckTime
  property bool enableFreeAssign
  property bool enableDeputy

  property bool firstRun: true

  // Player property of client
  property string serverAddr
  property int serverPort
  property string screenName: ""
  property string password: ""
  // string => { roomId => config }
  property var roomConfigCache: ({})

  // Client data
  property string serverMotd: ""
  property list<string> serverHiddenPacks: []
  property bool serverEnableBot: true
  property int roomCapacity: 0
  property int roomTimeout: 0
  property bool heg: false
  property bool observing: false
  property bool replaying: false
  property bool replayingShowCards: false
  property list<string> blockedUsers: []
  property int totalTime: 0 // FIXME: only for notifying

  onObservingChanged: lcall("SetObserving", observing);
  onReplayingChanged: lcall("SetReplaying", replaying);
  onReplayingShowCardsChanged: lcall("SetReplayingShowCards", replayingShowCards);

  // onDisabledGeneralsChanged: {
  //   disableGeneralSchemes[disableSchemeIdx] = disabledGenerals;
  // }

  function findFavorite(addr, port) {
    for (const s of favoriteServers) {
      if (s.addr === addr && s.port === port) {
        return s;
      }
    }
    return undefined;
  }

  function removeFavorite(addr, port) {
    for (const i in favoriteServers) {
      const s = favoriteServers[i];
      if (s.addr === addr && s.port === port) {
        favoriteServers.splice(i, 1);
        saveConf();
        return;
      }
    }
  }

  function addFavorite(addr, port, name, username, password) {
    for (const i in favoriteServers) {
      const s = favoriteServers[i];
      if (s.addr === addr && s.port === port) {
        s.name = name;
        s.username = username;
        s.password = password;
        saveConf();
        return false;
      }
    }
    favoriteServers.unshift({ addr, port, name, username, password });
    saveConf();
    return true;
  }


  function loadConf() {
    conf = JSON.parse(Backend.loadConf());
    winX = conf.winX ?? 100;
    winY = conf.winY ?? 100;
    winWidth = conf.winWidth ?? 960;
    winHeight = conf.winHeight ?? 540;
    lastLoginServer = conf.lastLoginServer ?? "127.0.0.1";
    //savedPassword = conf.savedPassword ?? {};
    favoriteServers = conf.favoriteServers ?? [];
    lobbyBg = conf.lobbyBg ?? AppPath + "/image/background";
    roomBg = conf.roomBg ?? AppPath + "/image/gamebg";
    bgmFile = conf.bgmFile ?? AppPath + "/audio/system/bgm.mp3";
    language = conf.language ?? (() => {
      let ret = SysLocale;
      if (ret.startsWith('zh_')) {
        return 'zh_CN';
      } else if (ret.startsWith('vi_')) {
        return 'vi_VN';
      } else {
        return 'en_US';
      }
    })();
    // disabledPack = conf.disabledPack ?? [ "test_p_0" ];
    preferedMode = conf.preferedMode ?? "aaa_role_mode";
    preferedPlayerNum = conf.preferedPlayerNum ?? 2;
    preferredGeneralNum = conf.preferredGeneralNum ?? 3;
    preferredFilter = conf.preferredFilter ?? {
      name: "", // 房间名
      id: "", // 房间ID
      modes : [], // 游戏模式
      full : 2, // 满员，0满，1未满，2不限
      hasPassword : 2, // 密码，0有，1无，2不限
    };
    ladyImg = conf.ladyImg ?? AppPath + "/image/lady";
    Backend.volume = conf.effectVolume ?? 50.;
    bgmVolume = conf.bgmVolume ?? 50.;
    disableMsgAudio = conf.disableMsgAudio ?? false;
    disableGameOverAudio = conf.disableGameOverAudio ?? false;
    hideUseless = conf.hideUseless ?? false;
    hideObserverChatter = conf.hideObserverChatter ?? false;
    rotateTableCard = conf.rotateTableCard ?? false;
    hidePresents = conf.hidePresents ?? false;
    autoTarget = conf.autoTarget ?? false;
    doubleClickUse = conf.doubleClickUse ?? false;
    noSelfNullification = conf.noSelfNullification ?? false;
    preferredTimeout = conf.preferredTimeout ?? 15;
    preferredLuckTime = conf.preferredLuckTime ?? 0;
    enableFreeAssign = conf.enableFreeAssign ?? false;
    enableDeputy = conf.enableDeputy ?? false;
    firstRun = conf.firstRun ?? true;
    // disabledGenerals = conf.disabledGenerals ?? [];
    // disableGeneralSchemes = conf.disableGeneralSchemes ?? [ disabledGenerals ];
    // disableSchemeIdx = conf.disableSchemeIdx ?? 0;
    disableSchemes = conf.disableSchemes ?? [{
      name: "",
      banPkg: {},    // 被禁用的包，内部数据为 包名: 白名单武将名数组
      normalPkg: {},  // 未被禁用的包，内部数据为 包名: 黑名单武将名数组
      banCardPkg: [], // 被禁用的卡包
    }];
    currentDisableIdx = conf.currentDisableIdx ?? 0;
    curScheme = disableSchemes[currentDisableIdx];
    shownPkg = conf.shownPkg ?? [];
    favoriteGenerals = conf.favoriteGenerals ?? [];
    blockedUsers = conf.blockedUsers ?? [];
    enabledResourcePacks = conf.enabledResourcePacks ?? [];
  }

  function saveConf() {
    conf.winX = realMainWin.x;
    conf.winY = realMainWin.y;
    conf.winWidth = realMainWin.width;
    conf.winHeight = realMainWin.height;
    conf.lastLoginServer = lastLoginServer;
    //conf.savedPassword = savedPassword;
    conf.favoriteServers = favoriteServers;
    conf.lobbyBg = lobbyBg;
    conf.roomBg = roomBg;
    conf.bgmFile = bgmFile;
    conf.language = language;
    // conf.disabledPack = disabledPack;
    conf.preferedMode = preferedMode;
    conf.preferedPlayerNum = preferedPlayerNum;
    conf.preferredFilter = preferredFilter;
    conf.ladyImg = ladyImg;
    conf.preferredGeneralNum = preferredGeneralNum;
    conf.effectVolume = Backend.volume;
    conf.bgmVolume = bgmVolume;
    conf.disableMsgAudio = disableMsgAudio;
    conf.disableGameOverAudio = disableGameOverAudio;
    conf.hideUseless = hideUseless;
    conf.hideObserverChatter = hideObserverChatter;
    conf.rotateTableCard = rotateTableCard;
    conf.hidePresents = hidePresents;
    conf.autoTarget = autoTarget;
    conf.doubleClickUse = doubleClickUse;
    conf.noSelfNullification = noSelfNullification;
    conf.preferredTimeout = preferredTimeout;
    conf.preferredLuckTime = preferredLuckTime;
    conf.enableFreeAssign = enableFreeAssign;
    conf.enableDeputy = enableDeputy;
    conf.firstRun = firstRun;
    // conf.disabledGenerals = disabledGenerals;
    // conf.disableGeneralSchemes = disableGeneralSchemes;
    // conf.disableSchemeIdx = disableSchemeIdx;
    disableSchemes[currentDisableIdx] = curScheme;
    conf.disableSchemes = disableSchemes;
    conf.shownPkg = shownPkg;
    conf.currentDisableIdx = currentDisableIdx;
    conf.favoriteGenerals = favoriteGenerals;
    conf.blockedUsers = blockedUsers;
    conf.enabledResourcePacks = enabledResourcePacks;

    Backend.saveConf(JSON.stringify(conf, undefined, 2));
  }
}

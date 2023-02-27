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

  // Player property of client
  property string serverAddr
  property string screenName: ""
  property string password: ""
  property string cipherText

  // Client data
  property int roomCapacity: 0
  property int roomTimeout: 0
  property bool enableFreeAssign: false
  property bool observing: false

  function loadConf() {
    conf = JSON.parse(Backend.loadConf());
    winX = conf.winX || 100;
    winY = conf.winY || 100;
    winWidth = conf.winWidth || 960;
    winHeight = conf.winHeight || 540;
    lastLoginServer = conf.lastLoginServer || "127.0.0.1";
    savedPassword = conf.savedPassword || {};
    lobbyBg = conf.lobbyBg || AppPath + "/image/background";
    roomBg = conf.roomBg || AppPath + "/image/gamebg";
    bgmFile = conf.bgmFile || AppPath + "/audio/system/bgm.mp3";
    language = conf.language || "zh_CN";
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

    Backend.saveConf(JSON.stringify(conf, undefined, 2));
  }
}

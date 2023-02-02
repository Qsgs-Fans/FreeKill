import QtQuick

QtObject {
  // Client configuration
  property real winWidth
  property real winHeight
  property var conf: ({})
  property string lastLoginServer
  property var savedPassword: ({})

  // Player property of client
  property string serverAddr
  property string screenName: ""
  property string password: ""
  property string cipherText

  // Client data
  property int roomCapacity: 0
  property int roomTimeout: 0

  function loadConf() {
    conf = JSON.parse(Backend.loadConf());
    winWidth = conf.winWidth || 960;
    winHeight = conf.winHeight || 540;
    lastLoginServer = conf.lastLoginServer || "127.0.0.1";
    savedPassword = conf.savedPassword || {};
  }

  function saveConf() {
    conf.winWidth = realMainWin.width;
    conf.winHeight = realMainWin.height;
    conf.lastLoginServer = lastLoginServer;
    conf.savedPassword = savedPassword;

    Backend.saveConf(JSON.stringify(conf, undefined, 2));
  }
}

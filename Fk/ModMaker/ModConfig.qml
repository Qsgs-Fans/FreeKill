import QtQuick

QtObject {
  property var conf

  property string userName
  property string email

  function loadConf() {
    conf = JSON.parse(ModBackend.readFile("mymod/config.json"));
    userName = conf.userName ?? "";
    email = conf.email ?? "";
  }

  function saveConf() {
    conf.userName = userName;
    conf.email = email;

    ModBackend.saveToFile("mymod/config.json", JSON.stringify(conf, undefined, 2));
  }
}

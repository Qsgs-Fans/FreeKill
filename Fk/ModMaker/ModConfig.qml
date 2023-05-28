import QtQuick

QtObject {
  property var conf

  property string userName
  property string email
  property var modList: []

  function loadConf() {
    conf = JSON.parse(ModBackend.readFile("mymod/config.json"));
    userName = conf.userName ?? "";
    email = conf.email ?? "";
    modList = conf.modList ?? [];
  }

  function saveConf() {
    conf.userName = userName;
    conf.email = email;
    conf.modList = modList;

    ModBackend.saveToFile("mymod/config.json", JSON.stringify(conf, undefined, 2));
  }

  function addMod(mod) {
    modList.push(mod);
    saveConf();
    modListChanged();
  }

  function removeMod(mod) {
    modList.splice(modList.indexOf(mod), 1);
    saveConf();
    modListChanged();
  }
}

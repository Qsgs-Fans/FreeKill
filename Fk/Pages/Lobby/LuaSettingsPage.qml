import QtQuick

import Fk
import Fk.Widgets as W

Item {
  id: root

  property string configName
  property var dynamicChildObject: []
  property var config: ({})

  W.PreferencePage {
    id: prefPage
    anchors.fill: parent
    groupWidth: width * 0.8
  }

  Text {
    anchors.centerIn: root
    text: "没有可配置项"
    font.pixelSize: 40
    color: "grey"
    visible: root.dynamicChildObject.length === 0
  }

  function buildComponent(data, parent) {
    const qml = data._qml;
    let component;
    if (qml.uri) {
      component = Qt.createComponent(qml.uri, qml.name);
    } else {
      component = Qt.createComponent(Cpp.path + '/' + qml.url);
    }

    if (component.status != Component.Ready) {
      return;
    }

    const propDict = {};
    for (const k in data) {
      if (!k.startsWith("_")) {
        propDict[k] = data[k];
      }
    }

    if (propDict["title"]) {
      const subTitle = "help: " + propDict["title"];
      if (Lua.tr(subTitle) != subTitle) {
        propDict["subTitle"] = Lua.tr(subTitle);
      }
      propDict["title"] = Lua.tr(propDict["title"]);
    }

    // 创建对象，绑定到config
    const settingsKey = data["_settingsKey"];
    const obj = component.createObject(parent, propDict);
    if (obj.value !== null && obj.value !== undefined) {
      if (root.config[settingsKey]) {
        obj.value = root.config[settingsKey];
      } else {
        root.config[settingsKey] = obj.value;
      }
    }
    obj.valueChanged?.connect(() => {
      if (!settingsKey) return;
      root.config[settingsKey] = obj.value;
      Db.saveModeSettings(root.configName, root.config);

      // TODO 更新余下的ui 但先偷懒
    });

    for (const v of data._children) {
      buildComponent(v, obj);
    }

    return obj;
  }

  function loadSettingsUI(data) {
    const newChildren = [];
    const newConf = Object.keys(root.config).length === 0;

    for (const dat of data) {
      newChildren.push(buildComponent(dat, prefPage.layout));
    }

    for (const v of dynamicChildObject) {
      v.destroy();
    }
    dynamicChildObject = newChildren;

    if (newConf) {
      Db.saveModeSettings(root.configName, root.config);
    }
  }

  // TODO 暂且懒得整动态刷新了
  // function updateSettingsUI(data) {
  //   for (const v of dynamicChildObject) {

  //   }
  // }
}

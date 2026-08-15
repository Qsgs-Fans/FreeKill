import QtQuick

import Fk
import Fk.Widgets as W

Item {
  id: root

  property string configName
  property var dynamicChildObject: []
  required property var config
  property bool isBoardgame: false
  property string gameModeName
  property bool needcopy: false // 有function时，会对settings进行拷贝（因为function求值的缘故）
  property bool updatingData: false

  signal settingsUpdated()

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
    const component = Lua.createComponent(data._qml);

    if (component.status != Component.Ready) {
      return;
    }

    const propDict = {};
    for (const k in data) {
      if (!k.startsWith("_")) {
        propDict[k] = data[k];
      }
    }

    if (propDict["subTitle"]) {
      propDict["subTitle"] = Lua.tr(propDict["subTitle"]);
    }

    if (propDict["title"]) {
      if (!propDict["subTitle"]) {
        const subTitle = "help: " + propDict["title"];
        if (Lua.tr(subTitle) != subTitle) {
          propDict["subTitle"] = Lua.tr(subTitle);
        }
      }
      propDict["title"] = Lua.tr(propDict["title"]);
    }

    // 创建对象，绑定到config
    const settingsKey = data["_settingsKey"];
    const obj = component.createObject(parent, propDict);
    if (obj.value !== null && obj.value !== undefined) {
      const cfg = root.config[root.isBoardgame ? "_game" : "_mode"];
      if (cfg[settingsKey]) {
        obj.value = cfg[settingsKey];
      } else {
        cfg[settingsKey] = obj.value;
      }
    }
    obj.valueChanged?.connect(() => {
      if (!settingsKey) return;

      const cfg = root.config[root.isBoardgame ? "_game" : "_mode"];
      cfg[settingsKey] = obj.value;
      if (root.needcopy && !root.updatingData) {
        // root.updateSettingsUI(settingsKey, obj.value);
        root.settingsUpdated();
      }

      Db.saveModeSettings(root.configName, cfg);
    });

    for (const v of data._children) {
      buildComponent(v, obj);
    }

    return obj;
  }

  function loadSettingsUI(data) {
    const newChildren = [];
    const cfg = root.config[root.isBoardgame ? "_game" : "_mode"];
    const newConf = Object.keys(cfg).length === 0;

    for (const dat of data) {
      newChildren.push(buildComponent(dat, prefPage.layout));
    }

    for (const v of dynamicChildObject) {
      v.destroy();
    }
    dynamicChildObject = newChildren;

    if (newConf) {
      Db.saveModeSettings(root.configName, cfg);
    }
  }

  function updateSettingsUI() {
    if (!root.gameModeName) return;
    updatingData = true;
    const getUIData = Lua.fn("GetUIDataOfSettings");
    const settingsData = getUIData(root.gameModeName, root.config, root.isBoardgame) ?? [];
    const assignDataToObject = (data, obj) => {
      const propDict = {};
      for (const k in data) {
        if (!k.startsWith("_")) {
          propDict[k] = data[k];
        }
      }

      if (propDict["subTitle"]) {
        propDict["subTitle"] = Lua.tr(propDict["subTitle"]);
      }

      if (propDict["title"]) {
        if (!propDict["subTitle"]) {
          const subTitle = "help: " + propDict["title"];
          if (Lua.tr(subTitle) != subTitle) {
            propDict["subTitle"] = Lua.tr(subTitle);
          }
        }
        propDict["title"] = Lua.tr(propDict["title"]);
      }

      // 算出prop之后贴给obj
      for (const k in propDict) {
        obj[k] = propDict[k];
      }
    };
    for (let i = 0; i < settingsData.length; i++) {
      const dat = settingsData[i];
      const obj = dynamicChildObject[i];
      if (!obj) continue;
      assignDataToObject(dat, obj);
      // 这里假设obj必定是W.PreferenceGroup了
      for (let j = 0; j < dat["_children"].length; j++) {
        assignDataToObject(dat["_children"][j], obj.children[j + 1]);
      }
    }
    updatingData = false;
  }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk

Item {
  id: root
  clip: true

  ColumnLayout {
    anchors.fill: parent
    RowLayout {
      Layout.fillWidth: true
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: Lua.tr("Ban List")
      }
      ComboBox {
        id: banCombo
        textRole: "name"
        Layout.fillWidth: true
        model: ListModel {
          id: banComboList
        }

        onCurrentIndexChanged: {
          word.text = "";
          Config.disableSchemes[Config.currentDisableIdx] = Config.curScheme;
          Config.currentDisableIdx = currentIndex;
          Config.curScheme = Config.disableSchemes[currentIndex];
        }
      }

      GridLayout {
        columns: 2

        Button {
          text: Lua.tr("New")
          onClicked: {
            const i = Config.disableSchemes.length;
            banComboList.append({
              name: Lua.tr("List") + (i + 1),
            });
            Config.disableSchemes.push({
              name: "",
              banPkg: {},
              normalPkg: {},
              banCardPkg: [],
            });
          }
        }

        Button {
          text: Lua.tr("Clear")
          onClicked: {
            Config.curScheme.banPkg = {};
            Config.curScheme.normalPkg = {};
            Config.curScheme.banCardPkg = [];
            Config.curScheme = Config.curScheme;
          }
        }

        Button {
          text: Lua.tr("Export")
          onClicked: {
            Backend.copyToClipboard(JSON.stringify(Config.curScheme));
            App.showToast(Lua.tr("Export Success"));
          }
        }

        Button {
          text: Lua.tr("Import")
          onClicked: {
            const str = Backend.readClipboard();
            let data;
            try {
              data = JSON.parse(str);
            } catch (e) {
              App.showToast(Lua.tr("Not Legal"));
              return;
            }
            if (!data instanceof Object || !data.banPkg || !data.normalPkg
              || !data.banCardPkg) {
              App.showToast(Lua.tr("Not JSON"));
              return;
            }
            Config.curScheme = data;
            if (data.name) {
              banComboList.get(banCombo.currentIndex).name = data.name;
            }
          }
        }
      }

      TextField {
        id: word
        clip: true
        leftPadding: 5
        rightPadding: 5
      }

      Button {
        text: Lua.tr("Rename")
        enabled: word.text !== ""
        onClicked: {
          banComboList.get(banCombo.currentIndex).name = word.text;
          Config.curScheme.name = word.text;
          word.text = "";
        }
      }
    }

    Text {
      Layout.fillWidth: true
      Layout.margins: 8
      wrapMode: Text.WrapAnywhere
      text: Lua.tr("Help_Ban_List")
    }

    GridLayout {
      id: grid
      flow: GridLayout.TopToBottom
      rows: 2
      Layout.fillWidth: true
      Layout.fillHeight: true

      Text {
        wrapMode: Text.WrapAnywhere
        text: Lua.tr("Ban_Generals")
        font.pixelSize: 18
        font.bold: true
      }

      GridView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        cellWidth: width / 2
        cellHeight: 24
        model: {
          let ret = [], k;
          const s = Config.curScheme;
          for (k in s.normalPkg) {
            ret.push(...s.normalPkg[k]);
          }
          return ret;
        }
        delegate: Text {
          //width: banChara.width
          text: {
            const prefix = modelData.split("__")[0];
            let name = Lua.tr(modelData);
            if (prefix !== modelData) {
              name += (" (" + Lua.tr(prefix) + ")");
            }
            return name;
          }
          font.pixelSize: 16
        }
      }

      Text {
        wrapMode: Text.WrapAnywhere
        text: Lua.tr("Ban_Packages")
        font.pixelSize: 18
        font.bold: true
      }

      GridView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        cellWidth: width / 2
        cellHeight: 24
        model: {
          let ret = [], k;
          const s = Config.curScheme;
          for (k in s.banPkg) {
            ret.push(k);
          }
          ret.push(...s.banCardPkg)
          return ret;
        }
        delegate: Text {
          width: parent.width / 2
          wrapMode: Text.WordWrap
          fontSizeMode: Text.HorizontalFit
          minimumPixelSize: 14
          elide: Text.ElideRight
          height: 24
          text: Lua.tr(modelData)
          font.pixelSize: 16
        }
      }

      Text {
        wrapMode: Text.WrapAnywhere
        text: Lua.tr("Whitelist_Generals")
        font.pixelSize: 18
        font.bold: true
      }

      GridView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        cellWidth: width / 2
        cellHeight: 24
        model: {
          let ret = [], k;
          const s = Config.curScheme;
          for (k in s.banPkg) {
            ret.push(...s.banPkg[k]);
          }
          return ret;
        }
        delegate: Text {
          text: {
            const prefix = modelData.split("__")[0];
            let name = Lua.tr(modelData);
            if (prefix !== modelData) {
              name += (" (" + Lua.tr(prefix) + ")");
            }
            return name;
          }
          font.pixelSize: 16
        }
      }

    }
  }

  Component.onCompleted: {
    for (let i = 0; i < Config.disableSchemes.length; i++) {
      banComboList.append({
        name: Config.disableSchemes[i]?.name || (Lua.tr("List") + (i + 1)),
      });
    }
    banCombo.currentIndex = Config.currentDisableIdx;
  }
}

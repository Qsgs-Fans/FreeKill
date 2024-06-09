// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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
        text: luatr("Ban List")
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
          config.disableSchemes[config.currentDisableIdx] = config.curScheme;
          config.currentDisableIdx = currentIndex;
          config.curScheme = config.disableSchemes[currentIndex];
        }
      }

      GridLayout {
        columns: 2

        Button {
          text: luatr("New")
          onClicked: {
            const i = config.disableSchemes.length;
            banComboList.append({
              name: luatr("List") + (i + 1),
            });
            config.disableSchemes.push({
              name: "",
              banPkg: {},
              normalPkg: {},
              banCardPkg: [],
            });
          }
        }

        Button {
          text: luatr("Clear")
          onClicked: {
            config.curScheme.banPkg = {};
            config.curScheme.normalPkg = {};
            config.curScheme.banCardPkg = [];
            config.curSchemeChanged();
          }
        }

        Button {
          text: luatr("Export")
          onClicked: {
            Backend.copyToClipboard(JSON.stringify(config.curScheme));
            toast.show(luatr("Export Success"));
          }
        }

        Button {
          text: luatr("Import")
          onClicked: {
            const str = Backend.readClipboard();
            let data;
            try {
              data = JSON.parse(str);
            } catch (e) {
              toast.show(luatr("Not Legal"));
              return;
            }
            if (!data instanceof Object || !data.banPkg || !data.normalPkg
              || !data.banCardPkg) {
              toast.show(luatr("Not JSON"));
              return;
            }
            config.curScheme = data;
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
        text: luatr("Rename")
        enabled: word.text !== ""
        onClicked: {
          banComboList.get(banCombo.currentIndex).name = word.text;
          config.curScheme.name = word.text;
          word.text = "";
        }
      }
    }

    Text {
      Layout.fillWidth: true
      Layout.margins: 8
      wrapMode: Text.WrapAnywhere
      text: luatr("Help_Ban_List")
    }

    GridLayout {
      id: grid
      flow: GridLayout.TopToBottom
      rows: 2
      Layout.fillWidth: true
      Layout.fillHeight: true

      Text {
        wrapMode: Text.WrapAnywhere
        text: luatr("Ban_Generals")
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
          const s = config.curScheme;
          for (k in s.normalPkg) {
            ret.push(...s.normalPkg[k]);
          }
          return ret;
        }
        delegate: Text {
          //width: banChara.width
          text: {
            const prefix = modelData.split("__")[0];
            let name = luatr(modelData);
            if (prefix !== modelData) {
              name += (" (" + luatr(prefix) + ")");
            }
            return name;
          }
          font.pixelSize: 16
        }
      }

      Text {
        wrapMode: Text.WrapAnywhere
        text: luatr("Ban_Packages")
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
          const s = config.curScheme;
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
          text: luatr(modelData)
          font.pixelSize: 16
        }
      }

      Text {
        wrapMode: Text.WrapAnywhere
        text: luatr("Whitelist_Generals")
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
          const s = config.curScheme;
          for (k in s.banPkg) {
            ret.push(...s.banPkg[k]);
          }
          return ret;
        }
        delegate: Text {
          text: {
            const prefix = modelData.split("__")[0];
            let name = luatr(modelData);
            if (prefix !== modelData) {
              name += (" (" + luatr(prefix) + ")");
            }
            return name;
          }
          font.pixelSize: 16
        }
      }

    }
  }

  Component.onCompleted: {
    for (let i = 0; i < config.disableSchemes.length; i++) {
      banComboList.append({
        name: config.disableSchemes[i]?.name || (luatr("List") + (i + 1)),
      });
    }
    banCombo.currentIndex = config.currentDisableIdx;
  }
}

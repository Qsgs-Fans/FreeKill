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
      anchors.rightMargin: 8
      spacing: 16
      Text {
        text: luatr("Ban List")
      }
      ComboBox {
        id: banCombo
        textRole: "name"
        model: ListModel {
          id: banComboList
        }

        onCurrentIndexChanged: {
          config.disableSchemeIdx = currentIndex;
          config.disabledGenerals = config.disableGeneralSchemes[currentIndex];
        }
      }

      Button {
        text: luatr("New")
        onClicked: {
          const i = config.disableGeneralSchemes.length;
          banComboList.append({
            name: luatr("List") + (i + 1),
          });
          config.disableGeneralSchemes.push([]);
        }
      }

      Button {
        text: luatr("Clear")
        onClicked: {
          config.disabledGenerals = [];
        }
      }

      Button {
        text: luatr("Export")
        onClicked: {
          Backend.copyToClipboard(JSON.stringify(config.disabledGenerals));
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
          if (!data instanceof Array) {
            toast.show(luatr("Not JSON"));
            return;
          }
          let d = [];
          for (let e of data) {
            if (typeof e === "string" && luatr(e) !== e) {
              d.push(e);
            }
          }
          config.disabledGenerals = d;
          toast.show(luatr("Import Success"));
        }
      }
    }

    Text {
      Layout.fillWidth: true
      Layout.margins: 8
      wrapMode: Text.WrapAnywhere
      text: luatr("Help_Ban_List")
    }

    GridView {
      id: listView
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      cellWidth: width / 4
      cellHeight: 24
      model: config.disabledGenerals
      delegate: Text {
        width: listView.width
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

  Component.onCompleted: {
    for (let i = 0; i < config.disableGeneralSchemes.length; i++) {
      banComboList.append({
        name: luatr("List") + (i + 1),
      });
    }
    banCombo.currentIndex = config.disableSchemeIdx;
  }
}

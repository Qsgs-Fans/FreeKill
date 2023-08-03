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
        text: Backend.translate("Ban List")
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
        text: Backend.translate("New")
        onClicked: {
          const i = config.disableGeneralSchemes.length;
          banComboList.append({
            name: Backend.translate("List") + (i + 1),
          });
          config.disableGeneralSchemes.push([]);
        }
      }

      Button {
        text: Backend.translate("Clear")
        onClicked: {
          config.disabledGenerals = [];
        }
      }
    }

    Text {
      Layout.fillWidth: true
      Layout.margins: 8
      wrapMode: Text.WrapAnywhere
      text: Backend.translate("Help_Ban_List")
    }

    RowLayout {
      Button {
        text: Backend.translate("Export")
        onClicked: {
          Backend.copyToClipboard(JSON.stringify(config.disabledGenerals));
          toast.show(Backend.translate("Export Success"));
        }
      }

      Button {
        text: Backend.translate("Import")
        onClicked: {
          const str = Backend.readClipboard();
          let data;
          try {
            data = JSON.parse(str);
          } catch (e) {
            toast.show(Backend.translate("Not Legal"));
            return;
          }
          if (!data instanceof Array) {
            toast.show(Backend.translate("Not JSON"));
            return;
          }
          let d = [];
          for (let e of data) {
            if (typeof e === "string" && Backend.translate(e) !== e) {
              d.push(e);
            }
          }
          config.disabledGenerals = d;
          toast.show(Backend.translate("Import Success"));
        }
      }
    }

    GridView {
      id: listView
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      cellWidth: width / 2
      cellHeight: 24
      model: config.disabledGenerals
      delegate: Text {
        width: listView.width
        text: {
          const prefix = modelData.split("__")[0];
          let name = Backend.translate(modelData);
          if (prefix !== modelData) {
            name += (" (" + Backend.translate(prefix) + ")");
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
        name: Backend.translate("List") + (i + 1),
      });
    }
    banCombo.currentIndex = config.disableSchemeIdx;
  }
}

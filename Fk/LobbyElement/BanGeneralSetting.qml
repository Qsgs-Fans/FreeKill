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
        text: "禁将方案"
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
        text: "新建"
        onClicked: {
          const i = config.disableGeneralSchemes.length;
          banComboList.append({
            name: "方案" + (i + 1),
          });
          config.disableGeneralSchemes.push([]);
        }
      }

      Button {
        text: "清空"
        onClicked: {
          config.disabledGenerals = [];
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
        name: "方案" + (i + 1),
      });
    }
    banCombo.currentIndex = config.disableSchemeIdx;
  }
}

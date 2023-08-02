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

    Text {
      Layout.fillWidth: true
      Layout.margins: 8
      wrapMode: Text.WrapAnywhere
      text: "导出键会将这个方案的内容复制到剪贴板中；" +
        "导入键会自动读取剪贴板，若可以导入则导入，不能导入则报错。"
    }

    RowLayout {
      Button {
        text: "导出"
        onClicked: {
          Backend.copyToClipboard(JSON.stringify(config.disabledGenerals));
          toast.show("该禁将方案已经复制到剪贴板。");
        }
      }

      Button {
        text: "导入"
        onClicked: {
          const str = Backend.readClipboard();
          let data;
          try {
            data = JSON.parse(str);
          } catch (e) {
            toast.show("导入失败：不是合法的JSON字符串。");
            return;
          }
          if (!data instanceof Array) {
            toast.show("导入失败：数据格式不对。");
            return;
          }
          let d = [];
          for (let e of data) {
            if (typeof e === "string" && Backend.translate(e) !== e) {
              d.push(e);
            }
          }
          config.disabledGenerals = d;
          toast.show("导入禁将方案成功。");
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

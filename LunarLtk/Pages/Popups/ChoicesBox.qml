// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import Fk.Components.Common

import LunarLtk
import LunarLtk.Models.Popups

pragma ComponentBehavior: Bound

GraphicsBox {
  id: root

  required property ChoicesModel dataModel
  title.text: dataModel.promptText
  width: contentLoader.width + 16
  height: contentLoader.height + title.height + (okCancel.visible ? okCancel.height : 0) + 24

  readonly property bool isOneLine: contentLoader.sourceComponent === onelineComponent
  property bool noOneLine: false

  onShown: {
    if (isOneLine && dataModel.minNum === 1 && dataModel.maxNum === 1 && !noOneLine && dataModel.single) {
      title.visible = false;
      background.visible = false;
      x = (roomScene.width - root.width) / 2;
      y = roomScene.dashboard.y - 20;
    }
  }

  Loader {
    id: contentLoader
    x: 8
    y: root.title.height + 8

    sourceComponent: {
      if (root.dataModel.detailed) {
        return detailedComponent;
      }

      const maxWidth = 1000;
      const merged = root.dataModel.allChoices.map(v => Ltk.processPrompt(v))
      .join("gksm")
      .replace(/<[^>]*>/g, "");

      const estimatedWidth = merged.length * 16;
      if (estimatedWidth < maxWidth) {
        return onelineComponent;
      }

      return gridComponent;
    }
  }

  RowLayout {
    id: okCancel
    height: childrenRect.height
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 8
    anchors.horizontalCenter: parent.horizontalCenter
    visible: root.dataModel && !root.dataModel.single

    spacing: 16

    MetroButton {
      text: Lua.tr("OK")
      Layout.preferredWidth: 64
      enabled: root.dataModel.feasible
      onClicked: root.dataModel.accepted();
    }

    MetroButton {
      text: Lua.tr("Cancel")
      Layout.preferredWidth: 64
      visible: root.dataModel.cancelable
      onClicked: root.dataModel.rejected();
    }
  }

  // 以下为几种页面样式

  Component {
    id: onelineComponent

    RowLayout {
      spacing: 8

      Repeater {
        model: root.dataModel.allChoices

        MetroButton {
          required property string modelData
          Layout.minimumWidth: 72
          text: Ltk.processPrompt(modelData)
          enabled: root.dataModel.choices.indexOf(modelData) !== -1
          checked: root.dataModel.result.includes(modelData)
          onClicked: {
            root.dataModel.toggleChoose(modelData);
          }
        }
      }
    }
  }

  Component {
    id: gridComponent

    GridLayout {
      flow: GridLayout.TopToBottom
      rows: 8
      columnSpacing: 8

      Repeater {
        model: root.dataModel.allChoices

        MetroButton {
          required property string modelData
          Layout.fillWidth: true
          Layout.minimumWidth: 72
          text: Ltk.processPrompt(modelData)
          enabled: root.dataModel.choices.indexOf(modelData) !== -1
          checked: root.dataModel.result.includes(modelData)
          onClicked: {
            root.dataModel.toggleChoose(modelData);
          }
        }
      }
    }
  }

  Component {
    id: detailedComponent

    ListView {
      model: root.dataModel.allChoices
      clip: true
      width: 800
      height: Math.min(600, contentHeight)
      spacing: 8

      delegate: RowLayout {
        required property string modelData
        spacing: 8
        width: parent.width
        height: Math.max(btn.height, desc.height)

        MetroButton {
          id: btn
          Layout.alignment: Qt.AlignVCenter
          Layout.preferredWidth: 160
          text: Ltk.processPrompt(parent.modelData)
          textFont.pixelSize: 18
          enabled: root.dataModel.choices.indexOf(parent.modelData) !== -1
          checked: root.dataModel.result.includes(parent.modelData)
          onClicked: {
            root.dataModel.toggleChoose(parent.modelData);
          }
        }

        Text {
          id: desc
          Layout.alignment: Qt.AlignVCenter
          Layout.fillWidth: true
          text: {
            const raw = ":" + parent.modelData;
            const ret = Lua.tr(raw);
            if (ret === raw) return "";
            return ret;
          }
          color: "#E4D5A0"
          font.pixelSize: 16
          wrapMode: Text.WordWrap
          textFormat: Text.RichText
        }
      }
    }
  }
}

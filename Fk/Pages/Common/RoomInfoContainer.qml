import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import Fk.Components.WaitingRoom
import Fk.Widgets as W
import LunarLtk

Item {
  id: root

  property bool viewFalse: false
  property Item scrollBarParent: parent
  property var settings: []
  property int columnCount: width >= 900 ? 3 : width >= 520 ? 2 : 1
  property color switchBackgroundColor: "transparent"
  property color switchBorderColor: "transparent"
  property int footerHeight: 52

  signal generalPoolRequested()

  Component.onCompleted: setDataList()

  function getSettingKey(prop, mainKey) {
    const data = Lua.client.settings;
    const value = data?.[mainKey]?.[prop['_settingsKey']];
    const key = prop.title;
    if (typeof value === "boolean") {
      const tr = Lua.hasTranslate("#" + key);
      const trNega = Lua.hasTranslate("#!" + key);
      if (tr) {
        return value ? [tr]: (trNega ? [trNega] : [Lua.tr(prop.title), Lua.tr(value)]);
      }
    }

    return [Lua.tr(prop.title), Lua.tr(value)];
  }

  function setDataList() {
    let _settings = [];
    const data = Lua.client.settings;
    let cardpack = Ltk.getAllCardPack();
    cardpack = cardpack.filter(p => !data.disabledPack.includes(p));
    const gameMode = data.gameMode;
    const boardgameSettingsData = Lua.getUIDataOfSettings(gameMode, data, true);
    const gameSettingsData = Lua.getUIDataOfSettings(gameMode, data, false);

    _settings.push([Lua.tr("GameMode"), Lua.tr(gameMode)]);
    _settings.push([Lua.tr("ResponseTime"), Config.roomTimeout]);
    for (const group of boardgameSettingsData) {
      for (const prop of group['_children']) {
        _settings.push(getSettingKey(prop, "_game"));
      }
    }
    for (const group of gameSettingsData) {
      for (const prop of group['_children']) {
        _settings.push(getSettingKey(prop, "_mode"));
      }
    }
    // TODO：往下一堆实质都是ltk特化，其他桌游要定制呢？
    if (Lua.ev(`Fk:getBoardGame('${gameMode}').name == 'lunarltk'`)) {
      _settings.push([Lua.tr("General Pool"), "1"]);
      _settings.push([Lua.tr('CardPackages'), cardpack.map(e => {
        let ret = Lua.tr(e);
        if (ret.search(/特殊牌|衍生牌/) === -1) {
          ret = "<b>" + ret + "</b>";
        }
        return ret;
      }).join('，')]);
    }
    settings = _settings;
  }

  Flickable {
    id: infoContainer

    ScrollBar.vertical: ScrollBar {
      parent: root.scrollBarParent
      anchors.top: infoContainer.top
      anchors.right: infoContainer.right
      anchors.rightMargin: -12
      anchors.bottom: infoContainer.bottom
      width: 8
    }

    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: filterBar.top
    anchors.bottomMargin: 10
    flickableDirection: Flickable.VerticalFlick
    contentHeight: roominfo.height
    clip: true

    GridLayout {
      id: roominfo
      width: parent.width
      columns: root.columnCount
      columnSpacing: 28
      rowSpacing: 8

      Repeater {
        model: root.settings

        Item {
          Layout.fillWidth: true
          Layout.preferredWidth: (roominfo.width - roominfo.columnSpacing * (root.columnCount - 1)) / root.columnCount
          Layout.columnSpan: wideRow ? root.columnCount : 1
          Layout.preferredHeight: Math.max(30, keyText.height)
          height: Math.max(30, keyText.height)
          required property var modelData
          property bool wideRow: {
            const value = modelData[1];
            return typeof value === "string" && value.length > 18;
          }
          visible: {
            if (root.viewFalse) return true;
            const value = modelData[1];
            return value !== "false" && value !== "" && value !== "否";
          }

          Text {
            id: titleText
            anchors.left: parent.left
            anchors.right: keyText.left
            anchors.rightMargin: 8
            text: parent.modelData[0]
            color: '#5e5e5e'
            font.pixelSize: 14
            elide: Text.ElideRight
          }

          Text {
            id: keyText
            anchors.right: parent.right
            width: parent.wideRow ? parent.width - titleText.implicitWidth - 10
              : Math.max(parent.width * 0.45, parent.width - titleText.implicitWidth - 10)
            horizontalAlignment: Text.AlignRight
            visible: parent.modelData[0] !== Lua.tr("General Pool") // TODO：ltk特化，其他桌游呢？
            text: {
              const str = parent.modelData[1];
              if (typeof str !== "string") return "";
              if (str === "true") return Lua.tr("True");
              if (str === "false") return Lua.tr("False");
              return str;
            }
            color: '#222222'
            font.pixelSize: 14
            wrapMode: Text.WordWrap
          }

          WButton {
            visible: parent.modelData[0] === Lua.tr("General Pool") // TODO：ltk特化，其他桌游呢？
            anchors.right: parent.right
            height: 20
            width: Math.min(140, parent.width)
            text: Lua.tr("View General Pool")
            textFont.pixelSize: 14
            title.color: '#e1f5f3'
            bg.radius: 10
            bg.color: '#8eb1ab'
            border.width: 0

            onClicked: root.generalPoolRequested()
          }
        }
      }
    }
  }

  W.SwitchRow {
    id: filterBar
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    rowHeight: root.footerHeight
    backgroundColor: root.switchBackgroundColor
    borderColor: root.switchBorderColor
    title: Lua.tr("View False Settings")

    checked: root.viewFalse
    onCheckedChanged: root.viewFalse = checked;
  }
}

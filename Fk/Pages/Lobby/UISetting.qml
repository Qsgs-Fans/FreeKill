// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import Fk
import Fk.Widgets as W

W.PreferencePage {
  groupWidth: width * 0.8

  Text {
    text: Lua.tr("No available UI package")
    font.bold: true
    color: '#979797'
    font.pixelSize: 30
    visible: boardGameUI.visibleBoardgames.length === 0
  }

  W.PreferenceGroup {
    id: boardGameUI
    property list<string> visibleBoardgames: []
    title: Lua.tr("Game UI settings")
    Repeater {
      id: currentRepeater
      model: getBoardGames()

      W.ComboRow {
        id: selfCombo
        title: Lua.tr(modelData)
        textRole: "translation"
        property list<string> uipaks: currentRepeater.getUIPackagesByBoardGame(modelData)
        visible: uipaks.length > 1 
        model: ListModel {
          id: boardgameListModel
          Component.onCompleted: {
            for (let i = 0; i < uipaks.length; i++) {
              boardgameListModel.append( {name: uipaks[i], translation: Lua.tr(uipaks[i])} )
            }
            if (uipaks.length > 1) {
              boardGameUI.visibleBoardgames.push(modelData)
            }
          }
        }

        onCurrentValueChanged: {
          if (currentValue !== undefined) {
            Config.enabledUIPackages[modelData] = currentValue.name;
          }  
        }

        Component.onCompleted: {
          let index = 0
          const config_ui = Config.enabledUIPackages[modelData] || "default"
          if (config_ui !== "default") {
            selfCombo.setCurrentIndex(uipaks.indexOf(config_ui))
          } else {
            selfCombo.setCurrentIndex(0)
          }
        }
      }

      function getBoardGames() {
        return Lua.evaluate(`(function()
          local names = {}
          for k, v in pairs(Fk.boardgames) do
            table.insertIfNeed(names, k)
          end
          return names
        end)()`)
      }

      function getUIPackagesByBoardGame(boardgame) {
        let list = Lua.evaluate(`(function()
          local list = Fk:listUIPackages() or {}
          return json.encode(list["${boardgame}"] or {})
        end)()`);
        let _list = JSON.parse(list);
        _list.splice(0, 0, "default");
        return _list
      }

      function isRowVisible(name) {
        return Lua.evaluate(`(function()
          return #(Fk:listUIPackages()["${name}"] or {}) > 0
        end)()`);
      }
    }
  }
}

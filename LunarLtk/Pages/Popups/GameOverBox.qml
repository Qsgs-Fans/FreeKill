// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Fk
import Fk.Components.Common

import LunarLtk.Models.Popups

GraphicsBox {
  id: root

  required property GameOverModel dataModel

  property bool summaryShown: true

  title.text: dataModel.titleText
  width: summaryShown ? 780 : 400
  height: queryResultList.height + 96

  TableView {
    id: queryResultList
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(contentWidth, parent.width - 30)
    height: parent.summaryShown ? contentHeight : 0
    y: root.title.height + 10
    clip: true
    columnSpacing: 10
    pressDelay: 500

    rowHeightProvider: () => 34
    columnWidthProvider: (col) => {
      let w = explicitColumnWidth(col);
      if (w >= 0)
        return Math.max(40, w);
      return implicitColumnWidth(col);
    }

    model: root.dataModel.tableModel

    delegate: Text {
      required property string display
      required property int column

      text: display
      color: "#E4D5A0"
      font.pixelSize: 20
      horizontalAlignment: column === 8 ? Text.AlignLeft : Text.AlignHCenter
    }
  }

  ToolButton {
    text: (parent.summaryShown ? "➖" : "➕")
    onClicked: {
      parent.summaryShown = !parent.summaryShown
    }
    anchors.top: parent.top
    anchors.right: parent.right
  }

  RowLayout {
    id: body
    anchors.right: parent.right
    anchors.rightMargin: parent.summaryShown ? 15 : parent.width / 2 - 15 - bkmBtn.width - repBtn.width / 2
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    width: parent.width
    spacing: 15

    Item { Layout.fillWidth: true }
    MetroButton {
      text: Lua.tr("Continue Game")
      visible: root.dataModel.canContinue
      onClicked: root.dataModel.continueGame(root)
    }

    MetroButton {
      text: Lua.tr("Back To Room")
      visible: root.dataModel.canBackToRoom
      onClicked: root.dataModel.backToRoom(root)
    }

    MetroButton {
      text: Lua.tr("Back To Lobby")
      onClicked: root.dataModel.backToLobby(root)
    }

    MetroButton {
      id: repBtn
      text: Lua.tr("Save Replay")
      visible: root.dataModel.canSaveReplay ?? false
      onClicked: root.dataModel.saveReplay(root)
    }

    MetroButton {
      id: bkmBtn
      text: Lua.tr("Bookmark Replay")
      visible: root.dataModel.canBookmarkReplay ?? false
      onClicked: root.dataModel.bookmarkReplay(root)
    }
  }
}

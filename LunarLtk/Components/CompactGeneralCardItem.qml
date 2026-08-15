// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

import Fk
import Fk.Components.GameCommon as Game
import LunarLtk

Game.BasicItem {
  id: root
  width: 64
  height: 64
  clip: true

  required property GeneralCardModel dataModel
  onDataModelChanged: dataModel.cardItem = root;

  Image {
    property bool useSmallPic: !!SkinBank.getGeneralExtraPic(root.dataModel.name, "avatar/")

    anchors.fill: parent
    source: SkinBank.getGeneralExtraPic(root.dataModel.name, "avatar/")
      ?? SkinBank.getGeneralPicture(root.dataModel.name)
    sourceClipRect: useSmallPic ? undefined : Qt.rect(61, 20, 128, 128)
  }

  Rectangle {
    id: prefixTag
    visible: root.dataModel.detailed && root.dataModel.prefix !== ""
    anchors.top: parent.top
    anchors.left: parent.left
    height: 16
    width: childrenRect.width + 4
    color: "#3C3229"
    opacity: 0.8

    Text {
      text: root.dataModel.prefix
      x: 2; y: 1
      font.family: Config.libianName
      font.pixelSize: 14
      color: "white"
      style: Text.Outline
      textFormat: Text.RichText
    }

    transform: Scale {
      xScale: prefixTag.width > root.width ? (root.width / prefixTag.width) : 1
    }
  }

  Rectangle {
    id: nameTag
    visible: root.dataModel.detailed
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    height: 16
    width: childrenRect.width + 4
    color: "snow"
    opacity: 0.8

    Text {
      text: Lua.tr(root.dataModel.name)
      x: 2; y: 1
      font.family: Config.libianName
      font.pixelSize: 14
      color: "black"
      textFormat: Text.RichText
    }

    transform: Scale {
      origin.x: nameTag.width
      origin.y: nameTag.height
      xScale: nameTag.width > root.width ? (root.width / nameTag.width) : 1
    }
  }

  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.width: 1
  }

  Image {
    width: 24; height: 23
    source: SkinBank.miscDir + "favorite"
    visible: Config.favoriteGenerals.includes(parent.dataModel.name) && parent.dataModel.showIsFavorite
    x: -8; y: 48
  }
}


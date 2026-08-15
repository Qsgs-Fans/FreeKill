// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import LunarLtk
import LunarLtk.Components

Flickable {
  id: root
  anchors.fill: parent

  property int cardId

  signal finish()

  contentHeight: details.height
  ScrollBar.vertical: ScrollBar {}

  RowLayout {
    id: details
    width: parent.width - 40
    x: 20
    spacing: 20

    CardItem {
      id: cardPic
      Layout.alignment: Qt.AlignTop
      Layout.topMargin: 10
      dataModel: CardModel {}
    }

    ColumnLayout {
      Text {
        id: screenName
        Layout.fillWidth: true
        font.pixelSize: 18
        color: "#E4D5A0"
      }

      TextEdit {
        id: skillDesc

        property var savedtext: []
        function clearSavedText() {
          savedtext = [];
        }
        Layout.fillWidth: true
        font.pixelSize: 18
        color: "#E4D5A0"

        readOnly: true
        selectByKeyboard: true
        selectByMouse: false
        wrapMode: TextEdit.WordWrap
        textFormat: TextEdit.RichText
        onLinkActivated: (link) => {
          if (link === "back") {
            text = savedtext.pop();
          } else {
            savedtext.push(text);
            text = '<a href="back">' + Lua.tr("Click to back") + '</a><br>' + Lua.tr(link);
          }
        }
      }
    }
  }

  onCardIdChanged: {
    const model = Ltk.createCardModel(cardId);
    const data = Ltk.getCardData(cardId, true);
    model.virtName = data.virt_name ?? "";
    model.selectable = true;
    cardPic.dataModel = model;
    screenName.text = Ltk.getCardName(cardId);
    skillDesc.text = Ltk.getCardDescription(cardId);
  }
}

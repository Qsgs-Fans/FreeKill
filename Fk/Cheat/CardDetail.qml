// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Fk.RoomElement

Flickable {
  id: root
  anchors.fill: parent
  property var extra_data: ({})

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
      cid: 0
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
            text = '<a href="back">' + luatr("Click to back") + '</a><br>' + luatr(link);
          }
        }
      }
    }
  }

  onExtra_dataChanged: {
    const card = extra_data.card;
    if (!card) return;
    cardPic.setData(card.toData());
    const name = card.virt_name ? card.virt_name : card.name;
    screenName.text = luatr(name);
    skillDesc.text = luatr(":" + name);
  }
}

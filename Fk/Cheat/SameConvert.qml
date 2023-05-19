// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Fk.RoomElement

Item {
  id: root
  anchors.fill: parent
  property var extra_data: ({})

  signal finish()

  Flickable {
    height: parent.height
    width: generalButtons.width
    anchors.centerIn: parent
    contentHeight: generalButtons.height
    ScrollBar.vertical: ScrollBar {}
    ColumnLayout {
      id: generalButtons
      Repeater {
        model: ListModel {
          id: glist
        }

        ColumnLayout {
          Text { text: Backend.translate(gname) }
          GridLayout {
            columns: 3

            Repeater {
              model: JSON.parse(Backend.callLuaFunction("GetSameGenerals", [gname]))

              GeneralCardItem {
                name: modelData
                selectable: true

                onClicked: {
                  let idx = 0;
                  for (; idx < extra_data.cards.count; idx++) {
                    if (extra_data.cards.get(idx).name === gname)
                      break;
                  }

                  if (idx < extra_data.cards.count) {
                    extra_data.cards.set(idx, { name: modelData });
                  }
                  root.finish();
                }
              }
            }
          }
        }
      }
    }
  }

  onExtra_dataChanged: {
    if (!extra_data.cards) return;
    for (let i = 0; i < extra_data.cards.count; i++) {
      glist.set(i, { gname: extra_data.cards.get(i).name });
    }
  }
}

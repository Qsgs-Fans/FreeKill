// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Fk
import Fk.Common

Item {
  id: root

  ToolBar {
    id: bar
    width: parent.width
    RowLayout {
      anchors.fill: parent
      ToolButton {
        icon.source: AppPath + "/image/modmaker/back"
        onClicked: mainStack.pop();
      }
      Label {
        text: luatr("Replay Manager")
        horizontalAlignment: Qt.AlignHCenter
        Layout.fillWidth: true
      }
      ToolButton {
        icon.source: AppPath + "/image/modmaker/menu"
        onClicked: menu.open()

        Menu {
          id: menu
          y: bar.height
          MenuItem {
            text: luatr("Replay from File")
            onTriggered: {
              fdialog.open();
            }
          }
        }
      }
    }
  }

  Rectangle {
    width: parent.width
    height: parent.height - bar.height
    anchors.top: bar.bottom
    color: "#A0EFEFEF"
    clip: true

    ListView {
      id: list
      clip: true
      anchors.fill: parent
      model: ListModel {
        id: model
      }
      delegate: Item {
        width: root.width
        height: 64

        Avatar {
          id: generalPic
          width: 48; height: 48
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.margins: 8
          general: _general
        }

        ColumnLayout {
          anchors.left: generalPic.right
          anchors.margins: 8
          Text {
            text: {
              const win = winner.split("+").indexOf(role) !== -1;
              const winStr = win ? luatr("Game Win") : luatr("Game Lose");
              return "<b>" + luatr(_general) + "</b> " + luatr(role)
                   + " " + winStr;
            }
            font.pixelSize: 20
            textFormat: Text.RichText
          }
          Text {
            text: {
              const y = repDate.slice(0,4);
              const month = repDate.slice(4,6);
              const d = repDate.slice(6,8);
              const h = repDate.slice(8,10);
              const m = repDate.slice(10,12);
              const s = repDate.slice(12,14);
              const dateStr = `${y}-${month}-${d} ${h}:${m}:${s}`;

              return playerName + " " + luatr(gameMode) + " " + dateStr
            }
          }
        }

        Button {
          id: replayBtn
          text: luatr("Play the Replay")
          anchors.right: delBtn.left
          anchors.rightMargin: 8
          onClicked: {
            config.observing = true;
            config.replaying = true;
            Backend.playRecord("recording/" + fileName);
          }
        }

        Button {
          id: delBtn
          text: luatr("Delete Replay")
          anchors.right: parent.right
          anchors.rightMargin: 8
          onClicked: {
            Backend.removeRecord(fileName);
            removeModel(index);
          }
        }
      }
    }
  }

  FileDialog {
    id: fdialog
    nameFilters: ["FK Rep Files (*.fk.rep)"];
    onAccepted: {
      config.observing = true;
      config.replaying = true;
      let str = selectedFile.toString(); // QUrl -> string
      Backend.playRecord(str);
    }
  }

  function updateList() {
    model.clear();
    const data = Backend.ls("recording");
    data.reverse();
    data.forEach(s => {
      const d = s.split(".");
      if (d.length !== 8) return;
      // s: <time>.<screenName>.<mode>.<general>.<role>.<winner>.fk.rep
      const [t, name, mode, general, role, winner] = d;

      model.append({
        fileName: s,
        repDate: t,
        playerName: name,
        gameMode: mode,
        _general: general,
        role: role,
        winner: winner,
      })
    });
  }

  function removeModel(index) {
    model.remove(index);
  }

  Component.onCompleted: {
    updateList();
  }
}

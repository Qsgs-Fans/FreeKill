// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import Fk
import Fk.Components.Common
import Fk.Widgets as W

Item {
  id: root

  Rectangle {
    id: replayList
    width: parent.width - replayDetail.width - 20
    height: parent.height - 20
    y: 10
    color: "#A0EFEFEF"
    radius: 8
    clip: true

    ListView {
      id: list
      clip: true
      anchors.fill: parent
      highlight: Rectangle { color: "lightsteelblue"; radius: 5 }
      highlightMoveDuration: 300
      model: ListModel {
        id: model
      }
      delegate: Item {
        width: replayList.width
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
          anchors.leftMargin: 8
          anchors.topMargin: 12
          Text {
            text: {
              const win = winner.split("+").indexOf(role) !== -1;
              const winStr = win ? Lua.tr("Game Win") : Lua.tr("Game Lose");
              return "<b>" + Lua.tr(_general) + "</b> " + Lua.tr(role)
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

              return playerName + " " + Lua.tr(gameMode) + " " + dateStr
            }
          }
        }

        Text {
          text: query?.my_comment ?? ""
          font.pixelSize: 20
          anchors.right: parent.right
          anchors.rightMargin: 4
          anchors.verticalCenter: parent.verticalCenter
        }

        W.TapHandler {
          onTapped: {
            if (list.currentIndex === index) {
              list.currentIndex = -1;
            } else {
              list.currentIndex = index;
            }
            commentEdit.updateText();
          }
        }
      }
    }
  }

  Rectangle {
    id: replayDetail
    width: 310
    height: parent.height - 20
    y: 10
    anchors.right: parent.right
    anchors.rightMargin: 10
    color: "#88EEEEEE"
    radius: 8

    Flickable {
      id: detailFlickable
      flickableDirection: Flickable.VerticalFlick
      contentHeight: detailLayout.height
      width: parent.width - 40
      height: parent.height - 40
      clip: true
      anchors.centerIn: parent
      ScrollBar.vertical: ScrollBar {}

      ColumnLayout {
        id: detailLayout
        width: parent.width

        TextField {
          id: commentEdit
          Layout.fillWidth: true
          placeholderText: Lua.tr("Note")
          enabled: list.currentIndex !== -1;
          function updateText() {
            const mdata = model.get(list.currentIndex);
            if (!mdata) return "";
            text = mdata.query?.my_comment ?? "";
          }
          onTextChanged: {
            if (!ClientInstance.checkSqlString(text)) return;
            const mdata = model.get(list.currentIndex);
            if (!mdata) return;
            Cpp.sqlquery(`REPLACE INTO starredRecording (id, replay_name, my_comment)
            VALUES (${mdata.query?.id ?? 'NULL'}, '${mdata.fileName}', '${text}');`);

            mdata.query = Cpp.sqlquery(
              `SELECT * FROM starredRecording WHERE replay_name = '${mdata.fileName}';`)[0];
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Button {
            id: replayBtn
            text: Lua.tr("Play the Replay")
            enabled: list.currentIndex !== -1
            Layout.fillWidth: true
            onClicked: {
              Config.observing = true;
              Config.replaying = true;
              const mdata = model.get(list.currentIndex);
              Backend.playRecord("recording/" + mdata.fileName);
            }
          }

          Button {
            id: delBtn
            text: Lua.tr("Delete Replay")
            enabled: list.currentIndex !== -1
            Layout.fillWidth: true
            onClicked: {
              const mdata = model.get(list.currentIndex);
              if (!mdata) return;
              const sql = (`DELETE FROM starredRecording WHERE
              replay_name = '${mdata.fileName}';`);
              Backend.removeRecord(mdata.fileName);
              model.remove(list.currentIndex);
              Cpp.sqlquery(sql);
            }
          }
        }

        Button {
          text: Lua.tr("Replay from File")
          Layout.fillWidth: true
          onClicked: {
            fdialog.open();
          }
        }
      }
    }
  }

  FileDialog {
    id: fdialog
    nameFilters: ["FK Rep Files (*.fk.rep)"];
    onAccepted: {
      Config.observing = true;
      Config.replaying = true;
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
      const query = Cpp.sqlquery(`SELECT * FROM starredRecording WHERE replay_name = '${s}';`)[0] ?? {};
      if (query.id === "#null") {
        query.id = null;
      } else {
        query.id = parseInt(query.id);
        if (query.id !== query.id)
          query.id = null;
      }

      model.append({
        fileName: s,
        repDate: t, // 开始时间
        playerName: name,
        gameMode: mode,
        _general: general,
        role: role,
        winner,
        query,
      })
    });
  }

  Component.onCompleted: {
    updateList();
  }
}

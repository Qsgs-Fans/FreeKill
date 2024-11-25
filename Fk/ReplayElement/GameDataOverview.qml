import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Fk.Common

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
      delegate: RowLayout {
        width: replayList.width
        height: 64

        Avatar {
          id: generalPic
          Layout.preferredWidth: 24
          Layout.preferredHeight: 24
          general: general
        }

        Text {
          text: {
            return ((result === "1") ? luatr("Game Win") : luatr("Game Lose"));
          }
        }

        Text {
          text: luatr(mode)
        }

        Text {
          text: luatr(role)
        }

        Text {
          text: {
            const date = new Date(time * 1000);
            return date.toLocaleString();
          }
        }

        TapHandler {
          onTapped: {
            if (list.currentIndex === index) {
              list.currentIndex = -1;
            } else {
              list.currentIndex = index;
            }
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

        Button {
          id: replayBtn
          text: {
            let ret = "重放录像";
            const mdata = model.get(list.currentIndex);
            if (!mdata) return ret;
            const query = ClientInstance.execSql(`
              SELECT * FROM myGameRecordings WHERE id = ${mdata.id};`);
            if (!query[0]) {
              ret = "录像已过期";
            }
            return ret;
          }
          enabled: {
            if (list.currentIndex === -1) return false;
            if (text === "录像已过期") return false;
            return true;
          }
          Layout.fillWidth: true
          onClicked: {
            config.observing = true;
            config.replaying = true;
            const mdata = model.get(list.currentIndex);
            Backend.playBlobRecord(mdata.id);
          }
        }

        Button {
          text: {
            let ret = "查看终盘战况";
            const mdata = model.get(list.currentIndex);
            if (!mdata) return ret;
            const query = ClientInstance.execSql(`
              SELECT * FROM myGameRoomData WHERE id = ${mdata.id};`);
            if (!query[0]) {
              ret = "终盘已过期";
            }
            return ret;
          }
          enabled: {
            if (list.currentIndex === -1) return false;
            if (text === "终盘已过期") return false;
            return true;
          }
          Layout.fillWidth: true
          onClicked: {
            config.observing = true;
            config.replaying = true;
            const mdata = model.get(list.currentIndex);
            Backend.reviewGameOverScene(mdata.id);
          }
        }

        Button {
          text: {
            let ret = "收藏录像";
            const mdata = model.get(list.currentIndex);
            if (!mdata) return ret;
            const query = ClientInstance.execSql(`
              SELECT * FROM starredRecording WHERE id = ${mdata.id};`);
            if (query[0]) {
              ret = "已收藏";
            }
            return ret;
          }
          enabled: {
            if (list.currentIndex === -1) return false;
            if (text === "已收藏") return false;
            if (replayBtn.text === "录像已过期") return false;
            return true;
          }
          Layout.fillWidth: true
          onClicked: {
          }
        }
      }
    }
  }

  Component.onCompleted: {
    model.clear();
    const data = ClientInstance.getMyGameData();
    data.forEach(s => {
      model.append(s);
    });
  }
}

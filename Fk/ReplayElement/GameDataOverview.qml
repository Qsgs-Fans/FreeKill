import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Fk.Common

Item {
  id: root

  Rectangle {
    id: replayList
    width: parent.width - 120 //- replayDetail.width - 20
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
      delegate: ColumnLayout{
        width: replayList.width
        height: list.currentIndex === index ? 114 : 64
        Behavior on height { NumberAnimation { duration: 200 } }
        spacing: -8

        RowLayout {
          width: parent.width
          height: 64
          Behavior on height { NumberAnimation { duration: 200 } }

          Item {
            Layout.preferredWidth: 80
            Layout.preferredHeight: 64
            property string g: general
            Avatar {
              id: avatar
              x: deputy_general ? 0 : 20
              y: 2
              width: 40
              height: 40
              general: parent.g
            }

            Avatar {
              anchors.left: avatar.right
              y: 2
              width: 40
              height: 40
              visible: !!deputy_general
              general: deputy_general || "diaochan"
            }

            Text {
              anchors.top: avatar.bottom
              anchors.topMargin: 2
              anchors.horizontalCenter: parent.horizontalCenter
              text: {
                let ret = luatr(general);
                if (deputy_general) {
                  ret += "/" + luatr(deputy_general);
                }
                return ret;
              }
            }
          }

          Text {
            Layout.preferredWidth: 60
            font.pixelSize: 20
            horizontalAlignment: Text.AlignHCenter
            // Layout.alignment: Qt.AlignTop
            text: {
              return ((result === 1) ? luatr("Game Win") : ((result === 2) ? luatr("Game Lose") : luatr("Game Draw")));
            }
          }

          Text {
            font.pixelSize: 20
            Layout.preferredWidth: 100
            horizontalAlignment: Text.AlignHCenter
            text: luatr(mode)
          }

          Text {
            font.pixelSize: 20
            Layout.preferredWidth: 60
            horizontalAlignment: Text.AlignHCenter
            text: luatr(role)
          }

          Text {
            font.pixelSize: 20
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            text: {
              const date = new Date(time * 1000);
              return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()} ${addZero(date.getHours())}:${addZero(date.getMinutes())}:${addZero(date.getSeconds())}` // 结束时间
            }
          }
        }
        RowLayout {
          width: parent.width
          height: list.currentIndex === index ? 40 : 0
          Behavior on height { NumberAnimation { duration: 200 } }
          visible: list.currentIndex === index
          Behavior on opacity { OpacityAnimator { duration: 200 } }

          Button {
            id: replayBtn
            text: {
              let ret = luatr("Replay Recording"); // 重放录像
              const query = sqlquery(`
                SELECT * FROM myGameRecordings WHERE id = ${id};`);
              if (!query[0]) {
                ret = luatr("Replay Expired"); // 录像已过期
              }
              return ret;
            }
            enabled: {
              if (list.currentIndex === -1) return false;
              if (text === luatr("Replay Expired")) return false;
              return true;
            }
            Layout.fillWidth: true
            onClicked: {
              config.observing = true;
              config.replaying = true;
              //const mdata = model.get(list.currentIndex);
              Backend.playBlobRecord(id);
            }
          }

          Button {
            text: {
              let ret = luatr("View Endgame"); // 查看终盘战况
              const query = sqlquery(`
                SELECT * FROM myGameRoomData WHERE id = ${id};`);
              if (!query[0]) {
                ret = luatr("Endgame Expired"); // 终盘已过期
              }
              return ret;
            }
            enabled: {
              if (list.currentIndex === -1) return false;
              if (text === luatr("Endgame Expired")) return false;
              return true;
            }
            Layout.fillWidth: true
            onClicked: {
              config.observing = true;
              config.replaying = true;
              Backend.reviewGameOverScene(id);
            }
          }

          Button {
            text: {
              let ret = luatr("Bookmark Replay"); // 收藏录像
              const query = sqlquery(`
                SELECT * FROM starredRecording WHERE id = ${id};`);
              if (query[0]) {
                ret = luatr("Already Bookmarked"); // 已收藏
              }
              return ret;
            }
            enabled: {
              if (list.currentIndex === -1) return false;
              if (text === luatr("Already Bookmarked")) return false;
              if (replayBtn.text === luatr("Replay Expired")) return false; // 录像已过期
              return true;
            }
            Layout.fillWidth: true
            onClicked: {
              const fileName = Backend.saveBlobRecordToFile(id);
              sqlquery(`REPLACE INTO starredRecording (id, replay_name, my_comment)
              VALUES (${id}, '${fileName + '.fk.rep'}', '⭐');`);
              list.currentIndexChanged();
            }
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

  Component.onCompleted: {
    model.clear();
    const data = ClientInstance.getMyGameData();
    data.forEach(s => {
      s.id = parseInt(s.id);
      s.time = parseInt(s.time);
      s.pid = parseInt(s.pid);
      s.result = parseInt(s.result);
      model.append(s);
    });
  }

  function addZero(temp) {
    if (temp < 10) return "0" + temp;
    else return temp;
  }
}

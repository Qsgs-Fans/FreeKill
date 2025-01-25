// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Fk.Pages
import Fk.Common

GraphicsBox {
  property string winner: ""
  property string my_role: "" // 拿不到Self.role
  property var summary: []

  id: root
  title.text: winner !== "" ? (winner.split("+").indexOf(my_role)=== -1 ?
                              luatr("Game Lose") : luatr("Game Win"))
                            : luatr("Game Draw")
  width: 600
  height: 350

  Rectangle {
    id: queryResultList
    anchors.horizontalCenter: parent.horizontalCenter
    width: parent.width - 30
    height: parent.height - 30 - body.height - title.height
    y: title.height + 10
    color: "#A0EFEFEF"
    radius: 8
    clip: true

    Text {
      text: ""
    }
    ListView {
      id: resultList
      clip: true
      anchors.fill: parent
      width: parent.width - 5
      model: ListModel {
        id: model
      }
      delegate: RowLayout {
        width: resultList.width
        height: 40

        /*
        Item {
          Layout.preferredWidth: 80
          Layout.preferredHeight: parent.height
          property string g: general
          Avatar {
            id: avatar
            x: deputy ? 0 : 20
            y: 2
            width: 40
            height: 40
            detailed: true
            visible: index !== 0
            general: parent.g
          }

          Avatar {
            anchors.left: avatar.right
            y: 2
            width: 40
            height: 40
            detailed: true
            visible: !!deputy && index !== 0
            general: deputy || "diaochan"
          }

          Text { // 右边大字；不能居中，丑死
            anchors.left: avatar.right
            anchors.leftMargin: 4
            font.pixelSize: 20
            font.bold: index === 0
            horizontalAlignment: Text.AlignHCenter
            text: {
              let ret = luatr(general);
              if (deputy) {
                ret += "/" + luatr(deputy);
              }
              return ret;
            }
          }

          Text { // 下边小字；要拉大行距
            anchors.top: avatar.bottom
            anchors.topMargin: 2
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
              let ret = luatr(general);
              if (deputy) {
                ret += "/" + luatr(deputy);
              }
              return ret;
            }
          }
        }
        */

        Text {
          id: generalText
          Layout.preferredWidth: 100
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 18
          font.bold: index === 0
          text: {
            let ret = luatr(general);
            if (deputy) {
              ret += "/" + luatr(deputy);
            }
            return ret;
          }
          elide: Text.ElideRight
          MouseArea{
            id: genralMa
            hoverEnabled: true
            anchors.fill: parent
          }

          ToolTip{
            height: 25
            x: 20
            y: 20
            visible: genralMa.containsMouse && generalText.contentWidth > 95 // 98不行
            contentItem: Text {
              text: {
                let ret = luatr(general);
                if (deputy) {
                  ret += "/" + luatr(deputy);
                }
                return ret;
              }
              color: "#D6D6D6"
            }
            background: Rectangle {
              color: "#222222"
            }
          }
        }
        Text {
          id: scnameText
          Layout.preferredWidth: 100
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 18
          font.bold: index === 0
          text: scname
          elide: Text.ElideRight
          MouseArea{
            id: nameMa
            hoverEnabled: true
            anchors.fill: parent
          }

          ToolTip{
            height: 25
            x: 20
            y: 20
            visible: nameMa.containsMouse && scnameText.contentWidth > 95 // 98不行
            contentItem: Text {
              text: scname
              color: "#D6D6D6"
            }
            background: Rectangle {
              color: "#222222"
            }
          }
        }
        Text {
          Layout.preferredWidth: 50
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 20
          font.bold: index === 0
          text: { return luatr(role); }
        }
        Text {
          Layout.preferredWidth: 50
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 20
          font.bold: index === 0
          text: turn
        }
        Text {
          Layout.preferredWidth: 50
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 20
          font.bold: index === 0
          text: recover
        }
        Text {
          Layout.preferredWidth: 50
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 20
          font.bold: index === 0
          text: damage
        }
        Text {
          Layout.preferredWidth: 50
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 20
          font.bold: index === 0
          text: damaged
        }
        Text {
          Layout.preferredWidth: 50
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 20
          font.bold: index === 0
          text: kill
        }
      }
    }
  }
  
  RowLayout {
    id: body
    anchors.right: parent.right
    anchors.rightMargin: 15
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    width: parent.width
    spacing: 15

    Item { Layout.fillWidth: true }
    MetroButton {
      text: luatr("Back To Room")
      visible: !config.observing

      onClicked: {
        roomScene.resetToInit();
        finished();
      }
    }

    MetroButton {
      text: luatr("Back To Lobby")

      onClicked: {
        if (config.replaying) {
          mainStack.pop();
          Backend.controlReplayer("shutdown");
        } else {
          ClientInstance.notifyServer("QuitRoom", "[]");
        }
      }
    }

    MetroButton {
      id: repBtn
      text: luatr("Save Replay")
      visible: config.observing && !config.replaying // 旁观

      onClicked: {
        repBtn.visible = false;
        lcall("SaveRecord");
        toast.show("OK.");
      }
    }

    MetroButton {
      id: bkmBtn
      text: luatr("Bookmark Replay")
      visible: !config.observing && !config.replaying // 玩家

      onClicked: {
        bkmBtn.visible = false;
        Backend.saveBlobRecordToFile(ClientInstance.getMyGameData()[0].id); // 建立在自动保存录像基础上
        toast.show("OK.");
      }
    }
  }

  function getSummary() {
    const summaryData = leval("ClientInstance.banners['GameSummary']");
    model.append({
      general: luatr("General"),
      scname: luatr("Name"),
      role: luatr("Role"),
      turn: luatr("Turn"),
      recover: luatr("Recover"),
      damage: luatr("Damage"),
      damaged: luatr("Damaged"),
      kill: luatr("Kill"),
      //handcards: luatr("Handcards"),
    });
    summaryData.forEach(s => {

      s.turn = s.turn.toString();
      s.recover = s.recover.toString();
      s.damage = s.damage.toString();
      s.damaged = s.damaged.toString();
      s.kill = s.kill.toString();
      model.append(s);
    });
  }

  onWinnerChanged: {
    Backend.playSound("./audio/system/" + (winner !== "" ? (winner.split("+").indexOf(my_role)=== -1 ?
                          "lose" : "win")
                        : "draw"));
  }

  Component.onCompleted: {
    my_role = leval("Self.role");
    getSummary();
  }
}

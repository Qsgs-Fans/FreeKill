// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
  id: root
  anchors.fill: parent
  property var extra_data: ({})
  property int pid

  signal finish()

  contentHeight: details.height
  ScrollBar.vertical: ScrollBar {}

  ColumnLayout {
    id: details
    width: parent.width - 40
    x: 20

    RowLayout {
      Button {
        text: Backend.translate("Give Flower")
        onClicked: {
          root.givePresent("Flower");
          root.finish();
        }
      }

      Button {
        text: Backend.translate("Give Egg")
        onClicked: {
          if (Math.random() < 0.03) {
            root.givePresent("GiantEgg");
          } else {
            root.givePresent("Egg");
          }
          root.finish();
        }
      }

      Button {
        text: Backend.translate("Give Shoe")
        enabled: Math.random() < 0.3
        onClicked: {
          root.givePresent("Shoe");
          root.finish();
        }
      }

      Button {
        text: Backend.translate("Kick From Room")
        visible: !roomScene.isStarted && roomScene.isOwner
        enabled: pid !== Self.id
        onClicked: {
          ClientInstance.notifyServer("KickPlayer", pid.toString());
          root.finish();
        }
      }
    }

    // TODO: player details
    Text {
      id: screenName
      Layout.fillWidth: true
      font.pixelSize: 18
    }

    TextEdit {
      id: skillDesc

      Layout.fillWidth: true
      font.pixelSize: 18

      readOnly: true
      selectByKeyboard: true
      selectByMouse: false
      wrapMode: TextEdit.WordWrap
      textFormat: TextEdit.RichText
    }
  }

  function givePresent(p) {
    ClientInstance.notifyServer(
      "Chat",
      JSON.stringify({
        type: 2,
        msg: "$!" + p + ":" + pid
      })
    );
  }

  onExtra_dataChanged: {
    if (!extra_data.photo) return;
    screenName.text = "";
    skillDesc.text = "";

    let id = extra_data.photo.playerid;
    if (id == 0) return;
    root.pid = id;

    screenName.text = extra_data.photo.screenName;

    let data = JSON.parse(Backend.callLuaFunction("GetPlayerSkills", [id]));
    data.forEach(t => {
      skillDesc.append("<b>" + Backend.translate(t.name) + "</b>: " + t.description)
    });
  }
}

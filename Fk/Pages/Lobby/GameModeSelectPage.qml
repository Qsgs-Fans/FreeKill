import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import Fk.Widgets as W

Item {
  id: root

  property string gameMode

  ButtonGroup { id: buttonGroup }
  ListView {
    id: morePagesListView
    y: 10
    clip: true
    height: parent.height - 10
    width: parent.width - 20
    anchors.horizontalCenter: parent.horizontalCenter

    spacing: 16

    model: ListModel {
      id: morePagesModel
    }

    delegate: ColumnLayout {
      width: morePagesListView.width

      Text {
        text: Lua.tr(pkname)
        font.pixelSize: 18
        // font.bold: true
        textFormat: Text.RichText
        wrapMode: Text.WrapAnywhere
        Layout.fillWidth: true
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 2
        color: "black"
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.4; color: "black" }
          GradientStop { position: 0.6; color: "transparent" }
        }
      }

      Item {
        Layout.preferredHeight: 4
      }

      GridLayout {
        // Layout.preferredWidth: parent.width
        columns: 4
        Repeater {
          model: modes
          delegate: RadioButton {
            text: Lua.tr(name)
            // Layout.fillWidth: true
            Layout.preferredWidth: morePagesListView.width / 4
            ButtonGroup.group: buttonGroup

            checked: root.gameMode === name
            onCheckedChanged: {
              if (checked) {
                root.gameMode = name;
                Config.preferedMode = name;
              }
            }
          }
        }
      }
    }
  }

  Component.onCompleted: {
    gameMode = Config.preferedMode;

    const modeData = Lua.fn(`function()
      local pkgs = table.map(table.filter(Fk.package_names, function(name)
        return #Fk.packages[name].game_modes > 0
      end), function(name)
        return {
          name = name,
          modes = table.map(Fk.packages[name].game_modes, function(v)
            return {
              name = v.name,
              minPlayer = v.minPlayer,
              maxPlayer = v.maxPlayer,
            }
          end),
        }
      end)

      return pkgs
    end`)();

    for (const v of modeData) {
      morePagesModel.append({
        pkname: v.name,
        modes: v.modes,
      });
    }

    // const mode_data = Lua.call("GetGameModes");
    // let i = 0;
    // for (const d of mode_data) {
    //   gameModeList.append(d);
    //   if (d.orig_name === gameMode) {
    //     gameModeCombo.setCurrentIndex(i);
    //   }
    //   i += 1;
    // }

  }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
  id: root
  height: parent.height
  width: layout.width
  anchors.fill: parent
  anchors.margins: 16
  clip: true
  contentWidth: layout.width
  contentHeight: layout.height
  ScrollBar.vertical: ScrollBar {}
  ScrollBar.horizontal: ScrollBar {} // considering long game mode name

  signal finished()

  ColumnLayout {
    id: layout
    anchors.top: parent.top

    Item { Layout.fillHeight: true }

    // roomId, roomName, gameMode, playerNum, capacity, hasPassword, outdated

    GridLayout {
      columns: 2

      // roomName
      RowLayout {
        anchors.rightMargin: 8
        spacing: 16
        Text {
          text: luatr("Room Name")
          font.bold: true
          font.pixelSize: 14
        }
        TextField {
          id: name
          maximumLength: 64
          font.pixelSize: 18
          Layout.rightMargin: 16
          Layout.fillWidth: true
          text: config.preferredFilter.name
        }
      }

      // roomId
      RowLayout {
        anchors.rightMargin: 8
        spacing: 16
        Text {
          text: luatr("Room ID")
          font.bold: true
          font.pixelSize: 14
        }
        TextField {
          id: id
          maximumLength: 64
          font.pixelSize: 18
          Layout.rightMargin: 16
          Layout.fillWidth: true
          text: config.preferredFilter.id
        }
      }
    }

    // gameMode
    ButtonGroup {
      id: childModes
      exclusive: false
      checkState: parentModeBox.checkState
    }

    CheckBox {
      id: parentModeBox
      text: luatr("Game Mode")
      font.bold: true
      checkState: childModes.checkState
    }
    GridLayout {
      columns: 6

      Repeater {
        id: modes
        model: ListModel {
          id: gameModeList
        }

        CheckBox {
          text: name
          checked: config.preferredFilter.modes.includes(name)
          leftPadding: indicator.width
          ButtonGroup.group: childModes
        }
      }
    }

    RowLayout {
      anchors.rightMargin: 8
      // spacing: 64
      // Layout.fillWidth: true

      // full
      Column {
        ButtonGroup {
          id: childFull
          exclusive: false
          checkState: parentFullBox.checkState
        }

        CheckBox {
          id: parentFullBox
          text: luatr("Room Fullness")
          font.bold: true
          checkState: childFull.checkState
        }

        GridLayout {
          columns: 6

          Repeater {
            id: fullStates
            model: ["Full", "Not Full"]

            CheckBox {
              text: luatr(modelData)
              checked: config.preferredFilter.full === index
              leftPadding: indicator.width
              ButtonGroup.group: childFull
            }
          }
        }
      }

      // hasPassword
      Column {
        ButtonGroup {
          id: childPw
          exclusive: false
          checkState: parentPwBox.checkState
        }

        CheckBox {
          id: parentPwBox
          text: luatr("Room Password")
          font.bold: true
          checkState: childPw.checkState
        }

        GridLayout {
          columns: 6

          Repeater {
            id: pwStates
            model: ["Has Password", "No Password"]

            CheckBox {
              text: luatr(modelData)
              checked: config.preferredFilter.hasPassword === index
              leftPadding: indicator.width
              ButtonGroup.group: childPw
            }
          }
        }
      }

      Button {
        text: luatr("Clear")
        onClicked: {
          opTimer.start();
          config.preferredFilter = {
            name: "",
            id: "",
            modes : [],
            full : 2,
            hasPassword : 2,
          }
          config.preferredFilterChanged();
          ClientInstance.notifyServer("RefreshRoomList", "");
          lobby_dialog.item.finished();
        }
      }

      Button {
        text: luatr("OK")
        // width: 200
        // enabled: !opTimer.running
        onClicked: {
          // opTimer.start();
          filterRoom();
          root.finished();
        }
      }
    }

    // capacity
    /*
    Column {
      ButtonGroup {
        id: childCapacity
        exclusive: false
        checkState: parentCapacityBox.checkState
      }

      CheckBox {
        id: parentCapacityBox
        text: luatr("Room Capacity")
        font.bold: true
        checkState: childCapacity.checkState
      }

      GridLayout {
        columns: 6

        Repeater {
          id: capacityStates
          model: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]

          CheckBox {
            text: modelData
            checked: false
            leftPadding: indicator.width
            ButtonGroup.group: childCapacity
          }
        }
      }
    }
    */

    Component.onCompleted: {
      const mode_data = lcall("GetGameModes");
      mode_data.forEach(d => {
        gameModeList.append(d);
      });
    }
  }
  function filterRoom() {
    let f = config.preferredFilter;

    f.name = name.text; // 字符串
    f.id = id.text; // 字符串

    // mode
    let modeList = [];
    if (parentModeBox.checkState === Qt.PartiallyChecked) {
      for (let index = 0; index < modes.count; index++) {
        var tCheckBox = modes.itemAt(index)
        if (tCheckBox.checked) {modeList.push(tCheckBox.text)}
      }
    }
    f.modes = modeList; // 翻译后的模式名数组

    f.full = parentFullBox.checkState === Qt.PartiallyChecked ? (fullStates.itemAt(0).checked ? 0 : 1) : 2; // 0: full, 1: not full, 2: all
    f.hasPassword = parentPwBox.checkState === Qt.PartiallyChecked ? (pwStates.itemAt(0).checked ? 0 : 1) : 2; // 0: has password, 1: no password, 2: all

    // capacity
    /*
    let capacityList = [];
    if (parentCapacityBox.checkState === Qt.PartiallyChecked) {
      for (let index = 0; index < capacityStates.count; index++) {
        var nCheckBox = capacityStates.itemAt(index)
        if (nCheckBox.checked) {capacityList.push(parseInt(nCheckBox.text))}
      }
    }
    */

    config.preferredFilterChanged();

    for (let i = roomModel.count - 1; i >= 0; i--) {
      const r = roomModel.get(i);
      if ((name.text !== '' && !r.roomName.includes(name.text))
        || (id.text !== '' && !r.roomId.toString().includes(id.text))
        || (modeList.length > 0 && !modeList.includes(luatr(r.gameMode)))
        || (f.full !== 2 &&
          (f.full === 0 ? r.playerNum < r.capacity : r.playerNum >= r.capacity))
        || (f.hasPassword !== 2 &&
          (f.hasPassword === 0 ? !r.hasPassword : r.hasPassword))
        // || (capacityList.length > 0 && !capacityList.includes(r.capacity))
      ) {
        roomModel.remove(i);
      }
    }
  }
}

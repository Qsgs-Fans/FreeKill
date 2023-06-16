// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Fk.RoomElement

Item {
  id: root
  anchors.fill: parent
  property var generalModel
  property var extra_data: ({})

  signal finish()

  ToolBar {
    id: bar
    width: parent.width
    RowLayout {
      anchors.fill: parent
      ToolButton {
        opacity: stack.depth > 1 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 100 } }
        text: Backend.translate("Back")
        onClicked: stack.pop()
      }
      Label {
        text: Backend.translate("Enable free assign")
        elide: Label.ElideRight
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
        Layout.fillWidth: true
      }
      ToolButton {
        opacity: 0
      }
    }
  }

  StackView {
    id: stack
    width: parent.width
    height: parent.height - bar.height
    anchors.top: bar.bottom
    initialItem: pkgList
  }

  ListModel {
    id: packages
  }

  Component {
    id: pkgList
    GridView {
      id: listView
      width: parent.width
      height: stack.height
      ScrollBar.vertical: ScrollBar {}
      model: packages
      clip: true
      cellWidth: width / 3
      cellHeight: 40

      delegate: ItemDelegate {
        width: listView.width / 3
        height: 40

        Text {
          text: Backend.translate(name)
          anchors.centerIn: parent
        }

        onClicked: {
          generalModel = JSON.parse(Backend.callLuaFunction("GetGenerals",
            [packages.get(index).name]));
          stack.push(generalList);
        }
      }
    }
  }

  Component {
    id: generalList
    ColumnLayout {
      clip: true
      width: stack.width
      height: stack.height
      Item { height: 6 }
      GridView {
        clip: true
        Layout.preferredWidth: stack.width - stack.width % 100 + 10
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignHCenter
        model: generalModel
        ScrollBar.vertical: ScrollBar {}

        cellHeight: 140
        cellWidth: 100

        delegate: GeneralCardItem {
          autoBack: false
          name: modelData
          onClicked: {
            stack.pop();
            extra_data.card.name = modelData;
            root.finish();
          }
        }
      }
    }
  }

  function load() {
    const packs = JSON.parse(Backend.callLuaFunction("GetAllGeneralPack", []));
    packs.forEach((name) => packages.append({ name: name }));
  }

  Component.onCompleted: {
    load();
  }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import Fk.Components.LunarLTK

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
        text: Lua.tr("Back")
        onClicked: stack.pop()
      }

      Label {
        text: Lua.tr("Enable free assign")
        elide: Label.ElideRight
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
        Layout.fillWidth: true
      }

      TextField {
        id: word
        placeholderText: "Search..."
        clip: true
        verticalAlignment: Qt.AlignVCenter
        background: Rectangle {
          implicitHeight: 16
          implicitWidth: 120
          color: "transparent"
        }
        focus: true
        onEditingFinished: {
          if (text !== "") {
            if (stack.depth > 1) stack.pop();
            generalModel = Lua.call("SearchAllGenerals", word.text);
            stack.push(generalList);
            word.text = "";
          }
        }
      }

      ToolButton {
        text: Lua.tr("Search")
        enabled: word.text !== ""
        onClicked: {
          if (stack.depth > 1) stack.pop();
          generalModel = Lua.call("SearchAllGenerals", word.text);
          stack.push(generalList);
          word.text = "";
        }
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
      cellWidth: width / 5
      cellHeight: 40

      delegate: ItemDelegate {
        width: listView.width / 5
        height: 40

        Text {
          text: Lua.tr(name)
          color: "#E4D5A0"
          anchors.centerIn: parent
        }

        onClicked: {
          generalModel = Lua.call("GetGenerals", packages.get(index).name);
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
    const packs = Lua.call("GetAllGeneralPack");
    packs.forEach((name) => packages.append({ name: name }));
  }

  Component.onCompleted: {
    load();
  }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk

import LunarLtk
import LunarLtk.Components
import LunarLtk.Models.Popups

pragma ComponentBehavior: Bound

Item {
  id: root
  anchors.fill: parent
  property var generalModel

  required property ChooseGeneralModel dataModel
  property int index

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
            generalModel = Ltk.searchAllGenerals(word.text);
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
          generalModel = Ltk.searchAllGenerals(word.text);
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
        required property var model

        Text {
          text: Lua.tr(parent.model.name)
          color: "#E4D5A0"
          anchors.centerIn: parent
        }

        onClicked: {
          root.generalModel = Ltk.getGenerals(model.name);
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
      Item { implicitHeight: 6 }
      GridView {
        clip: true
        Layout.preferredWidth: stack.width - stack.width % 100 + 10
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignHCenter
        model: root.generalModel
        ScrollBar.vertical: ScrollBar {}

        cellHeight: 140
        cellWidth: 100

        delegate: GeneralCardItem {
          required property string modelData
          autoBack: false
          dataModel: Ltk.createGeneralCardModel(modelData)
          onClicked: {
            stack.pop();
            root.dataModel.changeGeneral(root.index, dataModel);
            root.finish();
          }
        }
      }
    }
  }

  Component.onCompleted: {
    const packs = Ltk.getAllGeneralPack();
    packs.forEach((name) => packages.append({ name: name }));
  }
}

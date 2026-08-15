// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import LunarLtk
import LunarLtk.Models.Popups
import LunarLtk.Components

Item {
  id: root
  anchors.fill: parent

  signal finish()

  property ChooseGeneralModel dataModel

  Component {
    id: generalColumnComponent

    RowLayout {
      id: generalColumn
      required property string modelData
      required property int index
      visible: toConvertRepeater.model.length > 0
      spacing: 12
      CompactGeneralCardItem {
        // color: "#E4D5A0"
        dataModel: Ltk.createGeneralCardModel(parent.modelData, { detailed: false })
        Layout.alignment: Qt.AlignTop
      }

      Text {
        text: "===>"
        color: "#E4D5A0"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Layout.preferredWidth: 40
        Layout.preferredHeight: 64
        Layout.alignment: Qt.AlignTop
      }

      GridLayout {
        columns: 8
        rowSpacing: 4
        columnSpacing: 4

        Repeater {
          id: toConvertRepeater
          model: Ltk.getSameGenerals(generalColumn.modelData)

          CompactGeneralCardItem {
            required property string modelData
            dataModel: Ltk.createGeneralCardModel(modelData)
            selectable: true

            onClicked: {
              root.dataModel.changeGeneral(generalColumn.index, dataModel);

              root.finish();
            }
          }
        }
      }
    }
  }

  Flickable {
    height: parent.height - 20
    // width: generalButtons.width
    width: parent.width - 20
    anchors.centerIn: parent
    contentHeight: generalButtons.height
    ScrollBar.vertical: ScrollBar {}

    ColumnLayout {
      id: generalButtons
      Repeater {
        model: root.dataModel?.generals ?? []
        delegate: generalColumnComponent
      }
    }
  }
}

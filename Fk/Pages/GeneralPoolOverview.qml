// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Fk.Common

Item {
  id: root
  objectName: "GeneralPoolOverview"
  property int generalCount: 0
  property var allGenerals: []

  RowLayout {
    id: topBar
    anchors.top: parent.top
    width: parent.width

    Text {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignHCenter
      font.pixelSize: 18
      horizontalAlignment: Text.AlignHCenter
      text: luatr("%1 generals are enabled in this room").arg(root.generalCount);
    }

    Switch {
      id: showByPkg
      checked: true
      text: luatr("Show general pool by packages")
    }

    Button {
      text: luatr("Copy as ban scheme")
      onClicked: {
        const disabledGenerals = leval("ClientInstance.disabled_generals");
        const disabledPack = leval("ClientInstance.disabled_packs");
        const allPack = lcall("GetAllGeneralPack");
        const scheme = {
          name: (new Date).toJSON(),
          banCardPkg: lcall("GetAllCardPack").filter(p => disabledPack.includes(p)),
          banPkg: {},
          normalPkg: {},
        };
        for (let pkname of allPack) {
          if (disabledPack.includes(pkname)) {
            scheme.banPkg[pkname] = [];
            continue;
          }
          let generals = lcall("GetGenerals", pkname);
          let enabled_generals = generals.filter(g => !disabledGenerals.includes(g));
          let disabled_generals = generals.filter(g => !enabled_generals.includes(g));
          if (enabled_generals.length > generals.length * 0.4) {
            if (disabled_generals.length > 0) {
              scheme.normalPkg[pkname] = disabled_generals;
            }
          } else {
            scheme.banPkg[pkname] = enabled_generals;
          }
        }
        Backend.copyToClipboard(JSON.stringify(scheme));
        toast.show(luatr("Export Success"));
      }
    }
  }

  ListView {
    id: listView
    clip: true
    width: parent.width
    height: parent.height - topBar.height - 16
    spacing: 4
    anchors.top: topBar.bottom
    visible: showByPkg.checked
    model: ListModel {
      id: pkgModel
    }
    delegate: RowLayout {
      width: listView.width

      Text {
        text: luatr(pkname)
        font.pixelSize: 18
        textFormat: Text.RichText
        wrapMode: Text.WrapAnywhere
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: 100
      }

      Grid {
        Layout.fillWidth: true
        columns: Math.floor((listView.width - 100) / 68)
        rowSpacing: 4; columnSpacing: 4
        Repeater {
          id: repeater
          model: JSON.parse(all_generals)
          property var enableGenerals: JSON.parse(generals)
          Avatar {
            general: modelData
            detailed: true
            Rectangle {
              anchors.fill: parent
              color: "black"
              opacity: 0.6
              visible: !repeater.enableGenerals.includes(modelData)
            }
          }
        }
      }
    }
  }

  GridView {
    clip: true
    width: parent.width - (parent.width % 68)
    height: parent.height - topBar.height - 16
    anchors.top: topBar.bottom
    x: (parent.width % 68) / 2
    visible: !showByPkg.checked
    cellWidth: 68; cellHeight: 68
    model: root.allGenerals
    delegate: Avatar {
      general: modelData
      detailed: true
    }
  }

  Button {
    text: luatr("Quit")
    anchors.bottom: parent.bottom
    visible: mainStack.currentItem.objectName === "ModesOverview"
    onClicked: {
      mainStack.pop();
    }
  }

  Component.onCompleted: {
    const disabledGenerals = leval("ClientInstance.disabled_generals");
    const disabledPack = leval("ClientInstance.disabled_packs");
    const allPack = lcall("GetAllGeneralPack");
    pkgModel.clear();
    const allGenerals = [];
    for (let pkname of allPack) {
      if (disabledPack.includes(pkname)) continue;
      let all_generals = lcall("GetGenerals", pkname);
      all_generals = all_generals.filter(g => !leval(`Fk.generals['${g}'].hidden`));
      let generals = all_generals.filter(g => !disabledGenerals.includes(g));
      if (generals.length === 0) continue;
      pkgModel.append({
        pkname,
        generals: JSON.stringify(generals),
        all_generals: JSON.stringify(all_generals),
      });
      allGenerals.push(...generals);
    }
    root.generalCount = allGenerals.length;
    root.allGenerals = allGenerals;
  }
}


// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Fk
import Fk.Common
import Fk.Widgets as W

Item {
  id: root
  objectName: "GeneralPoolOverview"
  property int generalCount: 0
  property var allGenerals: []

  Component {
    id: avatarCard
    Item {
      width: 64; height: 64
      Avatar {
        general: modelData
        detailed: true
      }

      W.TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.NoButton
        gesturePolicy: TapHandler.WithinBounds

        onTapped: () => {
          popLoader.item.general = modelData;
          pop.open();
        }
      }
    }
  }

  Rectangle {
    id: favorite
    width: 140
    height: parent.height
    radius: 2

    Text {
      id: favorBar
      text: luatr("Favorite Generals")
      font.pixelSize: 18
      anchors.horizontalCenter: parent.horizontalCenter
    }

    GridView {
      clip: true
      x: 4
      width: parent.width; height: parent.height - favorBar.height
      anchors.top: favorBar.bottom
      cellWidth: 68; cellHeight: 68
      model: config.favoriteGenerals
      delegate: Item {
        width: 64; height: 64
        Avatar {
          general: modelData
          detailed: true
        }

        Rectangle {
          anchors.fill: parent
          color: "black"
          opacity: 0.6
          visible: !root.allGenerals.includes(modelData)
        }

        Image {
          width: 24; height: 23
          source: SkinBank.MISC_DIR + "favorite"
          x: -8; y: 48
        }

        W.TapHandler {
          acceptedButtons: Qt.LeftButton | Qt.NoButton
          gesturePolicy: TapHandler.WithinBounds

          onTapped: () => {
            popLoader.item.general = modelData;
            pop.open();
          }
        }
      }
    }
  }

  RowLayout {
    id: topBar
    anchors.left: favorite.right
    anchors.top: parent.top
    width: parent.width - favorite.width

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
    width: parent.width - favorite.width
    height: parent.height - topBar.height - 16
    spacing: 4
    anchors.top: topBar.bottom
    anchors.left: favorite.right
    visible: showByPkg.checked
    interactive: showByPkg.checked
    model: ListModel {
      id: pkgModel
    }
    delegate: RowLayout {
      width: listView.width

      Text {
        text: luatr(pkname)
        font.pixelSize: 16
        textFormat: Text.RichText
        wrapMode: Text.WrapAnywhere
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: 80
      }

      Grid {
        Layout.fillWidth: true
        columns: Math.floor((listView.width - 100) / 68)
        rowSpacing: 4; columnSpacing: 4
        Repeater {
          id: repeater
          model: JSON.parse(generals)
          property var enableGenerals: JSON.parse(generals)
          delegate: avatarCard
        }
      }
    }
  }

  GridView {
    clip: true
    width: parent.width - favorite.width
    height: parent.height - topBar.height - 16
    anchors.top: topBar.bottom
    anchors.left: favorite.right
    visible: !showByPkg.checked
    interactive: !showByPkg.checked
    cellWidth: 68; cellHeight: 68
    model: root.allGenerals
    delegate: avatarCard
  }

  Button {
    text: luatr("Quit")
    anchors.bottom: parent.bottom
    visible: mainStack.currentItem.objectName === "ModesOverview"
    onClicked: {
      mainStack.pop();
    }
  }

  Popup {
    id: pop
    width: realMainWin.width * 0.6
    height: realMainWin.height * 0.8
    anchors.centerIn: parent
    background: Rectangle {
      color: "#EEEEEEEE"
      radius: 5
      border.color: "#A6967A"
      border.width: 1
    }

    Loader {
      id: popLoader
      width: parent.width / mainWindow.scale
      height: parent.height / mainWindow.scale
      anchors.centerIn: parent
      scale: mainWindow.scale
      source: "GeneralDetailPage.qml"
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
      let generals = lcall("GetGenerals", pkname);
      generals = generals.filter(g => !leval(`Fk.generals['${g}'].hidden`));
      generals = generals.filter(g => !disabledGenerals.includes(g));
      if (generals.length === 0) continue;
      pkgModel.append({
        pkname,
        generals: JSON.stringify(generals),
      });
      allGenerals.push(...generals);
    }
    root.generalCount = allGenerals.length;
    root.allGenerals = allGenerals;
  }
}


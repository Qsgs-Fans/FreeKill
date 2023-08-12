// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
  id: root
  flickableDirection: Flickable.AutoFlickIfNeeded
  clip: true
  contentHeight: layout.height
  property bool loading: false
  ScrollBar.vertical: ScrollBar {
    parent: root.parent
    anchors.top: root.top
    anchors.right: root.right
    anchors.bottom: root.bottom
  }

  ColumnLayout {
    id: layout
    anchors.top: parent.top
    anchors.topMargin: 8

    Switch {
      text: Backend.translate("Disable Extension")
    }

    RowLayout {
      Text {
        text: Backend.translate("General Packages")
        font.bold: true
      }
      Button {
        text: Backend.translate("Select All")
        onClicked: {
          for (let i = 0; i < gpacks.count; i++) {
            const item = gpacks.itemAt(i);
            item.checked = true;
          }
        }
      }
      Button {
        text: Backend.translate("Revert Selection")
        onClicked: {
          for (let i = 0; i < gpacks.count; i++) {
            const item = gpacks.itemAt(i);
            item.checked = !item.checked;
          }
        }
      }
    }

    GridLayout {
      columns: 2

      Repeater {
        id: gpacks
        model: ListModel {
          id: gpacklist
        }

        CheckBox {
          text: name
          checked: pkg_enabled
          enabled: orig_name !== "test_p_0"

          onCheckedChanged: {
            if (!loading) {
              checkPackage(orig_name, checked);
            }
          }
        }
      }
    }

    RowLayout {
      Text {
        text: Backend.translate("Card Packages")
        font.bold: true
      }
      Button {
        text: Backend.translate("Select All")
        onClicked: {
          for (let i = 0; i < cpacks.count; i++) {
            const item = cpacks.itemAt(i);
            item.checked = true;
          }
        }
      }
      Button {
        text: Backend.translate("Revert Selection")
        onClicked: {
          for (let i = 0; i < cpacks.count; i++) {
            const item = cpacks.itemAt(i);
            item.checked = !item.checked;
          }
        }
      }
    }

    GridLayout {
      columns: 2

      Repeater {
        id: cpacks
        model: ListModel {
          id: cpacklist
        }

        CheckBox {
          text: name
          checked: pkg_enabled

          onCheckedChanged: {
            checkPackage(orig_name, checked);
          }
        }
      }
    }
  }

  function checkPackage(orig_name, checked) {
    const packs = config.disabledPack;
    if (checked) {
      const idx = packs.indexOf(orig_name);
      if (idx !== -1) packs.splice(idx, 1);
    } else {
      packs.push(orig_name);
    }
    Backend.callLuaFunction("UpdatePackageEnable", [orig_name, checked]);
    config.disabledPackChanged();
  }

  Component.onCompleted: {
    loading = true;
    const g = JSON.parse(Backend.callLuaFunction("GetAllGeneralPack", []));
    for (let orig of g) {
      if (config.serverHiddenPacks.includes(orig)) {
        continue;
      }
      gpacklist.append({
        name: Backend.translate(orig),
        orig_name: orig,
        pkg_enabled: !config.disabledPack.includes(orig),
      });
    }

    const c = JSON.parse(Backend.callLuaFunction("GetAllCardPack", []));
    for (let orig of c) {
      if (config.serverHiddenPacks.includes(orig)) {
        continue;
      }
      cpacklist.append({
        name: Backend.translate(orig),
        orig_name: orig,
        pkg_enabled: !config.disabledPack.includes(orig),
      });
    }
    loading = false;
  }
}

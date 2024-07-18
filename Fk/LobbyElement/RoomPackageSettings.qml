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

    /* 
    Switch {
      text: luatr("Disable Extension")
    }
    */

    RowLayout {
      Text {
        text: luatr("General Packages")
        font.bold: true
      }
      Button {
        text: luatr("Select All")
        onClicked: {
          for (let i = 0; i < gpacks.count; i++) {
            const item = gpacks.itemAt(i);
            item.checked = true;
          }
        }
      }
      Button {
        text: luatr("Revert Selection")
        onClicked: {
          for (let i = 0; i < gpacks.count; i++) {
            const item = gpacks.itemAt(i);
            item.checked = !item.checked;
          }
        }
      }
    }

    GridLayout {
      columns: 4

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
        text: luatr("Card Packages")
        font.bold: true
      }
      Button {
        text: luatr("Select All")
        onClicked: {
          for (let i = 0; i < cpacks.count; i++) {
            const item = cpacks.itemAt(i);
            item.checked = true;
          }
        }
      }
      Button {
        text: luatr("Revert Selection")
        onClicked: {
          for (let i = 0; i < cpacks.count; i++) {
            const item = cpacks.itemAt(i);
            item.checked = !item.checked;
          }
        }
      }
    }

    GridLayout {
      columns: 4

      Repeater {
        id: cpacks
        model: ListModel {
          id: cpacklist
        }

        CheckBox {
          text: name
          checked: pkg_enabled

          onCheckedChanged: {
            const packs = config.curScheme.banCardPkg;
            if (checked) {
              const idx = packs.indexOf(orig_name);
              if (idx !== -1) packs.splice(idx, 1);
            } else {
              packs.push(orig_name);
            }
            lcall("UpdatePackageEnable", orig_name, checked);
            config.curSchemeChanged();
          }
        }
      }
    }
  }

  function checkPackage(orig_name, checked) {
    const s = config.curScheme;
    if (!checked) {
      s.banPkg[orig_name] = [];
      delete s.normalPkg[orig_name];
    } else {
      delete s.normalPkg[orig_name];
      delete s.banPkg[orig_name];
    }
    lcall("UpdatePackageEnable", orig_name, checked);
    config.curSchemeChanged();
  }

  Component.onCompleted: {
    loading = true;
    const g = lcall("GetAllGeneralPack");
    let orig;
    for (orig of g) {
      if (config.serverHiddenPacks.includes(orig)) {
        continue;
      }
      gpacklist.append({
        name: luatr(orig),
        orig_name: orig,
        pkg_enabled: !config.curScheme.banPkg[orig],
      });
    }

    const c = lcall("GetAllCardPack");
    for (orig of c) {
      if (config.serverHiddenPacks.includes(orig)) {
        continue;
      }
      cpacklist.append({
        name: luatr(orig),
        orig_name: orig,
        pkg_enabled: !config.curScheme.banCardPkg.includes(orig),
      });
    }
    loading = false;
  }
}

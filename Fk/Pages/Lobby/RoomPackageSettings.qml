// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk

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

    RowLayout {
      Text {
        text: Lua.tr("General Packages Help")
        font.bold: true
      }
    }

    RowLayout {
      Text {
        text: Lua.tr("Card Packages")
        font.bold: true
      }
      Button {
        text: Lua.tr("Select All")
        onClicked: {
          for (let i = 0; i < cpacks.count; i++) {
            const item = cpacks.itemAt(i);
            item.checked = true;
          }
        }
      }
      Button {
        text: Lua.tr("Revert Selection")
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
            const packs = Config.curScheme.banCardPkg;
            if (checked) {
              const idx = packs.indexOf(orig_name);
              if (idx !== -1) packs.splice(idx, 1);
            } else {
              packs.push(orig_name);
            }
            Lua.call("UpdatePackageEnable", orig_name, checked);
            Config.curScheme = Config.curScheme;
          }
        }
      }
    }
  }

  function checkPackage(orig_name, checked) {
    return;
  }

  Component.onCompleted: {
    loading = true;
    let orig;

    const c = Lua.call("GetAllCardPack");
    for (orig of c) {
      if (Config.serverHiddenPacks.includes(orig)) {
        continue;
      }
      cpacklist.append({
        name: Lua.tr(orig),
        orig_name: orig,
        pkg_enabled: !Config.curScheme.banCardPkg.includes(orig),
      });
    }
    loading = false;
  }
}

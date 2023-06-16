// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
  id: root
  flickableDirection: Flickable.AutoFlickIfNeeded
  clip: true
  contentHeight: layout.height
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
      text: "禁用Lua拓展 (重启后生效)"
    }

    Text {
      text: Backend.translate("General Packages")
      font.bold: true
    }

    GridLayout {
      id: gpacks
      columns: 2

      Repeater {
        model: ListModel {
          id: gpacklist
        }

        CheckBox {
          text: name
          checked: pkg_enabled
          enabled: orig_name !== "test_p_0"

          onCheckedChanged: {
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
        }
      }
    }

    Text {
      text: Backend.translate("Card Packages")
      font.bold: true
    }

    GridLayout {
      id: cpacks
      columns: 2

      Repeater {
        model: ListModel {
          id: cpacklist
        }

        CheckBox {
          text: name
          checked: pkg_enabled

          onCheckedChanged: {
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
        }
      }
    }
  }

  Component.onCompleted: {
    const g = JSON.parse(Backend.callLuaFunction("GetAllGeneralPack", []));
    for (let orig of g) {
      gpacklist.append({
        name: Backend.translate(orig),
        orig_name: orig,
        pkg_enabled: config.disabledPack.indexOf(orig) === -1,
      });
    }

    const c = JSON.parse(Backend.callLuaFunction("GetAllCardPack", []));
    for (let orig of c) {
      cpacklist.append({
        name: Backend.translate(orig),
        orig_name: orig,
        pkg_enabled: config.disabledPack.indexOf(orig) === -1,
      });
    }
  }
}

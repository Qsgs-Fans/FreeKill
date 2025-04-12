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
          for (let i = 0; i < mods.count; i++) {
            const col = mods.itemAt(i);
            const gri = col.children[1];
            for (var j = 0; j < gri.children.length - 1; j++) { // 最后一个不是 CheckBox
              gri.children[j].checked = true;
            }
          }
        }
      }
      Button {
        text: luatr("Revert Selection")
        onClicked: {
          for (let i = 0; i < mods.count; i++) {
            const col = mods.itemAt(i);
            const gri = col.children[1];
            for (var j = 0; j < gri.children.length - 1; j++) {
              gri.children[j].checked = !gri.children[j].checked;
            }
          }
        }
      }
    }

    ColumnLayout {
      Repeater {
        id: mods
        model: ListModel {
          id: modList
        }
        Column {
          id: modColumn
          property bool pkgShown: config.shownPkg.includes(name) // 记忆展开状态
          ButtonGroup {
            id: childPkg
            exclusive: false
            checkState: parentModBox.checkState
          }

          RowLayout {
            spacing: 8
            CheckBox {
              id: parentModBox
              text: luatr(name)
              font.bold: true
              checkState: childPkg.checkState
              Layout.minimumWidth: 100
            }
            ToolButton {
              text: (modColumn.pkgShown ? "➖" : "➕")
              onClicked: {
                modColumn.pkgShown = !modColumn.pkgShown
                const idx = config.shownPkg.indexOf(name);
                if (idx === -1) {
                  config.shownPkg.push(name);
                } else {
                  config.shownPkg.splice(idx, 1);
                }
                config.shownPkgChanged();
              }
              background: Rectangle {
                implicitWidth: 20
                implicitHeight: 20

                visible: parent.down || parent.checked || parent.highlighted || parent.visualFocus
                  || (parent.enabled && parent.hovered)
              }
            }
          }

          GridLayout {
            id: pkgListLayout
            columns: 4
            rowSpacing: -5
            visible: parent.pkgShown
            Behavior on opacity { OpacityAnimator { duration: 200 } }

            Repeater {
              id: pkgList
              model: JSON.parse(pkgs)

              CheckBox {
                text: luatr(modelData)
                leftPadding: indicator.width
                ButtonGroup.group: childPkg
                enabled: modelData !== "test_p_0" // 测试包不允许选择
                checked: !config.curScheme.banPkg[modelData] // 初始状态

                onCheckedChanged: {
                  if (!loading) {
                    checkPackage(modelData, checked);
                  }
                }
              }
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
    const _mods = lcall("GetAllModNames");
    const modData = lcall("GetAllMods");
    const packs = lcall("GetAllGeneralPack");
    _mods.forEach(name => {
      const pkgs = modData[name].filter(p => packs.includes(p)
        && !config.serverHiddenPacks.includes(p));
      if (pkgs.length > 0)
        modList.append({ name: name, pkgs: JSON.stringify(pkgs) });
    });

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

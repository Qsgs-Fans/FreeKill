// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root

  ToolBar {
    id: bar
    width: parent.width
    RowLayout {
      anchors.fill: parent
      ToolButton {
        icon.source: AppPath + "/image/modmaker/back"
        onClicked: mainStack.pop();
      }
      Label {
        text: qsTr("Package Manager")
        horizontalAlignment: Qt.AlignHCenter
        Layout.fillWidth: true
      }
      ToolButton {
        icon.source: AppPath + "/image/modmaker/menu"
        onClicked: menu.open()

        Menu {
          id: menu
          y: bar.height

          MenuItem {
            text: qsTr("Enable All")
            onTriggered: {
              for (let i = 0; i < packageModel.count; i++) {
                const name = packageModel.get(i).pkgName;
                Pacman.enablePack(name);
              }
              updatePackageList();
            }
          }
          MenuItem {
            text: qsTr("Disable All")
            onTriggered: {
              for (let i = 0; i < packageModel.count; i++) {
                const name = packageModel.get(i).pkgName;
                Pacman.disablePack(name);
              }
              updatePackageList();
            }
          }
          MenuItem {
            text: qsTr("Upgrade All")
            onTriggered: {
              for (let i = 0; i < packageModel.count; i++) {
                const name = packageModel.get(i).pkgName;
                Pacman.upgradePack(name);
              }
              updatePackageList();
            }
          }
        }
      }
    }
  }

  Rectangle {
    width: parent.width
    height: parent.height - bar.height - urlInstaller.height
    anchors.top: bar.bottom
    color: "snow"
    opacity: 0.75
    clip: true

    ListView {
      id: packageList
      clip: true
      anchors.fill: parent
      model: ListModel {
        id: packageModel
      }
      delegate: ItemDelegate {
        width: root.width
        height: 64

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 8
          Text {
            text: "<b>" + pkgName + "</b> (" + pkgVersion + ")"
            font.pixelSize: 18
            textFormat: Text.RichText
            color: pkgEnabled === "1" ? "black" : "grey"
          }
          Text {
            text: pkgURL
            color: pkgEnabled === "1" ? "black" : "grey"
          }
        }

        Button {
          id: enableBtn
          text: pkgEnabled === "0" ? qsTr("Enable") : qsTr("Disable")
          anchors.right: upgradeBtn.left
          anchors.rightMargin: 8
          onClicked: {
            if (pkgEnabled === "0") {
              Pacman.enablePack(pkgName);
              pkgEnabled = "1";
            } else {
              Pacman.disablePack(pkgName);
              pkgEnabled = "0";
            }
            // updatePackageList();
          }
        }

        Button {
          id: upgradeBtn
          text: qsTr("Upgrade")
          anchors.right: delBtn.left
          anchors.rightMargin: 8
          onClicked: {
            Pacman.upgradePack(pkgName);
            // updatePackageList();
            const data = JSON.parse(Pacman.listPackages());
            const e = data[index];
            packageModel.set(index, {
              pkgName: e.name,
              pkgURL: e.url,
              pkgVersion: e.hash.substring(0, 8),
              pkgEnabled: e.enabled
            });
          }
        }

        Button {
          id: delBtn
          text: qsTr("Remove")
          anchors.right: parent.right
          anchors.rightMargin: 8
          onClicked: {
            Pacman.removePack(pkgName);
            // updatePackageList();
            packageModel.remove(index);
          }
        }

        onClicked: {
          Backend.copyToClipboard(pkgURL);
          toast.show(qsTr("Copied %1.").arg(pkgURL));
        }
      }
    }
  }

  Rectangle {
    id: urlInstaller
    width: parent.width
    height: childrenRect.height
    color: "snow"
    opacity: 0.75
    anchors.bottom: parent.bottom

    RowLayout {
      width: parent.width
      TextField {
        id: urlEdit
        Layout.fillWidth: true
        clip: true
      }

      Button {
        text: qsTr("Install From URL")
        enabled: urlEdit.text !== ""
        onClicked: {
          const url = urlEdit.text;
          mainWindow.busy = true;
          Pacman.downloadNewPack(url, true);
        }
      }
    }
  }

  function updatePackageList() {
    packageModel.clear();
    const data = JSON.parse(Pacman.listPackages());
    data.forEach(e => packageModel.append({
      pkgName: e.name,
      pkgURL: e.url,
      pkgVersion: e.hash.substring(0, 8),
      pkgEnabled: e.enabled
    }));
  }

  function downloadComplete() {
    const idx = packageList.currentIndex;
    updatePackageList();
    packageList.currentIndex = idx;
  }

  Component.onCompleted: {
    updatePackageList();
  }
}

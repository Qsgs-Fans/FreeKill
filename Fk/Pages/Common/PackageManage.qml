// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Fk
import Fk.Widgets as W

W.PageBase {
  id: root

  property var fullPackageList: []

  ToolBar {
    id: bar
    width: parent.width
    RowLayout {
      anchors.fill: parent
      ToolButton {
        icon.source: AppPath + "/image/modmaker/back"
        onClicked: App.quitPage();
      }
      Label {
        text: qsTr("Package Manager")
        horizontalAlignment: Qt.AlignHCenter
        Layout.fillWidth: true
      }
      TextField {
        id: searchField
        placeholderText: qsTr("Search package...")
        Layout.preferredWidth: 220
        clip: true
        onTextChanged: filterPackageList()
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
              syncPackStatus(pkgName, "1");
            } else {
              Pacman.disablePack(pkgName);
              syncPackStatus(pkgName, "0");
            }
          }
        }

        Button {
          id: upgradeBtn
          text: qsTr("Upgrade")
          anchors.right: delBtn.left
          anchors.rightMargin: 8
          onClicked: {
            upgradePackByName(pkgName);
          }
        }

        Button {
          id: delBtn
          text: qsTr("Remove")
          anchors.right: parent.right
          anchors.rightMargin: 8
          onClicked: {
            Pacman.removePack(pkgName);
            removeFromFullList(pkgName);
          }
        }

        onClicked: {
          Backend.copyToClipboard(pkgURL);
          App.showToast(qsTr("Copied %1.").arg(pkgURL));
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
          App.setBusy(true);
          Pacman.downloadNewPack(url, true);
        }
      }
    }
  }

  function updatePackageList() {
    packageModel.clear();
    const data = JSON.parse(Pacman.listPackages());
    fullPackageList = data;
    filterPackageList();
  }

  function filterPackageList() {
    packageModel.clear();
    const keyword = searchField.text.trim().toLowerCase();
    const list = keyword === "" ? fullPackageList : fullPackageList.filter(e => {
      return e.name.toLowerCase().includes(keyword) ||
             (e.url && e.url.toLowerCase().includes(keyword));
    });
    list.forEach(e => packageModel.append({
      pkgName: e.name,
      pkgURL: e.url,
      pkgVersion: e.hash.substring(0, 8),
      pkgEnabled: e.enabled
    }));
  }

  // 同步单个包的启用状态到 fullPackageList 并刷新显示
  function syncPackStatus(name, enabled) {
    for (let i = 0; i < fullPackageList.length; i++) {
      if (fullPackageList[i].name === name) {
        fullPackageList[i].enabled = enabled;
        break;
      }
    }
    filterPackageList();
  }

  // 从 fullPackageList 移除并刷新显示
  function removeFromFullList(name) {
    for (let i = 0; i < fullPackageList.length; i++) {
      if (fullPackageList[i].name === name) {
        fullPackageList.splice(i, 1);
        break;
      }
    }
    filterPackageList();
  }

  // 升级单个包并刷新显示
  function upgradePackByName(name) {
    Pacman.upgradePack(name);
    const data = JSON.parse(Pacman.listPackages());
    const e = data.find(d => d.name === name);
    if (e) {
      for (let i = 0; i < fullPackageList.length; i++) {
        if (fullPackageList[i].name === name) {
          fullPackageList[i] = e;
          break;
        }
      }
      filterPackageList();
    }
  }

  function downloadComplete() {
    const idx = packageList.currentIndex;
    updatePackageList();
    packageList.currentIndex = idx;
    App.setBusy(false);
  }

  function showTransferProgress(sender, data) {
    let msg = '';
    if (data.received_objects == data.total_objects) {
      msg = ("Resolving deltas %1/%2")
                     .arg(data.indexed_deltas)
                     .arg(data.total_deltas);
    } else if (data.total_objects > 0) {
      msg = ("Received %1/%2 objects (%3) in %4 KiB")
                     .arg(data.received_objects)
                     .arg(data.total_objects)
                     .arg(data.indexed_objects)
                     .arg(data.received_bytes / 1024);
    }
    console.log(msg);
  }

  Component.onCompleted: {
    updatePackageList();
  
    addCallback(Command.DownloadComplete, downloadComplete);
    addCallback(Command.PackageTransferProgress, showTransferProgress);
  }
}

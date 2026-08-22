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
              // 先同步 fullPackageList（作为搜索/过滤的数据源）
              for (let i = 0; i < fullPackageList.length; i++)
                fullPackageList[i].enabled = "1";
              // 再逐条更新 packageModel（保留 contentY 不跳回顶部）
              for (let i = 0; i < packageModel.count; i++) {
                const name = packageModel.get(i).pkgName;
                Pacman.enablePack(name);
                packageModel.setProperty(i, "pkgEnabled", "1");
              }
            }
          }
          MenuItem {
            text: qsTr("Disable All")
            onTriggered: {
              for (let i = 0; i < fullPackageList.length; i++)
                fullPackageList[i].enabled = "0";
              for (let i = 0; i < packageModel.count; i++) {
                const name = packageModel.get(i).pkgName;
                Pacman.disablePack(name);
                packageModel.setProperty(i, "pkgEnabled", "0");
              }
            }
          }
          MenuItem {
            text: qsTr("Upgrade All")
            onTriggered: {
              // 逐包调用已有的 upgradePackByName（它内部只改单条，保留 contentY）
              for (let i = 0; i < packageModel.count; i++) {
                upgradePackByName(packageModel.get(i).pkgName);
              }
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
      return e.name.toLowerCase().includes(keyword);
    });
    list.forEach(e => packageModel.append({
      pkgName: e.name,
      pkgURL: e.url,
      pkgVersion: e.hash.substring(0, 8),
      pkgEnabled: e.enabled
    }));
  }

  // 同步单个包的启用状态：
  //   ① 改 fullPackageList 中的 enabled（作为数据源，后续 filter/search 要用）
  //   ② 在 packageModel 中按 pkgName 找对应行，setProperty 单独改一行的 pkgEnabled
  //   → 不再 clear()+append() 重建整个 ListModel，避免 ListView.contentY 归零跳回顶部
  function syncPackStatus(name, enabled) {
    // step1: fullPackageList 同步
    for (let i = 0; i < fullPackageList.length; i++) {
      if (fullPackageList[i].name === name) {
        fullPackageList[i].enabled = enabled;
        break;
      }
    }
    // step2: packageModel 局部更新（只改当前显示在列表里的这一行）
    for (let i = 0; i < packageModel.count; i++) {
      if (packageModel.get(i).pkgName === name) {
        packageModel.setProperty(i, "pkgEnabled", enabled);
        break;
      }
    }
  }

  // 从 fullPackageList 移除 + packageModel.remove 单条删除
  function removeFromFullList(name) {
    // step1: fullPackageList 移除
    for (let i = 0; i < fullPackageList.length; i++) {
      if (fullPackageList[i].name === name) {
        fullPackageList.splice(i, 1);
        break;
      }
    }
    // step2: packageModel.remove 删除当前显示的这一行，其余 delegate 不销毁
    // contentY 不会被重置为 0
    for (let i = 0; i < packageModel.count; i++) {
      if (packageModel.get(i).pkgName === name) {
        packageModel.remove(i);
        break;
      }
    }
  }

  // 升级单个包：单条局部更新，不重建整个模型
  function upgradePackByName(name) {
    Pacman.upgradePack(name);
    const data = JSON.parse(Pacman.listPackages());
    const e = data.find(d => d.name === name);
    if (!e) return;

    // step1: fullPackageList 更新对应条目
    for (let i = 0; i < fullPackageList.length; i++) {
      if (fullPackageList[i].name === name) {
        fullPackageList[i] = e;
        break;
      }
    }

    // step2: packageModel 局部改 pkgVersion / pkgEnabled
    const newVersion = (e.hash && typeof e.hash === "string") ? e.hash.substring(0, 8) : (e.hash || "");
    for (let i = 0; i < packageModel.count; i++) {
      if (packageModel.get(i).pkgName === name) {
        packageModel.setProperty(i, "pkgVersion", newVersion);
        packageModel.setProperty(i, "pkgEnabled", e.enabled);
        break;
      }
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

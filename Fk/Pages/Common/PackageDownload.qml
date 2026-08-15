import QtQuick

import Fk
import Fk.Widgets as W

W.PageBase {
  id: root


  property bool needRestart: false
  property var hasHandlerModel: []

  function setPackages(summary) {
    const localSummary = JSON.parse(Pacman.getPackSummary());
    packageModel.clear();
    hasHandlerModel = [];
    for (let data of summary) {
      data.oldHash = localSummary.find(d => d.name === data.name)?.hash ?? "(nil)";
      packageModel.append(data);
    }
  }

  property int currentPackageIndex: 0

  function downloadComplete(sender, data) {
    const item = packageRepeater.itemAt(root.currentPackageIndex);
    if (!item.hasError) {
      item.subTitle = "<font color='lime'>✓</font> Download Complete.";
    }

    let coreItem, coreModel;
    for (let i = 0; i < packageRepeater.count; i++) {
      const it = packageRepeater.itemAt(i);
      if (it.myName === "freekill-core") {
        coreItem = it;
        coreModel = packageModel.get(i);
        break;
      }
    }
    if (coreItem && coreModel) {
      if (coreModel.oldHash !== coreModel.hash && coreItem.hasError === false) {
        root.needRestart = true;
      }
    }

    if (hasHandlerModel.length > 0) {
      repairButton.visible = true;
    }
    backButton.visible = true;
  }

  function setDownloadingPackage(sender, name) {
    for (let i = 0; i < packageRepeater.count; i++) {
      const item = packageRepeater.itemAt(i);
      if (item.myName === name) {
        const oldItem = packageRepeater.itemAt(root.currentPackageIndex);
        if (!oldItem.hasError) {
          oldItem.subTitle = "<font color='lime'>✓</font> Download Complete.";
        }

        root.currentPackageIndex = i;
        packagePage.contentY = i * item.height;
        return;
      }
    }
  }

  function setDownloadError(sender, msg) {
    const item = packageRepeater.itemAt(root.currentPackageIndex);
    item.hasError = true;
    item.subTitle = "<font color='red'>✗</font> " + msg;
    if (item.myName !== "freekill-core") {
      [item.errorMsg, item.errorHandler] = fastRepair(msg);
      if (item.errorHandler !== null) {
        root.hasHandlerModel.push(root.currentPackageIndex);
      }
    }
  }

  function showTransferProgress(sender, data) {
    const item = packageRepeater.itemAt(root.currentPackageIndex);
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
    item.subTitle = "<font color='blue'>↓</font> " + msg;
  }

  W.PreferencePage {
    id: packagePage
    height: parent.height * 0.9
    width: parent.width * 0.5
    groupWidth: width * 0.9
    x: parent.width * 0.1
    y: parent.height * 0.05
    clip: true

    Behavior on contentY {
      NumberAnimation { duration: 100 }
    }

    W.PreferenceGroup {
      Repeater {
        id: packageRepeater
        model: ListModel { id: packageModel }

        W.ActionRow {
          property string myName: name
          property bool hasError: false
          property string errorMsg: ""
          property var errorHandler: null

          title: {
            const old = oldHash === "(nil)" ? oldHash : oldHash.substring(0, 8);
            const now = hash.substring(0, 8);
            let ret = `<b>${name}</b> `;
            if (old === now) {
              ret += "（无变化）"; //(Nothing to do)
            } else {
              ret += `${old} -> ${now}`;
            }
            if (errorMsg !== "") {
              ret += qsTr("Download Error: %1").arg(qsTr(errorMsg));
            }
            return ret;
          }
          subTitle: "⏰ Please wait..."

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "#E91E63"
            border.width: 4
            visible: root.currentPackageIndex === index
          }

          W.ButtonContent {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Fix")
            visible: parent.errorHandler !== null
            onClicked: {;
              parent.errorHandler(parent.myName, index);
              root.hasHandlerModel.remove(index);
            }
          }
        }
      }
    }
  }

  Rectangle {
    anchors.left: packagePage.right
    anchors.leftMargin: 8
    width: parent.width * 0.3
    height: parent.height * 0.9
    y: parent.height * 0.05
    radius: 16
    color: "#80FFFFFF"
    border.color: "#eeeeee"

    Text {
      anchors.top: parent.top
      anchors.topMargin: 8
      width: parent.width - 16
      x: 8
      font.pixelSize: 20
      wrapMode: Text.WrapAnywhere

      text: qsTr("DownloadMsg") + (root.needRestart ? qsTr("CoreChanged") : "")
    }

    W.ButtonContent {
      id: backButton
      visible: false
      text: root.needRestart ? qsTr("Done. Click to exit.") : qsTr("Done. Click to return.")
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 8
      width: parent.width - 16
      x: 8

      onClicked: {
        if (root.needRestart) {
          Config.saveConf();
          Qt.quit();
        } else {
          App.quitPage();
        }
      }
    }

    W.ButtonContent {
      id: repairButton
      visible: false
      text: qsTr("Fix All and Exit")
      anchors.bottom: backButton.top
      anchors.bottomMargin: 8
      width: parent.width - 16
      x: 8

      onClicked: {
        for (let idx of root.hasHandlerModel) {
          const it = packageRepeater.itemAt(idx);
          it.errorHandler(it.myName, idx);
        }
        App.quitPage();
      }
    }
  }

  Component.onCompleted: {
    addCallback(Command.DownloadComplete, downloadComplete);
    addCallback(Command.SetDownloadingPackage, setDownloadingPackage);
    addCallback(Command.PackageDownloadError, setDownloadError);
    addCallback(Command.PackageTransferProgress, showTransferProgress);
  }

  function fastRepair(errorMsg) {
    if (/Workspace is dirty/g.exec(errorMsg)) {
      return ["Workspace has unsaved changes", (packageName, index) => {
        console.log("Uninstalling " + packageName);
        Pacman.removePack(packageName);
        // updatePackageList();
        packageModel.remove(index);
      }];
    }else if (/exists and is not an empty directory/g.exec(errorMsg)) {
      return ["Directory exists and is not empty", null];
    } else if (/o such file or directory/g.exec(errorMsg)) {
      return ["No such file or directory", (packageName, index) => {
        console.log("Uninstalling " + packageName);
        Pacman.removePack(packageName);
        // updatePackageList();
        packageModel.remove(index);
      }];
    } else if (/authentiation required but no callback is set/g.exec(errorMsg)) {
      return ["Repository URL is inaccessible", null];
    } else if (/no match for id/g.exec(errorMsg)) {
      return ["Requested version not found", null];
    } else if (/Http/g.exec(errorMsg)) {
      return ["Network error", null];
    }
  
    return [null, null];
  }
}

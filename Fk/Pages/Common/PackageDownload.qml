import QtQuick

import Fk
import Fk.Widgets as W

W.PageBase {
  id: root


  property bool needRestart: false

  function setPackages(summary) {
    const localSummary = JSON.parse(Pacman.getPackSummary());
    packageModel.clear();
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
    item.subTitle = "<font color='red'>✗</font> " + msg;
    item.hasError = true;
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

          title: {
            const old = oldHash === "(nil)" ? oldHash : oldHash.substring(0, 8);
            const now = hash.substring(0, 8);
            let ret = `<b>${name}</b> `;
            if (old === now) {
              ret += "（无变化）"; //(Nothing to do)
            } else {
              ret += `${old} -> ${now}`;
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

      text: "正在与服务器同步拓展包。<br>请耐心等待，<b>必须在所有拓展包完成下载后才可以关闭该页面</b>。<br><br>若下载途中有<font color='red'>错误</font>产生，<b>则将无法进入服务器</b>，请截图并寻求帮助。" + (root.needRestart ? "<br><br>游戏核心包freekill-core发生更新，必须重启游戏才能生效，请点击按钮关闭游戏后手动重新打开。" : "")
    }

    W.ButtonContent {
      id: backButton
      visible: false
      text: root.needRestart ? "已完成，点击关闭游戏" : "已完成，点击返回"
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
  }

  Component.onCompleted: {
    addCallback(Command.DownloadComplete, downloadComplete);
    addCallback(Command.SetDownloadingPackage, setDownloadingPackage);
    addCallback(Command.PackageDownloadError, setDownloadError);
    addCallback(Command.PackageTransferProgress, showTransferProgress);
  }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import Fk
import Fk.Widgets as W

W.PageBase {
  id: root

  property var currentEnabled: []
  property var fullAvailableList: []
  property var fullEnabledList: []

  ListModel { id: availablePackModel }
  ListModel { id: enabledPackModel }

  function rebuildListModels() {
    let keyword = searchField.text.trim().toLowerCase();
    availablePackModel.clear();
    enabledPackModel.clear();
    const availList = keyword === "" ? fullAvailableList :
      fullAvailableList.filter(n => n.toLowerCase().includes(keyword));
    const enableList = keyword === "" ? fullEnabledList :
      fullEnabledList.filter(n => n.toLowerCase().includes(keyword));
    availList.forEach(p => availablePackModel.append({ name: p }));
    enableList.forEach(p => enabledPackModel.append({ name: p }));
  }

  function applyFilter() { rebuildListModels(); }

  // 将可用包移动到已启用列表（头部）
  function enablePack(name) {
    const idx = fullAvailableList.indexOf(name);
    if (idx !== -1) fullAvailableList.splice(idx, 1);
    if (fullEnabledList.indexOf(name) === -1)
      fullEnabledList.unshift(name);
    applyFilter();
  }

  // 将已启用包移动到可用列表（头部）
  function disablePack(name) {
    const idx = fullEnabledList.indexOf(name);
    if (idx !== -1) fullEnabledList.splice(idx, 1);
    if (fullAvailableList.indexOf(name) === -1)
      fullAvailableList.unshift(name);
    applyFilter();
  }

  // 在已启用列表中上移一条（根据名称在 full 列表里的位置操作）
  function moveEnabledUp(name) {
    const fi = fullEnabledList.indexOf(name);
    if (fi > 0) {
      const tmp = fullEnabledList[fi - 1];
      fullEnabledList[fi - 1] = name;
      fullEnabledList[fi] = tmp;
      applyFilter();
    }
  }

  function moveEnabledToTop(name) {
    const fi = fullEnabledList.indexOf(name);
    if (fi > 0) {
      fullEnabledList.splice(fi, 1);
      fullEnabledList.unshift(name);
      applyFilter();
    }
  }

  function moveEnabledDown(name) {
    const fi = fullEnabledList.indexOf(name);
    if (fi !== -1 && fi < fullEnabledList.length - 1) {
      const tmp = fullEnabledList[fi + 1];
      fullEnabledList[fi + 1] = name;
      fullEnabledList[fi] = tmp;
      applyFilter();
    }
  }

  function moveEnabledToBottom(name) {
    const fi = fullEnabledList.indexOf(name);
    if (fi !== -1 && fi < fullEnabledList.length - 1) {
      fullEnabledList.splice(fi, 1);
      fullEnabledList.push(name);
      applyFilter();
    }
  }

  Component.onCompleted: {
    availablePackModel.clear();
    enabledPackModel.clear();
    let allPacks = Backend.ls(Cpp.path + "/resource_pak/").filter(dir => {
      let full_dir = Cpp.path + "/resource_pak/" + dir
      return Fs.isDir(Fs.convertUrlToPath(full_dir));
    });
    currentEnabled = Config.enabledResourcePacks || [];
    let enabledSet = new Set(currentEnabled.filter(p => allPacks.indexOf(p) !== -1));
    let available = allPacks.filter(p => !enabledSet.has(p));
    fullEnabledList = currentEnabled.filter(p => allPacks.indexOf(p) !== -1);
    fullAvailableList = available;
    applyFilter();
  }

  ToolBar {
    id: bar
    width: parent.width
    RowLayout {
      anchors.fill: parent
      ToolButton {
        icon.source: AppPath + "/image/modmaker/back"
        onClicked: {
          let enabledList = [];
          for (let i = 0; i < enabledPackModel.count; ++i) {
            enabledList.push(enabledPackModel.get(i).name);
          }
          // 过滤状态下已启用列表被筛掉的部分也要合并回来
          for (let i = 0; i < fullEnabledList.length; ++i) {
            if (enabledList.indexOf(fullEnabledList[i]) === -1)
              enabledList.push(fullEnabledList[i]);
          }
          let isSame = enabledList.length === currentEnabled.length &&
          enabledList.every((v, i) => v === currentEnabled[i]);
          if (isSame) {
            App.quitPage();
          } else {
            quitDialog.open();
          }
        }
      }
      Label {
        text: qs.Tr("Resource Package Manager")
        horizontalAlignment: Qt.AlignHCenter
        Layout.fillWidth: true
      }
      TextField {
        id: searchField
        placeholderText: qs.Tr("Search Resource Packs")
        Layout.preferredWidth: 220
        clip: true
        onTextChanged: applyFilter()
      }
      ToolButton {
        text:  qs.Tr("Undo Changes");
        onClicked: root.Component.onCompleted()
      }
    }
  }

  MessageDialog {
    id: quitDialog
    title: qsTr("Quit")
    informativeText: qs.Tr("Unsaved settings. Are you sure to exit?")
    buttons: MessageDialog.Ok | MessageDialog.Cancel
    onButtonClicked: function (button) {
      switch (button) {
        case MessageDialog.Ok: {
          App.quitPage();
          break;
        }
        case MessageDialog.Cancel: {
          quitDialog.close();
        }
      }
    }
  }

  RowLayout {
    anchors.fill: parent
    anchors.margins: 60
    spacing: 40
    anchors.verticalCenter: parent.verticalCenter

    Rectangle {
      radius: 16
      color: "#80FFFFFF"
      border.color: "#eeeeee"
      //opacity: 0.5

      border.width: 1
      Layout.fillWidth: true
      Layout.preferredWidth: 340
      height: 420

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 24
        Label {
          text: qsTr("Available Resource Packs")
          font.bold: true
          font.pixelSize: 20
          horizontalAlignment: Text.AlignHCenter
          Layout.alignment: Qt.AlignHCenter
        }
        ListView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          model: availablePackModel
          delegate: ItemDelegate {
            width: 372
            height: 56
            Row {
              spacing: 16
              Rectangle {
                width: 50; height: 50; radius: 8
                color: "transparent"
                Image {
                  anchors.fill: parent
                  anchors.margins: 2
                  source: AppPath + "/resource_pak/" + name + "/icon.png"
                  fillMode: Image.PreserveAspectFit
                  visible: status === Image.Ready
                }
              }
              Text { text: name; font.bold: true; font.pixelSize: 16 }
            }
            onClicked: {
              root.enablePack(name);
            }

          }
          footer: Label {
            text: qsTr("%1 Resource Packs Available").arg(availablePackModel.count)
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }
    }

    Rectangle {
      radius: 16
      color: "#80FFFFFF"
      border.color: "#eeeeee"
      //opacity: 0.5

      border.width: 1
      Layout.fillWidth: true
      Layout.preferredWidth: 340
      height: 420
      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 24
        Label {
          text: qsTr("Enabled Resource Packs (Highest Priority at Top)")
          font.bold: true
          font.pixelSize: 20
          horizontalAlignment: Text.AlignHCenter
          Layout.alignment: Qt.AlignHCenter
        }
        ListView {
          id: enabledListView
          Layout.fillWidth: true
          Layout.fillHeight: true
          model: enabledPackModel
          delegate: ItemDelegate {
            width: 372
            height: 56
            RowLayout {
              width: parent.width
              spacing: 8
              Rectangle {
                width: 50
                height: 50
                radius: 8
                color: "transparent"
                Image {
                  anchors.fill: parent
                  anchors.margins: 2
                  source: AppPath + "/resource_pak/" + name + "/icon.png"
                  fillMode: Image.PreserveAspectFit
                  visible: status === Image.Ready
                }
              }
              Text {
                text: name
                font.bold: true
                font.pixelSize: 16
                Layout.fillWidth: true
              }

              // 上移按钮
              Button {
                id: upButton
                text: "↑"
                enabled: index > 0
                onClicked: {
                  root.moveEnabledUp(name);
                }
                onPressAndHold: { // 长按置首
                  root.moveEnabledToTop(name);
                }
              }

              // 下移按钮
              Button {
                id: downButton
                text: "↓"
                enabled: index < enabledPackModel.count - 1
                onClicked: {
                  root.moveEnabledDown(name);
                }
                onPressAndHold: { // 长按置尾
                  root.moveEnabledToBottom(name);
                }
              }

              // 卸载按钮
              Button {
                id: unloadButton
                text: "×"
                onClicked: {
                  root.disablePack(name);
                }
              }
            }

            // 点击事件区域，仅覆盖资源包图标和名称，不包括按钮
            /* MouseArea {
              onClicked: {
                availablePackModel.insert(0, { name: name });
                enabledPackModel.remove(index);
              }
            } */
          }
          footer: Label {
            text: qsTr("%1 Resource Packs Enabled").arg(enabledPackModel.count)
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }
    }
  }

  // 底部按钮
  Row {
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 20
    Button {
      width: 150
      text: qsTr("Save")
      onClicked: {
        // 使用完整列表保存，确保搜索筛选掉的条目也被保留
        Config.enabledResourcePacks = root.fullEnabledList.slice();
        Config.saveConf();
        App.quitPage();
      }
    }
  }
}

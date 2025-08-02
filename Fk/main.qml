// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Dialogs
import QtQuick.Controls
import QtQuick.Window
import "Logic.js" as Logic
import Fk.Pages
import Fk.Widgets as W

Window {
  id: realMainWin
  visible: true
  width: 960
  height: 540
  minimumWidth: 160
  minimumHeight: 90
  title: qsTr("FreeKill") + " v" + FkVersion
  property var callbacks: Logic.callbacks
  property list<string> tipList: []

  Item {
    id: mainWindow
    width: (parent.width / parent.height < 960 / 540)
      ? 960 : 540 * parent.width / parent.height
    height: (parent.width / parent.height > 960 / 540)
      ? 540 : 960 * parent.height / parent.width
    scale: parent.width / width
    anchors.centerIn: parent

    Config {
      id: config
    }

    Image {
      source: config.lobbyBg
      anchors.fill: parent
      fillMode: Image.PreserveAspectCrop
    }

    FontLoader { id: fontLibian; source: AppPath + "/fonts/FZLBGBK.ttf" }
    FontLoader { id: fontLi2; source: AppPath + "/fonts/FZLE.ttf" }

    StackView {
      id: mainStack
      visible: !mainWindow.busy
      // If error occurs during loading initialItem
      //   the program will fall into "polish()" loop
      // initialItem: init
      anchors.fill: parent
    }

    Component { id: init; Init {} }
    Component { id: packageDownload; PackageDownload {} }
    Component { id: packageManage; PackageManage {} }
    Component { id: resourcePackManage; ResourcePackManage {} }
    Component { id: lobby; Lobby {} }
    Component { id: generalsOverview; GeneralsOverview {} }
    Component { id: cardsOverview; CardsOverview {} }
    Component { id: modesOverview; ModesOverview {} }
    Component { id: replay; Replay {} }
    Component { id: room; Room {} }
    Component { id: aboutPage; About {} }

    property alias generalsOverviewPage: generalsOverview
    property alias cardsOverviewPage: cardsOverview
    property alias modesOverviewPage: modesOverview
    property alias aboutPage: aboutPage
    property alias replayPage: replay
    property bool busy: false
    property string busyText: ""
    onBusyChanged: busyText = "";
    property bool closing: false

    BusyIndicator {
      id: busyIndicator
      running: true
      anchors.centerIn: parent
      visible: mainWindow.busy === true
    }

    Text {
      anchors.top: busyIndicator.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.topMargin: 8
      visible: mainWindow.busy === true

      property int idx: 1
      text: tipList[idx - 1] ?? ""
      color: "#F0E5DA"
      font.pixelSize: 20
      font.family: fontLibian.name
      style: Text.Outline
      styleColor: "#3D2D1C"
      textFormat: Text.RichText
      width: parent.width * 0.7
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WrapAnywhere

      onVisibleChanged: idx = 0;

      Timer {
        running: parent.visible
        interval: 3600
        repeat: true
        onTriggered: {
          const oldIdx = parent.idx;
          while (parent.idx === oldIdx) {
            parent.idx = Math.floor(Math.random() * tipList.length) + 1;
          }
        }
      }
    }

    Item {
      visible: mainWindow.busy === true && mainWindow.busyText !== ""
      anchors.bottom: parent.bottom
      height: 32
      width: parent.width
      Rectangle {
        anchors.fill: parent
        color: "#88EEEEEE"
      }
      Text {
        anchors.centerIn: parent
        text: mainWindow.busyText
        font.pixelSize: 24
      }
    }

    Popup {
      id: errDialog
      property string txt: ""
      modal: true
      anchors.centerIn: parent
      width: Math.min(contentWidth + 24, realMainWin.width * 0.9)
      height: Math.min(contentHeight + 24, realMainWin.height * 0.9)
      closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
      padding: 12
      contentItem: Text {
        text: errDialog.txt
        wrapMode: Text.WordWrap

        W.TapHandler {
          onTapped: errDialog.close();
        }
      }
    }

    ToastManager {
      id: toast
    }

    Connections {
      target: Backend
      function onNotifyUI(command, jsonData) {
        if (command === "ErrorDialog") {
          errDialog.txt = jsonData;
          errDialog.open();
          return;
        }
        mainWindow.handleMessage(command, jsonData);
      }
    }

    function handleMessage(command, jsonData) {
      const cb = callbacks[command]
      if (typeof(cb) === "function") {
        cb(jsonData);
      } else {
        callbacks["ErrorMsg"]("Unknown command " + command + "!");
      }
    }
  }

  Shortcut {
    sequences: [ StandardKey.FullScreen ]
    onActivated: {
      if (realMainWin.visibility === Window.FullScreen)
        realMainWin.showNormal();
      else
        realMainWin.showFullScreen();
    }
  }

  Loader {
    id: splashLoader
    anchors.fill: parent
  }

  Component.onCompleted: {
    mainStack.push(init);
    if (config.firstRun) {
      config.firstRun = false;
      mainStack.push(Qt.createComponent("Tutorial.qml").createObject());
    }
    if (!Debugging) {
      splashLoader.source = "Splash.qml";
      splashLoader.item.disappeared.connect(() => {
        splashLoader.source = "";
      });
    }
    if (OS !== "Android" && OS !== "Web") {
      x = config.winX;
      y = config.winY;
      width = config.winWidth;
      height = config.winHeight;
    }

    const tips = Backend.loadTips();
    tipList = tips.trim().split("\n");
  }

  MessageDialog {
    id: exitMessageDialog
    title: realMainWin.title
    informativeText: qsTr("Are you sure to exit?")
    buttons: MessageDialog.Ok | MessageDialog.Cancel
    onButtonClicked: function (button, role) {
      switch (button) {
        case MessageDialog.Ok: {
          mainWindow.closing = true;
          config.winWidth = width;
          config.winHeight = height;
          config.saveConf();
          Backend.quitLobby(false);
          realMainWin.close();
          break;
        }
        case MessageDialog.Cancel: {
          exitMessageDialog.close();
        }
      }
    }
  }

  onClosing: (closeEvent) => {
    if (!mainWindow.closing) {
      closeEvent.accepted = false;
      exitMessageDialog.open();
    }
  }

  property var sheduled_download: ""
  function tryUpdatePackage() {
    if (sheduled_download !== "") {
      // mainWindow.busy = true;
      mainStack.push(packageDownload);
      const downloadPage = mainStack.currentItem as PackageDownload;
      downloadPage.setPackages(sheduled_download);
      Pacman.loadSummary(JSON.stringify(sheduled_download), true);
      sheduled_download = "";
    }
  }

  // fake global functions
  function lcall(funcName, ...params) {
    return Backend.callLuaFunction(funcName, [...params]);
  }

  function leval(lua) {
    return Backend.evalLuaExp(`return ${lua}`);
  }

  function luatr(src) {
    return Backend.translate(src);
  }

  function sqlquery(s) {
    return ClientInstance.execSql(s);
  }
}

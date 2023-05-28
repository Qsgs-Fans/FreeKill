// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "Logic.js" as Logic
import Fk.Pages

Window {
  id: realMainWin
  visible: true
  width: 960
  height: 540
  minimumWidth: 160
  minimumHeight: 90
  title: qsTr("FreeKill") + " v" + FkVersion
  property var callbacks: Logic.callbacks
  property var tipList: []

Item {
  id: mainWindow
  width: (parent.width / parent.height < 960 / 540)
    ? 960 : 540 * parent.width / parent.height
  height: (parent.width / parent.height > 960 / 540)
    ? 540 : 960 * parent.height / parent.width
  scale: parent.width / width
  anchors.centerIn: parent
  property bool is_pending: false
  property var pending_message: []

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
    // If error occurs during loading initialItem, the program will fall into "polish()" loop
    // initialItem: init
    anchors.fill: parent
  }

  Component { id: init; Init {} }
  Component { id: packageManage; PackageManage {} }
  Component { id: modMaker; ModMaker {} }
  Component { id: lobby; Lobby {} }
  Component { id: generalsOverview; GeneralsOverview {} }
  Component { id: cardsOverview; CardsOverview {} }
  Component { id: modesOverview; ModesOverview {} }
  Component { id: room; Room {} }
  Component { id: aboutPage; About {} }

  property var generalsOverviewPage
  property var cardsOverviewPage
  property alias modesOverviewPage: modesOverview
  property alias aboutPage: aboutPage
  property bool busy: false
  property string busyText: ""
  onBusyChanged: busyText = "";

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

      TapHandler {
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
      if (mainWindow.is_pending && command !== "ChangeSelf") {
        mainWindow.pending_message.push({ command: command, jsonData: jsonData });
      } else {
        if (command === "StartChangeSelf") {
          mainWindow.is_pending = true;
        }
        mainWindow.handleMessage(command, jsonData);
      }
    }
  }

  function fetchMessage() {
    let ret = pending_message.splice(0, 1)[0];
    if (pending_message.length === 0) {
      is_pending = false;
    }
    return ret;
  }

  function handleMessage(command, jsonData) {
    let cb = callbacks[command]
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

  onClosing: {
    config.winWidth = width;
    config.winHeight = height;
    config.saveConf();
    Backend.quitLobby(false);
  }
}

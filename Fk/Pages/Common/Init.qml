// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Fk
import Fk.Widgets as W

import LunarLtk

W.PageBase {
  id: root
  property alias serverDialog: serverDialogLoader

  Item {
    width: 960 * 0.8
    height: 540 * 0.8
    anchors.centerIn: parent

    Item {
      id: left
      width: 300
      height: parent.height

      Image {
        id: lady
        width: parent.width + 20
        height: parent.height
        fillMode: Image.PreserveAspectFit
      }

      Image {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        width: parent.width
        source: Cpp.path + "/image/widelogo"
      }
    }

    Rectangle {
      id: right
      anchors.left: left.right
      width: parent.width - left.width
      height: parent.height
      color: "#AAFAFAFB"
      radius: 16

      ColumnLayout {
        width: parent.width * 0.8
        height: parent.height * 0.8
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 40
        //spacing

        Text {
          text: qsTr("Welcome back!")
          font.pixelSize: 28
          Layout.alignment: Qt.AlignHCenter
        }

        Button {
          Layout.fillWidth: true
          text: qsTr("Console start")
          onClicked: {
            Config.serverAddr = "127.0.0.1";
            Config.serverPort = 9527;
            const serverCfg = Config.findFavorite("127.0.0.1", 9527);
            Config.screenName = serverCfg?.username ?? "player";
            Config.password = serverCfg?.password ?? "1234";
            App.setBusy(true);
            Config.addFavorite(Config.serverAddr, Config.serverPort, "",
            Config.screenName, Config.password);
            Backend.startServer(9527);

            Backend.joinServer("127.0.0.1", 9527);
            ClientInstance.setLoginInfo(Config.screenName, Config.password);
          }
        }

        Button {
          text: qsTr("Join Server")
          Layout.fillWidth: true
          display: AbstractButton.TextBesideIcon
          onClicked: {
            serverDialog.show();
          }
        }

        Button {
          Layout.fillWidth: true
          text: qsTr("PackageManage")
          onClicked: {
            App.enterNewPage(Qt.createComponent("Fk.Pages.Common", "PackageManage"));
          }
        }

        Button {
          Layout.fillWidth: true
          text: qsTr("ResourcePackManage")
          onClicked: {
            App.enterNewPage(Qt.createComponent("Fk.Pages.Common", "ResourcePackManage"));
          }
        }

        Button {
          Layout.fillWidth: true
          text: qsTr("Quit Game")
          onClicked: {
            Config.saveConf();
            Qt.quit();
          }
        }
      }

      Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.bottomMargin: 12
        text: qsTr("FreeKill") + " v" + Cpp.version
        font.pixelSize: 16
        font.bold: true
      }

      Text {
        id: faqTxt
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 8
        anchors.bottomMargin: 8
        text: qsTr("FAQ")
        color: "blue"
        font.pixelSize: 24
        font.underline: true

        W.TapHandler {
          onTapped: {
            Mediator.notify(root, Command.PushPage, Qt.createComponent("Fk.Pages.Common", "Tutorial"))
          }
        }
      }

      Text {
        anchors.right: faqTxt.left
        anchors.bottom: parent.bottom
        anchors.rightMargin: 8
        anchors.bottomMargin: 8
        text: qsTr("ResFix")
        color: "blue"
        font.pixelSize: 24
        font.underline: true
        visible: OS === "Android"

        W.TapHandler {
          onTapped: {
            Backend.askFixResource();
          }
        }
      }
    }
  }

  Item {
    id: serverDialog
    width: parent.width * 0.8
    height: parent.height * 0.9
    anchors.centerIn: parent
    visible: false

    Rectangle {
      anchors.fill: parent
      opacity: 0.9
      radius: 8
      color: "snow"
      border.color: "black"
    }

    MouseArea {
      anchors.fill: parent
    }

    Loader {
      id: serverDialogLoader
      anchors.fill: parent
      source: "JoinServer.qml"
    }

    PropertyAnimation on opacity {
      id: showAnim
      from: 0
      to: 1
      duration: 400
      running: false
      onStarted: {
        serverDialogLoader.item.loadConfig();
      }
    }

    PropertyAnimation on opacity {
      id: hideAnim
      from: 1
      to: 0
      duration: 400
      running: false
      onFinished: {
        serverDialog.visible = false;
      }
    }

    function show() {
      visible = true;
      showAnim.start();
    }

    function hide() {
      hideAnim.start();
    }
  }

  function downloadComplete() {
    App.showToast(qsTr("updated packages for md5"));
  }

  function enterLobby(sender, data) {
    Config.lastLoginServer = Config.serverAddr;
    // 幂等进入 Lobby：先清掉栈内可能残留的 Lobby/页面，保证栈中只保留一个 Lobby
    App.backToStart();
    App.enterNewPage(Qt.createComponent("Fk.Pages.Lobby", "Lobby"));
    App.setBusy(false);
    if (Cpp.quickStartMode !== "") {
      quickStartTimer.start();
    } else {
      Cpp.notifyServer("RefreshRoomList", "");
    }
    Config.saveConf();
  }

  // 快速启动定时器：等待Lobby页面加载完毕后自动创建房间
  Timer {
    id: quickStartTimer
    interval: 20
    repeat: false
    onTriggered: {
      const gameMode = Cpp.quickStartMode;
      if (!gameMode) return;

      App.setBusy(true);
      Config.quickStartMode = gameMode;
      const boardgameName = Lua.evaluate(`Fk:getBoardGame('${gameMode}').name`);
      const boardgameConf = Db.getModeSettings(boardgameName);
      const gameModeConf = Db.getModeSettings(boardgameName + ':' + gameMode);
      let k, arr;

      let disabledGenerals = [];
      for (k in Config.curScheme.banPkg) {
        arr = Config.curScheme.banPkg[k];
        if (arr.length !== 0) {
          const generals = Ltk.getGenerals(k);
          if (generals.length !== 0) {
            disabledGenerals.push(...generals.filter(g => !arr.includes(g)));
          }
        }
      }
      for (k in Config.curScheme.normalPkg) {
        arr = Config.curScheme.normalPkg[k] ?? [];
        if (arr.length !== 0)
        disabledGenerals.push(...arr);
      }

      let disabledPack = Config.curScheme.banCardPkg.slice();
      for (k in Config.curScheme.banPkg) {
        if (Config.curScheme.banPkg[k].length === 0)
        disabledPack.push(k);
      }
      Config.serverHiddenPacks.forEach(p => {
        if (!disabledPack.includes(p)) {
          disabledPack.push(p);
        }
      });

      const data = Cpp.quickStartConfig;
      let playerNum = data["playerNum"] ?? 2;

      ClientInstance.notifyServer("CreateRoom", [
        Lua.tr("Quick Start"),
        playerNum,
        data.timeout ?? Config.preferredTimeout,
        {
          gameMode,
          roomName: Lua.tr("Quick Start"),
          password: "",
          _game: data.boardgameConf ?? boardgameConf,
          _mode: data.gameModeConf ?? gameModeConf,
          disabledPack: boardgameName === "lunarltk" ? disabledPack : [],
          disabledGenerals: boardgameName === "lunarltk" ? disabledGenerals : [],
          _quickStart: Cpp.quickStartConfig,
        }
      ]);
    }
  }

  function setDetectedServer(sender, data) {
    const item = serverDialogLoader.item;
    if (item) {
      // App.showToast(qsTr("Detected Server %1").arg(j.slice(7)), 10000);
      item.addLANServer(data.slice(7))
    }
  }

  function getServerDetail(sender, data) {
    const [ver, icon, desc, capacity, count, addr] = JSON.parse(data);
    const item = serverDialogLoader.item;
    if (item) {
      let [_addr, port] = addr.split(',');
      port = parseInt(port);
      item.updateServerDetail(_addr, port, [ver, icon, desc, capacity, count]);
    }
  }

  // 快速启动：自动执行单机启动流程
  Timer {
    id: autoStartTimer
    interval: 100
    repeat: false
    onTriggered: {
      if (Cpp.quickStartMode === "") return;
      Config.serverAddr = "127.0.0.1";
      Config.serverPort = 9527;
      const serverCfg = Config.findFavorite("127.0.0.1", 9527);
      Config.screenName = serverCfg?.username ?? "player";
      Config.password = serverCfg?.password ?? "1234";
      App.setBusy(true);
      Config.addFavorite(Config.serverAddr, Config.serverPort, "",
      Config.screenName, Config.password);
      Backend.startServer(9527);
      Backend.joinServer("127.0.0.1", 9527);
      ClientInstance.setLoginInfo(Config.screenName, Config.password);
    }
  }

  Component.onCompleted: {
    lady.source = Config.ladyImg;

    addCallback(Command.EnterLobby, enterLobby);

    addCallback(Command.ServerDetected, setDetectedServer);
    addCallback(Command.GetServerDetail, getServerDetail);

    if (Cpp.quickStartMode !== "") {
      autoStartTimer.start();
    }
  }
}

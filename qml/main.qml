import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Dialogs
import "Logic.js" as Logic
import "Pages"

Window {
  id: realMainWin
  visible: true
  width: 960
  height: 540
  property var callbacks: Logic.callbacks

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
    initialItem: OS !== "Web" ? init : webinit
    anchors.fill: parent
  }

  Component { id: init; Init {} }
  Component { id: webinit; WebInit {} }
  Component { id: packageManage; PackageManage {} }
  Component { id: lobby; Lobby {} }
  Component { id: generalsOverview; GeneralsOverview {} }
  Component { id: cardsOverview; CardsOverview {} }
  Component { id: room; Room {} }
  Component { id: aboutPage; About {} }

  property var generalsOverviewPage
  property var cardsOverviewPage
  property alias aboutPage: aboutPage
  property bool busy: false
  property string busyText: ""
  onBusyChanged: busyText = "";

  BusyIndicator {
    running: true
    anchors.centerIn: parent
    visible: mainWindow.busy === true
  }
  Item {
    visible: mainWindow.busy === true && mainWindow.busyText !== ""
    anchors.bottom: parent.bottom
    height: 32
    width: parent.width
    Rectangle {
      anchors.fill: parent
      color: "#88888888"
    }
    Text {
      anchors.centerIn: parent
      text: mainWindow.busyText
      font.pixelSize: 24
    }
  }

  // global popup. it is modal and just lower than toast
  Rectangle {
    id: globalPopupDim
    anchors.fill: parent
    color: "black"
    opacity: 0
    visible: !mainWindow.busy

    property bool stateVisible: false
    states: [
      State { 
        when: globalPopupDim.stateVisible
        PropertyChanges { target: globalPopupDim; opacity: 0.5 }
      },
      State { 
        when: !globalPopupDim.stateVisible
        PropertyChanges { target: globalPopupDim; opacity: 0.0 }
      }
    ]
    
    transitions: Transition {
      NumberAnimation { properties: "opacity"; easing.type: Easing.InOutQuad }
    }
  }

  Popup {
    id: globalPopup
    property string source: ""
    modal: true
    dim: false    // cannot animate the dim 
    focus: true
    opacity: mainWindow.busy ? 0 : 1
    closePolicy: Popup.CloseOnEscape
    anchors.centerIn: parent

    onAboutToShow: {
      globalPopupDim.stateVisible = true
    }

    enter: Transition {
      NumberAnimation { properties: "opacity"; from: 0; to: 1 }
      NumberAnimation { properties: "scale"; from: 0.4; to: 1 }
    }

    onAboutToHide: {
      globalPopupDim.stateVisible = false
    }

    exit: Transition {
      NumberAnimation { properties: "opacity"; from: 1; to: 0 }
      NumberAnimation { properties: "scale"; from: 1; to: 0.4 }
    }

    Loader {
      visible: !mainWindow.busy
      source: globalPopup.source === "" ? "" : "GlobalPopups/" + globalPopup.source
      onSourceChanged: {
        if (item === null)
          return;
        item.finished.connect(() => {
          globalPopup.close();
          globalPopup.source = "";
        });
      }
    }
  }

  ToastManager {
    id: toast
  }

  Connections {
    target: Backend
    function onNotifyUI(command, jsonData) {
      if (command == "ErrorDialog") {
        let text = jsonData;
        // only show 3 lines in main text
        let lines = text.split("\n");
        let brief = "";
        let detail = "";
        for (let i = 0; i < lines.length; i++) {
          if (i < 3) {
            brief += lines[i] + "\n";
          }
        }
        if (lines.length > 3) {
          detail = text;
        }
        errDialog.text = brief;
        errDialog.detailedText = detail;
        errDialog.close();
        errDialog.open();
        return;
      }
      let cb = callbacks[command]
      if (typeof(cb) === "function") {
        cb(jsonData);
      } else {
        callbacks["ErrorMsg"]("Unknown command " + command + "!");
      }
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

  Component.onCompleted: {
    if (OS !== "Android" && OS !== "Web") {
      width = config.winWidth;
      height = config.winHeight;
    }
  }

  MessageDialog {
    id: errDialog
    buttons: MessageDialog.Ok
  }

  onClosing: {
    config.winWidth = width;
    config.winHeight = height;
    config.saveConf();
    Backend.quitLobby();
  }
}

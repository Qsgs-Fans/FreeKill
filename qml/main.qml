import QtQuick
import QtQuick.Controls
import QtQuick.Window
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
    source: AppPath + "/image/background"
    anchors.fill: parent
    fillMode: Image.PreserveAspectCrop
  }

  FontLoader { id: fontLiSu; source: AppPath + "/fonts/simli.ttf" }
  FontLoader { id: fontLibian; source: AppPath + "/fonts/FZLBGBK.ttf" }
  FontLoader { id: fontLi2; source: AppPath + "/fonts/FZLE.ttf" }

  StackView {
    id: mainStack
    visible: !mainWindow.busy
    initialItem: init
    anchors.fill: parent
  }

  Component { id: init; Init {} }
  Component { id: lobby; Lobby {} }
  Component { id: generalsOverview; GeneralsOverview {} }
  Component { id: cardsOverview; CardsOverview {} }
  Component { id: room; Room {} }

  property var generalsOverviewPage
  property var cardsOverviewPage

  property bool busy: false
  BusyIndicator {
    running: true
    anchors.centerIn: parent
    visible: mainWindow.busy === true
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
    if (!Android) {
      width = config.winWidth;
      height = config.winHeight;
    }
  }

  onClosing: {
    config.winWidth = width;
    config.winHeight = height;
    config.saveConf();
    Backend.quitLobby();
  }
}

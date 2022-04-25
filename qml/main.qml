import QtQuick 2.15
import QtQuick.Controls 2.0
import QtQuick.Window 2.0
import "Logic.js" as Logic
import "Pages"

Window {
  id: mainWindow
  visible: true
  width: 720
  height: 480
  property var callbacks: Logic.callbacks

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

  property bool busy: false
  BusyIndicator {
    running: true
    anchors.centerIn: parent
    visible: mainWindow.busy === true
  }

  Config {
    id: config
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

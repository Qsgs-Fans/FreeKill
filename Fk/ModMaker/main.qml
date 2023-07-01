import QtQuick
import QtQuick.Controls

Item {
  Component { id: modInit; ModInit {} }

  StackView {
    id: modStack
    anchors.fill: parent
    /*
    pushEnter: Transition {
      PropertyAnimation {
        property: "opacity"
        from: 0
        to:1
        duration: 200
      }
    }
    pushExit: Transition {
      PropertyAnimation {
        property: "opacity"
        from: 1
        to:0
        duration: 200
      }
    }
    popEnter: Transition {
      PropertyAnimation {
        property: "opacity"
        from: 0
        to:1
        duration: 200
      }
    }
    popExit: Transition {
      PropertyAnimation {
        property: "opacity"
        from: 1
        to:0
        duration: 200
      }
    }
    */
  }

  ModConfig {
    id: modConfig
  }

  Component.onCompleted: {
    if (!ModBackend) {
      Backend.createModBackend();
    }
    modConfig.loadConf();
    modStack.push(modInit);
  }
}

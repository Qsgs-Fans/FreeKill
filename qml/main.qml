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

    Component {
        id: init
        Init {}
    }

    Component {
        id: lobby
        Lobby {}
    }

    Component {
        id: room
        Room {}
    }

    Component {
        id: createRoom
        CreateRoom {}
    }

    property bool busy: false
    BusyIndicator {
        running: true
        anchors.centerIn: parent
        visible: mainWindow.busy === true
    }

    Config {
        id: config
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

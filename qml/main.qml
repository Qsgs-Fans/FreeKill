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

    Rectangle {
        id: toast
        opacity: 0
        z: 998
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.8
        radius: 16
        color: "#F2808A87"
        height: toast_text.height + 20
        width: toast_text.width + 40
        Text {
            id: toast_text
            text: "FreeKill"
            anchors.centerIn: parent
            color: "white"
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 240
                easing.type: Easing.InOutQuad
            }
        }
        SequentialAnimation {
            id: keepAnim
            running: toast.opacity == 1
            PauseAnimation {
                duration: 2800
            }

            ScriptAction {
                script: {
                    toast.opacity = 0;
                }
            }
        }

        function show(text) {
            opacity = 1;
            toast_text.text = text;
        }
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

import QtQuick 2.15
import QtQuick.Controls 2.0
import QtQuick.Window 2.0

Window {
    id: mainWindow
    visible: true
    width: 720
    height: 480
    property var callbacks: ({
        "error_msg": function(json_data) {
            toast.show(json_data);
            if (mainWindow.state === "busy")
                mainWindow.state = "init";
        },
        "enter_lobby": function(json_data) {
            mainWindow.state = "lobby";
        }
    })

    Loader {
        id: mainLoader
        source: "Page/Init.qml"
        anchors.fill: parent
    }

    property string state: "init"

    onStateChanged: {
        switch (state) {
            case "init":
                mainLoader.source = "Page/Init.qml";
                break;
            case "lobby":
                mainLoader.source = "Page/Lobby.qml";
                break;
            case "room":
                mainLoader.source = "Page/Room.qml";
                break;
            case "busy":
                mainLoader.source = "";
                break;
            default: break;
        }
    }

    property string busyString: "Busy"

    BusyIndicator {
        running: true
        anchors.centerIn: parent
        visible: mainWindow.state === "busy"
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
                    toast.opacity = 0
                }
            }
        }

        function show(text) {
            opacity = 1
            toast_text.text = text
        }
    }

    Connections {
        target: Backend
        function onNotifyUI(command, json_data) {
            let cb = callbacks[command]
            if (typeof(cb) === "function") {
                cb(json_data);
            } else {
                callbacks["error_msg"]("Unknown UI command " + command + "!");
            }
        }
    }
}

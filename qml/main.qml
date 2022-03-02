import QtQuick 2.15
import QtQuick.Controls 2.0
import QtQuick.Window 2.0
import "Pages"

Window {
    id: mainWindow
    visible: true
    width: 720
    height: 480
    property var callbacks: ({
        "ErrorMsg": function(jsonData) {
            toast.show(jsonData);
            mainWindow.busy = false;
        },
        "EnterLobby": function(jsonData) {
            if (mainStack.depth === 1) {
                mainStack.push(lobby);
            }
            mainWindow.busy = false;
        },
        "EnterRoom": function(jsonData) {
            mainStack.push(room);
            mainWindow.busy = false;
        },
        "UpdateRoomList": function(jsonData) {
            let current = mainStack.currentItem;    // should be lobby
            current.roomModel.clear();
            JSON.parse(jsonData).forEach(function(room) {
                current.roomModel.append({
                    roomId: room[0],
                    roomName: room[1],
                    gameMode: room[2],
                    playerNum: room[3],
                    capacity: room[4],
                });
            });
        }
    })

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

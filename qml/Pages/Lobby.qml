import QtQuick 2.15
import QtQuick.Controls 2.0
import QtQuick.Window 2.0
import QtQuick.Layouts 1.15

Item {
    id: root
    width: 640; height: 480
    Component {
        id: roomDelegate

        Row {
            spacing: 24
            Text {
                width: 40
                text: String(roomId)
            }

            Text {
                width: 40
                text: roomName
            }

            Text {
                width: 20
                text: gameMode
            }

            Text {
                width: 10
                color: (playerNum == capacity) ? "red" : "black"
                text: String(playerNum) + "/" + String(capacity)
            }

            Text {
                text: "Enter"
                font.underline: true
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {    parent.color = "blue"   }
                    onExited: { parent.color = "black"  }
                    onClicked: {
                        mainWindow.busy = true;
                        Backend.notifyServer(
                            "enter_room",
                            JSON.stringify([roomId])
                        );
                    }
                }
            }
        }
    }

    ListModel {
        id: roomModel
    }

    RowLayout {
        anchors.fill: parent
        Rectangle {
            width: root.width * 0.7
            height: root.height
            color: "#e2e2e1"
            radius: 4
            Text {
                text: "Room List"
            }
            ListView {
                height: parent.height * 0.9
                width: parent.width * 0.95
                anchors.centerIn: parent
                id: roomList
                delegate: roomDelegate
                model: roomModel
            }
            Rectangle {
                id: scrollbar
                anchors.right: roomList.right
                y: roomList.visibleArea.yPosition * roomList.height
                width: 10
                radius: 4
                height: roomList.visibleArea.heightRatio * roomList.height
                color: "#a89da8"
            }
        }

        ColumnLayout {
            Text {
                text: "Avatar"
            }
            Button {
                text: "Create Room"
                onClicked: {
                    mainStack.push(createRoom);
                }
            }
            Button {
                text: "Generals Overview"
            }
            Button {
                text: "Cards Overview"
            }
            Button {
                text: "Scenarios Overview"
            }
            Button {
                text: "About"
            }
            Button {
                text: "Exit Lobby"
                onClicked: {
                    toast.show("Goodbye.");
                    Backend.quitLobby();
                    mainStack.pop();
                }
            }
        }
    }

    Loader {
        id: lobby_dialog
        z: 1000
        onSourceChanged: {
            if (item === null)
                return;
            item.finished.connect(function(){
                source = "";
            });
            item.widthChanged.connect(function(){
                lobby_dialog.moveToCenter();
            });
            item.heightChanged.connect(function(){
                lobby_dialog.moveToCenter();
            });
            moveToCenter();
        }

        function moveToCenter()
        {
            item.x = Math.round((root.width - item.width) / 2);
            item.y = Math.round(root.height * 0.67 - item.height / 2);
        }
    }

    Component.onCompleted: {
        toast.show("Welcome to FreeKill lobby!");
    }
}


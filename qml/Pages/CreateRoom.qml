import QtQuick 2.15
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.15

Item {
    id: root
    Frame {
        anchors.centerIn: parent
        Column {
            x: 32
            y: 20
            spacing: 20

            RowLayout {
                anchors.rightMargin: 8
                spacing: 16
                Text {
                    text: "Room Name"
                }
                TextField {
                    id: roomName
                    font.pixelSize: 18
                    text: "tmp's Room"
                }
            }

            RowLayout {
                anchors.rightMargin: 8
                spacing: 16
                Text {
                    text: "Player num"
                }
                SpinBox {
                    id: playerNum
                    from: 2
                    to: 8
                }
            }

            RowLayout {
                anchors.rightMargin: 8
                spacing: 16
                Button {
                    text: "OK"
                    onClicked: {
                        mainWindow.busy = true;
                        mainStack.pop();
                        Backend.notifyServer(
                            "CreateRoom",
                            JSON.stringify([roomName.text, playerNum.value])
                        );
                    }
                }
                Button {
                    text: "Cancel"
                    onClicked: {
                        mainStack.pop();
                    }
                }
            }
        }
    }
}

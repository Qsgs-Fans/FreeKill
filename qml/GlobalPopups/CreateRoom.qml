import QtQuick 2.15
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.15

Item {
    id: root

    width: childrenRect.width
    height: childrenRect.height

    signal finished()

    ColumnLayout {
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
                text: Self.screenName + "'s Room"
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
                    root.finished();
                    mainWindow.busy = true;
                    ClientInstance.notifyServer(
                        "CreateRoom",
                        JSON.stringify([roomName.text, playerNum.value])
                    );
                }
            }
            Button {
                text: "Cancel"
                onClicked: {
                    root.finished();
                }
            }
        }
    }
}

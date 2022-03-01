import QtQuick 2.15
import QtQuick.Controls 2.0

Item {
    id: root

    Frame {
        id: join_server
        anchors.centerIn: parent
        Column {
            spacing: 8
            TextField {
                id: server_addr
                text: "127.0.0.1"
            }
            TextField {
                text: "player"
            }
            Button {
                text: "Join Server"
                onClicked: {
                    mainWindow.busy = true;
                    toast.show("Connecting to host...");
                    Backend.joinServer(server_addr.text);
                }
            }
            Button {
                text: "Console start"
                onClicked: {
                    mainWindow.busy = true;
                    toast.show("Connecting to host...");
                    Backend.startServer(9527);
                    Backend.joinServer("127.0.0.1");
                }
            }
        }
    }
}

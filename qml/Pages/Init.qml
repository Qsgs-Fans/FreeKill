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
                id: screenNameEdit
                text: "player"
            }
            TextField {
                id: avatarEdit
                text: "liubei"
            }
            /*
            TextField {
                id: passwordEdit
                text: ""
                echoMode: TextInput.Password
                passwordCharacter: "*"
            }
            */
            Button {
                text: "Join Server"
                onClicked: {
                    config.screenName = screenNameEdit.text;
                    config.avatar = avatarEdit.text;
                    mainWindow.busy = true;
                    toast.show("Connecting to host...");
                    Backend.joinServer(server_addr.text);
                }
            }
            Button {
                text: "Console start"
                onClicked: {
                    config.screenName = screenNameEdit.text;
                    config.avatar = avatarEdit.text;
                    mainWindow.busy = true;
                    toast.show("Connecting to host...");
                    Backend.startServer(9527);
                    Backend.joinServer("127.0.0.1");
                }
            }
        }
    }
}

import QtQuick 2.0
import QtQuick.Controls 2.0
import QtQuick.Window 2.0

Window
{
    visible: true
    width: 300
    height: 240

    Column {
        TextField {
            id: server_addr
            text: "127.0.0.1"
        }
        TextField {
            text: "player"
        }
        Button {
            text: "Join Server"
            onClicked: Backend.joinServer(server_addr.text);
        }
        TextField {
            id: server_port
            text: "9527"
        }
        Button {
            text: "Start Server"
            onClicked: Backend.startServer(parseInt(server_port.text));
        }
    }
}

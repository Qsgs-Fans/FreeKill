import QtQuick 2.15
import QtQuick.Controls 2.0

Item {
    id: root
    Text {
        anchors.centerIn: parent
        text: "You are in room."
    }
    Button {
        text: "quit"
        onClicked: {
            mainStack.pop();
            Backend.notifyServer("quit_room", "[]");
        }
    }
}


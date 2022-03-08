import QtQuick 2.15
import QtQuick.Controls 2.0
import "RoomElement"
import "RoomLogic.js" as Logic

Item {
    id: roomScene
    Text {
        anchors.centerIn: parent
        text: "You are in room."
    }
    Button {
        text: "quit"
        onClicked: {
            mainStack.pop();
            mainWindow.callbacks["Test"]();
            Backend.notifyServer("QuitRoom", "[]");
        }
    }
}


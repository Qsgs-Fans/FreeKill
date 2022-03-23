import QtQuick 2.15
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.15
import "RoomElement"
import "RoomLogic.js" as Logic

Item {
    id: roomScene

    property var photoModel: []
    property int playerNum: 0
    property var dashboardModel

    // tmp
    Text {
        anchors.centerIn: parent
        text: "You are in room."
    }
    Button {
        text: "quit"
        anchors.bottom: parent.bottom
        onClicked: {
            mainStack.pop();
            Backend.notifyServer("QuitRoom", "[]");
        }
    }

    // For debugging
    RowLayout {
        visible: Debugging ? true : false
        width: parent.width
        TextField {
            id: lua
            Layout.fillWidth: true
            text: "player"
        }
        Button {
            text: "DoLuaScript"
            onClicked: {
                Backend.notifyServer("DoLuaScript", JSON.stringify([lua.text]));
            }
        }
    }

    /* Layout:
     * +---------------------+
     * |   Photos, get more  |
     * | in arrangePhotos()  |
     * |      tablePile      |
     * | progress,prompt,btn |
     * +---------------------+
     * |      dashboard      |
     * +---------------------+
     */

    Item {
        id: roomArea
        width: roomScene.width
        height: roomScene.height - dashboard.height

        Repeater {
            id: photos
            model: photoModel
            Photo {
                // TODO
            }
        }

        onWidthChanged: Logic.arrangePhotos();
        onHeightChanged: Logic.arrangePhotos();

        InvisibleCardArea {
            id: drawPile
            x: parent.width / 2
            y: roomScene.height / 2
        }

        TablePile {
            id: tablePile
            width: parent.width * 0.6
            height: 150
            x: parent.width * 0.2
            y: parent.height * 0.5
        }
    }

    Dashboard {
        id: dashboard
        width: roomScene.width
        anchors.top: roomArea.bottom
    }

    Component.onCompleted: {
        toast.show("Sucesessfully entered room.");
        Logic.arrangePhotos();
    }
}


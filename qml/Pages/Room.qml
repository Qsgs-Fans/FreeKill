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

    property bool isOwner: false
    property bool isStarted: false

    // tmp
    Text {
        anchors.centerIn: parent
        text: "You are in room."
    }
    Button {
        text: "quit"
        anchors.bottom: parent.bottom
        onClicked: {
            ClientInstance.notifyServer("QuitRoom", "[]");
        }
    }
    Button {
        text: "start game"
        visible: isOwner && !isStarted
        anchors.centerIn: parent
    }

    // For debugging
    RowLayout {
        visible: Debugging ? true : false
        width: parent.width
        TextField {
            id: lua
            Layout.fillWidth: true
            text: "print \"Hello world.\""
        }
        Button {
            text: "DoLuaScript"
            onClicked: {
                ClientInstance.notifyServer("DoLuaScript", JSON.stringify([lua.text]));
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
                general: modelData.general
                screenName: modelData.screenName
                role: modelData.role
                kingdom: modelData.kingdom
                netstate: modelData.netstate
                maxHp: modelData.maxHp
                hp: modelData.hp
                seatNumber: modelData.seatNumber
                isDead: modelData.isDead
                dying: modelData.dying
                faceturned: modelData.faceturned
                chained: modelData.chained
                drank: modelData.drank
                isOwner: modelData.isOwner
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

        self.general: dashboardModel.general
        self.screenName: dashboardModel.screenName
        self.role: dashboardModel.role
        self.kingdom: dashboardModel.kingdom
        self.netstate: dashboardModel.netstate
        self.maxHp: dashboardModel.maxHp
        self.hp: dashboardModel.hp
        self.seatNumber: dashboardModel.seatNumber
        self.isDead: dashboardModel.isDead
        self.dying: dashboardModel.dying
        self.faceturned: dashboardModel.faceturned
        self.chained: dashboardModel.chained
        self.drank: dashboardModel.drank
        self.isOwner: dashboardModel.isOwner
    }

    Component.onCompleted: {
        toast.show("Sucesessfully entered room.");

        dashboardModel = {
            id: Self.id,
            general: Self.avatar,
            screenName: Self.screenName,
            role: "unknown",
            kingdom: "qun",
            netstate: "online",
            maxHp: 0,
            hp: 0,
            seatNumber: 1,
            isDead: false,
            dying: false,
            faceturned: false,
            chained: false,
            drank: false,
            isOwner: false
        }

        playerNum = config.roomCapacity;

        let i;
        for (i = 1; i < playerNum; i++) {
            photoModel.push({
                id: -1,
                general: "",
                screenName: "",
                role: "unknown",
                kingdom: "qun",
                netstate: "online",
                maxHp: 0,
                hp: 0,
                seatNumber: i + 1,
                isDead: false,
                dying: false,
                faceturned: false,
                chained: false,
                drank: false,
                isOwner: false
            });
        }
        photoModel = photoModel;    // Force the Repeater reload

        Logic.arrangePhotos();
    }
}


import QtQuick 2.15
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.15
import "RoomElement"
import "RoomLogic.js" as Logic

Item {
    id: roomScene

    property int playerNum: 0
    property var dashboardModel

    property bool isOwner: false
    property bool isStarted: false

    property alias popupBox: popupBox

    // tmp
    Button {
        text: "quit"
        anchors.bottom: parent.bottom
        onClicked: {
            ClientInstance.clearPlayers();
            ClientInstance.notifyServer("QuitRoom", "[]");
        }
    }
    Button {
        text: "start game"
        visible: dashboardModel.isOwner && !isStarted
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

    ListModel {
        id: photoModel
    }

    Item {
        id: roomArea
        width: roomScene.width
        height: roomScene.height - dashboard.height

        Repeater {
            id: photos
            model: photoModel
            Photo {
                general: _general
                screenName: _screenName
                role: _role
                kingdom: _kingdom
                netstate: _netstate
                maxHp: _maxHp
                hp: _hp
                seatNumber: _seatNumber
                isDead: _isDead
                dying: _dying
                faceturned: _faceturned
                chained: _chained
                drank: _drank
                isOwner: _isOwner
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

    Loader {
        id: popupBox
        onSourceChanged: {
            if (item === null)
                return;
            item.finished.connect(function(){
                source = "";
            });
            item.widthChanged.connect(function(){
                popupBox.moveToCenter();
            });
            item.heightChanged.connect(function(){
                popupBox.moveToCenter();
            });
            moveToCenter();
        }

        function moveToCenter()
        {
            item.x = Math.round((roomArea.width - item.width) / 2);
            item.y = Math.round(roomArea.height * 0.67 - item.height / 2);
        }
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
            photoModel.append({
                id: -1,
                index: i - 1,   // For animating seat swap
                _general: "",
                _screenName: "",
                _role: "unknown",
                _kingdom: "qun",
                _netstate: "online",
                _maxHp: 0,
                _hp: 0,
                _seatNumber: i + 1,
                _isDead: false,
                _dying: false,
                _faceturned: false,
                _chained: false,
                _drank: false,
                _isOwner: false
            });
        }

        Logic.arrangePhotos();
    }
}


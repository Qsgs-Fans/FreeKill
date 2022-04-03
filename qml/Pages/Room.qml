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
    property alias promptText: prompt.text

    // tmp
    Row {
        Button{text:"摸1牌"
        onClicked:{
            Logic.moveCards([{
                from:Logic.Player.DrawPile,
                to:Logic.Player.PlaceHand,
                cards:[1],
            }])
        }}
        Button{text:"弃1牌"
        onClicked:{Logic.moveCards([{
                to:Logic.Player.DrawPile,
                from:Logic.Player.PlaceHand,
                cards:[1],
            }])}}
    }
    Button {
        text: "quit"
        anchors.top: parent.top
        anchors.right: parent.right
        onClicked: {
            ClientInstance.clearPlayers();
            ClientInstance.notifyServer("QuitRoom", "[]");
        }
    }
    Button {
        text: "add robot"
        visible: dashboardModel.isOwner && !isStarted
        anchors.centerIn: parent
        onClicked: {
            ClientInstance.notifyServer("AddRobot", "[]");
        }
    }

    states: [
        State { name: "notactive" }, // Normal status
        State { name: "playing" }, // Playing cards in playing phase
        State { name: "responding" }, // all requests need to operate dashboard
        State { name: "replying" } // requests only operate a popup window
    ]
    state: "notactive"
    transitions: [
        Transition {
            from: "*"; to: "notactive"
            ScriptAction {
                script: {
                    promptText = "";
                    progress.visible = false;
                    okCancel.visible = false;
                    endPhaseButton.visible = false;

                    if (popupBox.item != null) {
                        popupBox.item.finished();
                    } 
                }
            }
        },

        Transition {
            from: "*"; to: "playing"
            ScriptAction {
                script: {
                    progress.visible = true;
                    okCancel.visible = true;
                    endPhaseButton.visible = true;
                }
            }
        },

        Transition {
            from: "*"; to: "responding"
            ScriptAction {
                script: {
                    progress.visible = true;
                    okCancel.visible = true;
                }
            }
        },

        Transition {
            from: "*"; to: "replying"
            ScriptAction {
                script: {
                    progress.visible = true;
                }
            }
        }
    ]

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
                general: model.general
                screenName: model.screenName
                role: model.role
                kingdom: model.kingdom
                netstate: model.netstate
                maxHp: model.maxHp
                hp: model.hp
                seatNumber: model.seatNumber
                isDead: model.isDead
                dying: model.dying
                faceup: model.faceup
                chained: model.chained
                drank: model.drank
                isOwner: model.isOwner
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
        self.faceup: dashboardModel.faceup
        self.chained: dashboardModel.chained
        self.drank: dashboardModel.drank
        self.isOwner: dashboardModel.isOwner
    }

    Item {
        id: controls
        anchors.bottom: dashboard.top
        anchors.bottomMargin: -40
        width: roomScene.width

        Text {
            id: prompt
            visible: progress.visible
            anchors.bottom: progress.top
            anchors.bottomMargin: 8
            anchors.horizontalCenter: progress.horizontalCenter
        }

        ProgressBar {
            id: progress
            width: parent.width * 0.6
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: okCancel.top
            anchors.bottomMargin: 8
            from: 0.0
            to: 100.0

            visible: false
            NumberAnimation on value {
                running: progress.visible
                from: 100.0
                to: 0.0
                duration: config.roomTimeout * 1000

                onFinished: {
                    roomScene.state = "notactive"
                }
            }
        }

        Row {
            id: okCancel
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: progress.horizontalCenter
            spacing: 20
            visible: false

            Button {
                id: okButton
                text: "OK"
                onClicked: Logic.doOkButton();
            }

            Button {
                id: cancelButton
                text: "Cancel"
                onClicked: Logic.doCancelButton();
            }
        }

        Button {
            id: endPhaseButton
            text: "End"
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            anchors.right: parent.right
            anchors.rightMargin: 30
            visible: false;
            onClicked: Logic.doCancelButton();
        }
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
            faceup: true,
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
                faceup: true,
                chained: false,
                drank: false,
                isOwner: false
            });
        }

        Logic.arrangePhotos();
    }
}


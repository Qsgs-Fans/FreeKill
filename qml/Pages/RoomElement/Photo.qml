import QtQuick 2.15
import QtGraphicalEffects 1.15
import QtQuick.Controls 2.15
import "PhotoElement"
import "../skin-bank.js" as SkinBank

Item {
    id: root
    width: 175
    height: 233
    scale: 0.8
    property string general: ""
    property string screenName: ""
    property string role: "unknown"
    property string kingdom: "qun"
    property string netstate: "online"
    property alias handcards: handcardAreaItem.length
    property int maxHp: 0
    property int hp: 0
    property int seatNumber: 1
    property bool isDead: false
    property bool dying: false
    property bool faceup: true
    property bool chained: false
    property bool drank: false
    property bool isOwner: false
    property string status: "normal"

    property alias handcardArea: handcardAreaItem
    property alias equipArea: equipAreaItem
    property alias delayedTrickArea: delayedTrickAreaItem
    property alias specialArea: handcardAreaItem

    property alias progressBar: progressBar
    property alias progressTip: progressTip.text

    property bool selectable: false
    property bool selected: false

    Behavior on x {
        NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
    }

    Behavior on y {
        NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
    }

    PixmapAnimation {
        id: animFrame
        source: "selected"
        anchors.centerIn: parent
        loop: true
        scale: 1.1
    }

    Image {
        id: back
        source: SkinBank.PHOTO_BACK_DIR + root.kingdom
    }

    Text {
        id: generalName
        x: 5
        y: 28
        font.family: "FZLiBian-S02"
        font.pixelSize: 22
        opacity: 0.7
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 18
        lineHeightMode: Text.FixedHeight
        color: "white"
        width: 24
        wrapMode: Text.WordWrap
        text: ""
    }

    HpBar {
        id: hp
        x: 8
        value: root.hp
        maxValue: root.maxHp
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
    }

    Image {
        id: generalImage
        width: 138
        height: 222
        smooth: true
        visible: false
        fillMode: Image.PreserveAspectCrop
        source: (general != "") ? SkinBank.GENERAL_DIR + general : ""
    }

    Rectangle {
        id: photoMask
        x: 31
        y: 5
        width: 138
        height: 222
        radius: 8
        visible: false
    }

    OpacityMask {
        anchors.fill: photoMask
        source: generalImage
        maskSource: photoMask
    }

    Colorize {
        anchors.fill: photoMask
        source: generalImage
        saturation: 0
        visible: root.isDead
    }

    Image {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: 8
        anchors.rightMargin: 4
        source: SkinBank.PHOTO_DIR + (isOwner ? "owner" : "ready")
        visible: screenName != "" && !roomScene.isStarted
    }

    Image {
        visible: equipAreaItem.length > 0
        source: SkinBank.PHOTO_DIR + "equipbg"
        x: 31
        y: 121
    }

    Image {
        source: root.status != "normal" ? SkinBank.STATUS_DIR + root.status : ""
        x: -6
    }

    Image {
        id: turnedOver
        visible: !root.faceup
        source: SkinBank.PHOTO_DIR + "faceturned"
        x: 29; y: 5
    }

    EquipArea {
        id: equipAreaItem

        x: 31
        y: 139
    }

    Image {
        id: chain
        visible: root.chained
        source: SkinBank.PHOTO_DIR + "chain"
        anchors.horizontalCenter: parent.horizontalCenter
        y: 72
    }

    Image {
        // id: saveme
        visible: root.isDead || root.dying
        source: SkinBank.DEATH_DIR + (root.isDead ? root.role : "saveme")
        anchors.centerIn: photoMask
    }

    Image {
        id: netstat
        source: SkinBank.STATE_DIR + root.netstate
        x: photoMask.x
        y: photoMask.y
    }

    Image {
        id: handcardNum
        source: SkinBank.PHOTO_DIR + "handcard"
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -6
        x: -6

        Text {
            text: root.handcards
            font.family: "FZLiBian-S02"
            font.pixelSize: 32
            //font.weight: 30
            color: "white"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            style: Text.Outline
        }
    }

    RoleComboBox {
        id: role
        value: root.role
        anchors.top: parent.top
        anchors.topMargin: -4
        anchors.right: parent.right
        anchors.rightMargin: -4
    }

    GlowText {
        id: seatNum
        visible: !progressBar.visible
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -32
        property var seatChr: ["一", "二", "三", "四", "五", "六", "七", "八"]
        font.family: "FZLiShu II-S06S"
        font.pixelSize: 32
        text: seatChr[seatNumber - 1]

        glow.color: "brown"
        glow.spread: 0.2
        glow.radius: 8
        glow.samples: 12
    }

    SequentialAnimation {
        id: trembleAnimation
        running: false
        PropertyAnimation {
            target: root
            property: "x"
            to: root.x - 20
            easing.type: Easing.InQuad
            duration: 100
        }
        PropertyAnimation {
            target: root
            property: "x"
            to: root.x
            easing.type: Easing.OutQuad
            duration: 100
        }
    }
    
    function tremble() {
        trembleAnimation.start()
    }

    ProgressBar {
        id: progressBar
        width: parent.width
        height: 4
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -4
        from: 0.0
        to: 100.0

        visible: false
        NumberAnimation on value {
            running: progressBar.visible
            from: 100.0
            to: 0.0
            duration: config.roomTimeout * 1000

            onFinished: {
                progressBar.visible = false;
                root.progressTip = "";
            }
        }
    }

    Image {
        anchors.top: progressBar.bottom
        anchors.topMargin: 1
        source: SkinBank.PHOTO_DIR + "control/tip"
        visible: progressTip.text != ""
        Text {
            id: progressTip
            font.family: "FZLiBian-S02"
            font.pixelSize: 18
            x: 18
            color: "white"
            text: ""
        }
    }

    PixmapAnimation {
        id: animSelectable
        source: "selectable"
        anchors.centerIn: parent
        loop: true
    }

    InvisibleCardArea {
        id: handcardAreaItem
        anchors.centerIn: parent
    }

    DelayedTrickArea {
        id: delayedTrickAreaItem
        rows: 1
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
    }

    InvisibleCardArea {
        id: defaultArea
        anchors.centerIn: parent
    }

    onGeneralChanged: {
        if (!roomScene.isStarted) return;
        generalName.text = Backend.translate(general);
        let data = JSON.parse(Backend.getGeneralData(general));
        kingdom = data[0];
    }
}

import QtQuick 2.15
import QtGraphicalEffects 1.15
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
    property int handcards: 0
    property int maxHp: 0
    property int hp: 0
    property int seatNumber: 1
    property bool isDead: false
    property bool dying: false
    property bool faceturned: false
    property bool chained: false
    property bool drank: false
    property bool isOwner: false

    Behavior on x {
        NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
    }

    Behavior on y {
        NumberAnimation { duration: 600; easing.type: Easing.InOutQuad }
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
        id: turnedOver
        visible: root.faceturned
        source: SkinBank.PHOTO_DIR + "faceturned"
        anchors.centerIn: photoMask
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
}

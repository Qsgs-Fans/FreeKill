import QtQuick 2.15
import QtGraphicalEffects 1.15
import "PhotoElement"
import "../skin-bank.js" as SkinBank

Item {
    id: root
    width: 175
    height: 233
    property string general: "liubei"
    property string pack:"standard"
    property string screenName: ""
    property string role: "lord"
    property string kingdom: "shu"
    property string netstate: "trust"
    property int handcards: 0
    property int maxHp: 5
    property int hp: -1
    property int seatNumber: 3
    property bool isDead: false
    property bool dying: false

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
        text: "刘备"
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
        source: SkinBank.PACKAGES + pack + "/image/generals/" + general
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

    Text {
        id: seatNum
        visible: false // TODO
        property var seatChr: ["一", "二", "三", "四", "五", "六", "七"]
        font.family: "FZLiShu II-S06S"
        text: seatChr[root.seatNumber - 1]
    }
}

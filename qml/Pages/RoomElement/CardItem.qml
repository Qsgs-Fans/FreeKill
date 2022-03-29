import QtQuick 2.15
import QtGraphicalEffects 1.0
import "../skin-bank.js" as SkinBank

/* Layout of card:
 *      +--------+
 * num -|5       |
 * suit-|s       |
 *      |  img   |
 *      |        |
 *      |footnote|
 *      +--------+
 */

Item {
    id: root
    width: 93
    height: 130

    // properties for the view
    property string suit: "club"
    property int number: 7
    property string name: "slash"
    property string color: ""    // only use when suit is empty
    property string footnote: "曹操对刘备"    // footnote, e.g. "A use card to B"
    property bool footnoteVisible: true
    property bool known: true       // if false it only show a card back
    property bool enabled: true     // if false the card will be grey
    property alias card: cardItem
    property alias glow: glowItem

    function getColor() {
        if (suit != "")
            return (suit == "heart" || suit == "diamond") ? "red" : "black";
        else return color;
    }

    // properties for animation and game system
    property int cid: 0
    property bool selectable: true
    property bool selected: false
    property bool draggable: false
    property bool autoBack: true
    property int origX: 0
    property int origY: 0
    property real origOpacity: 1
    property bool isClicked: false
    property bool moveAborted: false
    property alias goBackAnim: goBackAnimation
    property int goBackDuration: 500

    signal toggleDiscards()
    signal clicked()
    signal doubleClicked()
    signal thrown()
    signal released()
    signal entered()
    signal exited()
    signal moveFinished()
    signal generalChanged()     // For choose general freely
    signal hoverChanged(bool enter)

    RectangularGlow {
        id: glowItem
        anchors.fill: parent
        glowRadius: 8
        spread: 0
        color: "#88FFFFFF"
        cornerRadius: 8
        visible: false
    }

    Image {
        id: cardItem
        source: known ? (name != "" ? SkinBank.CARD_DIR + name : "")
                      : (SkinBank.CARD_DIR + "card-back")
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
    }

    Image {
        id: suitItem
        visible: known
        source: suit != "" ? SkinBank.CARD_SUIT_DIR + suit : ""
        x: 3
        y: 19
        width: 21
        height: 17
    }

    Image {
        id: numberItem
        visible: known
        source: (suit != "" && number > 0) ? SkinBank.CARD_DIR
            + "number/" + root.getColor() + "/" + number : ""
        x: 0
        y: 0
        width: 27
        height: 28
    }

    Image {
        id: colorItem
        visible: known && suit == ""
        source: (visible && color != "") ? SkinBank.CARD_SUIT_DIR + "/" + color : ""
        x: 1
    }

    GlowText {
        id: footnoteItem
        text: footnote
        x: 6
        y: parent.height - height - 6
        width: root.width - x * 2
        color: "#E4D5A0"
        visible: footnoteVisible
        wrapMode: Text.WrapAnywhere
        horizontalAlignment: Text.AlignHCenter
        font.family: "FZLiBian-S02"
        font.pixelSize: 14
        glow.color: "black"
        glow.spread: 1
        glow.radius: 1
        glow.samples: 12
    }

    Rectangle {
        visible: !root.selectable
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: 0.7
    }

    MouseArea {
        anchors.fill: parent
        drag.target: draggable ? parent : undefined
        drag.axis: Drag.XAndYAxis
        hoverEnabled: true

        onReleased: {
            root.isClicked = mouse.isClick;
            parent.released();
            if (autoBack)
                goBackAnimation.start();
        }

        onEntered: {
            parent.entered();
            if (draggable) {
                glow.visible = true;
                root.z++;
            }
        }

        onExited: {
            parent.exited();
            if (draggable) {
                glow.visible = false;
                root.z--;
            }
        }

        onClicked: {
            selected = selectable ? !selected : false;
            parent.clicked();
        }
    }

    ParallelAnimation {
        id: goBackAnimation

        PropertyAnimation {
            target: root
            property: "x"
            to: origX
            easing.type: Easing.OutQuad
            duration: goBackDuration
        }

        PropertyAnimation {
            target: root
            property: "y"
            to: origY
            easing.type: Easing.OutQuad
            duration: goBackDuration
        }

        SequentialAnimation {
            PropertyAnimation {
                target: root
                property: "opacity"
                to: 1
                easing.type: Easing.OutQuad
                duration: goBackDuration * 0.8
            }

            PropertyAnimation {
                target: root
                property: "opacity"
                to: origOpacity
                easing.type: Easing.OutQuad
                duration: goBackDuration * 0.2
            }
        }

        onStopped: {
            if (!moveAborted)
                root.moveFinished();
        }
    }

    function setData(data)
    {
        cid = data.cid;
        name = data.name;
        suit = data.suit;
        number = data.number;
        color = data.color;
    }

    function toData()
    {
        var data = {
            cid: cid,
            name: name,
            suit: suit,
            number: number,
            color: color
        };
        return data;
    }

    function goBack(animated)
    {
        if (animated) {
            moveAborted = true;
            goBackAnimation.stop();
            moveAborted = false;
            goBackAnimation.start();
        } else {
            x = origX;
            y = origY;
            opacity = origOpacity;
        }
    }

    function destroyOnStop()
    {
        root.moveFinished.connect(function(){
            destroy();
        });
    }
}

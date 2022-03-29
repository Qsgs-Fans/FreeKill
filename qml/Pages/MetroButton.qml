import QtQuick 2.15

Item {
    property bool enabled: true
    property alias text: title.text
    property alias textColor: title.color
    property alias textFont: title.font
    property alias backgroundColor: bg.color
    property alias border: bg.border
    property alias iconSource: icon.source
    property int padding: 5

    signal clicked

    id: button
    width: icon.width + title.implicitWidth + padding * 2
    height: Math.max(icon.height, title.implicitHeight) + padding * 2

    Rectangle {
        id: bg
        anchors.fill: parent
        color: "black"
        border.width: 2
        border.color: "white"
        opacity: 0.8
    }

    states: [
        State {
            name: "hovered"; when: mouse.containsMouse
            PropertyChanges { target: bg; color: "white" }
            PropertyChanges { target: title; color: "black" }
        },
        State {
            name: "disabled"; when: !enabled
            PropertyChanges { target: button; opacity: 0.2 }
        }
    ]

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: parent.enabled
        onReleased: if (parent.enabled) parent.clicked()
    }

    Row {
        x: padding
        y: padding
        anchors.centerIn: parent
        spacing: 5

        Image {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            fillMode: Image.PreserveAspectFit
        }

        Text {
            id: title
            font.pixelSize: 18
            // font.family: "WenQuanYi Micro Hei"
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            color: "white"
        }
    }
}


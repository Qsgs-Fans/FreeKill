import QtQuick 2.15

Rectangle {
    function show(text, duration) {
        message.text = text;
        time = Math.max(duration, 2 * fadeTime);
        animation.start();
    }

    id: root

    readonly property real defaultTime: 3000
    property real time: defaultTime
    readonly property real fadeTime: 300

    anchors.horizontalCenter: parent != null ? parent.horizontalCenter : undefined
    height: message.height + 20
    width: message.width + 40
    radius: 16

    opacity: 0
    color: "#F2808A87"

    Text {
        id: message
        color: "white"
        horizontalAlignment: Text.AlignHCenter
        anchors.centerIn: parent
    }

    SequentialAnimation on opacity {
        id: animation
        running: false


        NumberAnimation {
            to: .9
            duration: fadeTime
        }

        PauseAnimation {
            duration: time - 2 * fadeTime
        }

        NumberAnimation {
            to: 0
            duration: fadeTime
        }

        onRunningChanged: {
            if (!running) {
                toast.model.remove(index);
            }
        }
    }
}

import QtQuick 2.15
import "../../skin-bank.js" as SkinBank

Image {
    source: SkinBank.MAGATAMA_DIR + "0"
    state: "3"

    states: [
        State {
            name: "3"
            PropertyChanges {
                target: main
                source: SkinBank.MAGATAMA_DIR + "3"
                opacity: 1
                scale: 1
            }
        },
        State {
            name: "2"
            PropertyChanges {
                target: main
                source: SkinBank.MAGATAMA_DIR + "2"
                opacity: 1
                scale: 1
            }
        },
        State {
            name: "1"
            PropertyChanges {
                target: main
                source: SkinBank.MAGATAMA_DIR + "1"
                opacity: 1
                scale: 1
            }
        },
        State {
            name: "0"
            PropertyChanges {
                target: main
                source: SkinBank.MAGATAMA_DIR + "0"
                opacity: 0
                scale: 4
            }
        }
    ]

    transitions: Transition {
        PropertyAnimation {
            properties: "opacity,scale"
        }
    }

    Image {
        id: main
        anchors.centerIn: parent
    }
}



import QtQuick 2.15
import "../../skin-bank.js" as SkinBank

Image {
    property string value: "unknown"
    property var options: ["unknown", "loyalist", "rebel", "renegade"]

    id: root
    source: visible ? SkinBank.ROLE_DIR + value : ""
    visible: value != "hidden"

    Image {
        property string value: "unknown"

        id: assumptionBox
        source: SkinBank.ROLE_DIR + value
        visible: root.value == "unknown"

        MouseArea {
            anchors.fill: parent
            onClicked: optionPopupBox.visible = true;
        }
    }

    Column {
        id: optionPopupBox
        visible: false
        spacing: 2

        Repeater {
            model: options

            Image {
                source: SkinBank.ROLE_DIR + modelData

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        optionPopupBox.visible = false;
                        assumptionBox.value = modelData;
                    }
                }
            }
        }
    }
}

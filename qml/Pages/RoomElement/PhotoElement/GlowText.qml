import QtQuick 2.15
import QtGraphicalEffects 1.0

Item {
    property alias text: textItem.text
    property alias color: textItem.color
    property alias font: textItem.font
    property alias fontSizeMode: textItem.fontSizeMode
    property alias horizontalAlignment: textItem.horizontalAlignment
    property alias verticalAlignment: textItem.verticalAlignment
    property alias style: textItem.style
    property alias styleColor: textItem.styleColor
    property alias wrapMode: textItem.wrapMode
    property alias lineHeight: textItem.lineHeight
    property alias glow: glowItem

    width: textItem.implicitWidth
    height: textItem.implicitHeight

    Text {
        id: textItem
        anchors.fill: parent
    }

    Glow {
        id: glowItem
        source: textItem
        anchors.fill: textItem
    }
}

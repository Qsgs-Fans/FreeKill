import QtQuick 2.15

Column {
    id: root
    property int maxValue: 4
    property int value: 4
    property var colors: ["#F4180E", "#F4180E", "#E3B006", "#25EC27"]

    Repeater {
        id: repeater
        model: maxValue <= 4 ? maxValue : 0
        Magatama {
            state: (maxValue - 1 - index) >= value ? 0 : (value >= 3 || value >= maxValue ? 3 : (value <= 0 ? 0 : value))
        }
    }

    Column {
        visible: maxValue > 4
        spacing: -4

        Magatama {
            state: (value >= 3 || value >= maxValue) ? 3 : (value <= 0 ? 0 : value)
        }

        GlowText {
            id: hpItem
            width: root.width
            text: value
            color: root.colors[(value >= 3 || value >= maxValue) ? 3 : (value <= 0 ? 0 : value)]
            font.family: "FZLiBian-S02"
            font.pixelSize: 22
            font.bold: true
            horizontalAlignment: Text.AlignHCenter

            glow.color: "#3E3F47"
            glow.spread: 0.8
            glow.radius: 8
            glow.samples: 12
        }

        GlowText {
            id: splitter
            width: root.width
            text: "/"
            z: -10
            color: hpItem.color
            font: hpItem.font
            horizontalAlignment: hpItem.horizontalAlignment

            glow.color: hpItem.glow.color
            glow.spread: hpItem.glow.spread
            glow.radius: hpItem.glow.radius
            glow.samples: hpItem.glow.samples
        }

        GlowText {
            id: maxHpItem
            width: root.width
            text: maxValue
            color: hpItem.color
            font: hpItem.font
            horizontalAlignment: hpItem.horizontalAlignment

            glow.color: hpItem.glow.color
            glow.spread: hpItem.glow.spread
            glow.radius: hpItem.glow.radius
            glow.samples: hpItem.glow.samples
        }
    }
}


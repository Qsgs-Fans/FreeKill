// Copyright (C) 2020 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Templates as T
import QtQuick.NativeStyle as NativeStyle

T.SpinBox {
    id: control

    property bool nativeIndicators: up.indicator.hasOwnProperty("_qt_default")
                                    && down.indicator.hasOwnProperty("_qt_default")
    readonly property bool __notCustomizable: true

    // Note: the indicators are inside the contentItem
    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentItem.implicitWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding,
                             up.implicitIndicatorHeight + down.implicitIndicatorHeight)

    spacing: 2

    validator: IntValidator {
        locale: control.locale.name
        bottom: Math.min(control.from, control.to)
        top: Math.max(control.from, control.to)
    }

    contentItem: TextField {
        text: control.displayText
        font: control.font
        color: control.palette.text
        selectionColor: control.palette.highlight
        selectedTextColor: control.palette.highlightedText
        horizontalAlignment: Qt.AlignLeft
        verticalAlignment: Qt.AlignVCenter
        implicitWidth: Math.max(90 /* minimum */, contentWidth + leftPadding + rightPadding)

        topPadding: 0
        bottomPadding: 0
        leftPadding: 10
        rightPadding: up.indicator.width + 10

        readOnly: !control.editable
        validator: control.validator
        inputMethodHints: control.inputMethodHints

        clip: width < implicitWidth

        readonly property bool __ignoreNotCustomizable: true

        // Since the indicators are embedded inside the TextField we need to avoid that
        // the TextField consumes mouse events for that area.
        // We achieve that by setting a containmentMask
        containmentMask: Item { height: contentItem.height; width: contentItem.width - upAndDown.width }
    }

    NativeStyle.SpinBox {
        id: upAndDown
        control: control
        subControl: NativeStyle.SpinBox.Up
        visible: nativeIndicators
        x: up.indicator.x
        y: up.indicator.y
        //implicitHeight: contentItem.implicitHeight-2
        height: parent.height-2
        useNinePatchImage: false
        z:99
    }

    up.indicator: Item {
        x: parent.width - width - 2
        y: 1
        height: upAndDown.height >> 1
        implicitWidth: upAndDown.implicitWidth
        implicitHeight: (upAndDown.implicitHeight >> 1)
        property bool _qt_default
        readonly property bool __ignoreNotCustomizable: true
    }

    down.indicator: Item {
        x: parent.width - width - 2
        y: up.indicator.y + (upAndDown.height >> 1)
        height: upAndDown.height - up.indicator.height
        implicitWidth: upAndDown.implicitWidth
        implicitHeight: upAndDown.implicitHeight >> 1
        property bool _qt_default
        readonly property bool __ignoreNotCustomizable: true
    }

    // No background, the TextField will cover the whole control
    background: Item {
        readonly property bool __ignoreNotCustomizable: true
    }
}

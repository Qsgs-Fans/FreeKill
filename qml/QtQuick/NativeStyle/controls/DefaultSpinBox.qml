// Copyright (C) 2020 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T
import QtQuick.NativeStyle as NativeStyle

T.SpinBox {
    id: control

    readonly property bool __nativeBackground: background instanceof NativeStyle.StyleItem
    readonly property bool __notCustomizable: true

    implicitWidth: Math.max(implicitBackgroundWidth + spacing + up.implicitIndicatorWidth
                            + leftInset + rightInset,
                            90 /* minimum */ )
    implicitHeight: Math.max(implicitBackgroundHeight, up.implicitIndicatorHeight + down.implicitIndicatorHeight
                    + (spacing * 3)) + topInset + bottomInset

    spacing: 2

    leftPadding: (__nativeBackground ? background.contentPadding.left: 0)
    topPadding: (__nativeBackground ? background.contentPadding.top: 0)
    rightPadding: (__nativeBackground ? background.contentPadding.right : 0) + up.implicitIndicatorWidth + spacing
    bottomPadding: (__nativeBackground ? background.contentPadding.bottom: 0) + spacing

    validator: IntValidator {
        locale: control.locale.name
        bottom: Math.min(control.from, control.to)
        top: Math.max(control.from, control.to)
    }

    contentItem: TextInput {
        text: control.displayText
        font: font.font
        color: control.palette.text
        selectionColor: control.palette.highlight
        selectedTextColor: control.palette.highlightedText
        horizontalAlignment: Qt.AlignLeft
        verticalAlignment: Qt.AlignVCenter

        topPadding: 2
        bottomPadding: 2
        leftPadding: 10
        rightPadding: 10

        readOnly: !control.editable
        validator: control.validator
        inputMethodHints: control.inputMethodHints
    }

    up.indicator: NativeStyle.SpinBox {
        control: control
        subControl: NativeStyle.SpinBox.Up
        x: parent.width - width - spacing
        y: (parent.height / 2) - height
        useNinePatchImage: false
    }

    down.indicator: NativeStyle.SpinBox {
        control: control
        subControl: NativeStyle.SpinBox.Down
        x: up.indicator.x
        y: up.indicator.y + up.indicator.height
        useNinePatchImage: false
    }

    background: NativeStyle.SpinBox {
        control: control
        subControl: NativeStyle.SpinBox.Frame
        contentWidth: contentItem.implicitWidth
        contentHeight: contentItem.implicitHeight
    }
}

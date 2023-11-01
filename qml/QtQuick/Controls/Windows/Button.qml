// Copyright (C) 2020 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Controls.impl
import QtQuick.NativeStyle as NativeStyle

NativeStyle.DefaultButton {
    id: control

    background: NativeStyle.Button {
        control: control
        contentWidth: contentItem.implicitWidth
        contentHeight: contentItem.implicitHeight
        useNinePatchImage: false
        overrideState: NativeStyle.StyleItem.NeverHovered

        readonly property bool __ignoreNotCustomizable: true
    }

    NativeStyle.Button {
        id: hoverButton
        control: control
        x: background.x
        y: background.y
        width: background.width
        height: background.height
        useNinePatchImage: false
        overrideState: NativeStyle.StyleItem.AlwaysHovered
        opacity: control.hovered ? 1 : 0
        visible: opacity !== 0
        Behavior on opacity { NumberAnimation { duration: hoverButton.transitionDuration } }
    }

    contentItem: IconLabel {
        spacing: control.spacing
        mirrored: control.mirrored
        display: control.display

        icon: control.icon
        text: control.text
        font: control.font
        color: control.flat && !control.down ? (control.visualFocus ? control.palette.highlight : control.palette.windowText) : control.palette.buttonText

        readonly property bool __ignoreNotCustomizable: true
    }
}

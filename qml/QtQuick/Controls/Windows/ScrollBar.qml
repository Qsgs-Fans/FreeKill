// Copyright (C) 2020 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.NativeStyle as NativeStyle

NativeStyle.DefaultScrollBar {
    id: controlRoot

    readonly property bool __notCustomizable: true

    topPadding:    orientation === Qt.Vertical   ? controlRoot.__decreaseVisual.indicator.height : 0
    bottomPadding: orientation === Qt.Vertical   ? controlRoot.__increaseVisual.indicator.height : 0
    leftPadding:   orientation === Qt.Horizontal ? controlRoot.__decreaseVisual.indicator.width : 0
    rightPadding:  orientation === Qt.Horizontal ? controlRoot.__increaseVisual.indicator.width : 0

    contentItem: NativeStyle.ScrollBar {
        control: controlRoot
        subControl: NativeStyle.ScrollBar.Handle

        readonly property bool __ignoreNotCustomizable: true
    }

    NativeStyle.ScrollBar {
        // Fade a hovered-looking version of the handle
        // on top of the default handle when hovering it
        x: contentItem.x
        y: contentItem.y
        z: 1
        width: contentItem.width
        height: contentItem.height
        control: controlRoot
        subControl: NativeStyle.ScrollBar.Handle
        overrideState: NativeStyle.StyleItem.AlwaysHovered
        opacity: controlRoot.hovered || control.pressed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: contentItem.transitionDuration } }
    }

    // The groove background should have window color
    Rectangle {
        x: background.x
        y: background.y
        z: -1
        width: background.width
        height: background.height
        color: controlRoot.palette.window
    }

    background: NativeStyle.ScrollBar {
        control: controlRoot
        subControl: NativeStyle.ScrollBar.Groove
        overrideState: NativeStyle.ScrollBar.NeverHovered

        readonly property bool __ignoreNotCustomizable: true
    }

    __decreaseVisual.indicator: NativeStyle.ScrollBar {
        control: controlRoot
        subControl: NativeStyle.ScrollBar.SubLine
        overrideState: NativeStyle.ScrollBar.AlwaysHovered
        opacity: controlRoot.__decreaseVisual.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: contentItem.transitionDuration } }
        useNinePatchImage: false

        readonly property bool __ignoreNotCustomizable: true
    }

    NativeStyle.ScrollBar {
        control: controlRoot
        subControl: NativeStyle.ScrollBar.SubLine
        overrideState: NativeStyle.ScrollBar.AlwaysSunken
        opacity: controlRoot.__decreaseVisual.pressed ? 1 : 0
        useNinePatchImage: false
        z: 1
    }

    __increaseVisual.indicator: NativeStyle.ScrollBar {
        control: controlRoot
        subControl: NativeStyle.ScrollBar.AddLine
        x: orientation === Qt.Horizontal ? controlRoot.width - width : 0
        y: orientation === Qt.Vertical ? controlRoot.height - height : 0
        overrideState: NativeStyle.ScrollBar.AlwaysHovered
        opacity: controlRoot.__increaseVisual.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: contentItem.transitionDuration } }
        useNinePatchImage: false

        readonly property bool __ignoreNotCustomizable: true
    }

    NativeStyle.ScrollBar {
        control: controlRoot
        subControl: NativeStyle.ScrollBar.AddLine
        x: __increaseVisual.indicator.x
        y: __increaseVisual.indicator.y
        z: 1
        overrideState: NativeStyle.ScrollBar.AlwaysSunken
        opacity: controlRoot.__increaseVisual.pressed ? 1 : 0
        useNinePatchImage: false
    }
}

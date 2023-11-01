// Copyright (C) 2020 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T
import QtQuick.NativeStyle as NativeStyle

T.GroupBox {
    id: control

    readonly property bool __nativeBackground: background instanceof NativeStyle.StyleItem
    readonly property bool __notCustomizable: true

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentWidth + leftPadding + rightPadding,
                            implicitLabelWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             contentHeight + topPadding + bottomPadding)

    label: Rectangle {
        color: control.palette.window
        property point labelPos : control.__nativeBackground
                                  ? background.labelPos
                                  : Qt.point(0,0)
        readonly property bool __ignoreNotCustomizable: true
        x: labelPos.x + background.x
        y: labelPos.y + background.y - (__nativeBackground ? background.groupBoxPadding.top : 0)
        width: children[0].implicitWidth
        height: children[0].implicitHeight
        Text {
            width: parent.width
            height: parent.height
            text: control.title
            font: control.font
            color: control.palette.windowText
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }

    leftPadding: __nativeBackground ? background.contentPadding.left : 0
    rightPadding: __nativeBackground ? background.contentPadding.right : 0
    topPadding: __nativeBackground ? background.contentPadding.top : 0
    bottomPadding: __nativeBackground ? background.contentPadding.bottom : 0

    leftInset: __nativeBackground ? background.groupBoxPadding.left : 0
    topInset: __nativeBackground ? background.groupBoxPadding.top : 0

    background: NativeStyle.GroupBox {
        control: control
        contentWidth: contentItem.implicitWidth
        contentHeight: contentItem.implicitHeight

        readonly property bool __ignoreNotCustomizable: true
    }
}

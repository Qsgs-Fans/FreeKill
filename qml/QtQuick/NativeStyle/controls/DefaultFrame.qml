// Copyright (C) 2020 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T
import QtQuick.NativeStyle as NativeStyle

T.Frame {
    id: control

    readonly property bool __nativeBackground: background instanceof NativeStyle.StyleItem
    readonly property bool __notCustomizable: true

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             contentHeight + topPadding + bottomPadding)

    leftPadding: __nativeBackground ? background.contentPadding.left : 12
    rightPadding: __nativeBackground ? background.contentPadding.right : 12
    topPadding: __nativeBackground ? background.contentPadding.top : 12
    bottomPadding: __nativeBackground ? background.contentPadding.bottom : 12

    background: NativeStyle.Frame {
        control: control
        contentWidth: control.contentWidth
        contentHeight: control.contentHeight

        readonly property bool __ignoreNotCustomizable: true
    }
}

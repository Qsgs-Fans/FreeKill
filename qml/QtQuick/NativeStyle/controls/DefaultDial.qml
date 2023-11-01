// Copyright (C) 2020 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T
import QtQuick.NativeStyle as NativeStyle

T.Dial {
    id: control

    readonly property bool __nativeBackground: background instanceof NativeStyle.StyleItem
    readonly property bool __notCustomizable: true

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding,
                            80 /* minimum */ )
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding,
                            80 /* minimum */ )

    background: NativeStyle.Dial {
        control: control
        useNinePatchImage: false

        readonly property bool __ignoreNotCustomizable: true
    }
}

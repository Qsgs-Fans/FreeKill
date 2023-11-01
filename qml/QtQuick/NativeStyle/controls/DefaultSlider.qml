// Copyright (C) 2020 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T
import QtQuick.NativeStyle as NativeStyle

T.Slider {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitHandleWidth + leftPadding + rightPadding,
                            control.horizontal ? 90 : 0 /* minimum */ )
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitHandleHeight + topPadding + bottomPadding,
                            control.vertical ? 90 : 0 /* minimum */ )

    readonly property bool __notCustomizable: true

    background: NativeStyle.Slider {
        control: control
        subControl: NativeStyle.Slider.Groove
        // We normally cannot use a nine patch image for the
        // groove if we draw tickmarks (since then the scaling
        // would scale the tickmarks too). The groove might
        // also use a different background color before, and
        // after, the handle.
        useNinePatchImage: false

        readonly property bool __ignoreNotCustomizable: true
    }

    handle: NativeStyle.Slider {
        control: control
        subControl: NativeStyle.Slider.Handle
        x: control.leftPadding + (control.horizontal ? control.visualPosition * (control.availableWidth - width) : (control.availableWidth - width) / 2)
        y: control.topPadding + (control.horizontal ? (control.availableHeight - height) / 2 : control.visualPosition * (control.availableHeight - height))
        useNinePatchImage: false

        readonly property bool __ignoreNotCustomizable: true
    }
}

// Copyright (C) 2017 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Templates as T
import QtQuick.Controls.Universal

T.Dial {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    background: Rectangle {
        implicitWidth: 100
        implicitHeight: 100

        x: control.width / 2 - width / 2
        y: control.height / 2 - height / 2
        width: Math.max(64, Math.min(control.width, control.height))
        height: width
        radius: width / 2
        color: "transparent"
        border.color: !control.enabled ? control.Universal.baseLowColor : control.Universal.baseMediumColor
        border.width: 2
    }

    handle: Rectangle {
        implicitWidth: 14
        implicitHeight: 14

        x: control.background.x + control.background.width / 2 - width / 2
        y: control.background.y + control.background.height / 2 - height / 2

        radius: width / 2
        color: !control.enabled ? control.Universal.baseLowColor :
                control.pressed ? control.Universal.baseMediumColor :
                control.hovered ? control.Universal.baseHighColor : control.Universal.baseMediumHighColor

        transform: [
            Translate {
                y: -control.background.height * 0.4 + control.handle.height / 2
            },
            Rotation {
                angle: control.angle
                origin.x: control.handle.width / 2
                origin.y: control.handle.height / 2
            }
        ]
    }
}

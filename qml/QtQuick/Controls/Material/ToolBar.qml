// Copyright (C) 2017 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Templates as T
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl

T.ToolBar {
    id: control

    Material.elevation: 0

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             contentHeight + topPadding + bottomPadding)

    Material.foreground: Material.toolTextColor

    spacing: 16

    background: Rectangle {
        implicitHeight: 48
        color: control.Material.toolBarColor

        layer.enabled: control.Material.elevation > 0
        layer.effect: ElevationEffect {
            elevation: control.Material.elevation
            fullWidth: true
        }
    }
}

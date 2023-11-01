// Copyright (C) 2017 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Templates as T
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl

Rectangle {
    id: indicator
    implicitWidth: 20
    implicitHeight: 20
    radius: width / 2
    border.width: 2
    border.color: !control.enabled ? control.Material.hintTextColor
        : control.checked || control.down ? control.Material.accentColor : control.Material.secondaryTextColor
    color: "transparent"

    property T.AbstractButton control

    Rectangle {
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 10
        height: 10
        radius: width / 2
        color: parent.border.color
        visible: indicator.control.checked || indicator.control.down
    }
}

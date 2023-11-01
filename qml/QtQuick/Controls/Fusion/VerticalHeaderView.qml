// Copyright (C) 2020 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Templates as T
import QtQuick.Controls.Fusion.impl

T.VerticalHeaderView {
    id: control

    // The contentWidth of TableView will be zero at start-up, until the delegate
    // items have been loaded. This means that even if the implicit width of
    // VerticalHeaderView should be the same as the content width in the end, we
    // need to ensure that it has at least a width of 1 at start-up, otherwise
    // TableView won't bother loading any delegates at all.
    implicitWidth: Math.max(1, contentWidth)
    implicitHeight: syncView ? syncView.height : 0

    delegate: Rectangle {
        id: delegate

        required property var model

        // Qt6: add cellPadding (and font etc) as public API in headerview
        readonly property real cellPadding: 8

        implicitWidth: Math.max(control.width, text.implicitWidth + (cellPadding * 2))
        implicitHeight: text.implicitHeight + (cellPadding * 2)

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Fusion.gradientStart(control.palette.button)
            }
            GradientStop {
                position: 1
                color: Fusion.gradientStop(control.palette.button)
            }
        }

        Label {
            id: text
            text: delegate.model[control.textRole]
            width: delegate.width
            height: delegate.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}

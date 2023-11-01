// Copyright (C) 2020 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T
import QtQuick.NativeStyle as NativeStyle

T.ScrollBar {
    id: control

    readonly property bool __nativeContentItem: contentItem instanceof NativeStyle.StyleItem

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    visible: policy === T.ScrollBar.AlwaysOn || (policy === T.ScrollBar.AsNeeded && size < 1.0)
    minimumSize: !__nativeContentItem ? 10 : orientation === Qt.Vertical ?
        contentItem.minimumSize.height / height : contentItem.minimumSize.width / width

    background: NativeStyle.ScrollBar {
        control: control
        subControl: NativeStyle.ScrollBar.Groove
    }

    contentItem: NativeStyle.ScrollBar {
        control: control
        subControl: NativeStyle.ScrollBar.Handle
    }
}

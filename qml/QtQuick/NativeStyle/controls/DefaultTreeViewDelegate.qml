// Copyright (C) 2021 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Templates as T
import QtQuick.NativeStyle as NativeStyle
import QtQuick.Controls

T.TreeViewDelegate {
    id: control

    implicitWidth: leftMargin + __contentIndent + implicitContentWidth + rightPadding + rightMargin
    implicitHeight: Math.max(indicator ? indicator.height : 0, implicitContentHeight) * 1.25

    indentation: indicator ? indicator.width : 12
    leftMargin: 4
    rightMargin: 4
    spacing: 4

    topPadding: contentItem ? (height - contentItem.implicitHeight) / 2 : 0
    leftPadding: !mirrored ? leftMargin + __contentIndent : width - leftMargin - __contentIndent - implicitContentWidth

    highlighted: control.selected || control.current
               || ((control.treeView.selectionBehavior === TableView.SelectRows
               || control.treeView.selectionBehavior === TableView.SelectionDisabled)
               && control.row === control.treeView.currentRow)

    required property int row
    required property var model
    readonly property real __contentIndent: !isTreeNode ? 0 : (depth * indentation) + (indicator ? indicator.width + spacing : 0)
    readonly property bool __notCustomizable: true

    indicator: Item {
        // Create an area that is big enough for the user to
        // click on, since the image is a bit small.
        readonly property real __indicatorIndent: control.leftMargin + (control.depth * control.indentation)
        x: !control.mirrored ? __indicatorIndent : control.width - __indicatorIndent - width
        y: (control.height - height) / 2
        width: 16
        height: 16
        NativeStyle.TreeIndicator {
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2
            control: control
            useNinePatchImage: false
        }

        readonly property bool __ignoreNotCustomizable: true
    }

    background: Rectangle {
        color: control.highlighted ? control.palette.highlight
               : (control.treeView.alternatingRows && control.row % 2 !== 0
               ? control.palette.alternateBase : control.palette.base)

        readonly property bool __ignoreNotCustomizable: true
    }

    contentItem: Label {
        clip: false
        text: control.model.display
        elide: Text.ElideRight
        color: control.highlighted ? control.palette.highlightedText : control.palette.buttonText
        visible: !control.editing

        readonly property bool __ignoreNotCustomizable: true
    }

    // The edit delegate is a separate component, and doesn't need
    // to follow the same strict rules that are applied to a control.
    // qmllint disable attached-property-reuse
    // qmllint disable controls-attached-property-reuse
    // qmllint disable controls-sanity
    TableView.editDelegate: FocusScope {
        width: parent.width
        height: parent.height

        readonly property int __role: {
            let model = control.treeView.model
            let index = control.treeView.index(row, column)
            let editText = model.data(index, Qt.EditRole)
            return editText !== undefined ? Qt.EditRole : Qt.DisplayRole
        }

        TextField {
            id: textField
            x: control.contentItem.x
            y: (parent.height - height) / 2
            width: control.contentItem.width
            text: control.treeView.model.data(control.treeView.index(row, column), __role)
            focus: true
        }

        TableView.onCommit: {
            let index = TableView.view.index(row, column)
            TableView.view.model.setData(index, textField.text, __role)
        }

        Component.onCompleted: textField.selectAll()
    }
    // qmllint enable attached-property-reuse
    // qmllint enable controls-attached-property-reuse
    // qmllint enable controls-sanity
}

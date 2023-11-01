// Copyright (C) 2021 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Controls.Fusion
import QtQuick.Controls.Fusion.impl
import QtQuick.Dialogs
import QtQuick.Dialogs.quickimpl
import QtQuick.Layouts
import QtQuick.Templates as T

import "." as DialogsImpl

FileDialogImpl {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentWidth + leftPadding + rightPadding,
                            implicitHeaderWidth,
                            implicitFooterWidth)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             contentHeight + topPadding + bottomPadding
                             + (implicitHeaderHeight > 0 ? implicitHeaderHeight + spacing : 0)
                             + (implicitFooterHeight > 0 ? implicitFooterHeight + spacing : 0))

    padding: 6
    horizontalPadding: 12

    standardButtons: T.Dialog.Open | T.Dialog.Cancel

    /*
        We use attached properties because we want to handle logic in C++, and:
        - We can't assume the footer only contains a DialogButtonBox (which would allow us
          to connect up to it in QQuickFileDialogImpl); it also needs to hold a ComboBox
          and therefore the root footer item will be e.g. a layout item instead.
        - We don't want to create our own "FileDialogButtonBox" (in order to be able to handle the logic
          in C++) because we'd need to copy (and hence duplicate code in) DialogButtonBox.qml.
    */
    FileDialogImpl.buttonBox: buttonBox
    FileDialogImpl.nameFiltersComboBox: nameFiltersComboBox
    FileDialogImpl.fileDialogListView: fileDialogListView
    FileDialogImpl.breadcrumbBar: breadcrumbBar
    FileDialogImpl.fileNameLabel: fileNameLabel
    FileDialogImpl.fileNameTextField: fileNameTextField

    background: Rectangle {
        implicitWidth: 600
        implicitHeight: 400
        color: control.palette.window
        border.color: control.palette.mid
        radius: 2

        Rectangle {
            z: -1
            x: 1
            y: 1
            width: parent.width
            height: parent.height
            color: control.palette.shadow
            opacity: 0.2
            radius: 2
        }
    }

    header: ColumnLayout {
        spacing: 0

        Label {
            objectName: "dialogTitleBarLabel"
            text: control.title
            horizontalAlignment: Label.AlignHCenter
            elide: Label.ElideRight
            font.bold: true
            padding: 6

            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.topMargin: control.title.length > 0 ? 0 : 12
            Layout.preferredHeight: control.title.length > 0 ? implicitHeight : 0
        }

        DialogsImpl.FolderBreadcrumbBar {
            id: breadcrumbBar
            dialog: control

            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12

            KeyNavigation.tab: fileDialogListView
        }
    }

    contentItem: Frame {
        padding: 0
        verticalPadding: 1

        ListView {
            id: fileDialogListView
            objectName: "fileDialogListView"
            anchors.fill: parent
            clip: true
            focus: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {}

            model: FolderListModel {
                folder: control.currentFolder
                nameFilters: control.selectedNameFilter.globs
                showDirsFirst: PlatformTheme.themeHint(PlatformTheme.ShowDirectoriesFirst)
                sortCaseSensitive: false
            }
            delegate: DialogsImpl.FileDialogDelegate {
                objectName: "fileDialogDelegate" + index
                x: 1
                width: ListView.view.width - 2
                highlighted: ListView.isCurrentItem
                dialog: control
                fileDetailRowWidth: nameFiltersComboBox.width

                KeyNavigation.backtab: breadcrumbBar
                KeyNavigation.tab: nameFiltersComboBox
            }
        }
    }

    footer: GridLayout {
        columnSpacing: 12
        columns: 3

        Label {
            id: fileNameLabel
            text: qsTr("File name")
            Layout.leftMargin: 12
            visible: false
        }

        TextField {
            id: fileNameTextField
            objectName: "fileNameTextField"
            text: control.fileName
            visible: false

            Layout.fillWidth: true
        }

        Label {
            text: qsTr("Filter")
            Layout.column: 0
            Layout.row: 1
            Layout.leftMargin: 12
            Layout.bottomMargin: 12
        }


        ComboBox {
            // OK to use IDs here, since users shouldn't be overriding this stuff.
            id: nameFiltersComboBox
            model: control.nameFilters

            Layout.fillWidth: true
            Layout.bottomMargin: 12
        }

        DialogButtonBox {
            id: buttonBox
            standardButtons: control.standardButtons
            spacing: 6
            horizontalPadding: 0
            verticalPadding: 0
            background: null

            // TODO: make the orientation vertical
            Layout.row: 1
            Layout.column: 2
            Layout.columnSpan: 1
            Layout.rightMargin: 12
            Layout.bottomMargin: 12
        }
    }

    T.Overlay.modal: Rectangle {
        color: Fusion.topShadow
    }

    T.Overlay.modeless: Rectangle {
        color: Fusion.topShadow
    }
}

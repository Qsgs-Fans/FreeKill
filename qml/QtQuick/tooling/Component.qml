// Copyright (C) 2020 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QML

QtObject {
    default property list<Member> members

    property string file
    required property string name
    property string prototype
    property var exports: []
    property var exportMetaObjectRevisions: []
    property var interfaces: []
    property var deferredNames: []
    property var immediateNames: []
    property string attachedType
    property string valueType
    property string extension
    property bool isSingleton: false
    property bool isCreatable: name.length > 0
    property bool isComposite: false
    property bool hasCustomParser: false
    property bool extensionIsNamespace: false
    property string accessSemantics: "reference"
    property string defaultProperty
    property string parentProperty
}

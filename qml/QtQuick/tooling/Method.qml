// Copyright (C) 2020 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QML

Member {
    default property list<Parameter> parameters
    property string type
    property int revision: 0
    property bool isConstructor: false
    property bool isList: false
    property bool isPointer: false
    property bool isJavaScriptFunction: false
    property bool isCloned: false
}

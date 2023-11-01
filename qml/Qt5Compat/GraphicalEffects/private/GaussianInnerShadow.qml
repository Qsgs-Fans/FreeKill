// Copyright (C) 2022 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import Qt5Compat.GraphicalEffects.private

Item {
    id: rootItem
    property variant source
    property real radius: 0.0
    property int maximumRadius: 0
    property real horizontalOffset: 0
    property real verticalOffset: 0
    property real spread: 0
    property color color: "black"
    property bool cached: false

    SourceProxy {
        id: sourceProxy
        input: rootItem.source
    }

    ShaderEffectSource {
        id: cacheItem
        anchors.fill: shaderItem
        visible: rootItem.cached
        smooth: true
        sourceItem: shaderItem
        live: true
        hideSource: visible
    }

    ShaderEffect{
        id: shadowItem
        anchors.fill: parent

        property variant original: sourceProxy.output
        property color color: rootItem.color
        property real horizontalOffset: rootItem.horizontalOffset / rootItem.width
        property real verticalOffset: rootItem.verticalOffset / rootItem.height

        visible: false
        fragmentShader: "qrc:/qt-project.org/imports/Qt5Compat/GraphicalEffects/shaders_ng/gaussianinnershadow_shadow.frag.qsb"
    }

    GaussianDirectionalBlur {
        id: blurItem
        anchors.fill: parent
        horizontalStep: 0.0
        verticalStep: 1.0 / parent.height
        source: horizontalBlur
        radius: rootItem.radius
        maximumRadius: rootItem.maximumRadius
        visible: false
    }

    GaussianDirectionalBlur {
        id: horizontalBlur
        width: transparentBorder ? parent.width + 2 * maximumRadius : parent.width
        height: parent.height
        horizontalStep: 1.0 / parent.width
        verticalStep: 0.0
        source: shadowItem
        radius: rootItem.radius
        maximumRadius: rootItem.maximumRadius
        visible: false
    }

    ShaderEffectSource {
        id: blurredSource
        sourceItem: blurItem
        live: true
        smooth: true
    }

    ShaderEffect {
        id: shaderItem
        anchors.fill: parent

        property variant original: sourceProxy.output
        property variant shadow: blurredSource
        property real spread: 1.0 - (rootItem.spread * 0.98)
        property color color: rootItem.color

        fragmentShader: "qrc:/qt-project.org/imports/Qt5Compat/GraphicalEffects/shaders_ng/gaussianinnershadow.frag.qsb"
    }
}

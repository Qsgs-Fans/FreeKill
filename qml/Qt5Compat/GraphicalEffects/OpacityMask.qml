// Copyright (C) 2020 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import Qt5Compat.GraphicalEffects.private

/*!
    \qmltype OpacityMask
    \inqmlmodule Qt5Compat.GraphicalEffects
    \since QtGraphicalEffects 1.0
    \inherits QtQuick2::Item
    \ingroup qtgraphicaleffects-mask
    \brief Masks the source item with another item.

    \table
    \header
        \li Source
        \li MaskSource
        \li Effect applied
    \row
        \li \image Original_bug.png
        \li \image OpacityMask_mask.png
        \li \image OpacityMask_bug.png
    \endtable

    \section1 Example

    The following example shows how to apply the effect.
    \snippet OpacityMask-example.qml example

*/
Item {
    id: rootItem

    /*!
        This property defines the source item that is going to be masked.

        \note It is not supported to let the effect include itself, for
        instance by setting source to the effect's parent.
    */
    property variant source

    /*!
        This property defines the item that is going to be used as the mask. The
        mask item gets rendered into an intermediate pixel buffer and the alpha
        values from the result are used to determine the source item's pixels
        visibility in the display.

        \table
        \header
            \li Original
            \li Mask
            \li Effect applied
        \row
            \li \image Original_bug.png
            \li \image OpacityMask_mask.png
            \li \image OpacityMask_bug.png
        \endtable
    */
    property variant maskSource

    /*!
        This property allows the effect output pixels to be cached in order to
        improve the rendering performance.

        Every time the source or effect properties are changed, the pixels in
        the cache must be updated. Memory consumption is increased, because an
        extra buffer of memory is required for storing the effect output.

        It is recommended to disable the cache when the source or the effect
        properties are animated.

        By default, the property is set to \c false.

        \note It is not supported to let the effect include itself, for
        instance by setting maskSource to the effect's parent.
    */
    property bool cached: false

    /*!
        This property controls how the alpha values of the sourceMask will behave.

        If this property is \c false, the resulting opacity is the source alpha
        multiplied with the mask alpha, \c{As * Am}.

        If this property is \c true, the resulting opacity is the source alpha
        multiplied with the inverse of the mask alpha, \c{As * (1 - Am)}.

        The default is \c false.

        \since 5.7
    */
    property bool invert: false

    SourceProxy {
        id: sourceProxy
        input: rootItem.source
    }

    SourceProxy {
        id: maskSourceProxy
        input: rootItem.maskSource
    }

    ShaderEffectSource {
        id: cacheItem
        anchors.fill: parent
        visible: rootItem.cached
        smooth: true
        sourceItem: shaderItem
        live: true
        hideSource: visible
    }

    ShaderEffect {
        id: shaderItem
        property variant source: sourceProxy.output
        property variant maskSource: maskSourceProxy.output

        anchors.fill: parent

        fragmentShader: invert ? "qrc:/qt-project.org/imports/Qt5Compat/GraphicalEffects/shaders_ng/opacitymask_invert.frag.qsb" : "qrc:/qt-project.org/imports/Qt5Compat/GraphicalEffects/shaders_ng/opacitymask.frag.qsb"
    }
}

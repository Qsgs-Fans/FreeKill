// Copyright (C) 2020 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import Qt5Compat.GraphicalEffects.private

/*!
    \qmltype BrightnessContrast
    \inqmlmodule Qt5Compat.GraphicalEffects
    \since QtGraphicalEffects 1.0
    \inherits QtQuick2::Item
    \ingroup qtgraphicaleffects-color
    \brief Adjusts brightness and contrast.

    This effect adjusts the source item colors.
    Brightness adjustment changes the perceived luminance of the source item.
    Contrast adjustment increases or decreases the color
    and brightness variations.

    \table
    \header
        \li Source
        \li Effect applied
    \row
        \li \image Original_bug.png
        \li \image BrightnessContrast_bug.png
    \endtable

    \section1 Example

    The following example shows how to apply the effect.
    \snippet BrightnessContrast-example.qml example

*/
Item {
    id: rootItem

    /*!
        This property defines the source item that provides the source pixels
        for the effect.

        \note It is not supported to let the effect include itself, for
        instance by setting source to the effect's parent.
    */
    property variant source

    /*!
        This property defines how much the source brightness is increased or
        decreased.

        The value ranges from -1.0 to 1.0. By default, the property is set to \c
        0.0 (no change).

        \table
        \header
        \li Output examples with different brightness values
        \li
        \li
        \row
            \li \image BrightnessContrast_brightness1.png
            \li \image BrightnessContrast_brightness2.png
            \li \image BrightnessContrast_brightness3.png
        \row
            \li \b { brightness: -0.25 }
            \li \b { brightness: 0 }
            \li \b { brightness: 0.5 }
        \row
            \li \l contrast: 0
            \li \l contrast: 0
            \li \l contrast: 0
        \endtable

    */
    property real brightness: 0.0

    /*!
        This property defines how much the source contrast is increased or
        decreased. The decrease of the contrast is linear, but the increase is
        applied with a non-linear curve to allow very high contrast adjustment at
        the high end of the value range.

        \table
        \header
            \li Contrast adjustment curve
        \row
            \li \image BrightnessContrast_contrast_graph.png
        \endtable

       The value ranges from -1.0 to 1.0. By default, the property is set to \c 0.0 (no change).

        \table
        \header
        \li Output examples with different contrast values
        \li
        \li
        \row
            \li \image BrightnessContrast_contrast1.png
            \li \image BrightnessContrast_contrast2.png
            \li \image BrightnessContrast_contrast3.png
        \row
            \li \b { contrast: -0.5 }
            \li \b { contrast: 0 }
            \li \b { contrast: 0.5 }
        \row
            \li \l brightness: 0
            \li \l brightness: 0
            \li \l brightness: 0
        \endtable

    */
    property real contrast: 0.0

    /*!
        This property allows the effect output pixels to be cached in order to
        improve the rendering performance.

        Every time the source or effect properties are changed, the pixels in
        the cache must be updated. Memory consumption is increased, because an
        extra buffer of memory is required for storing the effect output.

        It is recommended to disable the cache when the source or the effect
        properties are animated.

        By default, the property is set to \c false.

    */
    property bool cached: false

    SourceProxy {
        id: sourceProxy
        input: rootItem.source
        interpolation: input && input.smooth ? SourceProxy.LinearInterpolation : SourceProxy.NearestInterpolation
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
        property real brightness: rootItem.brightness
        property real contrast: rootItem.contrast

        anchors.fill: parent
        blending: !rootItem.cached

        fragmentShader: "qrc:/qt-project.org/imports/Qt5Compat/GraphicalEffects/shaders_ng/brightnesscontrast.frag.qsb"
    }
}

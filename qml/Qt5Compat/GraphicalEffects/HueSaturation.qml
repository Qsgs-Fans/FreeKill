// Copyright (C) 2020 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import Qt5Compat.GraphicalEffects.private

/*!
    \qmltype HueSaturation
    \inqmlmodule Qt5Compat.GraphicalEffects
    \since QtGraphicalEffects 1.0
    \inherits QtQuick2::Item
    \ingroup qtgraphicaleffects-color
    \brief Alters the source item colors in the HSL color space.

    HueSaturation is similar to the \l Colorize effect, but the hue and
    saturation property values are handled differently. The HueSaturation effect
    always shifts the hue, saturation, and lightness from the original, instead
    of setting them.

    \table
    \header
        \li Source
        \li Effect applied
    \row
        \li \image Original_bug.png
        \li \image HueSaturation_bug.png
    \endtable

    \section1 Example

    The following example shows how to apply the effect.
    \snippet HueSaturation-example.qml example

*/
Item {
    id: rootItem

    /*!
        This property defines the source item that provides the source pixels
        for the effect.

        \note It is not supported to let the effect include itself, for
        instance by setting source to the effect's parent.
    */
    property variant source: 0

    /*!
        This property defines the hue value which is added to the source hue
        value.

        The value ranges from -1.0 (decrease) to 1.0 (increase). By default, the
        property is set to \c 0.0 (no change).

        \table
        \header
        \li Output examples with different hue values
        \li
        \li
        \row
            \li \image HueSaturation_hue1.png
            \li \image HueSaturation_hue2.png
            \li \image HueSaturation_hue3.png
        \row
            \li \b { hue: -0.3 }
            \li \b { hue: 0.0 }
            \li \b { hue: 0.3 }
        \row
            \li \l saturation: 0
            \li \l saturation: 0
            \li \l saturation: 0
        \row
            \li \l lightness: 0
            \li \l lightness: 0
            \li \l lightness: 0
        \endtable

    */
    property real hue: 0.0

    /*!
        This property defines the saturation value value which is added to the
        source saturation value.

        The value ranges from -1.0 (decrease) to 1.0 (increase). By default, the
        property is set to \c 0.0 (no change).

        \table
        \header
        \li Output examples with different saturation values
        \li
        \li
        \row
            \li \image HueSaturation_saturation1.png
            \li \image HueSaturation_saturation2.png
            \li \image HueSaturation_saturation3.png
        \row
            \li \b { saturation: -0.8 }
            \li \b { saturation: 0.0 }
            \li \b { saturation: 1.0 }
        \row
            \li \l hue: 0
            \li \l hue: 0
            \li \l hue: 0
        \row
            \li \l lightness: 0
            \li \l lightness: 0
            \li \l lightness: 0
        \endtable

    */
    property real saturation: 0.0

    /*!
        This property defines the lightness value which is added to the source
        saturation value.

        The value ranges from -1.0 (decrease) to 1.0 (increase). By default, the
        property is set to \c 0.0 (no change).

        \table
        \header
        \li Output examples with different lightness values
        \li
        \li
        \row
            \li \image HueSaturation_lightness1.png
            \li \image HueSaturation_lightness2.png
            \li \image HueSaturation_lightness3.png
        \row
            \li \b { lightness: -0.5 }
            \li \b { lightness: 0.0 }
            \li \b { lightness: 0.5 }
        \row
            \li \l hue: 0
            \li \l hue: 0
            \li \l hue: 0
        \row
            \li \l saturation: 0
            \li \l saturation: 0
            \li \l saturation: 0
        \endtable

    */
    property real lightness: 0.0

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
        property variant hsl: Qt.vector3d(rootItem.hue, rootItem.saturation, rootItem.lightness)

        anchors.fill: parent

        fragmentShader: "qrc:/qt-project.org/imports/Qt5Compat/GraphicalEffects/shaders_ng/huesaturation.frag.qsb"
    }
}

// Copyright (C) 2020 The Qt Company Ltd.
// Copyright (C) 2017 Jolla Ltd, author: <gunnar.sletta@jollamobile.com>
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import Qt5Compat.GraphicalEffects.private

/*!
    \qmltype Glow
    \inqmlmodule Qt5Compat.GraphicalEffects
    \since QtGraphicalEffects 1.0
    \inherits QtQuick2::Item
    \ingroup qtgraphicaleffects-glow
    \brief Generates a blurred and colorized image of the source and places it
    behind the original, giving impression that the source is glowing.

    \table
    \header
        \li Source
        \li Effect applied
    \row
        \li \image Original_butterfly_black.png
        \li \image Glow_butterfly.png
    \endtable

    \section1 Example

    The following example shows how to apply the effect.
    \snippet Glow-example.qml example

*/
Item {
    id: root

    DropShadowBase {
        id: dps
        anchors.fill: parent
        color: "white"
        spread: 0.5
        horizontalOffset: 0
        verticalOffset: 0
    }

    /*!
        This property defines the source item that is going to be used as source
        for the generated glow.

        \note It is not supported to let the effect include itself, for
        instance by setting source to the effect's parent.
    */
    property alias source: dps.source

    /*!
        Radius defines the softness of the glow. A larger radius causes the
        edges of the glow to appear more blurry.

        Depending on the radius value, value of the \l{Glow::samples}{samples}
        should be set to sufficiently large to ensure the visual quality.

        The ideal blur is achieved by selecting \c samples and \c radius such
        that \c {samples = 1 + radius * 2}, such as:

        \table
        \header \li Radius             \li Samples
        \row    \li 0 \e{(no blur)}    \li 1
        \row    \li 1                  \li 3
        \row    \li 2                  \li 5
        \row    \li 3                  \li 7
        \endtable

        By default, the property is set to \c {floor(samples/2)}.

        \table
        \header
        \li Output examples with different radius values
        \li
        \li
        \row
            \li \image Glow_radius1.png
            \li \image Glow_radius2.png
            \li \image Glow_radius3.png
        \row
            \li \b { radius: 0 }
            \li \b { radius: 6 }
            \li \b { radius: 12 }
        \row
            \li \l samples: 25
            \li \l samples: 25
            \li \l samples: 25
        \row
            \li \l color: #ffffff
            \li \l color: #ffffff
            \li \l color: #ffffff
        \row
            \li \l spread: 0
            \li \l spread: 0
            \li \l spread: 0
        \endtable
    */
    property alias radius: dps.radius

    /*!
        This property defines how many samples are taken per pixel when edge
        softening blur calculation is done. Larger value produces better
        quality, but is slower to render.

        Ideally, this value should be twice as large as the highest required
        radius value plus one, such as:

        \table
        \header \li Radius             \li Samples
        \row    \li 0 \e{(no blur)}    \li 1
        \row    \li 1                  \li 3
        \row    \li 2                  \li 5
        \row    \li 3                  \li 7
        \endtable

        By default, the property is set to \c 9.

        This property is not intended to be animated. Changing this property will
        cause the underlying OpenGL shaders to be recompiled.
    */
    property alias samples: dps.samples

    /*!
        This property defines how large part of the glow color is strengthened
        near the source edges.

        The values range from 0.0 to 1.0. By default, the property is set to \c
        0.5.

        \note The implementation is optimized for medium and low spread values.
        Depending on the source, spread values closer to 1.0 may yield visually
        asymmetrical results.

        \table
        \header
        \li Output examples with different spread values
        \li
        \li
        \row
            \li \image Glow_spread1.png
            \li \image Glow_spread2.png
            \li \image Glow_spread3.png
        \row
            \li \b { spread: 0.0 }
            \li \b { spread: 0.5 }
            \li \b { spread: 1.0 }
        \row
            \li \l radius: 8
            \li \l radius: 8
            \li \l radius: 8
        \row
            \li \l samples: 17
            \li \l samples: 17
            \li \l samples: 17
        \row
            \li \l color: #ffffff
            \li \l color: #ffffff
            \li \l color: #ffffff
        \endtable
    */
    property alias spread: dps.spread

    /*!
        This property defines the RGBA color value which is used for the glow.

        By default, the property is set to \c "white".

        \table
        \header
        \li Output examples with different color values
        \li
        \li
        \row
            \li \image Glow_color1.png
            \li \image Glow_color2.png
            \li \image Glow_color3.png
        \row
            \li \b { color: #ffffff }
            \li \b { color: #00ff00 }
            \li \b { color: #aa00ff00 }
        \row
            \li \l radius: 8
            \li \l radius: 8
            \li \l radius: 8
        \row
            \li \l samples: 17
            \li \l samples: 17
            \li \l samples: 17
        \row
            \li \l spread: 0.5
            \li \l spread: 0.5
            \li \l spread: 0.5
        \endtable

    */
    property alias color: dps.color

    /*!
        \internal

        Starting Qt 5.6, this property has no effect. It is left here
        for source compatibility only.

        ### Qt 6: remove
    */
    property bool fast: false

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
    property alias cached: dps.cached

    /*!
        This property determines whether or not the effect has a transparent
        border.

        When set to \c true, the exterior of the item is padded with a
        transparent edge, making sampling outside the source texture use
        transparency instead of the edge pixels. Without this property, an
        image which has opaque edges will not get a blurred edge.

        By default, the property is set to \c true. Set it to false if the source
        already has a transparent edge to make the blurring a tiny bit faster.

        In the snippet below, the Rectangle on the left has transparent borders
        and has blurred edges, whereas the Rectangle on the right does not.

        \snippet Glow-transparentBorder-example.qml example

        \image Glow-transparentBorder.png
    */
    property alias transparentBorder: dps.transparentBorder
}

// Copyright (C) 2022 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import Qt5Compat.GraphicalEffects.private

/*!
    \qmltype Blend
    \inqmlmodule Qt5Compat.GraphicalEffects
    \since QtGraphicalEffects 1.0
    \inherits QtQuick2::Item
    \ingroup qtgraphicaleffects-blend
    \brief Merges two source items by using a blend mode.

    Blend mode can be selected with the \l{Blend::mode}{mode} property.

    \table
    \header
        \li source
        \li foregroundSource
        \li Effect applied
    \row
        \li \image Original_bug.png
        \li \image Original_butterfly.png
        \li \image Blend_bug_and_butterfly.png
    \endtable

    \note This effect is available when running with OpenGL.

    \section1 Example

    The following example shows how to apply the effect.
    \snippet Blend-example.qml example

*/

Item {
    id: rootItem

    /*!
        This property defines the source item that is going to be the base when
        \l{Blend::foregroundSource}{foregroundSource} is blended over it.

        \note It is not supported to let the effect include itself, for
        instance by setting source to the effect's parent.
    */
    property variant source

    /*!
        This property defines the item that is going to be blended over the
        \l{Blend::source}{source}.

        \note It is not supported to let the effect include itself, for
        instance by setting foregroundSource to the effect's parent.
    */
    property variant foregroundSource

    /*!
        This property defines the mode which is used when foregroundSource is
        blended over source. Values are case insensitive.

        \table
        \header
            \li mode
            \li description
        \row
            \li normal
            \li The pixel component values from foregroundSource are written
            over source by using alpha blending.
        \row
            \li addition
            \li The pixel component values from source and foregroundSource are
            added together and written.
        \row
            \li average
            \li The pixel component values from source and foregroundSource are
            averaged and written.
        \row
            \li color
            \li The lightness value from source is combined with hue and
            saturation from foregroundSource and written.
        \row
            \li colorBurn
            \li The darker pixels from source are darkened more, if both source
            and foregroundSource pixels are light the result is light.
        \row
            \li colorDodge
            \li The lighter pixels from source are lightened more, if both
            source and foregroundSource pixels are dark the result is dark.
        \row
            \li darken
            \li The darker pixel component value from source and
            foregroundSource is written.
        \row
            \li darkerColor
            \li The lower luminance pixel rgb-value from source and
            foregroundSource is written.
        \row
            \li difference
            \li The absolute pixel component value difference between source and
            foregroundSource is written.
        \row
            \li divide
            \li The pixel component values from source is divided by the value
            from foregroundSource and written.
        \row
            \li exclusion
            \li The pixel component value difference with reduced contrast
            between source and foregroundSource is written.
        \row
            \li hardLight
            \li The pixel component values from source are lightened or darkened
            according to foregroundSource values and written.
        \row
            \li hue
            \li The hue value from foregroundSource is combined with saturation
            and lightness from source and written.
        \row
            \li lighten
            \li The lightest pixel component value from source and
            foregroundSource is written.
        \row
            \li lighterColor
            \li The higher luminance pixel rgb-value from source and
            foregroundSource is written.
        \row
            \li lightness
            \li The lightness value from foregroundSource is combined with hue
            and saturation from source and written.
        \row
            \li multiply
            \li The pixel component values from source and foregroundSource are
            multiplied together and written.
        \row
            \li negation
            \li The inverted absolute pixel component value difference between
            source and foregroundSource is written.
        \row
            \li saturation
            \li The saturation value from foregroundSource is combined with hue
            and lightness from source and written.
        \row
            \li screen
            \li The pixel values from source and foregroundSource are negated,
            then multiplied, negated again, and written.
        \row
            \li subtract
            \li Pixel value from foregroundSource is subracted from source and
            written.
        \row
            \li softLight
            \li The pixel component values from source are lightened or darkened
            slightly according to foregroundSource values and written.

        \endtable

        \table
        \header
            \li Example source
            \li Example foregroundSource
        \row
            \li \image Original_bug.png
            \li \image Original_butterfly.png
        \endtable

        \table
        \header
        \li Output examples with different mode values
        \li
        \li
        \row
            \li \image Blend_mode1.png
            \li \image Blend_mode2.png
            \li \image Blend_mode3.png
        \row
            \li \b { mode: normal }
            \li \b { mode: addition }
            \li \b { mode: average }
        \row
            \li \image Blend_mode4.png
            \li \image Blend_mode5.png
            \li \image Blend_mode6.png
        \row
            \li \b { mode: color }
            \li \b { mode: colorBurn }
            \li \b { mode: colorDodge }
        \row
            \li \image Blend_mode7.png
            \li \image Blend_mode8.png
            \li \image Blend_mode9.png
        \row
            \li \b { mode: darken }
            \li \b { mode: darkerColor }
            \li \b { mode: difference }
        \row
            \li \image Blend_mode10.png
            \li \image Blend_mode11.png
            \li \image Blend_mode12.png
        \row
            \li \b { mode: divide }
            \li \b { mode: exclusion }
            \li \b { mode: hardlight }
        \row
            \li \image Blend_mode13.png
            \li \image Blend_mode14.png
            \li \image Blend_mode15.png
        \row
            \li \b { mode: hue }
            \li \b { mode: lighten }
            \li \b { mode: lighterColor }
        \row
            \li \image Blend_mode16.png
            \li \image Blend_mode17.png
            \li \image Blend_mode18.png
        \row
            \li \b { mode: lightness }
            \li \b { mode: negation }
            \li \b { mode: multiply }
        \row
            \li \image Blend_mode19.png
            \li \image Blend_mode20.png
            \li \image Blend_mode21.png
        \row
            \li \b { mode: saturation }
            \li \b { mode: screen }
            \li \b { mode: subtract }
        \row
            \li \image Blend_mode22.png
        \row
            \li \b { mode: softLight }
        \endtable
    */
    property string mode: "normal"

    /*!
    This property allows the effect output pixels to be cached in order to
    improve the rendering performance.

    Every time the source or effect properties are changed, the pixels in the
    cache must be updated. Memory consumption is increased, because an extra
    buffer of memory is required for storing the effect output.

    It is recommended to disable the cache when the source or the effect
    properties are animated.

    By default, the property is set to false.

    */
    property bool cached: false

    SourceProxy {
        id: backgroundSourceProxy
        input: rootItem.source
    }

    SourceProxy {
        id: foregroundSourceProxy
        input: rootItem.foregroundSource
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
        property variant source: backgroundSourceProxy.output
        property variant foregroundSource: foregroundSourceProxy.output
        property string mode: rootItem.mode
        anchors.fill: parent

        function buildFragmentShader() {
            var shader = fragmentShaderBegin

            switch (mode.toLowerCase()) {
                case "addition" : shader += blendModeAddition; break;
                case "average" : shader += blendModeAverage; break;
                case "color" : shader += blendModeColor; break;
                case "colorburn" : shader += blendModeColorBurn; break;
                case "colordodge" : shader += blendModeColorDodge; break;
                case "darken" : shader += blendModeDarken; break;
                case "darkercolor" : shader += blendModeDarkerColor; break;
                case "difference" : shader += blendModeDifference; break;
                case "divide" : shader += blendModeDivide; break;
                case "exclusion" : shader += blendModeExclusion; break;
                case "hardlight" : shader += blendModeHardLight; break;
                case "hue" : shader += blendModeHue; break;
                case "lighten" : shader += blendModeLighten; break;
                case "lightercolor" : shader += blendModeLighterColor; break;
                case "lightness" : shader += blendModeLightness; break;
                case "negation" : shader += blendModeNegation; break;
                case "normal" : shader += blendModeNormal; break;
                case "multiply" : shader += blendModeMultiply; break;
                case "saturation" : shader += blendModeSaturation; break;
                case "screen" : shader += blendModeScreen; break;
                case "subtract" : shader += blendModeSubtract; break;
                case "softlight" : shader += blendModeSoftLight; break;
                default: shader += "gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);"; break;
            }

            shader += fragmentShaderEnd
            fragmentShader = ShaderBuilder.buildFragmentShader(shader)

            // Workaround for a bug just to make sure display gets updated when the mode changes.
            sourceChanged()
        }

        Component.onCompleted: {
            buildFragmentShader()
        }

        onModeChanged: {
            buildFragmentShader()
        }

        property string blendModeAddition: "result.rgb = min(rgb1 + rgb2, 1.0);"
        property string blendModeAverage: "result.rgb = 0.5 * (rgb1 + rgb2);"
        property string blendModeColor: "result.rgb = HSLtoRGB(vec3(RGBtoHSL(rgb2).xy, RGBtoL(rgb1)));"
        property string blendModeColorBurn: "result.rgb = clamp(1.0 - ((1.0 - rgb1) / max(vec3(1.0 / 256.0), rgb2)), vec3(0.0), vec3(1.0));"
        property string blendModeColorDodge: "result.rgb = clamp(rgb1 / max(vec3(1.0 / 256.0), (1.0 - rgb2)), vec3(0.0), vec3(1.0));"
        property string blendModeDarken: "result.rgb = min(rgb1, rgb2);"
        property string blendModeDarkerColor: "result.rgb = 0.3 * rgb1.r + 0.59 * rgb1.g + 0.11 * rgb1.b > 0.3 * rgb2.r + 0.59 * rgb2.g + 0.11 * rgb2.b ? rgb2 : rgb1;"
        property string blendModeDifference: "result.rgb = abs(rgb1 - rgb2);"
        property string blendModeDivide: "result.rgb = clamp(rgb1 / rgb2, 0.0, 1.0);"
        property string blendModeExclusion: "result.rgb = rgb1 + rgb2 - 2.0 * rgb1 * rgb2;"
        property string blendModeHardLight: "result.rgb = vec3(channelBlendHardLight(rgb1.r, rgb2.r), channelBlendHardLight(rgb1.g, rgb2.g), channelBlendHardLight(rgb1.b, rgb2.b));"
        property string blendModeHue: "result.rgb = HSLtoRGB(vec3(RGBtoHSL(rgb2).x, RGBtoHSL(rgb1).yz));"
        property string blendModeLighten: "result.rgb = max(rgb1, rgb2);"
        property string blendModeLighterColor: "result.rgb = 0.3 * rgb1.r + 0.59 * rgb1.g + 0.11 * rgb1.b > 0.3 * rgb2.r + 0.59 * rgb2.g + 0.11 * rgb2.b ? rgb1 : rgb2;"
        property string blendModeLightness: "result.rgb = HSLtoRGB(vec3(RGBtoHSL(rgb1).xy, RGBtoL(rgb2)));"
        property string blendModeMultiply: "result.rgb = rgb1 * rgb2;"
        property string blendModeNegation: "result.rgb = 1.0 - abs(1.0 - rgb1 - rgb2);"
        property string blendModeNormal: "result.rgb = rgb2; a = max(color1.a, color2.a);"
        property string blendModeSaturation: "vec3 hsl1 = RGBtoHSL(rgb1); result.rgb = HSLtoRGB(vec3(hsl1.x, RGBtoHSL(rgb2).y, hsl1.z));"
        property string blendModeScreen: "result.rgb = 1.0 - (vec3(1.0) - rgb1) * (vec3(1.0) - rgb2);"
        property string blendModeSubtract: "result.rgb = max(rgb1 - rgb2, vec3(0.0));"
        property string blendModeSoftLight: "result.rgb = rgb1 * ((1.0 - rgb1) * rgb2 + (1.0 - (1.0 - rgb1) * (1.0 - rgb2)));"

        property string fragmentShaderBegin: "#version 440

            layout(location = 0) in vec2 qt_TexCoord0;
            layout(location = 0) out vec4 fragColor;

            layout(std140, binding = 0) uniform buf {
                mat4 qt_Matrix;
                float qt_Opacity;
            };
            layout(binding = 1) uniform sampler2D source;
            layout(binding = 2) uniform sampler2D foregroundSource;

            float RGBtoL(vec3 color) {
                float cmin = min(color.r, min(color.g, color.b));
                float cmax = max(color.r, max(color.g, color.b));
                float l = (cmin + cmax) / 2.0;
                return l;
            }

            vec3 RGBtoHSL(vec3 color) {
                float cmin = min(color.r, min(color.g, color.b));
                float cmax = max(color.r, max(color.g, color.b));
                float h = 0.0;
                float s = 0.0;
                float l = (cmin + cmax) / 2.0;
                float diff = cmax - cmin;

                if (diff > 1.0 / 256.0) {
                    if (l < 0.5)
                        s = diff / (cmin + cmax);
                    else
                        s = diff / (2.0 - (cmin + cmax));

                    if (color.r == cmax)
                        h = (color.g - color.b) / diff;
                    else if (color.g == cmax)
                        h = 2.0 + (color.b - color.r) / diff;
                    else
                        h = 4.0 + (color.r - color.g) / diff;

                    h /= 6.0;
                }
                return vec3(h, s, l);
                }

            float hueToIntensity(float v1, float v2, float h) {
                h = fract(h);
                if (h < 1.0 / 6.0)
                    return v1 + (v2 - v1) * 6.0 * h;
                else if (h < 1.0 / 2.0)
                    return v2;
                else if (h < 2.0 / 3.0)
                    return v1 + (v2 - v1) * 6.0 * (2.0 / 3.0 - h);

                return v1;
            }

            vec3 HSLtoRGB(vec3 color) {
                float h = color.x;
                float l = color.z;
                float s = color.y;

                if (s < 1.0 / 256.0)
                    return vec3(l, l, l);

                float v1;
                float v2;
                if (l < 0.5)
                    v2 = l * (1.0 + s);
                else
                    v2 = (l + s) - (s * l);

                v1 = 2.0 * l - v2;

                float d = 1.0 / 3.0;
                float r = hueToIntensity(v1, v2, h + d);
                float g = hueToIntensity(v1, v2, h);
                float b = hueToIntensity(v1, v2, h - d);
                return vec3(r, g, b);
            }

            float channelBlendHardLight(float c1, float c2) {
                return c2 > 0.5 ? (1.0 - (1.0 - 2.0 * (c2 - 0.5)) * (1.0 - c1)) : (2.0 * c1 * c2);
            }

            void main() {
                vec4 result = vec4(0.0);
                vec4 color1 = texture(source, qt_TexCoord0);
                vec4 color2 = texture(foregroundSource, qt_TexCoord0);
                vec3 rgb1 = color1.rgb / max(1.0/256.0, color1.a);
                vec3 rgb2 = color2.rgb / max(1.0/256.0, color2.a);
                float a = max(color1.a, color1.a * color2.a);
        "

        property string fragmentShaderEnd: "
                fragColor.rgb = mix(rgb1, result.rgb, color2.a);
                fragColor.rbg *= a;
                fragColor.a = a;
                fragColor *= qt_Opacity;
            }
        "
    }
}

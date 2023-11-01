// Copyright (C) 2022 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import Qt5Compat.GraphicalEffects.private

Item {
    id: rootItem
    property variant source
    property real deviation: (radius + 1) / 3.3333
    property real radius: 0.0
    property int maximumRadius: 0
    property real horizontalStep: 0.0
    property real verticalStep: 0.0
    property bool transparentBorder: false
    property bool cached: false

    property bool enableColor: false
    property color color: "white"
    property real spread: 0.0

    property bool enableMask: false
    property variant maskSource

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
        anchors.fill: rootItem
        visible: rootItem.cached
        smooth: true
        sourceItem: shaderItem
        live: true
        hideSource: visible
    }

    ShaderEffect {
        id: shaderItem
        property variant source: sourceProxy.output
        property real deviation: Math.max(0.1, rootItem.deviation)
        property real radius: rootItem.radius
        property int maxRadius: rootItem.maximumRadius
        property bool transparentBorder: rootItem.transparentBorder
        property real gaussianSum: 0.0
        property real startIndex: 0.0
        property real deltaFactor: (2 * radius - 1) / (maxRadius * 2 - 1)
        property real expandX: transparentBorder && rootItem.horizontalStep > 0 ? maxRadius / width : 0.0
        property real expandY: transparentBorder && rootItem.verticalStep > 0 ? maxRadius / height : 0.0
        property variant gwts: []
        property variant delta: Qt.vector3d(rootItem.horizontalStep * deltaFactor, rootItem.verticalStep * deltaFactor, startIndex);
        property variant factor_0_2: Qt.vector3d(gwts[0], gwts[1], gwts[2]);
        property variant factor_3_5: Qt.vector3d(gwts[3], gwts[4], gwts[5]);
        property variant factor_6_8: Qt.vector3d(gwts[6], gwts[7], gwts[8]);
        property variant factor_9_11: Qt.vector3d(gwts[9], gwts[10], gwts[11]);
        property variant factor_12_14: Qt.vector3d(gwts[12], gwts[13], gwts[14]);
        property variant factor_15_17: Qt.vector3d(gwts[15], gwts[16], gwts[17]);
        property variant factor_18_20: Qt.vector3d(gwts[18], gwts[19], gwts[20]);
        property variant factor_21_23: Qt.vector3d(gwts[21], gwts[22], gwts[23]);
        property variant factor_24_26: Qt.vector3d(gwts[24], gwts[25], gwts[26]);
        property variant factor_27_29: Qt.vector3d(gwts[27], gwts[28], gwts[29]);
        property variant factor_30_31: Qt.point(gwts[30], gwts[31]);

        property color color: rootItem.color
        property real spread: 1.0 - (rootItem.spread * 0.98)
        property variant maskSource: maskSourceProxy.output

        anchors.fill: rootItem

        function gausFunc(x){
            //Gaussian function = h(x):=(1/sqrt(2*3.14159*(D^2))) * %e^(-(x^2)/(2*(D^2)));
            return (1.0 / Math.sqrt(2 * Math.PI * (Math.pow(shaderItem.deviation, 2)))) * Math.pow(Math.E, -((Math.pow(x, 2)) / (2 * (Math.pow(shaderItem.deviation, 2)))));
        }

        function updateGaussianWeights() {
            gaussianSum = 0.0;
            startIndex = -maxRadius + 0.5

            var n = new Array(32);
            for (var j = 0; j < 32; j++)
                n[j] = 0;

            var max = maxRadius * 2
            var delta = (2 * radius - 1) / (max - 1);
            for (var i = 0; i < max; i++) {
                n[i] = gausFunc(-radius + 0.5 + i * delta);
                gaussianSum += n[i];
            }

            gwts = n;
        }

        function buildFragmentShader() {

        var shaderSteps = [
            "fragColor += texture(source, texCoord) * factor_0_2.x; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_0_2.y; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_0_2.z; texCoord += shift;",

            "fragColor += texture(source, texCoord) * factor_3_5.x; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_3_5.y; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_3_5.z; texCoord += shift;",

            "fragColor += texture(source, texCoord) * factor_6_8.x; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_6_8.y; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_6_8.z; texCoord += shift;",

            "fragColor += texture(source, texCoord) * factor_9_11.x; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_9_11.y; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_9_11.z; texCoord += shift;",

            "fragColor += texture(source, texCoord) * factor_12_14.x; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_12_14.y; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_12_14.z; texCoord += shift;",

            "fragColor += texture(source, texCoord) * factor_15_17.x; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_15_17.y; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_15_17.z; texCoord += shift;",

            "fragColor += texture(source, texCoord) * factor_18_20.x; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_18_20.y; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_18_20.z; texCoord += shift;",

            "fragColor += texture(source, texCoord) * factor_21_23.x; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_21_23.y; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_21_23.z; texCoord += shift;",

            "fragColor += texture(source, texCoord) * factor_24_26.x; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_24_26.y; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_24_26.z; texCoord += shift;",

            "fragColor += texture(source, texCoord) * factor_27_29.x; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_27_29.y; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_27_29.z; texCoord += shift;",

            "fragColor += texture(source, texCoord) * factor_30_31.x; texCoord += shift;",
            "fragColor += texture(source, texCoord) * factor_30_31.y; texCoord += shift;"
        ]

            var shader = fragmentShaderBegin
            var samples = maxRadius * 2
            if (samples > 32) {
                console.log("DirectionalGaussianBlur.qml WARNING: Maximum of blur radius (16) exceeded!")
                samples = 32
            }

            for (var i = 0; i < samples; i++) {
                shader += shaderSteps[i]
            }

            shader += fragmentShaderEnd

            var colorizeSteps = ""
            var colorizeUniforms = ""

            var maskSteps = ""
            var maskUniforms = ""

            if (enableColor) {
                colorizeSteps += "fragColor = mix(vec4(0), color, clamp((fragColor.a - 0.0) / (spread - 0.0), 0.0, 1.0));\n"
                colorizeUniforms += "vec4 color;\n"
                colorizeUniforms += "float spread;\n"
            }

            if (enableMask) {
                maskSteps += "shift *= texture(maskSource, qt_TexCoord0).a;\n"
                maskUniforms += "layout(binding = 2) uniform sampler2D maskSource;\n"
            }

            shader = shader.replace("PLACEHOLDER_COLORIZE_STEPS", colorizeSteps)
            shader = shader.replace("PLACEHOLDER_COLORIZE_UNIFORMS", colorizeUniforms)
            shader = shader.replace("PLACEHOLDER_MASK_STEPS", maskSteps)
            shader = shader.replace("PLACEHOLDER_MASK_UNIFORMS", maskUniforms)

            fragmentShader = ShaderBuilder.buildFragmentShader(shader)
        }

        onDeviationChanged: updateGaussianWeights()

        onRadiusChanged: updateGaussianWeights()

        onTransparentBorderChanged: {
            buildFragmentShader()
            updateGaussianWeights()
        }

        onMaxRadiusChanged: {
            buildFragmentShader()
            updateGaussianWeights()
        }

        Component.onCompleted: {
            buildFragmentShader()
            updateGaussianWeights()
        }

        property string fragmentShaderBegin: "#version 440
            layout(location = 0) in vec2 qt_TexCoord0;
            layout(location = 0) out vec4 fragColor;

            layout(std140, binding = 0) uniform buf {
                mat4 qt_Matrix;
                float qt_Opacity;
                vec3 delta;
                vec3 factor_0_2;
                vec3 factor_3_5;
                vec3 factor_6_8;
                vec3 factor_9_11;
                vec3 factor_12_14;
                vec3 factor_15_17;
                vec3 factor_18_20;
                vec3 factor_21_23;
                vec3 factor_24_26;
                vec3 factor_27_29;
                vec2 factor_30_31;
                float gaussianSum;
                float expandX;
                float expandY;
                PLACEHOLDER_COLORIZE_UNIFORMS
            };
            layout(binding = 1) uniform sampler2D source;
            PLACEHOLDER_MASK_UNIFORMS

            void main() {
                vec2 shift = vec2(delta.x, delta.y);

                PLACEHOLDER_MASK_STEPS

                float index = delta.z;
                vec2 texCoord = qt_TexCoord0;
                texCoord.s = (texCoord.s - expandX) / (1.0 - 2.0 * expandX);
                texCoord.t = (texCoord.t - expandY) / (1.0 - 2.0 * expandY);
                texCoord +=  (shift * index);

                fragColor = vec4(0.0, 0.0, 0.0, 0.0);
        "

        property string fragmentShaderEnd: "

                fragColor /= gaussianSum;

                PLACEHOLDER_COLORIZE_STEPS

                fragColor *= qt_Opacity;
            }
        "
     }
}

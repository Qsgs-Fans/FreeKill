#version 440

layout(location = 0) in vec4 vColor;
layout(location = 1) in vec2 vTex;

// 显式 binding=1：与 SRB 中 sampledTexture(1, ...) 对齐
layout(binding = 1) uniform sampler2D uTex;

layout(location = 0) out vec4 fragColor;

void main() {
    vec4 t = texture(uTex, vTex);
    t.rgb *= t.a * vColor.a;
    fragColor = vColor * t;
}

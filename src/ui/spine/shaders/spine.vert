#version 440

layout(location = 0) in vec2 position;
layout(location = 1) in vec4 color;
layout(location = 2) in vec2 texCoord;

layout(location = 0) out vec4 vColor;
layout(location = 1) out vec2 vTex;

layout(std140, binding = 0) uniform ubuf {
    mat4 mvp;
    float opacity;
} buf;

void main() {
    gl_Position = buf.mvp * vec4(position, 0.0, 1.0);
    vColor = color * buf.opacity;
    vTex = texCoord;
}

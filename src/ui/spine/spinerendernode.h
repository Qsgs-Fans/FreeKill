/******************************************************************************
 * Spine Runtimes Software License
 * Version 2.1
 *
 * Copyright (c) 2013, Esoteric Software
 * All rights reserved.
 *
 * You are granted a perpetual, non-exclusive, non-sublicensable and
 * non-transferable license to install, execute and perform the Spine Runtimes
 * Software (the "Software") solely for internal use. Without the written
 * permission of Esoteric Software (typically granted by licensing Spine), you
 * may not (a) modify, translate, adapt or otherwise create derivative works,
 * improvements of the Software or develop new applications using the Software
 * or (b) remove, delete, alter or obscure any trademarks or any copyright,
 * trademark, patent or other intellectual property or proprietary rights
 * notices on or in the Software, including any copy thereof. Redistributions
 * in binary or source form must include this license and terms.
 *
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#ifndef SPINERENDERNODE_H
#define SPINERENDERNODE_H

#include <QtQuick/qsgrendernode.h>
#include <QImage>
#include <QQuickWindow>
#include <QRectF>
#include <vector>

// ---------------------------------------------------------------------------
// RHI 原生渲染节点（跨 OpenGL / Vulkan / D3D / Metal）。
// 取代旧的 QQuickFramebufferObject + QOpenGL 渲染管线。
//
// 线程模型：
//   - GUI 线程（SkeletonAnimationFbo::updatePaintNode）调用 sync()/setTextures()
//     填充数据；
//   - 渲染线程调用 prepare()/render() 消费数据（Qt 场景图保证同一帧内
//     updatePaintNode 先于 render，不会并发）。
// ---------------------------------------------------------------------------

// 交错顶点：位置(float2) + 颜色(uchar4, straight) + 纹理坐标(float2)
struct SpineVertex {
    float x, y;
    unsigned char r, g, b, a;
    float u, v;
};

// 一个三角形批次（顶点已展开、无索引）
struct SpineBatch {
    int vertexOffset = 0;
    int vertexCount = 0;
    int textureIndex = -1;   // <0 表示纯色（不使用纹理）
    bool additive = false;
    bool textured = true;
};

// 每帧传给渲染节点的数据
struct SpineFrameData {
    std::vector<SpineVertex> triangles;   // 图集批次的顶点
    std::vector<SpineBatch> batches;
    std::vector<SpineVertex> lines;       // 调试：骨骼线/包围框（line list）
    std::vector<SpineVertex> points;      // 调试：骨骼原点（point list）
    bool premultiplied = true;            // 图集是否为预乘 alpha
    bool valid = false;
};

class SpineRenderNode : public QSGRenderNode
{
public:
    explicit SpineRenderNode(QQuickWindow *window);
    ~SpineRenderNode() override;

    // GUI 线程：每帧推送最新数据
    void sync(const SpineFrameData &data);

    // GUI 线程：骨架(重新)加载后推送图集图像，epoch 用于去重
    void setTextures(const std::vector<QImage> &images, int epoch);

    void releaseResources() override;
    RenderingFlags flags() const override;
    StateFlags changedStates() const override;

protected:
    void prepare() override;
    void render(const RenderState *state) override;

private:
    struct Private;
    Private *d;
    QQuickWindow *m_window;
};

#endif // SPINERENDERNODE_H

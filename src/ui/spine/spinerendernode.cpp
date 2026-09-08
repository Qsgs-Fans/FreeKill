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

#include "spinerendernode.h"

#include <rhi/qrhi.h>
#include <rhi/qshader.h>

#include <QDebug>
#include <QFile>
#include <QHash>
#include <QRect>
#include <cstring>

// ---------------------------------------------------------------------------
// shader 统一使用构建期由 qsb 预编译的 .qsb 资源（见 src/CMakeLists.txt 的
// qt_add_shaders）。相比运行期用 QShaderBaker 烘焙，qsb 工具生成的 .qsb 内
// 含各后端（SPIR-V / GLSL+ES / HLSL / MSL）变体及正确的 sampler 绑定元数据，
// Qt RHI 的 OpenGL/GLES 后端可据此正确采样，避免安卓骨骼黑屏。
// ---------------------------------------------------------------------------

namespace {

QHash<QString, QShader> &shaderCache()
{
    static QHash<QString, QShader> cache;
    return cache;
}

QShader loadShader(const QString &resourcePath)
{
    const QString key = QStringLiteral("r:") + resourcePath;
    QHash<QString, QShader> &cache = shaderCache();
    auto it = cache.constFind(key);
    if (it != cache.constEnd())
        return it.value();

    QFile f(resourcePath);
    if (!f.open(QIODevice::ReadOnly)) {
        qWarning().noquote() << "SpineRenderNode: cannot open shader resource" << resourcePath;
        return QShader();
    }
    QShader s = QShader::fromSerialized(f.readAll());
    if (!s.isValid()) {
        qWarning().noquote() << "SpineRenderNode: shader resource invalid" << resourcePath;
        return QShader();
    }
    cache.insert(key, s);
    return s;
}

} // namespace

// ---------------------------------------------------------------------------
// RHI 资源宿主
// ---------------------------------------------------------------------------

struct SpineRenderNode::Private
{
    QRhi *rhi = nullptr;

    SpineFrameData frame;           // GUI 线程写，渲染线程读
    std::vector<QImage> textures;   // 图集图像（RGBA8888，straight 字节）
    int textureEpoch = 0;
    int bakedEpoch = -1;
    bool invalidated = true;        // 首次或骨架重载后需重建资源

    QRhiBuffer *uniformBuffer = nullptr;
    QRhiBuffer *triBuffer = nullptr;
    QRhiBuffer *debugBuffer = nullptr;
    int triCapacity = 0;
    int debugCapacity = 0;

    std::vector<QRhiTexture *> rhiTextures;
    std::vector<QRhiSampler *> rhiSamplers;
    std::vector<QRhiShaderResourceBindings *> textureSrbs;

    QRhiShaderResourceBindings *colorSrb = nullptr;
    QRhiGraphicsPipeline *colorLinePipe = nullptr;
    QRhiGraphicsPipeline *colorPointPipe = nullptr;
    QRhiGraphicsPipeline *texPipes[2][2] = { { nullptr, nullptr }, { nullptr, nullptr } };

    void freeRhi()
    {
        for (int i = 0; i < 2; ++i)
            for (int j = 0; j < 2; ++j) {
                delete texPipes[i][j];
                texPipes[i][j] = nullptr;
            }
        delete colorLinePipe; colorLinePipe = nullptr;
        delete colorPointPipe; colorPointPipe = nullptr;
        delete colorSrb; colorSrb = nullptr;
        for (auto *t : rhiTextures) delete t;
        rhiTextures.clear();
        for (auto *s : rhiSamplers) delete s;
        rhiSamplers.clear();
        for (auto *s : textureSrbs) delete s;
        textureSrbs.clear();
        delete uniformBuffer; uniformBuffer = nullptr;
        delete triBuffer; triBuffer = nullptr;
        delete debugBuffer; debugBuffer = nullptr;
        triCapacity = 0;
        debugCapacity = 0;
        bakedEpoch = -1;
        // 注意：不要把 rhi 置空。prepare() 每次开头都会重新赋值，
        // 而 render() 依赖 d->rhi 判断是否可绘制；invalidated 触发
        // freeRhi() 后若 rhi 变空，会导致 render() 永久空转。
    }
};

SpineRenderNode::SpineRenderNode(QQuickWindow *window)
    : d(new Private)
    , m_window(window)
{
}

SpineRenderNode::~SpineRenderNode()
{
    delete d;
}

void SpineRenderNode::sync(const SpineFrameData &data)
{
    d->frame = data;
}

void SpineRenderNode::setTextures(const std::vector<QImage> &images, int epoch)
{
    // updatePaintNode 每帧都会调用本函数。只有图集发生实质变化
    // （首次加载 / 骨架重载，epoch 递增）才需要重建渲染线程资源；
    // 否则每帧 invalidated 会导致管线/纹理被反复释放重建，
    // 且 freeRhi() 曾把 d->rhi 置空令 render() 永久空转（画面空白）。
    if (epoch == d->textureEpoch)
        return;
    d->textures = images;
    d->textureEpoch = epoch;
    d->invalidated = true;
}

QSGRenderNode::RenderingFlags SpineRenderNode::flags() const
{
    return QSGRenderNode::NoExternalRendering;
}

QSGRenderNode::StateFlags SpineRenderNode::changedStates() const
{
    return QSGRenderNode::ViewportState | QSGRenderNode::ScissorState;
}

void SpineRenderNode::releaseResources()
{
    if (d)
        d->freeRhi();
}

// ---------------------------------------------------------------------------

static QRhiGraphicsPipeline *createTexturePipeline(QRhi *rhi, QRhiShaderResourceBindings *srb,
                                                   const QShader &vs, const QShader &fs,
                                                   bool additive, QRhiRenderPassDescriptor *rp)
{
    QRhiGraphicsPipeline *p = rhi->newGraphicsPipeline();
    p->setTopology(QRhiGraphicsPipeline::Triangles);
    p->setCullMode(QRhiGraphicsPipeline::None);
    p->setDepthTest(false);
    p->setDepthWrite(false);

    QRhiGraphicsPipeline::TargetBlend blend;
    blend.enable = true;
    blend.srcColor = QRhiGraphicsPipeline::One;
    blend.dstColor = additive ? QRhiGraphicsPipeline::One
                              : QRhiGraphicsPipeline::OneMinusSrcAlpha;
    blend.srcAlpha = QRhiGraphicsPipeline::One;
    blend.dstAlpha = QRhiGraphicsPipeline::OneMinusSrcAlpha;
    p->setTargetBlends({ blend });

    QRhiVertexInputLayout inputLayout;
    inputLayout.setBindings({ { int(sizeof(SpineVertex)) } });
    inputLayout.setAttributes({
        { 0, 0, QRhiVertexInputAttribute::Float2, 0 },
        { 0, 1, QRhiVertexInputAttribute::UNormByte4, int(offsetof(SpineVertex, r)) },
        { 0, 2, QRhiVertexInputAttribute::Float2, int(offsetof(SpineVertex, u)) },
    });
    p->setVertexInputLayout(inputLayout);
    p->setShaderResourceBindings(srb);
    p->setShaderStages({
        QRhiShaderStage(QRhiShaderStage::Vertex, vs),
        QRhiShaderStage(QRhiShaderStage::Fragment, fs),
    });
    p->setRenderPassDescriptor(rp);
    if (!p->create()) {
        qWarning() << "SpineRenderNode: texture pipeline create FAILED (additive="
                   << additive << ")";
        delete p;
        return nullptr;
    }
    return p;
}

static QRhiGraphicsPipeline *createColorPipeline(QRhi *rhi, QRhiShaderResourceBindings *srb,
                                                 const QShader &vs, const QShader &fs,
                                                 QRhiGraphicsPipeline::Topology topo,
                                                 QRhiRenderPassDescriptor *rp)
{
    QRhiGraphicsPipeline *p = rhi->newGraphicsPipeline();
    p->setTopology(topo);
    p->setCullMode(QRhiGraphicsPipeline::None);
    p->setDepthTest(false);
    p->setDepthWrite(false);

    QRhiGraphicsPipeline::TargetBlend blend;
    blend.enable = true;
    p->setTargetBlends({ blend });

    QRhiVertexInputLayout inputLayout;
    inputLayout.setBindings({ { int(sizeof(SpineVertex)) } });
    inputLayout.setAttributes({
        { 0, 0, QRhiVertexInputAttribute::Float2, 0 },
        { 0, 1, QRhiVertexInputAttribute::UNormByte4, int(offsetof(SpineVertex, r)) },
    });
    p->setVertexInputLayout(inputLayout);
    p->setShaderResourceBindings(srb);
    p->setShaderStages({
        QRhiShaderStage(QRhiShaderStage::Vertex, vs),
        QRhiShaderStage(QRhiShaderStage::Fragment, fs),
    });
    p->setRenderPassDescriptor(rp);
    if (!p->create()) {
        qWarning() << "SpineRenderNode: color pipeline create FAILED";
        delete p;
        return nullptr;
    }
    return p;
}

void SpineRenderNode::prepare()
{
    QRhi *rhi = m_window ? m_window->rhi() : nullptr;
    if (!rhi || !renderTarget() || !commandBuffer()) {
        static int sSkipWarn = 0;
        if (sSkipWarn++ < 8)
            qWarning() << "[Spine] prepare SKIPPED rhi=" << (rhi != nullptr)
                       << "renderTarget=" << (renderTarget() != nullptr)
                       << "commandBuffer=" << (commandBuffer() != nullptr)
                       << "frameValid=" << d->frame.valid;
        return;
    }
    d->rhi = rhi;

    if (d->invalidated) {
        d->freeRhi();
        d->invalidated = false;
    }

    QRhiResourceUpdateBatch *updates = rhi->nextResourceUpdateBatch();

    if (!d->uniformBuffer) {
        d->uniformBuffer = rhi->newBuffer(QRhiBuffer::Dynamic, QRhiBuffer::UniformBuffer, 80);
        if (!d->uniformBuffer->create()) {
            qWarning() << "SpineRenderNode: uniform buffer create FAILED";
            delete d->uniformBuffer;
            d->uniformBuffer = nullptr;
        }
    }

    // 图集纹理（epoch 变化时重建并上传）
    if (d->textureEpoch != d->bakedEpoch) {
        for (auto *t : d->rhiTextures) delete t;
        d->rhiTextures.clear();
        for (auto *s : d->rhiSamplers) delete s;
        d->rhiSamplers.clear();
        for (auto *s : d->textureSrbs) delete s;
        d->textureSrbs.clear();

        for (int i = 0; i < int(d->textures.size()); ++i) {
            const QImage &img = d->textures[i];
            if (img.isNull())
                continue;
            QRhiTexture *tex = rhi->newTexture(QRhiTexture::RGBA8, img.size(), 1);
            if (!tex->create()) {
                delete tex;
                continue;
            }
            QRhiSampler *sampler = rhi->newSampler(QRhiSampler::Linear, QRhiSampler::Linear,
                                                   QRhiSampler::None,
                                                   QRhiSampler::ClampToEdge, QRhiSampler::ClampToEdge);
            if (!sampler->create()) {
                qWarning() << "SpineRenderNode: sampler create FAILED";
                delete sampler;
                delete tex;
                continue;
            }

            QRhiShaderResourceBindings *srb = rhi->newShaderResourceBindings();
            srb->setBindings({
                QRhiShaderResourceBinding::uniformBuffer(
                    0, QRhiShaderResourceBinding::VertexStage | QRhiShaderResourceBinding::FragmentStage,
                    d->uniformBuffer),
                QRhiShaderResourceBinding::sampledTexture(
                    1, QRhiShaderResourceBinding::FragmentStage, tex, sampler),
            });
            if (!srb->create()) {
                qWarning() << "SpineRenderNode: texture SRB create FAILED";
                delete srb;
                delete sampler;
                delete tex;
                continue;
            }

            d->rhiTextures.push_back(tex);
            d->rhiSamplers.push_back(sampler);
            d->textureSrbs.push_back(srb);
            updates->uploadTexture(
                tex, QRhiTextureUploadEntry(0, 0, QRhiTextureSubresourceUploadDescription(img)));
        }
        d->bakedEpoch = d->textureEpoch;
    }

    // 顶点/常量上传仅在帧有效时才有内容；纹理上传（图集页）在任何情况下
    // 都要提交，否则即使后续帧有效也不会再触发上传（epoch 已对齐）。
    if (d->frame.valid) {
        const int triBytes = int(d->frame.triangles.size()) * int(sizeof(SpineVertex));
        const int lineBytes = int(d->frame.lines.size()) * int(sizeof(SpineVertex));
        const int pointBytes = int(d->frame.points.size()) * int(sizeof(SpineVertex));

        if (!d->triBuffer || triBytes > d->triCapacity) {
            delete d->triBuffer;
            d->triCapacity = qMax(16384, triBytes);
            d->triBuffer = rhi->newBuffer(QRhiBuffer::Dynamic, QRhiBuffer::VertexBuffer, d->triCapacity);
            if (!d->triBuffer->create()) {
                qWarning() << "SpineRenderNode: tri buffer create FAILED";
                delete d->triBuffer;
                d->triBuffer = nullptr;
                d->triCapacity = 0;
            }
        }
        const int debugBytes = lineBytes + pointBytes;
        if (!d->debugBuffer || debugBytes > d->debugCapacity) {
            delete d->debugBuffer;
            d->debugCapacity = qMax(4096, debugBytes);
            d->debugBuffer = rhi->newBuffer(QRhiBuffer::Dynamic, QRhiBuffer::VertexBuffer, d->debugCapacity);
            if (!d->debugBuffer->create()) {
                qWarning() << "SpineRenderNode: debug buffer create FAILED";
                delete d->debugBuffer;
                d->debugBuffer = nullptr;
                d->debugCapacity = 0;
            }
        }

        if (triBytes)
            updates->updateDynamicBuffer(d->triBuffer, 0, triBytes, d->frame.triangles.data());
        if (lineBytes)
            updates->updateDynamicBuffer(d->debugBuffer, 0, lineBytes, d->frame.lines.data());
        if (pointBytes)
            updates->updateDynamicBuffer(d->debugBuffer, lineBytes, pointBytes, d->frame.points.data());

        struct { float m[16]; float opacity; float pad[3]; } ubuf;
        const QMatrix4x4 mvp = *projectionMatrix() * *matrix();
        memcpy(ubuf.m, mvp.constData(), 64);
        ubuf.opacity = float(inheritedOpacity());
        updates->updateDynamicBuffer(d->uniformBuffer, 0, 80, &ubuf);
    }

    commandBuffer()->resourceUpdate(updates);
}

void SpineRenderNode::render(const RenderState *state)
{
    if (!d->rhi || !d->frame.valid || !commandBuffer() || !renderTarget())
        return;

    QRhiCommandBuffer *cb = commandBuffer();
    const QSize size = renderTarget()->pixelSize();
    cb->setViewport(QRhiViewport(0, 0, float(size.width()), float(size.height())));

    // QSGRenderNode 的内容不会被 Qt Quick 自动裁剪，必须自行应用
    // RenderState 提供的 scissor（设备像素、顶部原点坐标系）。
    // 否则即使父 QQuickItem 设置了 clip，骨骼仍会画到父区域之外。
    if (state && state->scissorEnabled()) {
        const QRect r = state->scissorRect();
        cb->setScissor(QRhiScissor(r.x(), r.y(), r.width(), r.height()));
    } else {
        cb->setScissor(QRhiScissor(0, 0, size.width(), size.height()));
    }

    QRhiRenderPassDescriptor *rp = renderTarget()->renderPassDescriptor();

    // 懒建：uniform-only 绑定（纯色管线用）
    if (!d->colorSrb) {
        d->colorSrb = d->rhi->newShaderResourceBindings();
        d->colorSrb->setBindings({
            QRhiShaderResourceBinding::uniformBuffer(
                0, QRhiShaderResourceBinding::VertexStage | QRhiShaderResourceBinding::FragmentStage,
                d->uniformBuffer),
        });
        if (!d->colorSrb->create()) {
            qWarning() << "SpineRenderNode: color SRB create FAILED";
            delete d->colorSrb;
            d->colorSrb = nullptr;
        }
    }

    const QShader vs = loadShader(QStringLiteral(":/shaders/spine.vert.qsb"));
    if (!vs.isValid()) {
        // 预编译 .qsb 资源缺失/无效时无法绘制，直接返回
        return;
    }

    // 图集三角形批
    if (!d->frame.batches.empty()) {
        const int pmaIdx = d->frame.premultiplied ? 1 : 0;
        const QShader fsPma = loadShader(QStringLiteral(":/shaders/spine_pma.frag.qsb"));
        const QShader fsStraight = loadShader(QStringLiteral(":/shaders/spine_straight.frag.qsb"));

        for (const SpineBatch &b : d->frame.batches) {
            if (b.vertexCount <= 0 || b.textureIndex < 0 || b.textureIndex >= int(d->textureSrbs.size()))
                continue;
            const int addIdx = b.additive ? 1 : 0;
            QRhiGraphicsPipeline *&pipe = d->texPipes[pmaIdx][addIdx];
            if (!pipe) {
                pipe = createTexturePipeline(d->rhi, d->textureSrbs[b.textureIndex],
                                             vs, pmaIdx ? fsPma : fsStraight, b.additive, rp);
                if (!pipe)
                    continue;   // create 失败，本批跳过（已打日志）
            }
            cb->setGraphicsPipeline(pipe);
            cb->setShaderResources(d->textureSrbs[b.textureIndex]);
            QRhiCommandBuffer::VertexInput bindings[] = { { d->triBuffer, 0 } };
            cb->setVertexInput(0, 1, bindings);
            cb->draw(quint32(b.vertexCount), 1, quint32(b.vertexOffset), 0);
        }
    }

    // 调试线 / 点
    if (!d->frame.lines.empty() || !d->frame.points.empty()) {
        const QShader fsPlain = loadShader(QStringLiteral(":/shaders/spine_plain.frag.qsb"));

        if (!d->frame.lines.empty()) {
            if (!d->colorLinePipe) {
                d->colorLinePipe = createColorPipeline(d->rhi, d->colorSrb, vs, fsPlain,
                                                       QRhiGraphicsPipeline::Lines, rp);
                if (!d->colorLinePipe)
                    return;     // create 失败（已打日志）
            }
            cb->setGraphicsPipeline(d->colorLinePipe);
            cb->setShaderResources(d->colorSrb);
            QRhiCommandBuffer::VertexInput bindings[] = { { d->debugBuffer, 0 } };
            cb->setVertexInput(0, 1, bindings);
            cb->draw(quint32(d->frame.lines.size()), 1, 0, 0);
        }

        if (!d->frame.points.empty()) {
            if (!d->colorPointPipe) {
                d->colorPointPipe = createColorPipeline(d->rhi, d->colorSrb, vs, fsPlain,
                                                        QRhiGraphicsPipeline::Points, rp);
                if (!d->colorPointPipe)
                    return;     // create 失败（已打日志）
            }
            cb->setGraphicsPipeline(d->colorPointPipe);
            cb->setShaderResources(d->colorSrb);
            const int lineBytes = int(d->frame.lines.size()) * int(sizeof(SpineVertex));
            QRhiCommandBuffer::VertexInput bindings[] = { { d->debugBuffer, lineBytes } };
            cb->setVertexInput(0, 1, bindings);
            cb->draw(quint32(d->frame.points.size()), 1, 0, 0);
        }
    }
}

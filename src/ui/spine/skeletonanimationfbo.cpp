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

#include "skeletonanimationfbo.h"
#include "spineversion.h"
#include "spinerendernode.h"
#include <QQuickWindow>
#include <QtQml/QQmlFile>
#include <cstring>
#include "texture.h"

#define SAFE_DELETE(p) {if(p) { delete (p); (p)=NULL;} }

SkeletonAnimationFbo::SkeletonAnimationFbo(QQuickItem *parent)
    :QQuickItem(parent)
    ,mScale(1.0f)
    ,mSkin("default")
    ,mTimeScale(1.0f)
    ,mPremultipliedAlapha(true)
    ,mDebugSlots(false)
    ,mDebugBones(false)
    ,mSpineVersion(SpineVersion::Auto)
    ,mDetectedVersion(SpineVersion::Unknown)
    ,mShouldRelaseCacheTexture(false)
    ,mSkeletonLoaded(false)
    ,mBackend(nullptr)
{
    setFlag(ItemHasContents, true);
}

SkeletonAnimationFbo::~SkeletonAnimationFbo()
{
    releaseSkeletonRelatedData();
}

void SkeletonAnimationFbo::setToSetupPose()
{
    if (!isSkeletonValid()){
        qDebug()<<"SkeletonAnimation::setToSetupPose Error: Skeleton is not ready";
        return;
    }
    mBackend->setToSetupPose();
}

void SkeletonAnimationFbo::setBonesToSetupPose()
{
    if (!isSkeletonValid()){
        qDebug()<<"SkeletonAnimation::setBonesToSetupPose Error: Skeleton is not ready";
        return;
    }
    mBackend->setBonesToSetupPose();
}

void SkeletonAnimationFbo::setSlotsToSetupPose()
{
    if (!isSkeletonValid()){
        qDebug()<<"SkeletonAnimation::setSlotsToSetupPose Error: Skeleton is not ready";
        return;
    }
    mBackend->setSlotsToSetupPose();
}

bool SkeletonAnimationFbo::setAttachment(const QString &slotName, const QString &attachmentName)
{
    if (!isSkeletonValid()){
        qDebug()<<"SkeletonAnimation::setAttachment Error: Skeleton is not ready";
        return false;
    }

    return mBackend->setAttachment(slotName, attachmentName);
}

void SkeletonAnimationFbo::setMix(const QString &fromAnimation, const QString &toAnimation, float duration)
{
    if (!isSkeletonValid()){
        qDebug()<<"SkeletonAnimation::setMix Error: Skeleton is not ready.";
        return;
    }

    mBackend->setMix(fromAnimation, toAnimation, duration);
}

void SkeletonAnimationFbo::setAnimation(int trackIndex, const QString& name, bool loop)
{
    if (!isSkeletonValid()){
        qDebug()<<"SkeletonAnimation::setAnimation Error: Skeleton is not ready";
        return;
    }

    if (!mBackend->setAnimation(trackIndex, name, loop))
        qDebug()<<"SkeletonAnimation::setAnimation Error: Animation is not found:"<<name;
}

void SkeletonAnimationFbo::addAnimation(int trackIndex, const QString& name, bool loop, float delay)
{
    if (!isSkeletonValid()){
        qDebug()<<"SkeletonAnimation::addAnimation Error: Skeleton is not ready";
        return;
    }

    if (!mBackend->addAnimation(trackIndex, name, loop, delay))
        qDebug()<<"SkeletonAnimation::addAnimation Error: Animation is not found:"<<name;
}

bool SkeletonAnimationFbo::isPlaying(int trackIndex)
{
    if (!isSkeletonValid())
        return false;
    return mBackend->isPlaying(trackIndex);
}

void SkeletonAnimationFbo::clearTracks()
{
    if (!isSkeletonValid()){
        qDebug()<<"SkeletonAnimation::clearTracks Error: Skeleton is not ready";
        return;
    }
    mBackend->clearTracks();
}

void SkeletonAnimationFbo::clearTrack(int trackIndex)
{
    if (!isSkeletonValid()){
        qDebug()<<"SkeletonAnimation::clearTrack Error: Skeleton is not ready";
        return;
    }
    mBackend->clearTrack(trackIndex);
}

void SkeletonAnimationFbo::setSkeletonDataFile(const QUrl & url)
{
    if (mSkeletonDataFile == url)
        return;
    mSkeletonDataFile = url;
    Q_EMIT skeletonDataFileChanged(mSkeletonDataFile);

    if (isComponentComplete()) {
        loadSkeletonAndAtlasData();
    }
}

void SkeletonAnimationFbo::setAtlasFile(const QUrl & url)
{
    if (mAtlasFile == url)
        return;
    mAtlasFile = url;
    Q_EMIT atlasFileChanged(mAtlasFile);

    if (isComponentComplete()) {
        loadSkeletonAndAtlasData();
    }
}

void SkeletonAnimationFbo::setScale(float value)
{
    if (mScale == value)
        return;
    mScale = value;
    Q_EMIT scaleChanged();
    if (isComponentComplete()) {
        loadSkeletonAndAtlasData();
    }
}

void SkeletonAnimationFbo::setSkin(const QString & value)
{
    if (mSkin == value)
        return;
    mSkin = value;
    Q_EMIT skinChanged();

    if (isSkeletonValid())
        mBackend->setSkin(mSkin);
}

void SkeletonAnimationFbo::setTimeScale(float value)
{
    if (mTimeScale == value)
        return;
    mTimeScale = value;
    Q_EMIT timeScaleChanged();
}

void SkeletonAnimationFbo::setPremultipliedAlapha(bool value)
{
    if (mPremultipliedAlapha == value)
        return;
    mPremultipliedAlapha = value;
    Q_EMIT premultipliedAlaphaChanged();
}

void SkeletonAnimationFbo::setDebugSlots(bool debug)
{
    if (mDebugSlots == debug)
        return;
    mDebugSlots = debug;
    Q_EMIT debugSlotsChanged();
}

void SkeletonAnimationFbo::setDebugBones(bool debug)
{
    if (mDebugBones == debug)
        return;
    mDebugBones = debug;
    Q_EMIT debugBonesChanged();
}

void SkeletonAnimationFbo::setSourceSize(const QSize & size)
{
    if (mSourceSize == size)
        return;
    mSourceSize = size;
    Q_EMIT sourceSizeChanged();
}

void SkeletonAnimationFbo::setSpineVersion(int value)
{
    if (mSpineVersion == value)
        return;
    mSpineVersion = value;
    Q_EMIT spineVersionChanged();
    if (isComponentComplete()) {
        loadSkeletonAndAtlasData();
    }
}

QSGNode *SkeletonAnimationFbo::updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *)
{
    SpineRenderNode *node = static_cast<SpineRenderNode *>(oldNode);
    if (!node)
        node = new SpineRenderNode(window());
    mRenderNode = node;

    // 骨架重载后推送新的图集（epoch 变化才会触发纹理重建）
    node->setTextures(std::vector<QImage>(mAtlasImages.cbegin(), mAtlasImages.cend()),
                      mTextureEpoch);

    SpineFrameData frame;
    if (isSkeletonValid())
        buildFrameData(frame);
    node->sync(frame);

    // 每次同步完帧数据都要显式标记内容已变化：
    // 1) 无 layer 时保证 render node 每帧被重新绘制；
    // 2) 有 layer（离屏缓存）时，Qt 依据 dirty 判断是否重渲 layer 纹理，
    //    否则动画会定格在首帧。QSGRenderNode 不像几何节点那样自带脏标记。
    node->markDirty(QSGNode::DirtyMaterial);

    return node;
}

// 收集当前骨架引用的所有图集贴图，统一转成 RGBA8888（保留原始 straight/pma 字节）
// 并建立 Texture* -> 图集序号 的映射。
void SkeletonAnimationFbo::collectAtlasImages()
{
    if (!isSkeletonValid())
        return;

    mBackend->collectDrawCommands(mDrawCommands);

    QVector<QImage> images;
    QHash<Texture *, int> index;
    for (const SpineDrawCommand &cmd : mDrawCommands) {
        Texture *tex = static_cast<Texture *>(cmd.texture);
        if (!tex || !tex->image() || tex->image()->isNull())
            continue;
        if (index.contains(tex))
            continue;
        QImage img = tex->image()->convertToFormat(QImage::Format_RGBA8888);
        index.insert(tex, images.size());
        images.push_back(std::move(img));
    }

    mAtlasImages = images;
    mTextureIndex = index;
    ++mTextureEpoch;
}

namespace {
// 把骨骼世界坐标（Spine：x 向右、y 向上）映射到本 item 局部坐标（y 向下）。
// 两种布局模式：
//  1) item 被 QML 显式指定了宽高：骨骼包围盒左上角对齐 item 原点并拉伸填满
//     （经典“内容适配”模式，兼容显式布局/大尺寸贴图用法）；
//  2) item 无显式宽高（自由锚点定位，如 SkinArea 里 x/y + Item.scale 用法）：
//     以骨骼的“世界坐标原点 (0,0)”为锚 —— 局部坐标 = 世界坐标（仅 y 翻转）。
//     同一套皮肤的 bg/body 骨骼共享世界原点，因此会天然重合；
//     QML 的 x/y 就是世界原点所在位置（默认 0.5/0.5 = 居中），
//     Item.scale 围绕该原点缩放。
struct SpineLocalMapper {
    QRectF bounds;
    qreal scaleX = 1.0, scaleY = 1.0;
    bool centerAnchor = false;
    SpineLocalMapper(const QRectF &b, const QSizeF &item)
        : bounds(b)
    {
        if (b.width() > 0.0001f && b.height() > 0.0001f &&
            item.width() > 0.0001f && item.height() > 0.0001f) {
            scaleX = item.width() / b.width();
            scaleY = item.height() / b.height();
            centerAnchor = false; // 显式尺寸：左上对齐 + 填满
        } else {
            centerAnchor = true;  // 自由锚：世界原点对齐 item 原点 (0,0)
        }
    }
    float x(qreal wx) const {
        return centerAnchor ? float(wx)                // 世界坐标原样（共享原点天然对齐）
                            : float((wx - bounds.left()) * scaleX);
    }
    float y(qreal wy) const {
        // y 翻转：骨骼世界 y 向上，视觉 y 向下
        return centerAnchor ? float(-wy)
                            : float((bounds.height() - (wy - bounds.top())) * scaleY);
    }
    float u(float u) const { return u; }
};
} // namespace

void SkeletonAnimationFbo::buildFrameData(SpineFrameData &frame)
{
    frame = SpineFrameData();
    frame.premultiplied = mPremultipliedAlapha;

    if (mBounds.isNull() || mBounds.width() <= 0 || mBounds.height() <= 0)
        return;

    const SpineLocalMapper map(mBounds, QSizeF(width(), height()));

    // —— 图集三角形批 ——
    for (const SpineDrawCommand &cmd : mDrawCommands) {
        Texture *tex = static_cast<Texture *>(cmd.texture);
        if (!tex)
            continue;
        const auto it = mTextureIndex.constFind(tex);
        if (it == mTextureIndex.cend())
            continue;

        const int base = int(frame.triangles.size());
        const int vc = cmd.vertexCount;
        const float r = cmd.r, g = cmd.g, b = cmd.b, a = cmd.a;
        frame.triangles.reserve(size_t(base + vc * 3));
        // 无索引展开：indices 为空时按 0..vc-1
        for (int k = 0; k < cmd.indexCount; ++k) {
            const unsigned short idx = cmd.indices ? cmd.indices[k] : (unsigned short)k;
            if (idx >= vc)
                continue;
            const float *v = cmd.vertices + idx * 2;
            const float *t = cmd.uvs + idx * 2;
            SpineVertex vert;
            vert.x = map.x(v[0]);
            vert.y = map.y(v[1]);
            vert.r = (unsigned char)(r * 255.0f);
            vert.g = (unsigned char)(g * 255.0f);
            vert.b = (unsigned char)(b * 255.0f);
            vert.a = (unsigned char)(a * 255.0f);
            vert.u = t[0];
            vert.v = t[1];
            frame.triangles.push_back(vert);
        }

        SpineBatch batch;
        batch.vertexOffset = base;
        batch.vertexCount = int(frame.triangles.size()) - base;
        batch.textureIndex = it.value();
        batch.additive = cmd.additiveBlending;
        if (batch.vertexCount > 0)
            frame.batches.push_back(batch);
    }

    // —— 调试绘制 ——
    if (mDebugSlots) {
        const QVector<std::vector<float>> regions = mBackend->collectDebugSlotRegions();
        for (const std::vector<float> &verts : regions) {
            // 蓝框：4 段 LineList
            for (int k = 0; k < 4; ++k) {
                const int i0 = k;
                const int i1 = (k + 1) % 4;
                SpineVertex a, bv;
                a.x = map.x(verts[i0 * 2]); a.y = map.y(verts[i0 * 2 + 1]);
                bv.x = map.x(verts[i1 * 2]); bv.y = map.y(verts[i1 * 2 + 1]);
                a.r = a.g = bv.r = bv.g = 0; a.b = bv.b = 255; a.a = bv.a = 255;
                a.u = bv.u = a.v = bv.v = 0;
                frame.lines.push_back(a);
                frame.lines.push_back(bv);
            }
        }
    }

    if (mDebugBones) {
        const QVector<SpineBoneDebug> bones = mBackend->collectDebugBones();
        for (const SpineBoneDebug &bone : bones) {
            // 骨骼长度线（红）
            SpineVertex a, bv;
            a.x = map.x(bone.worldX); a.y = map.y(bone.worldY);
            bv.x = map.x(bone.endX); bv.y = map.y(bone.endY);
            a.r = bv.r = 255; a.g = bv.g = 0; a.b = bv.b = 0; a.a = bv.a = 255;
            a.u = bv.u = a.v = bv.v = 0;
            frame.lines.push_back(a);
            frame.lines.push_back(bv);
        }
        // 骨骼原点：根骨蓝、其余绿
        for (int i = 0; i < bones.size(); ++i) {
            SpineVertex p;
            p.x = map.x(bones[i].worldX);
            p.y = map.y(bones[i].worldY);
            p.r = 0;
            p.g = i == 0 ? 0 : 255;
            p.b = i == 0 ? 255 : 0;
            p.a = 255;
            p.u = p.v = 0;
            frame.points.push_back(p);
        }
    }

    frame.valid = true;
}


void SkeletonAnimationFbo::onSpineEvent(const SpineEventInfo& info)
{
    switch (info.type) {
    case 0: // start
        Q_EMIT skeletonStart(info.trackIndex);
        break;
    case 1: // end
        Q_EMIT skeletonEnd(info.trackIndex);
        break;
    case 2: // complete
        Q_EMIT skeletonComplete(info.trackIndex, info.loopCount);
        break;
    case 3: // event
    {
        SpineEvent* spineEvent = new SpineEvent(this);
        spineEvent->setEvent(info);
        mEventCache.push_back(spineEvent);
        Q_EMIT skeletonEvent(info.trackIndex, spineEvent);
        break;
    }
    default:
        break;
    }
}

void SkeletonAnimationFbo::updateSkeletonAnimation()
{
    if (!isSkeletonValid()) {
        update();
        return;
    }

    if (!mEventCache.isEmpty()){
        Q_FOREACH(SpineEvent* event, mEventCache)
            SAFE_DELETE(event);
        mEventCache.clear();
    }

    qint64 mSecs = 0;
    if (!mTimer.isValid())
        mTimer.start();
    else
        mSecs = mTimer.restart();

    const float deltaTime = mSecs/1000.0 * mTimeScale;
    mBackend->update(deltaTime);

    // 注意：mBounds 在 loadSkeletonAndAtlasData() 时确定一次并保持不变，
    // 作为骨骼内容的固定渲染基准。若每帧改为“当前姿态包围盒”，动画中
    // 四肢摆动引起的包围盒边界微变会经顶点映射放大，表现为上下抖动与
    // 内容整体错位漂移。
    mBackend->collectDrawCommands(mDrawCommands); // 每帧刷新当前姿势的绘制命令

    // 若绘制命令引用了尚未收录的图集页（首次加载 / 换肤后的第一帧时
    // 后端可能尚无命令，图集为空），此时补建图集缓存与索引；collectAtlasImages
    // 会递增 mTextureEpoch，从而驱动渲染节点重建并上传纹理。
    bool needAtlas = false;
    for (const SpineDrawCommand &cmd : mDrawCommands) {
        if (cmd.texture && !mTextureIndex.contains(static_cast<Texture *>(cmd.texture))) {
            needAtlas = true;
            break;
        }
    }
    if (needAtlas)
        collectAtlasImages();

    // 不再由 C++ 设置 item 宽高：item 无显式尺寸时走“中心锚定”模式
    // （QML 的 x/y 即骨骼中心）；QML 若显式给出宽高则走“填满适配”模式，
    // 两者都以 load 时确定的 mBounds 作为固定基准，避免动画中抖动/漂移。
    update();
}

void SkeletonAnimationFbo::loadSkeletonAndAtlasData()
{
    releaseSkeletonRelatedData();

    if (mAtlasFile.isEmpty() || !mAtlasFile.isValid()){
        qDebug()<<"SkeletonAnimation::loadSkeletonAndAtlasData Error: Invalid AtlasFile:"<<mAtlasFile;
        return;
    }

    if (mSkeletonDataFile.isEmpty() || !mSkeletonDataFile.isValid()){
        qDebug()<<"SkeletonAnimation::loadSkeletonAndAtlasData Error: Invalid SkeletonDataFile:"<<mSkeletonDataFile;
        return;
    }

    const QString skeletonPath = QQmlFile::urlToLocalFileOrQrc(mSkeletonDataFile);

    // 检测（或确认）Spine 版本：显式指定优先，否则从文件自动检测
    const int effective = (mSpineVersion == SpineVersion::Auto)
        ? static_cast<int>(detectSpineVersion(skeletonPath))
        : mSpineVersion;
    if (mDetectedVersion != effective) {
        mDetectedVersion = effective;
        Q_EMIT detectedVersionChanged();
    }
    const SpineVersion::Type ver = static_cast<SpineVersion::Type>(effective);

    mBackend = createSpineBackend(ver);
    if (!mBackend) {
        qWarning() << "SkeletonAnimation: 不支持的 Spine 版本" << spineVersionToString(ver)
                   << "，无法加载。SkeletonDataFile:" << mSkeletonDataFile;
        return;
    }

    mBackend->setEventCallback([this](const SpineEventInfo &info) { onSpineEvent(info); });

    const QString atlasPath = QQmlFile::urlToLocalFileOrQrc(mAtlasFile);
    // 支持 .json 与 .skel（3.4+）；Spine 2.1 运行时无二进制读取器，.skel 会加载失败
    if (!mBackend->load(skeletonPath, atlasPath, mScale, mSkin)) {
        qWarning() << "SkeletonAnimation: 加载骨架失败。"
                   << "skeleton:" << mSkeletonDataFile
                   << "atlas:" << mAtlasFile
                   << "version:" << spineVersionToString(ver);
        releaseSkeletonRelatedData();
        return;
    }

    mSkeletonLoaded = true;

    mBounds = mBackend->bounds();
    if (mBounds.width() > 0 && mBounds.height() > 0) {
        setSourceSize(QSize(mBounds.width(), mBounds.height()));
        // 重要：不要 setImplicitSize/setWidth/setHeight。若设置了 implicitSize，
        // Qt 定位器（Row/Column 等）会把无显式宽高的子项宽度改成 implicitWidth，
        // 使骨骼 item 被“偷偷”赋成 bounds 尺寸、从而误入 fill 适配模式。
        // 这里刻意让自由定位的骨骼保持 0 尺寸 → 渲染层走“中心锚定”。
        // QML 若想“填满适配”，请显式给骨架 width/height。
    }

    collectAtlasImages(); // 建立图集 -> QImage 缓存与索引
    mTimer.invalidate();
}

QRectF SkeletonAnimationFbo::calculateSkeletonRect()
{
    if (!isSkeletonValid())
        return QRectF();

    return mBackend->bounds();
}

bool SkeletonAnimationFbo::isSkeletonValid()
{
    return mSkeletonLoaded && mBackend;
}

void SkeletonAnimationFbo::releaseSkeletonRelatedData()
{
    delete mBackend;
    mBackend = nullptr;

    mSkeletonLoaded = false;
    mAtlasImages.clear();
    mTextureIndex.clear();
    ++mTextureEpoch; // 使渲染节点下一帧重建纹理缓存
    mShouldRelaseCacheTexture = true;
}

void SkeletonAnimationFbo::componentComplete()
{
    QQuickItem::componentComplete();
    loadSkeletonAndAtlasData();
}


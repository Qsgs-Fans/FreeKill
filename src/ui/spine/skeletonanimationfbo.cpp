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
#include <QQuickWindow>
#include <QtQml/QQmlFile>
#include "texture.h"
#include "skeletonrenderer.h"
#include "rendercmdscache.h"

#define SAFE_DELETE(p) {if(p) { delete (p); (p)=NULL;} }

SkeletonAnimationFbo::SkeletonAnimationFbo(QQuickItem *parent)
    :QQuickFramebufferObject(parent)
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
    this->setTextureFollowsItemSize(true);
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

QQuickFramebufferObject::Renderer *SkeletonAnimationFbo::createRenderer() const
{
    return new SkeletonRenderer;
}

void SkeletonAnimationFbo::renderToCache(Renderer* renderer, RenderCmdsCache* cache)
{
    if (!cache)
        return;
    cache->clear();

    if (!renderer)
        return;

    SkeletonRenderer* skeletonRenderer = static_cast<SkeletonRenderer*>(renderer);
    if (mShouldRelaseCacheTexture){
        mShouldRelaseCacheTexture = false;
        skeletonRenderer->releaseTextures();
    }

    if (!isSkeletonValid())
        return;

    cache->setSkeletonRect(mBounds);
    cache->setPremultipliedAlpha(mPremultipliedAlapha);
    cache->bindShader(RenderCmdsCache::ShaderTexture);

    mBackend->collectDrawCommands(mDrawCommands);

    int additive = -1;
    Color color;
    for (const SpineDrawCommand &cmd : mDrawCommands) {
        QOpenGLTexture* texture = skeletonRenderer->getGLTexture(static_cast<Texture*>(cmd.texture));
        if (!texture)
            continue;

        const bool isAdditive = cmd.additiveBlending;
        if ((isAdditive ? 1 : 0) != additive) {
            cache->cacheTriangleDrawCall();
            // 始终使用预乘混合；直通转预乘在 fragment shader 中完成
            cache->blendFunc(GL_ONE, isAdditive ? GL_ONE : GL_ONE_MINUS_SRC_ALPHA);
            additive = isAdditive ? 1 : 0;
        }

        // 顶点颜色保持 straight，预乘转换交给 shader
        color.r = static_cast<GLubyte>(cmd.r * 255);
        color.g = static_cast<GLubyte>(cmd.g * 255);
        color.b = static_cast<GLubyte>(cmd.b * 255);
        color.a = static_cast<GLubyte>(cmd.a * 255);

        cache->drawTriangles(texture,
                             cmd.vertices, cmd.uvs, cmd.vertexCount * 2,
                             cmd.indices, cmd.indexCount, color);
    }
    cache->cacheTriangleDrawCall();

    if (mDebugSlots || mDebugBones) {
        cache->bindShader(RenderCmdsCache::ShaderColor);
        if (mDebugSlots) {
            // Slots.
            cache->drawColor(0, 0, 255, 255);
            cache->lineWidth(1);

            const QVector<std::vector<float>> regions = mBackend->collectDebugSlotRegions();
            for (const std::vector<float> &verts : regions) {
                Point points[4];
                points[0] = Point(verts[0], verts[1]);
                points[1] = Point(verts[2], verts[3]);
                points[2] = Point(verts[4], verts[5]);
                points[3] = Point(verts[6], verts[7]);
                cache->drawPoly(points, 4);
            }
        }// END if (mDebugSlots)

        if (mDebugBones) {
            // Bone lengths.
            cache->lineWidth(2);
            cache->drawColor(255, 0, 0, 255);
            const QVector<SpineBoneDebug> bones = mBackend->collectDebugBones();
            for (const SpineBoneDebug &bone : bones) {
                cache->drawLine(Point(bone.worldX, bone.worldY), Point(bone.endX, bone.endY));
            }
            // Bone origins.
            cache->pointSize(4.0);
            cache->drawColor(0, 0, 255, 255); // Root bone is blue.
            for (int i = 0; i < bones.size(); i++) {
                cache->drawPoint(Point(bones[i].worldX, bones[i].worldY));
                if (i == 0) cache->drawColor(0, 255, 0, 255);
            }
        }// END if (mDebugBones)
    }//END if (mDebugSlots || mDebugBones)
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

    mBounds = calculateSkeletonRect();
    setSourceSize(QSize(mBounds.width(), mBounds.height()));
    setImplicitSize(mBounds.width(), mBounds.height());
    setPosition(QPointF(mBounds.left(), -1.0f*(mBounds.top() + mBounds.height())));
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
    mShouldRelaseCacheTexture = true;
}

void SkeletonAnimationFbo::componentComplete()
{
    QQuickItem::componentComplete();
    loadSkeletonAndAtlasData();
}


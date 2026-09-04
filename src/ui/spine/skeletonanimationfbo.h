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

#ifndef SKELETONANIMATION_H
#define SKELETONANIMATION_H

#include <QtQuick/QQuickItem>
#include <QtQuick/qsgnode.h>
#include <QUrl>
#include <QElapsedTimer>
#include <QList>
#include <QVector>
#include <QHash>
#include <QImage>
#include "spinebackend.h"
#include "spineevent.h"

QT_FORWARD_DECLARE_CLASS(Texture)
class SpineRenderNode;
class SpineFrameData;

// 历史遗留命名（原为 QQuickFramebufferObject），现为普通 QQuickItem，
// 渲染通过 SpineRenderNode（QSGRenderNode + RHI）完成，可适配
// OpenGL / Vulkan / D3D / Metal 等全部 Qt Quick 后端。
class SkeletonAnimationFbo : public QQuickItem
{
    Q_OBJECT
    Q_DISABLE_COPY(SkeletonAnimationFbo)

    Q_PROPERTY(QUrl skeletonDataFile READ skeletonDataFile WRITE setSkeletonDataFile NOTIFY skeletonDataFileChanged)
    Q_PROPERTY(QUrl atlasFile READ atlasFile WRITE setAtlasFile NOTIFY atlasFileChanged)
    Q_PROPERTY(float scale READ scale WRITE setScale NOTIFY scaleChanged)
    Q_PROPERTY(QString skin READ skin WRITE setSkin NOTIFY skinChanged)
    Q_PROPERTY(float timeScale READ timeScale WRITE setTimeScale NOTIFY timeScaleChanged)
    Q_PROPERTY(bool premultipliedAlapha READ premultipliedAlapha WRITE setPremultipliedAlapha NOTIFY premultipliedAlaphaChanged)
    Q_PROPERTY(bool debugSlots READ debugSlots WRITE setDebugSlots NOTIFY debugSlotsChanged)
    Q_PROPERTY(bool debugBones READ debugBones WRITE setDebugBones NOTIFY debugBonesChanged)
    Q_PROPERTY(QSize sourceSize READ sourceSize NOTIFY sourceSizeChanged)
    Q_PROPERTY(int spineVersion READ spineVersion WRITE setSpineVersion NOTIFY spineVersionChanged)
    Q_PROPERTY(int detectedVersion READ detectedVersion NOTIFY detectedVersionChanged)

Q_SIGNALS:
    void skeletonStart(int trackIndex);
    void skeletonEnd(int trackIndex);
    void skeletonComplete(int trackIndex, int loopCount);
    void skeletonEvent(int trackIndex, SpineEvent* event);

    void skeletonDataFileChanged(const QUrl&);
    void atlasFileChanged(const QUrl&);
    void scaleChanged();
    void skinChanged();
    void timeScaleChanged();
    void premultipliedAlaphaChanged();
    void debugSlotsChanged();
    void debugBonesChanged();
    void sourceSizeChanged();
    void spineVersionChanged();
    void detectedVersionChanged();

public:
    explicit SkeletonAnimationFbo(QQuickItem *parent = 0);
    ~SkeletonAnimationFbo();

    Q_INVOKABLE void setToSetupPose();
    Q_INVOKABLE void setBonesToSetupPose();
    Q_INVOKABLE void setSlotsToSetupPose();
    Q_INVOKABLE bool setAttachment(const QString& slotName, const QString& attachmentName);
    Q_INVOKABLE void setMix(const QString& fromAnimation, const QString& toAnimation, float duration);
    Q_INVOKABLE void setAnimation (int trackIndex, const QString& name, bool loop);
    Q_INVOKABLE void addAnimation (int trackIndex, const QString& name, bool loop, float delay = 0);
    Q_INVOKABLE bool isPlaying(int trackIndex = 0);
    Q_INVOKABLE void clearTracks ();
    Q_INVOKABLE void clearTrack(int trackIndex = 0);

    QUrl skeletonDataFile()const { return mSkeletonDataFile; }
    void setSkeletonDataFile(const QUrl&);

    QUrl atlasFile()const { return mAtlasFile;}
    void setAtlasFile(const QUrl&);

    float scale() const { return mScale;}
    void setScale(float);

    QString skin() const { return mSkin;}
    void setSkin(const QString&);

    float timeScale() const { return mTimeScale;}
    void setTimeScale(float);

    bool premultipliedAlapha()const { return mPremultipliedAlapha;}
    void setPremultipliedAlapha(bool);

    bool debugSlots() const { return mDebugSlots;}
    void setDebugSlots(bool);

    bool debugBones() const { return mDebugBones;}
    void setDebugBones(bool);

    QSize sourceSize()const { return mSourceSize;}
    void setSourceSize(const QSize&);

    int spineVersion() const { return mSpineVersion; }
    void setSpineVersion(int);

    int detectedVersion() const { return mDetectedVersion; }

protected:
    QSGNode *updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *) override;

public Q_SLOTS:
    void updateSkeletonAnimation();

protected:
    void loadSkeletonAndAtlasData();
    QRectF calculateSkeletonRect();

    bool isSkeletonValid();
    void releaseSkeletonRelatedData();
    virtual void componentComplete();

private:
    void onSpineEvent(const SpineEventInfo& info);
    void collectAtlasImages();
    void buildFrameData(SpineFrameData &frame);

    QUrl mSkeletonDataFile;
    QUrl mAtlasFile;
    float mScale;
    QString mSkin;
    float mTimeScale;
    bool mPremultipliedAlapha;
    bool mDebugSlots;
    bool mDebugBones;
    QSize mSourceSize;

    int mSpineVersion;
    int mDetectedVersion;

    QElapsedTimer mTimer;

    bool mShouldRelaseCacheTexture;
    bool mSkeletonLoaded;

    SpineBackend *mBackend;
    QVector<SpineDrawCommand> mDrawCommands;
    QRectF mBounds;

    // 渲染节点与图集纹理缓存
    SpineRenderNode *mRenderNode = nullptr;
    QVector<QImage> mAtlasImages;
    QHash<Texture *, int> mTextureIndex;
    int mTextureEpoch = 0;

    QList<SpineEvent*> mEventCache;
};

#endif // SKELETONANIMATION_H


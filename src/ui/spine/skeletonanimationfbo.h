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
#include <memory>
#include <functional>
#include "spinebackend.h"
#include "spineevent.h"

QT_FORWARD_DECLARE_CLASS(Texture)
class SpineRenderNode;
class SpineFrameData;
template<typename T> class QFutureWatcher;

// 后台加载的产物（耗时工作在加载线程完成，成功后整体移交 GUI 线程）。
// backend 所有权随本结构转移：谁最后持有本结构，谁负责释放 backend。
struct SkeletonLoadResult {
    SpineBackend *backend = nullptr;
    bool ok = false;
    int version = SpineVersion::Unknown;
    QRectF bounds;
    QVector<QImage> atlasImages;          // RGBA8888 图集（后台已转好格式）
    QHash<Texture *, int> textureIndex;   // Texture* -> atlasImages 下标
    ~SkeletonLoadResult() { delete backend; }
};

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
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadedChanged)

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
    void loadedChanged();
    // 一次加载尝试结束（无论成功/失败，均在 GUI 线程发出）。
    // ok=true：数据真正就绪（此时 loaded 亦为 true）；ok=false：加载失败
    // （文件缺失/解析失败/版本不支持等），供上层把该层标记为“已结束但不可用”。
    void skeletonLoadFinished(bool ok);

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

    // 骨架是否已成功加载完成（可播放）。加载完成/重载时变化，供 QML 同步协调。
    bool loaded() const { return mSkeletonLoaded; }

protected:
    QSGNode *updatePaintNode(QSGNode *oldNode, UpdatePaintNodeData *) override;

public Q_SLOTS:
    void updateSkeletonAnimation();

protected:
    void loadSkeletonAndAtlasData();
    void loadSkeletonAndAtlasDataSync();   // 同步加载（运行时重载沿用，保持播放阶段行为不变）
    void loadSkeletonAndAtlasDataAsync();  // 首次创建：后台线程加载，避免创建瞬间卡 GUI
    QRectF calculateSkeletonRect();

    bool isSkeletonValid();
    void releaseSkeletonRelatedData(bool notify = true);  // notify=false 用于析构路径
    virtual void componentComplete();

private:
    // —— 异步加载（仅创建/重载时在后台读纹理，播放阶段不异步）——
    void onSkeletonLoadFinished(std::shared_ptr<SkeletonLoadResult> res); // GUI 线程，加载完成回调
    void applyLoadedSkeleton(std::shared_ptr<SkeletonLoadResult> res); // GUI 线程应用后台加载结果
    void flushPendingCalls();               // 骨架就绪后回放加载期间排队的调用

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
    bool mLoading = false;                  // 后台加载进行中
    bool mReloadRequested = false;          // 加载期间属性又被改动，待完成后用最新参数重载
    quint64 mLoadGeneration = 0;            // 每次发起加载自增，过期结果直接丢弃
    QVector<std::function<void()>> mPendingCalls; // 加载期间收到的骨架调用（就绪后回放）

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


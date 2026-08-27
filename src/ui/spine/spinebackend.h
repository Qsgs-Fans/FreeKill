#ifndef SPINEBACKEND_H
#define SPINEBACKEND_H

#include <QString>
#include <QVector>
#include <QRectF>
#include <functional>
#include <vector>

#include "spineversion.h"

// 一条可绘制命令（与版本无关）。
// 顶点/索引均为不拥有内存的指针：vertices 指向后端复用缓冲（仅当帧有效），
// indices 指向 attachment 持久数据或静态 quad 索引。避免每帧堆分配。
struct SpineDrawCommand {
    void *texture = nullptr;        // Texture*（由渲染器映射为 GL 纹理）
    const float *uvs = nullptr;     // 纹理坐标，指向 attachment 的持久数据
    const float *vertices = nullptr;      // 世界坐标，2 * vertexCount 个 float（复用缓冲）
    int vertexCount = 0;                  // 顶点数（xy 对数）
    const unsigned short *indices = nullptr; // 三角形索引（持久数据）
    int indexCount = 0;
    float r = 1.0f, g = 1.0f, b = 1.0f, a = 1.0f; // 最终颜色（a 为整体透明度乘数）
    bool additiveBlending = false;
};

// 动画事件信息（与版本无关）。
struct SpineEventInfo {
    int type = 0;      // 0=start, 1=end, 2=complete, 3=event
    int trackIndex = 0;
    int loopCount = 0;
    // 事件定义（event->data）
    QString name;
    int dataIntValue = 0;
    float dataFloatValue = 0.0f;
    QString dataStringValue;
    // 事件实例值（event 自身）
    int intValue = 0;
    float floatValue = 0.0f;
    QString stringValue;
};

// 骨骼调试信息（与版本无关）。
struct SpineBoneDebug {
    float worldX = 0.0f, worldY = 0.0f;
    float endX = 0.0f, endY = 0.0f; // 骨骼长度方向端点
};

using SpineEventCallback = std::function<void(const SpineEventInfo &)>;

// 版本无关的 Spine 后端接口。
class SpineBackend {
public:
    virtual ~SpineBackend() = default;

    virtual bool load(const QString &jsonPath, const QString &atlasPath,
                      float scale, const QString &skin) = 0;
    virtual void update(float delta) = 0;
    virtual void collectDrawCommands(QVector<SpineDrawCommand> &out) = 0;
    virtual QRectF bounds() = 0;

    virtual bool setAnimation(int track, const QString &name, bool loop) = 0;
    virtual bool addAnimation(int track, const QString &name, bool loop, float delay) = 0;
    virtual bool isPlaying(int track) = 0;
    virtual void clearTracks() = 0;
    virtual void clearTrack(int track) = 0;
    virtual void setMix(const QString &from, const QString &to, float duration) = 0;
    virtual void setSkin(const QString &skin) = 0;
    virtual void setToSetupPose() = 0;
    virtual void setBonesToSetupPose() = 0;
    virtual void setSlotsToSetupPose() = 0;
    virtual bool setAttachment(const QString &slotName, const QString &attachmentName) = 0;

    // 调试绘制：region 附件（每个 8 个 float 世界坐标）与骨骼线段。
    virtual QVector<SpineBoneDebug> collectDebugBones() = 0;
    virtual QVector<std::vector<float>> collectDebugSlotRegions() = 0;

    virtual void setEventCallback(const SpineEventCallback &cb) = 0;
};

// 按版本创建后端；返回 nullptr 表示不支持。
SpineBackend *createSpineBackend(SpineVersion::Type version);

#endif // SPINEBACKEND_H

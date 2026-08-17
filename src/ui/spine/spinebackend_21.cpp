// Spine 2.1 后端（旧 API：spSkinnedMeshAttachment、3 参 compute、直接颜色字段）。
#include <spine/spine.h>
#include <spine/extension.h>

#include "spinebackend.h"
#include "texture.h"

#include <QFile>
#include <QString>
#include <cfloat>
#include <cstdlib>
#include <cstring>
#include <vector>

#define SPINE_PREFIX sp21
#include "spinebackend_hooks.inc"
#undef SPINE_PREFIX

namespace {

class SpineBackend21 : public SpineBackend {
    typedef sp21Skeleton Skeleton;
    typedef sp21SkeletonData SkeletonData;
    typedef sp21SkeletonJson SkeletonJson;
    typedef sp21Atlas Atlas;
    typedef sp21AtlasRegion AtlasRegion;
    typedef sp21Animation Animation;
    typedef sp21AnimationState AnimationState;
    typedef sp21AnimationStateData AnimationStateData;
    typedef sp21Slot Slot;
    typedef sp21Event Event;
    typedef sp21RegionAttachment RegionAttachment;
    typedef sp21MeshAttachment MeshAttachment;
    typedef sp21SkinnedMeshAttachment SkinnedMeshAttachment;

    Skeleton *mSkeleton = nullptr;
    Atlas *mAtlas = nullptr;
    AnimationState *mAnimationState = nullptr;
    SpineEventCallback mEventCallback;

    static void animationCallback(AnimationState *state, int trackIndex, sp21EventType type,
                                  Event *event, int loopCount) {
        SpineBackend21 *self = (SpineBackend21 *)state->rendererObject;
        if (!self || !self->mEventCallback)
            return;
        SpineEventInfo info;
        info.trackIndex = trackIndex;
        info.loopCount = loopCount;
        switch (type) {
        case SP_ANIMATION_START: info.type = 0; break;
        case SP_ANIMATION_END:   info.type = 1; break;
        case SP_ANIMATION_COMPLETE: info.type = 2; break;
        case SP_ANIMATION_EVENT:
            info.type = 3;
            if (event) {
                if (event->data) {
                    info.name = event->data->name ? QString::fromUtf8(event->data->name) : QString();
                    info.dataIntValue = event->data->intValue;
                    info.dataFloatValue = event->data->floatValue;
                    info.dataStringValue = event->data->stringValue
                            ? QString::fromUtf8(event->data->stringValue) : QString();
                }
                info.intValue = event->intValue;
                info.floatValue = event->floatValue;
                info.stringValue = event->stringValue ? QString::fromUtf8(event->stringValue) : QString();
            }
            break;
        default: return;
        }
        self->mEventCallback(info);
    }

    template <typename T>
    static Texture *textureOf(T *att) {
        return (Texture *)((AtlasRegion *)att->rendererObject)->page->rendererObject;
    }

    void disposeInternal() {
        if (mAnimationState) {
            sp21AnimationStateData_dispose(mAnimationState->data);
            sp21AnimationState_dispose(mAnimationState);
            mAnimationState = nullptr;
        }
        if (mSkeleton) {
            sp21SkeletonData_dispose(mSkeleton->data);
            sp21Skeleton_dispose(mSkeleton);
            mSkeleton = nullptr;
        }
        if (mAtlas) {
            sp21Atlas_dispose(mAtlas);
            mAtlas = nullptr;
        }
    }

public:
    ~SpineBackend21() override { disposeInternal(); }

    bool load(const QString &jsonPath, const QString &atlasPath, float scale, const QString &skin) override {
        disposeInternal();
        const std::string atlasStr = atlasPath.toStdString();
        mAtlas = sp21Atlas_createFromFile(atlasStr.c_str(), nullptr);
        if (!mAtlas)
            return false;

        SkeletonJson *json = sp21SkeletonJson_create(mAtlas);
        json->scale = scale;
        const std::string skelStr = jsonPath.toStdString();
        SkeletonData *data = sp21SkeletonJson_readSkeletonDataFile(json, skelStr.c_str());
        if (!data) {
            sp21SkeletonJson_dispose(json);
            disposeInternal();
            return false;
        }
        sp21SkeletonJson_dispose(json);

        mSkeleton = sp21Skeleton_create(data);
        if (!skin.isEmpty())
            sp21Skeleton_setSkinByName(mSkeleton, skin.toStdString().c_str());

        mAnimationState = sp21AnimationState_create(sp21AnimationStateData_create(mSkeleton->data));
        mAnimationState->rendererObject = this;
        mAnimationState->listener = &SpineBackend21::animationCallback;
        return true;
    }

    void update(float delta) override {
        if (!mSkeleton || !mAnimationState)
            return;
        sp21Skeleton_update(mSkeleton, delta);
        sp21AnimationState_update(mAnimationState, delta);
        sp21AnimationState_apply(mAnimationState, mSkeleton);
        sp21Skeleton_updateWorldTransform(mSkeleton);
    }

    void collectDrawCommands(QVector<SpineDrawCommand> &out) override {
        out.clear();
        if (!mSkeleton)
            return;
        for (int i = 0, n = mSkeleton->slotsCount; i < n; ++i) {
            Slot *slot = mSkeleton->drawOrder[i];
            if (!slot || !slot->attachment)
                continue;
            switch (slot->attachment->type) {
            case SP_ATTACHMENT_REGION: {
                RegionAttachment *region = (RegionAttachment *)slot->attachment;
                std::vector<float> verts(8);
                sp21RegionAttachment_computeWorldVertices(region, slot->bone, verts.data());
                SpineDrawCommand cmd;
                cmd.texture = textureOf(region);
                cmd.vertices = std::move(verts);
                cmd.uvs = region->uvs;
                cmd.vertexCount = 4;
                cmd.indices = {0, 1, 2, 2, 3, 0};
                cmd.r = mSkeleton->r * slot->r * region->r;
                cmd.g = mSkeleton->g * slot->g * region->g;
                cmd.b = mSkeleton->b * slot->b * region->b;
                cmd.a = mSkeleton->a * slot->a * region->a;
                cmd.additiveBlending = slot->data->additiveBlending != 0;
                out.push_back(std::move(cmd));
                break;
            }
            case SP_ATTACHMENT_MESH: {
                MeshAttachment *mesh = (MeshAttachment *)slot->attachment;
                const int vcount = mesh->verticesCount;
                std::vector<float> verts((size_t)vcount * 2);
                sp21MeshAttachment_computeWorldVertices(mesh, slot, verts.data());
                SpineDrawCommand cmd;
                cmd.texture = textureOf(mesh);
                cmd.vertices = std::move(verts);
                cmd.uvs = mesh->uvs;
                cmd.vertexCount = vcount;
                cmd.indices.assign(mesh->triangles, mesh->triangles + mesh->trianglesCount);
                cmd.r = mSkeleton->r * slot->r * mesh->r;
                cmd.g = mSkeleton->g * slot->g * mesh->g;
                cmd.b = mSkeleton->b * slot->b * mesh->b;
                cmd.a = mSkeleton->a * slot->a * mesh->a;
                cmd.additiveBlending = slot->data->additiveBlending != 0;
                out.push_back(std::move(cmd));
                break;
            }
            case SP_ATTACHMENT_SKINNED_MESH: {
                SkinnedMeshAttachment *mesh = (SkinnedMeshAttachment *)slot->attachment;
                const int vcount = mesh->uvsCount;
                std::vector<float> verts((size_t)vcount * 2);
                sp21SkinnedMeshAttachment_computeWorldVertices(mesh, slot, verts.data());
                SpineDrawCommand cmd;
                cmd.texture = textureOf(mesh);
                cmd.vertices = std::move(verts);
                cmd.uvs = mesh->uvs;
                cmd.vertexCount = vcount;
                cmd.indices.assign(mesh->triangles, mesh->triangles + mesh->trianglesCount);
                cmd.r = mSkeleton->r * slot->r * mesh->r;
                cmd.g = mSkeleton->g * slot->g * mesh->g;
                cmd.b = mSkeleton->b * slot->b * mesh->b;
                cmd.a = mSkeleton->a * slot->a * mesh->a;
                cmd.additiveBlending = slot->data->additiveBlending != 0;
                out.push_back(std::move(cmd));
                break;
            }
            default:
                break;
            }
        }
    }

    QRectF bounds() override {
        if (!mSkeleton)
            return QRectF();
        float minX = FLT_MAX, minY = FLT_MAX, maxX = -FLT_MAX, maxY = -FLT_MAX;
        for (int i = 0, n = mSkeleton->slotsCount; i < n; ++i) {
            Slot *slot = mSkeleton->drawOrder[i];
            if (!slot || !slot->attachment)
                continue;
            int vcount = 0;
            std::vector<float> verts;
            switch (slot->attachment->type) {
            case SP_ATTACHMENT_REGION: {
                RegionAttachment *region = (RegionAttachment *)slot->attachment;
                verts.resize(8);
                sp21RegionAttachment_computeWorldVertices(region, slot->bone, verts.data());
                vcount = 4;
                break;
            }
            case SP_ATTACHMENT_MESH: {
                MeshAttachment *mesh = (MeshAttachment *)slot->attachment;
                vcount = mesh->verticesCount;
                verts.resize((size_t)vcount * 2);
                sp21MeshAttachment_computeWorldVertices(mesh, slot, verts.data());
                break;
            }
            case SP_ATTACHMENT_SKINNED_MESH: {
                SkinnedMeshAttachment *mesh = (SkinnedMeshAttachment *)slot->attachment;
                vcount = mesh->uvsCount;
                verts.resize((size_t)vcount * 2);
                sp21SkinnedMeshAttachment_computeWorldVertices(mesh, slot, verts.data());
                break;
            }
            default:
                continue;
            }
            for (int k = 0; k < vcount; ++k) {
                const float x = verts[(size_t)k * 2];
                const float y = verts[(size_t)k * 2 + 1];
                if (x < minX) minX = x;
                if (x > maxX) maxX = x;
                if (y < minY) minY = y;
                if (y > maxY) maxY = y;
            }
        }
        if (minX > maxX || minY > maxY)
            return QRectF();
        return QRectF(minX, minY, maxX - minX, maxY - minY);
    }

    bool setAnimation(int track, const QString &name, bool loop) override {
        if (!mSkeleton || !mAnimationState)
            return false;
        Animation *anim = sp21SkeletonData_findAnimation(mSkeleton->data, name.toStdString().c_str());
        if (!anim)
            return false;
        sp21AnimationState_setAnimation(mAnimationState, track, anim, loop ? 1 : 0);
        return true;
    }

    bool addAnimation(int track, const QString &name, bool loop, float delay) override {
        if (!mSkeleton || !mAnimationState)
            return false;
        Animation *anim = sp21SkeletonData_findAnimation(mSkeleton->data, name.toStdString().c_str());
        if (!anim)
            return false;
        sp21AnimationState_addAnimation(mAnimationState, track, anim, loop ? 1 : 0, delay);
        return true;
    }

    bool isPlaying(int track) override {
        if (!mAnimationState)
            return false;
        return sp21AnimationState_getCurrent(mAnimationState, track) != nullptr;
    }

    void clearTracks() override {
        if (mAnimationState)
            sp21AnimationState_clearTracks(mAnimationState);
    }

    void clearTrack(int track) override {
        if (mAnimationState)
            sp21AnimationState_clearTrack(mAnimationState, track);
    }

    void setMix(const QString &from, const QString &to, float duration) override {
        if (mAnimationState && mAnimationState->data)
            sp21AnimationStateData_setMixByName(mAnimationState->data, from.toStdString().c_str(),
                                                to.toStdString().c_str(), duration);
    }

    void setSkin(const QString &skin) override {
        if (mSkeleton)
            sp21Skeleton_setSkinByName(mSkeleton, skin.toStdString().c_str());
    }

    void setToSetupPose() override {
        if (mSkeleton)
            sp21Skeleton_setToSetupPose(mSkeleton);
    }

    void setBonesToSetupPose() override {
        if (mSkeleton)
            sp21Skeleton_setBonesToSetupPose(mSkeleton);
    }

    void setSlotsToSetupPose() override {
        if (mSkeleton)
            sp21Skeleton_setSlotsToSetupPose(mSkeleton);
    }

    bool setAttachment(const QString &slotName, const QString &attachmentName) override {
        if (!mSkeleton)
            return false;
        return sp21Skeleton_setAttachment(mSkeleton, slotName.toStdString().c_str(),
                                          attachmentName.toStdString().c_str()) != 0;
    }

    QVector<SpineBoneDebug> collectDebugBones() override {
        QVector<SpineBoneDebug> out;
        if (!mSkeleton)
            return out;
        for (int i = 0, n = mSkeleton->bonesCount; i < n; ++i) {
            sp21Bone *bone = mSkeleton->bones[i];
            SpineBoneDebug b;
            b.worldX = bone->worldX;
            b.worldY = bone->worldY;
            b.endX = bone->data->length * bone->m00 + bone->worldX;
            b.endY = bone->data->length * bone->m10 + bone->worldY;
            out.push_back(b);
        }
        return out;
    }

    QVector<std::vector<float>> collectDebugSlotRegions() override {
        QVector<std::vector<float>> out;
        if (!mSkeleton)
            return out;
        for (int i = 0, n = mSkeleton->slotsCount; i < n; ++i) {
            Slot *slot = mSkeleton->drawOrder[i];
            if (!slot || !slot->attachment || slot->attachment->type != SP_ATTACHMENT_REGION)
                continue;
            RegionAttachment *region = (RegionAttachment *)slot->attachment;
            std::vector<float> verts(8);
            sp21RegionAttachment_computeWorldVertices(region, slot->bone, verts.data());
            out.push_back(std::move(verts));
        }
        return out;
    }

    void setEventCallback(const SpineEventCallback &cb) override {
        mEventCallback = cb;
    }
};

} // namespace

SpineBackend *createBackend21() {
    return new SpineBackend21();
}

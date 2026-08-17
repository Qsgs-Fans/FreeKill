// 现代版本后端（3.4~4.2），由各版本 .cpp 定义好 SPINE_PREFIX 与各标志后包含。
// 标志：
//   SPINE_COLOR_STRUCT    0=颜色为直接字段 r/g/b/a（3.4/3.5），1=颜色为 spXXColor color 结构体（3.6+）
//   SPINE_REGION_COMPUTE  0=3参(bone)，1=5参(bone,offset,stride)，2=5参(slot,offset,stride)
//   SPINE_VERTEX_COMPUTE  0=3参(slot)，1=7参(slot,start,count,world,offset,stride)
//   SPINE_LISTENER_V4     0=3.4监听器(state,trackIndex,type,event,loopCount)，1=3.5+监听器(state,type,entry,event)
//   SPINE_HAS_SKELETON_UPDATE 0=无 Skeleton_update（4.1），1=有
//   SPINE_UPDATE_WORLD_PHYSICS 0=updateWorldTransform(skeleton)，1=updateWorldTransform(skeleton,physics)（4.2）

#define SP_FN(name) SPINE_CONCAT2(SPINE_PREFIX, name)
#define SP_TYPE(name) SPINE_CONCAT2(SPINE_PREFIX, name)

#if SPINE_COLOR_STRUCT
#define SP_C_R(o) ((o)->color.r)
#define SP_C_G(o) ((o)->color.g)
#define SP_C_B(o) ((o)->color.b)
#define SP_C_A(o) ((o)->color.a)
#else
#define SP_C_R(o) ((o)->r)
#define SP_C_G(o) ((o)->g)
#define SP_C_B(o) ((o)->b)
#define SP_C_A(o) ((o)->a)
#endif

#if SPINE_REGION_COMPUTE == 0
#define SP_COMPUTE_REGION(att, slot, world) SP_FN(RegionAttachment_computeWorldVertices)(att, slot->bone, world)
#elif SPINE_REGION_COMPUTE == 1
#define SP_COMPUTE_REGION(att, slot, world) SP_FN(RegionAttachment_computeWorldVertices)(att, slot->bone, world, 0, 2)
#else
#define SP_COMPUTE_REGION(att, slot, world) SP_FN(RegionAttachment_computeWorldVertices)(att, slot, world, 0, 2)
#endif

#if SPINE_VERTEX_COMPUTE == 0
#define SP_COMPUTE_VERTEX(att, slot, count, world) SP_FN(VertexAttachment_computeWorldVertices)(att, slot, world)
#else
#define SP_COMPUTE_VERTEX(att, slot, count, world) SP_FN(VertexAttachment_computeWorldVertices)(att, slot, 0, count, world, 0, 2)
#endif

// 3.4+ 的混合模式统一为 slot->data->blendMode（2.1 才用 additiveBlending）
#define SP_IS_ADDITIVE(slot) ((slot)->data->blendMode == SP_BLEND_MODE_ADDITIVE)

namespace {

class SpineBackendModern : public SpineBackend {
    typedef SP_TYPE(Skeleton) Skeleton;
    typedef SP_TYPE(SkeletonData) SkeletonData;
    typedef SP_TYPE(SkeletonJson) SkeletonJson;
    typedef SP_TYPE(SkeletonBinary) SkeletonBinary;
    typedef SP_TYPE(Atlas) Atlas;
    typedef SP_TYPE(AtlasRegion) AtlasRegion;
    typedef SP_TYPE(AnimationState) AnimationState;
    typedef SP_TYPE(AnimationStateData) AnimationStateData;
    typedef SP_TYPE(Animation) Animation;
    typedef SP_TYPE(Slot) Slot;
    typedef SP_TYPE(Bone) Bone;
    typedef SP_TYPE(TrackEntry) TrackEntry;
    typedef SP_TYPE(Event) Event;
    typedef SP_TYPE(RegionAttachment) RegionAttachment;
    typedef SP_TYPE(MeshAttachment) MeshAttachment;
    typedef SP_TYPE(VertexAttachment) VertexAttachment;

    Skeleton *mSkeleton = nullptr;
    Atlas *mAtlas = nullptr;
    AnimationState *mAnimationState = nullptr;
    SpineEventCallback mEventCallback;

#if SPINE_LISTENER_V4
    // 4.x：spXXAnimationStateListener(state, type, entry, event)
    static void animationCallback(AnimationState *state, SP_TYPE(EventType) type,
                                  TrackEntry *entry, Event *event) {
        SpineBackendModern *self = (SpineBackendModern *)state->rendererObject;
        if (!self || !self->mEventCallback)
            return;
        SpineEventInfo info;
        info.trackIndex = entry ? entry->trackIndex : 0;
        info.loopCount = 0;
        // 4.x 监听器不传 loopCount，按 trackTime / duration 计算（对齐 3.x 的语义）
        if (entry && entry->animation && entry->animation->duration > 0)
            info.loopCount = (int)(entry->trackTime / entry->animation->duration);
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
                    info.dataStringValue = event->data->stringValue ? QString::fromUtf8(event->data->stringValue) : QString();
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
#else
    // 3.x：spXXAnimationStateListener(state, trackIndex, type, event, loopCount)
    static void animationCallback(AnimationState *state, int trackIndex, SP_TYPE(EventType) type,
                                  Event *event, int loopCount) {
        SpineBackendModern *self = (SpineBackendModern *)state->rendererObject;
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
                    info.dataStringValue = event->data->stringValue ? QString::fromUtf8(event->data->stringValue) : QString();
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
#endif

    static Texture *textureOf(RegionAttachment *att) {
        return (Texture *)((AtlasRegion *)att->rendererObject)->page->rendererObject;
    }
    static Texture *textureOf(MeshAttachment *att) {
        return (Texture *)((AtlasRegion *)att->rendererObject)->page->rendererObject;
    }

    void disposeInternal() {
        if (mAnimationState) {
            SP_FN(AnimationStateData_dispose)(mAnimationState->data);
            SP_FN(AnimationState_dispose)(mAnimationState);
            mAnimationState = nullptr;
        }
        if (mSkeleton) {
            SP_FN(SkeletonData_dispose)(mSkeleton->data);
            SP_FN(Skeleton_dispose)(mSkeleton);
            mSkeleton = nullptr;
        }
        if (mAtlas) {
            SP_FN(Atlas_dispose)(mAtlas);
            mAtlas = nullptr;
        }
    }

public:
    ~SpineBackendModern() override { disposeInternal(); }

    bool load(const QString &skeletonPath, const QString &atlasPath, float scale, const QString &skin) override {
        disposeInternal();
        const std::string atlasStr = atlasPath.toStdString();
        mAtlas = SP_FN(Atlas_createFromFile)(atlasStr.c_str(), nullptr);
        if (!mAtlas)
            return false;

        const std::string skelStr = skeletonPath.toStdString();
        const bool isBinary = skeletonPath.endsWith(QStringLiteral(".skel"), Qt::CaseInsensitive);
        SkeletonData *data = nullptr;

        if (isBinary) {
            SkeletonBinary *binary = SP_FN(SkeletonBinary_create)(mAtlas);
            binary->scale = scale;
            data = SP_FN(SkeletonBinary_readSkeletonDataFile)(binary, skelStr.c_str());
            SP_FN(SkeletonBinary_dispose)(binary);
        } else {
            SkeletonJson *json = SP_FN(SkeletonJson_create)(mAtlas);
            json->scale = scale;
            data = SP_FN(SkeletonJson_readSkeletonDataFile)(json, skelStr.c_str());
            SP_FN(SkeletonJson_dispose)(json);
        }

        if (!data) {
            disposeInternal();
            return false;
        }

        mSkeleton = SP_FN(Skeleton_create)(data);
        if (!skin.isEmpty())
            SP_FN(Skeleton_setSkinByName)(mSkeleton, skin.toStdString().c_str());

        mAnimationState = SP_FN(AnimationState_create)(SP_FN(AnimationStateData_create)(mSkeleton->data));
        mAnimationState->rendererObject = this;
        mAnimationState->listener = &SpineBackendModern::animationCallback;
        return true;
    }

    void update(float delta) override {
        if (!mSkeleton || !mAnimationState)
            return;
#if SPINE_HAS_SKELETON_UPDATE
        SP_FN(Skeleton_update)(mSkeleton, delta);
#endif
        SP_FN(AnimationState_update)(mAnimationState, delta);
        SP_FN(AnimationState_apply)(mAnimationState, mSkeleton);
#if SPINE_UPDATE_WORLD_PHYSICS
        SP_FN(Skeleton_updateWorldTransform)(mSkeleton, SP_PHYSICS_UPDATE);
#else
        SP_FN(Skeleton_updateWorldTransform)(mSkeleton);
#endif
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
                SP_COMPUTE_REGION(region, slot, verts.data());
                SpineDrawCommand cmd;
                cmd.texture = textureOf(region);
                cmd.vertices = std::move(verts);
                cmd.uvs = region->uvs;
                cmd.vertexCount = 4;
                cmd.indices = {0, 1, 2, 2, 3, 0};
                cmd.r = SP_C_R(mSkeleton) * SP_C_R(slot) * SP_C_R(region);
                cmd.g = SP_C_G(mSkeleton) * SP_C_G(slot) * SP_C_G(region);
                cmd.b = SP_C_B(mSkeleton) * SP_C_B(slot) * SP_C_B(region);
                cmd.a = SP_C_A(mSkeleton) * SP_C_A(slot) * SP_C_A(region);
                cmd.additiveBlending = SP_IS_ADDITIVE(slot);
                out.push_back(std::move(cmd));
                break;
            }
            case SP_ATTACHMENT_MESH:
            case SP_ATTACHMENT_LINKED_MESH: {
                MeshAttachment *mesh = (MeshAttachment *)slot->attachment;
                const int floats = mesh->super.worldVerticesLength;
                std::vector<float> verts((size_t)floats);
                SP_COMPUTE_VERTEX((VertexAttachment *)mesh, slot, floats, verts.data());
                SpineDrawCommand cmd;
                cmd.texture = textureOf(mesh);
                cmd.vertices = std::move(verts);
                cmd.uvs = mesh->uvs;
                cmd.vertexCount = floats / 2;
                cmd.indices.assign(mesh->triangles, mesh->triangles + mesh->trianglesCount);
                cmd.r = SP_C_R(mSkeleton) * SP_C_R(slot) * SP_C_R(mesh);
                cmd.g = SP_C_G(mSkeleton) * SP_C_G(slot) * SP_C_G(mesh);
                cmd.b = SP_C_B(mSkeleton) * SP_C_B(slot) * SP_C_B(mesh);
                cmd.a = SP_C_A(mSkeleton) * SP_C_A(slot) * SP_C_A(mesh);
                cmd.additiveBlending = SP_IS_ADDITIVE(slot);
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
            if (slot->attachment->type == SP_ATTACHMENT_REGION) {
                RegionAttachment *region = (RegionAttachment *)slot->attachment;
                verts.resize(8);
                SP_COMPUTE_REGION(region, slot, verts.data());
                vcount = 4;
            } else if (slot->attachment->type == SP_ATTACHMENT_MESH ||
                       slot->attachment->type == SP_ATTACHMENT_LINKED_MESH) {
                MeshAttachment *mesh = (MeshAttachment *)slot->attachment;
                const int floats = mesh->super.worldVerticesLength;
                vcount = floats / 2;
                verts.resize((size_t)floats);
                SP_COMPUTE_VERTEX((VertexAttachment *)mesh, slot, floats, verts.data());
            } else {
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
        Animation *anim = SP_FN(SkeletonData_findAnimation)(mSkeleton->data, name.toStdString().c_str());
        if (!anim)
            return false;
        SP_FN(AnimationState_setAnimation)(mAnimationState, track, anim, loop ? 1 : 0);
        return true;
    }

    bool addAnimation(int track, const QString &name, bool loop, float delay) override {
        if (!mSkeleton || !mAnimationState)
            return false;
        Animation *anim = SP_FN(SkeletonData_findAnimation)(mSkeleton->data, name.toStdString().c_str());
        if (!anim)
            return false;
        SP_FN(AnimationState_addAnimation)(mAnimationState, track, anim, loop ? 1 : 0, delay);
        return true;
    }

    bool isPlaying(int track) override {
        if (!mAnimationState)
            return false;
        return SP_FN(AnimationState_getCurrent)(mAnimationState, track) != nullptr;
    }

    void clearTracks() override {
        if (mAnimationState)
            SP_FN(AnimationState_clearTracks)(mAnimationState);
    }

    void clearTrack(int track) override {
        if (mAnimationState)
            SP_FN(AnimationState_clearTrack)(mAnimationState, track);
    }

    void setMix(const QString &from, const QString &to, float duration) override {
        if (mAnimationState && mAnimationState->data)
            SP_FN(AnimationStateData_setMixByName)(mAnimationState->data, from.toStdString().c_str(),
                                                   to.toStdString().c_str(), duration);
    }

    void setSkin(const QString &skin) override {
        if (mSkeleton)
            SP_FN(Skeleton_setSkinByName)(mSkeleton, skin.toStdString().c_str());
    }

    void setToSetupPose() override {
        if (mSkeleton)
            SP_FN(Skeleton_setToSetupPose)(mSkeleton);
    }

    void setBonesToSetupPose() override {
        if (mSkeleton)
            SP_FN(Skeleton_setBonesToSetupPose)(mSkeleton);
    }

    void setSlotsToSetupPose() override {
        if (mSkeleton)
            SP_FN(Skeleton_setSlotsToSetupPose)(mSkeleton);
    }

    bool setAttachment(const QString &slotName, const QString &attachmentName) override {
        if (!mSkeleton)
            return false;
        return SP_FN(Skeleton_setAttachment)(mSkeleton, slotName.toStdString().c_str(),
                                             attachmentName.toStdString().c_str()) != 0;
    }

    QVector<SpineBoneDebug> collectDebugBones() override {
        QVector<SpineBoneDebug> out;
        if (!mSkeleton)
            return out;
        for (int i = 0, n = mSkeleton->bonesCount; i < n; ++i) {
            Bone *bone = mSkeleton->bones[i];
            SpineBoneDebug b;
            b.worldX = bone->worldX;
            b.worldY = bone->worldY;
            b.endX = bone->data->length * bone->a + bone->worldX;
            b.endY = bone->data->length * bone->b + bone->worldY;
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
            SP_COMPUTE_REGION(region, slot, verts.data());
            out.push_back(std::move(verts));
        }
        return out;
    }

    void setEventCallback(const SpineEventCallback &cb) override {
        mEventCallback = cb;
    }
};

} // namespace

#undef SP_FN
#undef SP_TYPE
#undef SP_C_R
#undef SP_C_G
#undef SP_C_B
#undef SP_C_A
#undef SP_COMPUTE_REGION
#undef SP_COMPUTE_VERTEX
#undef SP_IS_ADDITIVE

/******************************************************************************
 * Spine Runtimes Software License v2.5
 *
 * Copyright (c) 2013-2016, Esoteric Software
 * All rights reserved.
 *
 * You are granted a perpetual, non-exclusive, non-sublicensable, and
 * non-transferable license to use, install, execute, and perform the Spine
 * Runtimes software and derivative works solely for personal or internal
 * use. Without the written permission of Esoteric Software (see Section 2 of
 * the Spine Software License Agreement), you may not (a) modify, translate,
 * adapt, or develop new applications using the Spine Runtimes or otherwise
 * create derivative works or improvements of the Spine Runtimes or (b) remove,
 * delete, alter, or obscure any trademarks or any copyright, trademark, patent,
 * or other intellectual property or proprietary rights notices on or in the
 * Software, including any copy thereof. Redistributions in binary or source
 * form must include this license and terms.
 *
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, BUSINESS INTERRUPTION, OR LOSS OF
 * USE, DATA, OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 * IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#ifndef SPINE_SKELETONDATA_H_
#define SPINE_SKELETONDATA_H_

#include <spine/dll.h>
#include <spine/BoneData.h>
#include <spine/SlotData.h>
#include <spine/Skin.h>
#include <spine/EventData.h>
#include <spine/Animation.h>
#include <spine/IkConstraintData.h>
#include <spine/TransformConstraintData.h>
#include <spine/PathConstraintData.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp36SkeletonData {
	const char* version;
	const char* hash;
	float width, height;

	int bonesCount;
	sp36BoneData** bones;

	int slotsCount;
	sp36SlotData** slots;

	int skinsCount;
	sp36Skin** skins;
	sp36Skin* defaultSkin;

	int eventsCount;
	sp36EventData** events;

	int animationsCount;
	sp36Animation** animations;

	int ikConstraintsCount;
	sp36IkConstraintData** ikConstraints;

	int transformConstraintsCount;
	sp36TransformConstraintData** transformConstraints;

	int pathConstraintsCount;
	sp36PathConstraintData** pathConstraints;
} sp36SkeletonData;

SP_API sp36SkeletonData* sp36SkeletonData_create ();
SP_API void sp36SkeletonData_dispose (sp36SkeletonData* self);

SP_API sp36BoneData* sp36SkeletonData_findBone (const sp36SkeletonData* self, const char* boneName);
SP_API int sp36SkeletonData_findBoneIndex (const sp36SkeletonData* self, const char* boneName);

SP_API sp36SlotData* sp36SkeletonData_findSlot (const sp36SkeletonData* self, const char* slotName);
SP_API int sp36SkeletonData_findSlotIndex (const sp36SkeletonData* self, const char* slotName);

SP_API sp36Skin* sp36SkeletonData_findSkin (const sp36SkeletonData* self, const char* skinName);

SP_API sp36EventData* sp36SkeletonData_findEvent (const sp36SkeletonData* self, const char* eventName);

SP_API sp36Animation* sp36SkeletonData_findAnimation (const sp36SkeletonData* self, const char* animationName);

SP_API sp36IkConstraintData* sp36SkeletonData_findIkConstraint (const sp36SkeletonData* self, const char* constraintName);

SP_API sp36TransformConstraintData* sp36SkeletonData_findTransformConstraint (const sp36SkeletonData* self, const char* constraintName);

SP_API sp36PathConstraintData* sp36SkeletonData_findPathConstraint (const sp36SkeletonData* self, const char* constraintName);

#ifdef SPINE_SHORT_NAMES
typedef sp36SkeletonData SkeletonData;
#define SkeletonData_create(...) sp36SkeletonData_create(__VA_ARGS__)
#define SkeletonData_dispose(...) sp36SkeletonData_dispose(__VA_ARGS__)
#define SkeletonData_findBone(...) sp36SkeletonData_findBone(__VA_ARGS__)
#define SkeletonData_findBoneIndex(...) sp36SkeletonData_findBoneIndex(__VA_ARGS__)
#define SkeletonData_findSlot(...) sp36SkeletonData_findSlot(__VA_ARGS__)
#define SkeletonData_findSlotIndex(...) sp36SkeletonData_findSlotIndex(__VA_ARGS__)
#define SkeletonData_findSkin(...) sp36SkeletonData_findSkin(__VA_ARGS__)
#define SkeletonData_findEvent(...) sp36SkeletonData_findEvent(__VA_ARGS__)
#define SkeletonData_findAnimation(...) sp36SkeletonData_findAnimation(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONDATA_H_ */

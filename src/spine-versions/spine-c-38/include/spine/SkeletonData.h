/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated January 1, 2020. Replaces all prior versions.
 *
 * Copyright (c) 2013-2020, Esoteric Software LLC
 *
 * Integration of the Spine Runtimes into software or otherwise creating
 * derivative works of the Spine Runtimes is permitted under the terms and
 * conditions of Section 2 of the Spine Editor License Agreement:
 * http://esotericsoftware.com/spine-editor-license
 *
 * Otherwise, it is permitted to integrate the Spine Runtimes into software
 * or otherwise create derivative works of the Spine Runtimes (collectively,
 * "Products"), provided that each user of the Products must obtain their own
 * Spine Editor license and redistribution of the Products in any form must
 * include this license and copyright notice.
 *
 * THE SPINE RUNTIMES ARE PROVIDED BY ESOTERIC SOFTWARE LLC "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL ESOTERIC SOFTWARE LLC BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES,
 * BUSINESS INTERRUPTION, OR LOSS OF USE, DATA, OR PROFITS) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THE SPINE RUNTIMES, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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

typedef struct sp38SkeletonData {
	const char* version;
	const char* hash;
	float x, y, width, height;

	int stringsCount;
	char** strings;

	int bonesCount;
	sp38BoneData** bones;

	int slotsCount;
	sp38SlotData** slots;

	int skinsCount;
	sp38Skin** skins;
	sp38Skin* defaultSkin;

	int eventsCount;
	sp38EventData** events;

	int animationsCount;
	sp38Animation** animations;

	int ikConstraintsCount;
	sp38IkConstraintData** ikConstraints;

	int transformConstraintsCount;
	sp38TransformConstraintData** transformConstraints;

	int pathConstraintsCount;
	sp38PathConstraintData** pathConstraints;
} sp38SkeletonData;

SP_API sp38SkeletonData* sp38SkeletonData_create ();
SP_API void sp38SkeletonData_dispose (sp38SkeletonData* self);

SP_API sp38BoneData* sp38SkeletonData_findBone (const sp38SkeletonData* self, const char* boneName);
SP_API int sp38SkeletonData_findBoneIndex (const sp38SkeletonData* self, const char* boneName);

SP_API sp38SlotData* sp38SkeletonData_findSlot (const sp38SkeletonData* self, const char* slotName);
SP_API int sp38SkeletonData_findSlotIndex (const sp38SkeletonData* self, const char* slotName);

SP_API sp38Skin* sp38SkeletonData_findSkin (const sp38SkeletonData* self, const char* skinName);

SP_API sp38EventData* sp38SkeletonData_findEvent (const sp38SkeletonData* self, const char* eventName);

SP_API sp38Animation* sp38SkeletonData_findAnimation (const sp38SkeletonData* self, const char* animationName);

SP_API sp38IkConstraintData* sp38SkeletonData_findIkConstraint (const sp38SkeletonData* self, const char* constraintName);

SP_API sp38TransformConstraintData* sp38SkeletonData_findTransformConstraint (const sp38SkeletonData* self, const char* constraintName);

SP_API sp38PathConstraintData* sp38SkeletonData_findPathConstraint (const sp38SkeletonData* self, const char* constraintName);

#ifdef SPINE_SHORT_NAMES
typedef sp38SkeletonData SkeletonData;
#define SkeletonData_create(...) sp38SkeletonData_create(__VA_ARGS__)
#define SkeletonData_dispose(...) sp38SkeletonData_dispose(__VA_ARGS__)
#define SkeletonData_findBone(...) sp38SkeletonData_findBone(__VA_ARGS__)
#define SkeletonData_findBoneIndex(...) sp38SkeletonData_findBoneIndex(__VA_ARGS__)
#define SkeletonData_findSlot(...) sp38SkeletonData_findSlot(__VA_ARGS__)
#define SkeletonData_findSlotIndex(...) sp38SkeletonData_findSlotIndex(__VA_ARGS__)
#define SkeletonData_findSkin(...) sp38SkeletonData_findSkin(__VA_ARGS__)
#define SkeletonData_findEvent(...) sp38SkeletonData_findEvent(__VA_ARGS__)
#define SkeletonData_findAnimation(...) sp38SkeletonData_findAnimation(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONDATA_H_ */

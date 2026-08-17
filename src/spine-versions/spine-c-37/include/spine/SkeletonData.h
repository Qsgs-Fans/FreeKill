/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated May 1, 2019. Replaces all prior versions.
 *
 * Copyright (c) 2013-2019, Esoteric Software LLC
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
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE LLC "AS IS" AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
 * NO EVENT SHALL ESOTERIC SOFTWARE LLC BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, BUSINESS
 * INTERRUPTION, OR LOSS OF USE, DATA, OR PROFITS) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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

typedef struct sp37SkeletonData {
	const char* version;
	const char* hash;
	float width, height;

	int bonesCount;
	sp37BoneData** bones;

	int slotsCount;
	sp37SlotData** slots;

	int skinsCount;
	sp37Skin** skins;
	sp37Skin* defaultSkin;

	int eventsCount;
	sp37EventData** events;

	int animationsCount;
	sp37Animation** animations;

	int ikConstraintsCount;
	sp37IkConstraintData** ikConstraints;

	int transformConstraintsCount;
	sp37TransformConstraintData** transformConstraints;

	int pathConstraintsCount;
	sp37PathConstraintData** pathConstraints;
} sp37SkeletonData;

SP_API sp37SkeletonData* sp37SkeletonData_create ();
SP_API void sp37SkeletonData_dispose (sp37SkeletonData* self);

SP_API sp37BoneData* sp37SkeletonData_findBone (const sp37SkeletonData* self, const char* boneName);
SP_API int sp37SkeletonData_findBoneIndex (const sp37SkeletonData* self, const char* boneName);

SP_API sp37SlotData* sp37SkeletonData_findSlot (const sp37SkeletonData* self, const char* slotName);
SP_API int sp37SkeletonData_findSlotIndex (const sp37SkeletonData* self, const char* slotName);

SP_API sp37Skin* sp37SkeletonData_findSkin (const sp37SkeletonData* self, const char* skinName);

SP_API sp37EventData* sp37SkeletonData_findEvent (const sp37SkeletonData* self, const char* eventName);

SP_API sp37Animation* sp37SkeletonData_findAnimation (const sp37SkeletonData* self, const char* animationName);

SP_API sp37IkConstraintData* sp37SkeletonData_findIkConstraint (const sp37SkeletonData* self, const char* constraintName);

SP_API sp37TransformConstraintData* sp37SkeletonData_findTransformConstraint (const sp37SkeletonData* self, const char* constraintName);

SP_API sp37PathConstraintData* sp37SkeletonData_findPathConstraint (const sp37SkeletonData* self, const char* constraintName);

#ifdef SPINE_SHORT_NAMES
typedef sp37SkeletonData SkeletonData;
#define SkeletonData_create(...) sp37SkeletonData_create(__VA_ARGS__)
#define SkeletonData_dispose(...) sp37SkeletonData_dispose(__VA_ARGS__)
#define SkeletonData_findBone(...) sp37SkeletonData_findBone(__VA_ARGS__)
#define SkeletonData_findBoneIndex(...) sp37SkeletonData_findBoneIndex(__VA_ARGS__)
#define SkeletonData_findSlot(...) sp37SkeletonData_findSlot(__VA_ARGS__)
#define SkeletonData_findSlotIndex(...) sp37SkeletonData_findSlotIndex(__VA_ARGS__)
#define SkeletonData_findSkin(...) sp37SkeletonData_findSkin(__VA_ARGS__)
#define SkeletonData_findEvent(...) sp37SkeletonData_findEvent(__VA_ARGS__)
#define SkeletonData_findAnimation(...) sp37SkeletonData_findAnimation(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONDATA_H_ */

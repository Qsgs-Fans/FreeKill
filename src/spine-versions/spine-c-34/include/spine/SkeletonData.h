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

typedef struct sp34SkeletonData {
	const char* version;
	const char* hash;
	float width, height;

	int bonesCount;
	sp34BoneData** bones;

	int slotsCount;
	sp34SlotData** slots;

	int skinsCount;
	sp34Skin** skins;
	sp34Skin* defaultSkin;

	int eventsCount;
	sp34EventData** events;

	int animationsCount;
	sp34Animation** animations;

	int ikConstraintsCount;
	sp34IkConstraintData** ikConstraints;

	int transformConstraintsCount;
	sp34TransformConstraintData** transformConstraints;

	int pathConstraintsCount;
	sp34PathConstraintData** pathConstraints;
} sp34SkeletonData;

sp34SkeletonData* sp34SkeletonData_create ();
void sp34SkeletonData_dispose (sp34SkeletonData* self);

sp34BoneData* sp34SkeletonData_findBone (const sp34SkeletonData* self, const char* boneName);
int sp34SkeletonData_findBoneIndex (const sp34SkeletonData* self, const char* boneName);

sp34SlotData* sp34SkeletonData_findSlot (const sp34SkeletonData* self, const char* slotName);
int sp34SkeletonData_findSlotIndex (const sp34SkeletonData* self, const char* slotName);

sp34Skin* sp34SkeletonData_findSkin (const sp34SkeletonData* self, const char* skinName);

sp34EventData* sp34SkeletonData_findEvent (const sp34SkeletonData* self, const char* eventName);

sp34Animation* sp34SkeletonData_findAnimation (const sp34SkeletonData* self, const char* animationName);

sp34IkConstraintData* sp34SkeletonData_findIkConstraint (const sp34SkeletonData* self, const char* constraintName);

sp34TransformConstraintData* sp34SkeletonData_findTransformConstraint (const sp34SkeletonData* self, const char* constraintName);

sp34PathConstraintData* sp34SkeletonData_findPathConstraint (const sp34SkeletonData* self, const char* constraintName);

#ifdef SPINE_SHORT_NAMES
typedef sp34SkeletonData SkeletonData;
#define SkeletonData_create(...) sp34SkeletonData_create(__VA_ARGS__)
#define SkeletonData_dispose(...) sp34SkeletonData_dispose(__VA_ARGS__)
#define SkeletonData_findBone(...) sp34SkeletonData_findBone(__VA_ARGS__)
#define SkeletonData_findBoneIndex(...) sp34SkeletonData_findBoneIndex(__VA_ARGS__)
#define SkeletonData_findSlot(...) sp34SkeletonData_findSlot(__VA_ARGS__)
#define SkeletonData_findSlotIndex(...) sp34SkeletonData_findSlotIndex(__VA_ARGS__)
#define SkeletonData_findSkin(...) sp34SkeletonData_findSkin(__VA_ARGS__)
#define SkeletonData_findEvent(...) sp34SkeletonData_findEvent(__VA_ARGS__)
#define SkeletonData_findAnimation(...) sp34SkeletonData_findAnimation(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONDATA_H_ */

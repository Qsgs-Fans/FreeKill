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

typedef struct sp40SkeletonData {
	const char *version;
	const char *hash;
	float x, y, width, height;
	float fps;
	const char *imagesPath;
	const char *audioPath;

	int stringsCount;
	char **strings;

	int bonesCount;
	sp40BoneData **bones;

	int slotsCount;
	sp40SlotData **slots;

	int skinsCount;
	sp40Skin **skins;
	sp40Skin *defaultSkin;

	int eventsCount;
	sp40EventData **events;

	int animationsCount;
	sp40Animation **animations;

	int ikConstraintsCount;
	sp40IkConstraintData **ikConstraints;

	int transformConstraintsCount;
	sp40TransformConstraintData **transformConstraints;

	int pathConstraintsCount;
	sp40PathConstraintData **pathConstraints;
} sp40SkeletonData;

SP_API sp40SkeletonData *sp40SkeletonData_create();

SP_API void sp40SkeletonData_dispose(sp40SkeletonData *self);

SP_API sp40BoneData *sp40SkeletonData_findBone(const sp40SkeletonData *self, const char *boneName);

SP_API sp40SlotData *sp40SkeletonData_findSlot(const sp40SkeletonData *self, const char *slotName);

SP_API sp40Skin *sp40SkeletonData_findSkin(const sp40SkeletonData *self, const char *skinName);

SP_API sp40EventData *sp40SkeletonData_findEvent(const sp40SkeletonData *self, const char *eventName);

SP_API sp40Animation *sp40SkeletonData_findAnimation(const sp40SkeletonData *self, const char *animationName);

SP_API sp40IkConstraintData *sp40SkeletonData_findIkConstraint(const sp40SkeletonData *self, const char *constraintName);

SP_API sp40TransformConstraintData *
sp40SkeletonData_findTransformConstraint(const sp40SkeletonData *self, const char *constraintName);

SP_API sp40PathConstraintData *sp40SkeletonData_findPathConstraint(const sp40SkeletonData *self, const char *constraintName);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONDATA_H_ */

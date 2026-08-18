/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated September 24, 2021. Replaces all prior versions.
 *
 * Copyright (c) 2013-2021, Esoteric Software LLC
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

typedef struct sp41SkeletonData {
	const char *version;
	const char *hash;
	float x, y, width, height;
	float fps;
	const char *imagesPath;
	const char *audioPath;

	int stringsCount;
	char **strings;

	int bonesCount;
	sp41BoneData **bones;

	int slotsCount;
	sp41SlotData **slots;

	int skinsCount;
	sp41Skin **skins;
	sp41Skin *defaultSkin;

	int eventsCount;
	sp41EventData **events;

	int animationsCount;
	sp41Animation **animations;

	int ikConstraintsCount;
	sp41IkConstraintData **ikConstraints;

	int transformConstraintsCount;
	sp41TransformConstraintData **transformConstraints;

	int pathConstraintsCount;
	sp41PathConstraintData **pathConstraints;
} sp41SkeletonData;

SP_API sp41SkeletonData *sp41SkeletonData_create();

SP_API void sp41SkeletonData_dispose(sp41SkeletonData *self);

SP_API sp41BoneData *sp41SkeletonData_findBone(const sp41SkeletonData *self, const char *boneName);

SP_API sp41SlotData *sp41SkeletonData_findSlot(const sp41SkeletonData *self, const char *slotName);

SP_API sp41Skin *sp41SkeletonData_findSkin(const sp41SkeletonData *self, const char *skinName);

SP_API sp41EventData *sp41SkeletonData_findEvent(const sp41SkeletonData *self, const char *eventName);

SP_API sp41Animation *sp41SkeletonData_findAnimation(const sp41SkeletonData *self, const char *animationName);

SP_API sp41IkConstraintData *sp41SkeletonData_findIkConstraint(const sp41SkeletonData *self, const char *constraintName);

SP_API sp41TransformConstraintData *
sp41SkeletonData_findTransformConstraint(const sp41SkeletonData *self, const char *constraintName);

SP_API sp41PathConstraintData *sp41SkeletonData_findPathConstraint(const sp41SkeletonData *self, const char *constraintName);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONDATA_H_ */

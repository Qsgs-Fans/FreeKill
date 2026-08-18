/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated July 28, 2023. Replaces all prior versions.
 *
 * Copyright (c) 2013-2023, Esoteric Software LLC
 *
 * Integration of the Spine Runtimes into software or otherwise creating
 * derivative works of the Spine Runtimes is permitted under the terms and
 * conditions of Section 2 of the Spine Editor License Agreement:
 * http://esotericsoftware.com/spine-editor-license
 *
 * Otherwise, it is permitted to integrate the Spine Runtimes into software or
 * otherwise create derivative works of the Spine Runtimes (collectively,
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
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE
 * SPINE RUNTIMES, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
#include <spine/PhysicsConstraintData.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp42SkeletonData {
	char *version;
	char *hash;
	float x, y, width, height;
    float referenceScale;
	float fps;
	const char *imagesPath;
	const char *audioPath;

	int stringsCount;
	char **strings;

	int bonesCount;
	sp42BoneData **bones;

	int slotsCount;
	sp42SlotData **slots;

	int skinsCount;
	sp42Skin **skins;
	sp42Skin *defaultSkin;

	int eventsCount;
	sp42EventData **events;

	int animationsCount;
	sp42Animation **animations;

	int ikConstraintsCount;
	sp42IkConstraintData **ikConstraints;

	int transformConstraintsCount;
	sp42TransformConstraintData **transformConstraints;

	int pathConstraintsCount;
	sp42PathConstraintData **pathConstraints;

    int physicsConstraintsCount;
    sp42PhysicsConstraintData **physicsConstraints;
} sp42SkeletonData;

SP_API sp42SkeletonData *sp42SkeletonData_create(void);

SP_API void sp42SkeletonData_dispose(sp42SkeletonData *self);

SP_API sp42BoneData *sp42SkeletonData_findBone(const sp42SkeletonData *self, const char *boneName);

SP_API sp42SlotData *sp42SkeletonData_findSlot(const sp42SkeletonData *self, const char *slotName);

SP_API sp42Skin *sp42SkeletonData_findSkin(const sp42SkeletonData *self, const char *skinName);

SP_API sp42EventData *sp42SkeletonData_findEvent(const sp42SkeletonData *self, const char *eventName);

SP_API sp42Animation *sp42SkeletonData_findAnimation(const sp42SkeletonData *self, const char *animationName);

SP_API sp42IkConstraintData *sp42SkeletonData_findIkConstraint(const sp42SkeletonData *self, const char *constraintName);

SP_API sp42TransformConstraintData *
sp42SkeletonData_findTransformConstraint(const sp42SkeletonData *self, const char *constraintName);

SP_API sp42PathConstraintData *sp42SkeletonData_findPathConstraint(const sp42SkeletonData *self, const char *constraintName);

SP_API sp42PhysicsConstraintData *sp42SkeletonData_findPhysicsConstraint(const sp42SkeletonData *self, const char *constraintName);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONDATA_H_ */

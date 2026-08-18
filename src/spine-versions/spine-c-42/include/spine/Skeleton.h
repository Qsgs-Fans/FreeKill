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

#ifndef SPINE_SKELETON_H_
#define SPINE_SKELETON_H_

#include <spine/dll.h>
#include <spine/SkeletonData.h>
#include <spine/Slot.h>
#include <spine/Skin.h>
#include <spine/IkConstraint.h>
#include <spine/TransformConstraint.h>
#include <spine/PathConstraint.h>
#include <spine/PhysicsConstraint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp42Skeleton {
	sp42SkeletonData *data;

	int bonesCount;
	sp42Bone **bones;
	sp42Bone *root;

	int slotsCount;
	sp42Slot **slots;
	sp42Slot **drawOrder;

	int ikConstraintsCount;
	sp42IkConstraint **ikConstraints;

	int transformConstraintsCount;
	sp42TransformConstraint **transformConstraints;

	int pathConstraintsCount;
	sp42PathConstraint **pathConstraints;

    int physicsConstraintsCount;
    sp42PhysicsConstraint **physicsConstraints;

	sp42Skin *skin;
	sp42Color color;
	float scaleX, scaleY;
	float x, y;

    float time;
} sp42Skeleton;

SP_API sp42Skeleton *sp42Skeleton_create(sp42SkeletonData *data);

SP_API void sp42Skeleton_dispose(sp42Skeleton *self);

/* Caches information about bones and constraints. Must be called if bones or constraints, or weighted path attachments
 * are added or removed. */
SP_API void sp42Skeleton_updateCache(sp42Skeleton *self);

SP_API void sp42Skeleton_updateWorldTransform(const sp42Skeleton *self, sp42Physics physics);

SP_API void sp42Skeleton_update(sp42Skeleton *self, float delta);

/* Sets the bones, constraints, and slots to their setup pose values. */
SP_API void sp42Skeleton_setToSetupPose(const sp42Skeleton *self);
/* Sets the bones and constraints to their setup pose values. */
SP_API void sp42Skeleton_setBonesToSetupPose(const sp42Skeleton *self);

SP_API void sp42Skeleton_setSlotsToSetupPose(const sp42Skeleton *self);

/* Returns 0 if the bone was not found. */
SP_API sp42Bone *sp42Skeleton_findBone(const sp42Skeleton *self, const char *boneName);

/* Returns 0 if the slot was not found. */
SP_API sp42Slot *sp42Skeleton_findSlot(const sp42Skeleton *self, const char *slotName);

/* Sets the skin used to look up attachments before looking in the SkeletonData defaultSkin. Attachments from the new skin are
 * attached if the corresponding attachment from the old skin was attached. If there was no old skin, each slot's setup mode
 * attachment is attached from the new skin.
 * @param skin May be 0.*/
SP_API void sp42Skeleton_setSkin(sp42Skeleton *self, sp42Skin *skin);
/* Returns 0 if the skin was not found. See sp42Skeleton_setSkin.
 * @param skinName May be 0. */
SP_API int sp42Skeleton_setSkinByName(sp42Skeleton *self, const char *skinName);

/* Returns 0 if the slot or attachment was not found. */
SP_API sp42Attachment *
sp42Skeleton_getAttachmentForSlotName(const sp42Skeleton *self, const char *slotName, const char *attachmentName);
/* Returns 0 if the slot or attachment was not found. */
SP_API sp42Attachment *
sp42Skeleton_getAttachmentForSlotIndex(const sp42Skeleton *self, int slotIndex, const char *attachmentName);
/* Returns 0 if the slot or attachment was not found.
 * @param attachmentName May be 0. */
SP_API int sp42Skeleton_setAttachment(sp42Skeleton *self, const char *slotName, const char *attachmentName);

/* Returns 0 if the IK constraint was not found. */
SP_API sp42IkConstraint *sp42Skeleton_findIkConstraint(const sp42Skeleton *self, const char *constraintName);

/* Returns 0 if the transform constraint was not found. */
SP_API sp42TransformConstraint *sp42Skeleton_findTransformConstraint(const sp42Skeleton *self, const char *constraintName);

/* Returns 0 if the path constraint was not found. */
SP_API sp42PathConstraint *sp42Skeleton_findPathConstraint(const sp42Skeleton *self, const char *constraintName);

/* Returns 0 if the physics constraint was not found. */
SP_API sp42PhysicsConstraint *sp42Skeleton_findPhysicsConstraint(const sp42Skeleton *self, const char *constraintName);

SP_API void sp42Skeleton_physicsTranslate(sp42Skeleton *self, float x, float y);

SP_API void sp42Skeleton_physicsRotate(sp42Skeleton *self, float x, float y, float degrees);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETON_H_*/

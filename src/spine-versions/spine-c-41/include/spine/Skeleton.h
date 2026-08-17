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

#ifndef SPINE_SKELETON_H_
#define SPINE_SKELETON_H_

#include <spine/dll.h>
#include <spine/SkeletonData.h>
#include <spine/Slot.h>
#include <spine/Skin.h>
#include <spine/IkConstraint.h>
#include <spine/TransformConstraint.h>
#include <spine/PathConstraint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp41Skeleton {
	sp41SkeletonData *const data;

	int bonesCount;
	sp41Bone **bones;
	sp41Bone *const root;

	int slotsCount;
	sp41Slot **slots;
	sp41Slot **drawOrder;

	int ikConstraintsCount;
	sp41IkConstraint **ikConstraints;

	int transformConstraintsCount;
	sp41TransformConstraint **transformConstraints;

	int pathConstraintsCount;
	sp41PathConstraint **pathConstraints;

	sp41Skin *const skin;
	sp41Color color;
	float scaleX, scaleY;
	float x, y;
} sp41Skeleton;

SP_API sp41Skeleton *sp41Skeleton_create(sp41SkeletonData *data);

SP_API void sp41Skeleton_dispose(sp41Skeleton *self);

/* Caches information about bones and constraints. Must be called if bones or constraints, or weighted path attachments
 * are added or removed. */
SP_API void sp41Skeleton_updateCache(sp41Skeleton *self);

SP_API void sp41Skeleton_updateWorldTransform(const sp41Skeleton *self);

/* Sets the bones, constraints, and slots to their setup pose values. */
SP_API void sp41Skeleton_setToSetupPose(const sp41Skeleton *self);
/* Sets the bones and constraints to their setup pose values. */
SP_API void sp41Skeleton_setBonesToSetupPose(const sp41Skeleton *self);

SP_API void sp41Skeleton_setSlotsToSetupPose(const sp41Skeleton *self);

/* Returns 0 if the bone was not found. */
SP_API sp41Bone *sp41Skeleton_findBone(const sp41Skeleton *self, const char *boneName);

/* Returns 0 if the slot was not found. */
SP_API sp41Slot *sp41Skeleton_findSlot(const sp41Skeleton *self, const char *slotName);

/* Sets the skin used to look up attachments before looking in the SkeletonData defaultSkin. Attachments from the new skin are
 * attached if the corresponding attachment from the old skin was attached. If there was no old skin, each slot's setup mode
 * attachment is attached from the new skin.
 * @param skin May be 0.*/
SP_API void sp41Skeleton_setSkin(sp41Skeleton *self, sp41Skin *skin);
/* Returns 0 if the skin was not found. See sp41Skeleton_setSkin.
 * @param skinName May be 0. */
SP_API int sp41Skeleton_setSkinByName(sp41Skeleton *self, const char *skinName);

/* Returns 0 if the slot or attachment was not found. */
SP_API sp41Attachment *
sp41Skeleton_getAttachmentForSlotName(const sp41Skeleton *self, const char *slotName, const char *attachmentName);
/* Returns 0 if the slot or attachment was not found. */
SP_API sp41Attachment *
sp41Skeleton_getAttachmentForSlotIndex(const sp41Skeleton *self, int slotIndex, const char *attachmentName);
/* Returns 0 if the slot or attachment was not found.
 * @param attachmentName May be 0. */
SP_API int sp41Skeleton_setAttachment(sp41Skeleton *self, const char *slotName, const char *attachmentName);

/* Returns 0 if the IK constraint was not found. */
SP_API sp41IkConstraint *sp41Skeleton_findIkConstraint(const sp41Skeleton *self, const char *constraintName);

/* Returns 0 if the transform constraint was not found. */
SP_API sp41TransformConstraint *sp41Skeleton_findTransformConstraint(const sp41Skeleton *self, const char *constraintName);

/* Returns 0 if the path constraint was not found. */
SP_API sp41PathConstraint *sp41Skeleton_findPathConstraint(const sp41Skeleton *self, const char *constraintName);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETON_H_*/

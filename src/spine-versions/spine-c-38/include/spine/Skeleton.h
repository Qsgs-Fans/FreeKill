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

typedef struct sp38Skeleton {
	sp38SkeletonData* const data;

	int bonesCount;
	sp38Bone** bones;
	sp38Bone* const root;

	int slotsCount;
	sp38Slot** slots;
	sp38Slot** drawOrder;

	int ikConstraintsCount;
	sp38IkConstraint** ikConstraints;

	int transformConstraintsCount;
	sp38TransformConstraint** transformConstraints;

	int pathConstraintsCount;
	sp38PathConstraint** pathConstraints;

	sp38Skin* const skin;
	sp38Color color;
	float time;
	float scaleX, scaleY;
	float x, y;

#ifdef __cplusplus
	sp38Skeleton() :
		data(0),
		bonesCount(0),
		bones(0),
		root(0),
		slotsCount(0),
		slots(0),
		drawOrder(0),

		ikConstraintsCount(0),
		ikConstraints(0),

		transformConstraintsCount(0),
		transformConstraints(0),

		skin(0),
		color(),
		time(0),
		scaleX(1),
		scaleY(1),
		x(0), y(0) {
	}
#endif
} sp38Skeleton;

SP_API sp38Skeleton* sp38Skeleton_create (sp38SkeletonData* data);
SP_API void sp38Skeleton_dispose (sp38Skeleton* self);

/* Caches information about bones and constraints. Must be called if bones or constraints, or weighted path attachments
 * are added or removed. */
SP_API void sp38Skeleton_updateCache (sp38Skeleton* self);
SP_API void sp38Skeleton_updateWorldTransform (const sp38Skeleton* self);

/* Sets the bones, constraints, and slots to their setup pose values. */
SP_API void sp38Skeleton_setToSetupPose (const sp38Skeleton* self);
/* Sets the bones and constraints to their setup pose values. */
SP_API void sp38Skeleton_setBonesToSetupPose (const sp38Skeleton* self);
SP_API void sp38Skeleton_setSlotsToSetupPose (const sp38Skeleton* self);

/* Returns 0 if the bone was not found. */
SP_API sp38Bone* sp38Skeleton_findBone (const sp38Skeleton* self, const char* boneName);
/* Returns -1 if the bone was not found. */
SP_API int sp38Skeleton_findBoneIndex (const sp38Skeleton* self, const char* boneName);

/* Returns 0 if the slot was not found. */
SP_API sp38Slot* sp38Skeleton_findSlot (const sp38Skeleton* self, const char* slotName);
/* Returns -1 if the slot was not found. */
SP_API int sp38Skeleton_findSlotIndex (const sp38Skeleton* self, const char* slotName);

/* Sets the skin used to look up attachments before looking in the SkeletonData defaultSkin. Attachments from the new skin are
 * attached if the corresponding attachment from the old skin was attached. If there was no old skin, each slot's setup mode
 * attachment is attached from the new skin.
 * @param skin May be 0.*/
SP_API void sp38Skeleton_setSkin (sp38Skeleton* self, sp38Skin* skin);
/* Returns 0 if the skin was not found. See sp38Skeleton_setSkin.
 * @param skinName May be 0. */
SP_API int sp38Skeleton_setSkinByName (sp38Skeleton* self, const char* skinName);

/* Returns 0 if the slot or attachment was not found. */
SP_API sp38Attachment* sp38Skeleton_getAttachmentForSlotName (const sp38Skeleton* self, const char* slotName, const char* attachmentName);
/* Returns 0 if the slot or attachment was not found. */
SP_API sp38Attachment* sp38Skeleton_getAttachmentForSlotIndex (const sp38Skeleton* self, int slotIndex, const char* attachmentName);
/* Returns 0 if the slot or attachment was not found.
 * @param attachmentName May be 0. */
SP_API int sp38Skeleton_setAttachment (sp38Skeleton* self, const char* slotName, const char* attachmentName);

/* Returns 0 if the IK constraint was not found. */
SP_API sp38IkConstraint* sp38Skeleton_findIkConstraint (const sp38Skeleton* self, const char* constraintName);

/* Returns 0 if the transform constraint was not found. */
SP_API sp38TransformConstraint* sp38Skeleton_findTransformConstraint (const sp38Skeleton* self, const char* constraintName);

/* Returns 0 if the path constraint was not found. */
SP_API sp38PathConstraint* sp38Skeleton_findPathConstraint (const sp38Skeleton* self, const char* constraintName);

SP_API void sp38Skeleton_update (sp38Skeleton* self, float deltaTime);

#ifdef SPINE_SHORT_NAMES
typedef sp38Skeleton Skeleton;
#define Skeleton_create(...) sp38Skeleton_create(__VA_ARGS__)
#define Skeleton_dispose(...) sp38Skeleton_dispose(__VA_ARGS__)
#define Skeleton_updateWorldTransform(...) sp38Skeleton_updateWorldTransform(__VA_ARGS__)
#define Skeleton_setToSetupPose(...) sp38Skeleton_setToSetupPose(__VA_ARGS__)
#define Skeleton_setBonesToSetupPose(...) sp38Skeleton_setBonesToSetupPose(__VA_ARGS__)
#define Skeleton_setSlotsToSetupPose(...) sp38Skeleton_setSlotsToSetupPose(__VA_ARGS__)
#define Skeleton_findBone(...) sp38Skeleton_findBone(__VA_ARGS__)
#define Skeleton_findBoneIndex(...) sp38Skeleton_findBoneIndex(__VA_ARGS__)
#define Skeleton_findSlot(...) sp38Skeleton_findSlot(__VA_ARGS__)
#define Skeleton_findSlotIndex(...) sp38Skeleton_findSlotIndex(__VA_ARGS__)
#define Skeleton_setSkin(...) sp38Skeleton_setSkin(__VA_ARGS__)
#define Skeleton_setSkinByName(...) sp38Skeleton_setSkinByName(__VA_ARGS__)
#define Skeleton_getAttachmentForSlotName(...) sp38Skeleton_getAttachmentForSlotName(__VA_ARGS__)
#define Skeleton_getAttachmentForSlotIndex(...) sp38Skeleton_getAttachmentForSlotIndex(__VA_ARGS__)
#define Skeleton_setAttachment(...) sp38Skeleton_setAttachment(__VA_ARGS__)
#define Skeleton_update(...) sp38Skeleton_update(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETON_H_*/

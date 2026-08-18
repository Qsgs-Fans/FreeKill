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

typedef struct sp37Skeleton {
	sp37SkeletonData* const data;

	int bonesCount;
	sp37Bone** bones;
	sp37Bone* const root;

	int slotsCount;
	sp37Slot** slots;
	sp37Slot** drawOrder;

	int ikConstraintsCount;
	sp37IkConstraint** ikConstraints;

	int transformConstraintsCount;
	sp37TransformConstraint** transformConstraints;

	int pathConstraintsCount;
	sp37PathConstraint** pathConstraints;

	sp37Skin* const skin;
	sp37Color color;
	float time;
	float scaleX, scaleY;
	float x, y;

#ifdef __cplusplus
	sp37Skeleton() :
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
} sp37Skeleton;

SP_API sp37Skeleton* sp37Skeleton_create (sp37SkeletonData* data);
SP_API void sp37Skeleton_dispose (sp37Skeleton* self);

/* Caches information about bones and constraints. Must be called if bones or constraints, or weighted path attachments
 * are added or removed. */
SP_API void sp37Skeleton_updateCache (sp37Skeleton* self);
SP_API void sp37Skeleton_updateWorldTransform (const sp37Skeleton* self);

/* Sets the bones, constraints, and slots to their setup pose values. */
SP_API void sp37Skeleton_setToSetupPose (const sp37Skeleton* self);
/* Sets the bones and constraints to their setup pose values. */
SP_API void sp37Skeleton_setBonesToSetupPose (const sp37Skeleton* self);
SP_API void sp37Skeleton_setSlotsToSetupPose (const sp37Skeleton* self);

/* Returns 0 if the bone was not found. */
SP_API sp37Bone* sp37Skeleton_findBone (const sp37Skeleton* self, const char* boneName);
/* Returns -1 if the bone was not found. */
SP_API int sp37Skeleton_findBoneIndex (const sp37Skeleton* self, const char* boneName);

/* Returns 0 if the slot was not found. */
SP_API sp37Slot* sp37Skeleton_findSlot (const sp37Skeleton* self, const char* slotName);
/* Returns -1 if the slot was not found. */
SP_API int sp37Skeleton_findSlotIndex (const sp37Skeleton* self, const char* slotName);

/* Sets the skin used to look up attachments before looking in the SkeletonData defaultSkin. Attachments from the new skin are
 * attached if the corresponding attachment from the old skin was attached. If there was no old skin, each slot's setup mode
 * attachment is attached from the new skin.
 * @param skin May be 0.*/
SP_API void sp37Skeleton_setSkin (sp37Skeleton* self, sp37Skin* skin);
/* Returns 0 if the skin was not found. See sp37Skeleton_setSkin.
 * @param skinName May be 0. */
SP_API int sp37Skeleton_setSkinByName (sp37Skeleton* self, const char* skinName);

/* Returns 0 if the slot or attachment was not found. */
SP_API sp37Attachment* sp37Skeleton_getAttachmentForSlotName (const sp37Skeleton* self, const char* slotName, const char* attachmentName);
/* Returns 0 if the slot or attachment was not found. */
SP_API sp37Attachment* sp37Skeleton_getAttachmentForSlotIndex (const sp37Skeleton* self, int slotIndex, const char* attachmentName);
/* Returns 0 if the slot or attachment was not found.
 * @param attachmentName May be 0. */
SP_API int sp37Skeleton_setAttachment (sp37Skeleton* self, const char* slotName, const char* attachmentName);

/* Returns 0 if the IK constraint was not found. */
SP_API sp37IkConstraint* sp37Skeleton_findIkConstraint (const sp37Skeleton* self, const char* constraintName);

/* Returns 0 if the transform constraint was not found. */
SP_API sp37TransformConstraint* sp37Skeleton_findTransformConstraint (const sp37Skeleton* self, const char* constraintName);

/* Returns 0 if the path constraint was not found. */
SP_API sp37PathConstraint* sp37Skeleton_findPathConstraint (const sp37Skeleton* self, const char* constraintName);

SP_API void sp37Skeleton_update (sp37Skeleton* self, float deltaTime);

#ifdef SPINE_SHORT_NAMES
typedef sp37Skeleton Skeleton;
#define Skeleton_create(...) sp37Skeleton_create(__VA_ARGS__)
#define Skeleton_dispose(...) sp37Skeleton_dispose(__VA_ARGS__)
#define Skeleton_updateWorldTransform(...) sp37Skeleton_updateWorldTransform(__VA_ARGS__)
#define Skeleton_setToSetupPose(...) sp37Skeleton_setToSetupPose(__VA_ARGS__)
#define Skeleton_setBonesToSetupPose(...) sp37Skeleton_setBonesToSetupPose(__VA_ARGS__)
#define Skeleton_setSlotsToSetupPose(...) sp37Skeleton_setSlotsToSetupPose(__VA_ARGS__)
#define Skeleton_findBone(...) sp37Skeleton_findBone(__VA_ARGS__)
#define Skeleton_findBoneIndex(...) sp37Skeleton_findBoneIndex(__VA_ARGS__)
#define Skeleton_findSlot(...) sp37Skeleton_findSlot(__VA_ARGS__)
#define Skeleton_findSlotIndex(...) sp37Skeleton_findSlotIndex(__VA_ARGS__)
#define Skeleton_setSkin(...) sp37Skeleton_setSkin(__VA_ARGS__)
#define Skeleton_setSkinByName(...) sp37Skeleton_setSkinByName(__VA_ARGS__)
#define Skeleton_getAttachmentForSlotName(...) sp37Skeleton_getAttachmentForSlotName(__VA_ARGS__)
#define Skeleton_getAttachmentForSlotIndex(...) sp37Skeleton_getAttachmentForSlotIndex(__VA_ARGS__)
#define Skeleton_setAttachment(...) sp37Skeleton_setAttachment(__VA_ARGS__)
#define Skeleton_update(...) sp37Skeleton_update(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETON_H_*/

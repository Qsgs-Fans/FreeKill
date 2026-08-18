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

typedef struct sp36Skeleton {
	sp36SkeletonData* const data;

	int bonesCount;
	sp36Bone** bones;
	sp36Bone* const root;

	int slotsCount;
	sp36Slot** slots;
	sp36Slot** drawOrder;

	int ikConstraintsCount;
	sp36IkConstraint** ikConstraints;

	int transformConstraintsCount;
	sp36TransformConstraint** transformConstraints;

	int pathConstraintsCount;
	sp36PathConstraint** pathConstraints;

	sp36Skin* const skin;
	sp36Color color;
	float time;
	int/*bool*/flipX, flipY;
	float x, y;

#ifdef __cplusplus
	sp36Skeleton() :
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
		flipX(0),
		flipY(0),
		x(0), y(0) {
	}
#endif
} sp36Skeleton;

SP_API sp36Skeleton* sp36Skeleton_create (sp36SkeletonData* data);
SP_API void sp36Skeleton_dispose (sp36Skeleton* self);

/* Caches information about bones and constraints. Must be called if bones or constraints, or weighted path attachments
 * are added or removed. */
SP_API void sp36Skeleton_updateCache (sp36Skeleton* self);
SP_API void sp36Skeleton_updateWorldTransform (const sp36Skeleton* self);

/* Sets the bones, constraints, and slots to their setup pose values. */
SP_API void sp36Skeleton_setToSetupPose (const sp36Skeleton* self);
/* Sets the bones and constraints to their setup pose values. */
SP_API void sp36Skeleton_setBonesToSetupPose (const sp36Skeleton* self);
SP_API void sp36Skeleton_setSlotsToSetupPose (const sp36Skeleton* self);

/* Returns 0 if the bone was not found. */
SP_API sp36Bone* sp36Skeleton_findBone (const sp36Skeleton* self, const char* boneName);
/* Returns -1 if the bone was not found. */
SP_API int sp36Skeleton_findBoneIndex (const sp36Skeleton* self, const char* boneName);

/* Returns 0 if the slot was not found. */
SP_API sp36Slot* sp36Skeleton_findSlot (const sp36Skeleton* self, const char* slotName);
/* Returns -1 if the slot was not found. */
SP_API int sp36Skeleton_findSlotIndex (const sp36Skeleton* self, const char* slotName);

/* Sets the skin used to look up attachments before looking in the SkeletonData defaultSkin. Attachments from the new skin are
 * attached if the corresponding attachment from the old skin was attached. If there was no old skin, each slot's setup mode
 * attachment is attached from the new skin.
 * @param skin May be 0.*/
SP_API void sp36Skeleton_setSkin (sp36Skeleton* self, sp36Skin* skin);
/* Returns 0 if the skin was not found. See sp36Skeleton_setSkin.
 * @param skinName May be 0. */
SP_API int sp36Skeleton_setSkinByName (sp36Skeleton* self, const char* skinName);

/* Returns 0 if the slot or attachment was not found. */
SP_API sp36Attachment* sp36Skeleton_getAttachmentForSlotName (const sp36Skeleton* self, const char* slotName, const char* attachmentName);
/* Returns 0 if the slot or attachment was not found. */
SP_API sp36Attachment* sp36Skeleton_getAttachmentForSlotIndex (const sp36Skeleton* self, int slotIndex, const char* attachmentName);
/* Returns 0 if the slot or attachment was not found.
 * @param attachmentName May be 0. */
SP_API int sp36Skeleton_setAttachment (sp36Skeleton* self, const char* slotName, const char* attachmentName);

/* Returns 0 if the IK constraint was not found. */
SP_API sp36IkConstraint* sp36Skeleton_findIkConstraint (const sp36Skeleton* self, const char* constraintName);

/* Returns 0 if the transform constraint was not found. */
SP_API sp36TransformConstraint* sp36Skeleton_findTransformConstraint (const sp36Skeleton* self, const char* constraintName);

/* Returns 0 if the path constraint was not found. */
SP_API sp36PathConstraint* sp36Skeleton_findPathConstraint (const sp36Skeleton* self, const char* constraintName);

SP_API void sp36Skeleton_update (sp36Skeleton* self, float deltaTime);

#ifdef SPINE_SHORT_NAMES
typedef sp36Skeleton Skeleton;
#define Skeleton_create(...) sp36Skeleton_create(__VA_ARGS__)
#define Skeleton_dispose(...) sp36Skeleton_dispose(__VA_ARGS__)
#define Skeleton_updateWorldTransform(...) sp36Skeleton_updateWorldTransform(__VA_ARGS__)
#define Skeleton_setToSetupPose(...) sp36Skeleton_setToSetupPose(__VA_ARGS__)
#define Skeleton_setBonesToSetupPose(...) sp36Skeleton_setBonesToSetupPose(__VA_ARGS__)
#define Skeleton_setSlotsToSetupPose(...) sp36Skeleton_setSlotsToSetupPose(__VA_ARGS__)
#define Skeleton_findBone(...) sp36Skeleton_findBone(__VA_ARGS__)
#define Skeleton_findBoneIndex(...) sp36Skeleton_findBoneIndex(__VA_ARGS__)
#define Skeleton_findSlot(...) sp36Skeleton_findSlot(__VA_ARGS__)
#define Skeleton_findSlotIndex(...) sp36Skeleton_findSlotIndex(__VA_ARGS__)
#define Skeleton_setSkin(...) sp36Skeleton_setSkin(__VA_ARGS__)
#define Skeleton_setSkinByName(...) sp36Skeleton_setSkinByName(__VA_ARGS__)
#define Skeleton_getAttachmentForSlotName(...) sp36Skeleton_getAttachmentForSlotName(__VA_ARGS__)
#define Skeleton_getAttachmentForSlotIndex(...) sp36Skeleton_getAttachmentForSlotIndex(__VA_ARGS__)
#define Skeleton_setAttachment(...) sp36Skeleton_setAttachment(__VA_ARGS__)
#define Skeleton_update(...) sp36Skeleton_update(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETON_H_*/

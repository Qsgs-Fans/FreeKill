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

#include <spine/SkeletonData.h>
#include <spine/Slot.h>
#include <spine/Skin.h>
#include <spine/IkConstraint.h>
#include <spine/TransformConstraint.h>
#include <spine/PathConstraint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp34Skeleton {
	sp34SkeletonData* const data;

	int bonesCount;
	sp34Bone** bones;
	sp34Bone* const root;

	int slotsCount;
	sp34Slot** slots;
	sp34Slot** drawOrder;

	int ikConstraintsCount;
	sp34IkConstraint** ikConstraints;
	sp34IkConstraint** ikConstraintsSorted;

	int transformConstraintsCount;
	sp34TransformConstraint** transformConstraints;

	int pathConstraintsCount;
	sp34PathConstraint** pathConstraints;

	sp34Skin* const skin;
	float r, g, b, a;
	float time;
	int/*bool*/flipX, flipY;
	float x, y;

#ifdef __cplusplus
	sp34Skeleton() :
		data(0),
		bonesCount(0),
		bones(0),
		root(0),
		slotsCount(0),
		slots(0),
		drawOrder(0),

		ikConstraintsCount(0),
		ikConstraints(0),
		ikConstraintsSorted(0),

		transformConstraintsCount(0),
		transformConstraints(0),

		skin(0),
		r(0), g(0), b(0), a(0),
		time(0),
		flipX(0),
		flipY(0),
		x(0), y(0) {
	}
#endif
} sp34Skeleton;

sp34Skeleton* sp34Skeleton_create (sp34SkeletonData* data);
void sp34Skeleton_dispose (sp34Skeleton* self);

/* Caches information about bones and constraints. Must be called if bones or constraints, or weighted path attachments
 * are added or removed. */
void sp34Skeleton_updateCache (sp34Skeleton* self);
void sp34Skeleton_updateWorldTransform (const sp34Skeleton* self);

/* Sets the bones, constraints, and slots to their setup pose values. */
void sp34Skeleton_setToSetupPose (const sp34Skeleton* self);
/* Sets the bones and constraints to their setup pose values. */
void sp34Skeleton_setBonesToSetupPose (const sp34Skeleton* self);
void sp34Skeleton_setSlotsToSetupPose (const sp34Skeleton* self);

/* Returns 0 if the bone was not found. */
sp34Bone* sp34Skeleton_findBone (const sp34Skeleton* self, const char* boneName);
/* Returns -1 if the bone was not found. */
int sp34Skeleton_findBoneIndex (const sp34Skeleton* self, const char* boneName);

/* Returns 0 if the slot was not found. */
sp34Slot* sp34Skeleton_findSlot (const sp34Skeleton* self, const char* slotName);
/* Returns -1 if the slot was not found. */
int sp34Skeleton_findSlotIndex (const sp34Skeleton* self, const char* slotName);

/* Sets the skin used to look up attachments before looking in the SkeletonData defaultSkin. Attachments from the new skin are
 * attached if the corresponding attachment from the old skin was attached. If there was no old skin, each slot's setup mode
 * attachment is attached from the new skin.
 * @param skin May be 0.*/
void sp34Skeleton_setSkin (sp34Skeleton* self, sp34Skin* skin);
/* Returns 0 if the skin was not found. See sp34Skeleton_setSkin.
 * @param skinName May be 0. */
int sp34Skeleton_setSkinByName (sp34Skeleton* self, const char* skinName);

/* Returns 0 if the slot or attachment was not found. */
sp34Attachment* sp34Skeleton_getAttachmentForSlotName (const sp34Skeleton* self, const char* slotName, const char* attachmentName);
/* Returns 0 if the slot or attachment was not found. */
sp34Attachment* sp34Skeleton_getAttachmentForSlotIndex (const sp34Skeleton* self, int slotIndex, const char* attachmentName);
/* Returns 0 if the slot or attachment was not found.
 * @param attachmentName May be 0. */
int sp34Skeleton_setAttachment (sp34Skeleton* self, const char* slotName, const char* attachmentName);

/* Returns 0 if the IK constraint was not found. */
sp34IkConstraint* sp34Skeleton_findIkConstraint (const sp34Skeleton* self, const char* constraintName);

/* Returns 0 if the transform constraint was not found. */
sp34TransformConstraint* sp34Skeleton_findTransformConstraint (const sp34Skeleton* self, const char* constraintName);

/* Returns 0 if the path constraint was not found. */
sp34PathConstraint* sp34Skeleton_findPathConstraint (const sp34Skeleton* self, const char* constraintName);

void sp34Skeleton_update (sp34Skeleton* self, float deltaTime);

#ifdef SPINE_SHORT_NAMES
typedef sp34Skeleton Skeleton;
#define Skeleton_create(...) sp34Skeleton_create(__VA_ARGS__)
#define Skeleton_dispose(...) sp34Skeleton_dispose(__VA_ARGS__)
#define Skeleton_updateWorldTransform(...) sp34Skeleton_updateWorldTransform(__VA_ARGS__)
#define Skeleton_setToSetupPose(...) sp34Skeleton_setToSetupPose(__VA_ARGS__)
#define Skeleton_setBonesToSetupPose(...) sp34Skeleton_setBonesToSetupPose(__VA_ARGS__)
#define Skeleton_setSlotsToSetupPose(...) sp34Skeleton_setSlotsToSetupPose(__VA_ARGS__)
#define Skeleton_findBone(...) sp34Skeleton_findBone(__VA_ARGS__)
#define Skeleton_findBoneIndex(...) sp34Skeleton_findBoneIndex(__VA_ARGS__)
#define Skeleton_findSlot(...) sp34Skeleton_findSlot(__VA_ARGS__)
#define Skeleton_findSlotIndex(...) sp34Skeleton_findSlotIndex(__VA_ARGS__)
#define Skeleton_setSkin(...) sp34Skeleton_setSkin(__VA_ARGS__)
#define Skeleton_setSkinByName(...) sp34Skeleton_setSkinByName(__VA_ARGS__)
#define Skeleton_getAttachmentForSlotName(...) sp34Skeleton_getAttachmentForSlotName(__VA_ARGS__)
#define Skeleton_getAttachmentForSlotIndex(...) sp34Skeleton_getAttachmentForSlotIndex(__VA_ARGS__)
#define Skeleton_setAttachment(...) sp34Skeleton_setAttachment(__VA_ARGS__)
#define Skeleton_update(...) sp34Skeleton_update(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETON_H_*/

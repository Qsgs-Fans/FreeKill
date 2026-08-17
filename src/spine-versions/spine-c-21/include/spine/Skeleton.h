/******************************************************************************
 * Spine Runtimes Software License
 * Version 2.1
 * 
 * Copyright (c) 2013, Esoteric Software
 * All rights reserved.
 * 
 * You are granted a perpetual, non-exclusive, non-sublicensable and
 * non-transferable license to install, execute and perform the Spine Runtimes
 * Software (the "Software") solely for internal use. Without the written
 * permission of Esoteric Software (typically granted by licensing Spine), you
 * may not (a) modify, translate, adapt or otherwise create derivative works,
 * improvements of the Software or develop new applications using the Software
 * or (b) remove, delete, alter or obscure any trademarks or any copyright,
 * trademark, patent or other intellectual property or proprietary rights
 * notices on or in the Software, including any copy thereof. Redistributions
 * in binary or source form must include this license and terms.
 * 
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#ifndef SPINE_SKELETON_H_
#define SPINE_SKELETON_H_

#include <spine/SkeletonData.h>
#include <spine/Slot.h>
#include <spine/Skin.h>
#include <spine/IkConstraint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp21Skeleton {
	sp21SkeletonData* const data;

	int bonesCount;
	sp21Bone** bones;
	sp21Bone* const root;

	int slotsCount;
	sp21Slot** slots;
	sp21Slot** drawOrder;

	int ikConstraintsCount;
	sp21IkConstraint** ikConstraints;

	sp21Skin* const skin;
	float r, g, b, a;
	float time;
	int/*bool*/flipX, flipY;
	float x, y;

#ifdef __cplusplus
	sp21Skeleton() :
		data(0),
		bonesCount(0),
		bones(0),
		root(0),
		slotsCount(0),
		slots(0),
		drawOrder(0),

		ikConstraintsCount(0),
		ikConstraints(0),

		skin(0),
		r(0), g(0), b(0), a(0),
		time(0),
		flipX(0),
		flipY(0),
		x(0), y(0) {
	}
#endif
} sp21Skeleton;

sp21Skeleton* sp21Skeleton_create (sp21SkeletonData* data);
void sp21Skeleton_dispose (sp21Skeleton* self);

/* Caches information about bones and IK constraints. Must be called if bones or IK constraints are added or removed. */
void sp21Skeleton_updateCache (const sp21Skeleton* self);
void sp21Skeleton_updateWorldTransform (const sp21Skeleton* self);

void sp21Skeleton_setToSetupPose (const sp21Skeleton* self);
void sp21Skeleton_setBonesToSetupPose (const sp21Skeleton* self);
void sp21Skeleton_setSlotsToSetupPose (const sp21Skeleton* self);

/* Returns 0 if the bone was not found. */
sp21Bone* sp21Skeleton_findBone (const sp21Skeleton* self, const char* boneName);
/* Returns -1 if the bone was not found. */
int sp21Skeleton_findBoneIndex (const sp21Skeleton* self, const char* boneName);

/* Returns 0 if the slot was not found. */
sp21Slot* sp21Skeleton_findSlot (const sp21Skeleton* self, const char* slotName);
/* Returns -1 if the slot was not found. */
int sp21Skeleton_findSlotIndex (const sp21Skeleton* self, const char* slotName);

/* Sets the skin used to look up attachments before looking in the SkeletonData defaultSkin. Attachments from the new skin are
 * attached if the corresponding attachment from the old skin was attached. If there was no old skin, each slot's setup mode
 * attachment is attached from the new skin.
 * @param skin May be 0.*/
void sp21Skeleton_setSkin (sp21Skeleton* self, sp21Skin* skin);
/* Returns 0 if the skin was not found. See sp21Skeleton_setSkin.
 * @param skinName May be 0. */
int sp21Skeleton_setSkinByName (sp21Skeleton* self, const char* skinName);

/* Returns 0 if the slot or attachment was not found. */
sp21Attachment* sp21Skeleton_getAttachmentForSlotName (const sp21Skeleton* self, const char* slotName, const char* attachmentName);
/* Returns 0 if the slot or attachment was not found. */
sp21Attachment* sp21Skeleton_getAttachmentForSlotIndex (const sp21Skeleton* self, int slotIndex, const char* attachmentName);
/* Returns 0 if the slot or attachment was not found.
 * @param attachmentName May be 0. */
int sp21Skeleton_setAttachment (sp21Skeleton* self, const char* slotName, const char* attachmentName);

/* Returns 0 if the IK constraint was not found. */
sp21IkConstraint* sp21Skeleton_findIkConstraint (const sp21Skeleton* self, const char* ikConstraintName);

void sp21Skeleton_update (sp21Skeleton* self, float deltaTime);

#ifdef SPINE_SHORT_NAMES
typedef sp21Skeleton Skeleton;
#define Skeleton_create(...) sp21Skeleton_create(__VA_ARGS__)
#define Skeleton_dispose(...) sp21Skeleton_dispose(__VA_ARGS__)
#define Skeleton_updateWorldTransform(...) sp21Skeleton_updateWorldTransform(__VA_ARGS__)
#define Skeleton_setToSetupPose(...) sp21Skeleton_setToSetupPose(__VA_ARGS__)
#define Skeleton_setBonesToSetupPose(...) sp21Skeleton_setBonesToSetupPose(__VA_ARGS__)
#define Skeleton_setSlotsToSetupPose(...) sp21Skeleton_setSlotsToSetupPose(__VA_ARGS__)
#define Skeleton_findBone(...) sp21Skeleton_findBone(__VA_ARGS__)
#define Skeleton_findBoneIndex(...) sp21Skeleton_findBoneIndex(__VA_ARGS__)
#define Skeleton_findSlot(...) sp21Skeleton_findSlot(__VA_ARGS__)
#define Skeleton_findSlotIndex(...) sp21Skeleton_findSlotIndex(__VA_ARGS__)
#define Skeleton_setSkin(...) sp21Skeleton_setSkin(__VA_ARGS__)
#define Skeleton_setSkinByName(...) sp21Skeleton_setSkinByName(__VA_ARGS__)
#define Skeleton_getAttachmentForSlotName(...) sp21Skeleton_getAttachmentForSlotName(__VA_ARGS__)
#define Skeleton_getAttachmentForSlotIndex(...) sp21Skeleton_getAttachmentForSlotIndex(__VA_ARGS__)
#define Skeleton_setAttachment(...) sp21Skeleton_setAttachment(__VA_ARGS__)
#define Skeleton_update(...) sp21Skeleton_update(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETON_H_*/

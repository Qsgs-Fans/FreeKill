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

#include <spine/Skeleton.h>
#include <string.h>
#include <spine/extension.h>

typedef struct {
	sp21Skeleton super;

	int boneCacheCount;
	int* boneCacheCounts;
	sp21Bone*** boneCache;
} _sp21Skeleton;

sp21Skeleton* sp21Skeleton_create (sp21SkeletonData* data) {
	int i, ii;

	_sp21Skeleton* internal = NEW(_sp21Skeleton);
	sp21Skeleton* self = SUPER(internal);
	CONST_CAST(sp21SkeletonData*, self->data) = data;

	self->bonesCount = self->data->bonesCount;
	self->bones = MALLOC(sp21Bone*, self->bonesCount);

	for (i = 0; i < self->bonesCount; ++i) {
		sp21BoneData* boneData = self->data->bones[i];
		sp21Bone* parent = 0;
		if (boneData->parent) {
			/* Find parent bone. */
			for (ii = 0; ii < self->bonesCount; ++ii) {
				if (data->bones[ii] == boneData->parent) {
					parent = self->bones[ii];
					break;
				}
			}
		}
		self->bones[i] = sp21Bone_create(boneData, self, parent);
	}
	CONST_CAST(sp21Bone*, self->root) = self->bones[0];

	self->slotsCount = data->slotsCount;
	self->slots = MALLOC(sp21Slot*, self->slotsCount);
	for (i = 0; i < self->slotsCount; ++i) {
		sp21SlotData *slotData = data->slots[i];

		/* Find bone for the slotData's boneData. */
		sp21Bone* bone = 0;
		for (ii = 0; ii < self->bonesCount; ++ii) {
			if (data->bones[ii] == slotData->boneData) {
				bone = self->bones[ii];
				break;
			}
		}
		self->slots[i] = sp21Slot_create(slotData, bone);
	}

	self->drawOrder = MALLOC(sp21Slot*, self->slotsCount);
	memcpy(self->drawOrder, self->slots, sizeof(sp21Slot*) * self->slotsCount);

	self->r = 1;
	self->g = 1;
	self->b = 1;
	self->a = 1;

	self->ikConstraintsCount = data->ikConstraintsCount;
	self->ikConstraints = MALLOC(sp21IkConstraint*, self->ikConstraintsCount);
	for (i = 0; i < self->data->ikConstraintsCount; ++i)
		self->ikConstraints[i] = sp21IkConstraint_create(self->data->ikConstraints[i], self);

	sp21Skeleton_updateCache(self);

	return self;
}

void sp21Skeleton_dispose (sp21Skeleton* self) {
	int i;
	_sp21Skeleton* internal = SUB_CAST(_sp21Skeleton, self);

	for (i = 0; i < internal->boneCacheCount; ++i)
		FREE(internal->boneCache[i]);
	FREE(internal->boneCache);
	FREE(internal->boneCacheCounts);

	for (i = 0; i < self->bonesCount; ++i)
		sp21Bone_dispose(self->bones[i]);
	FREE(self->bones);

	for (i = 0; i < self->slotsCount; ++i)
		sp21Slot_dispose(self->slots[i]);
	FREE(self->slots);

	for (i = 0; i < self->ikConstraintsCount; ++i)
		sp21IkConstraint_dispose(self->ikConstraints[i]);
	FREE(self->ikConstraints);

	FREE(self->drawOrder);
	FREE(self);
}

void sp21Skeleton_updateCache (const sp21Skeleton* self) {
	int i, ii;
	_sp21Skeleton* internal = SUB_CAST(_sp21Skeleton, self);

	for (i = 0; i < internal->boneCacheCount; ++i)
		FREE(internal->boneCache[i]);
	FREE(internal->boneCache);
	FREE(internal->boneCacheCounts);

	internal->boneCacheCount = self->ikConstraintsCount + 1;
	internal->boneCache = MALLOC(sp21Bone**, internal->boneCacheCount);
	internal->boneCacheCounts = CALLOC(int, internal->boneCacheCount);

	/* Compute array sizes. */
	for (i = 0; i < self->bonesCount; ++i) {
		sp21Bone* current = self->bones[i];
		do {
			for (ii = 0; ii < self->ikConstraintsCount; ++ii) {
				sp21IkConstraint* ikConstraint = self->ikConstraints[ii];
				sp21Bone* parent = ikConstraint->bones[0];
				sp21Bone* child = ikConstraint->bones[ikConstraint->bonesCount - 1];
				while (1) {
					if (current == child) {
						internal->boneCacheCounts[ii]++;
						internal->boneCacheCounts[ii + 1]++;
						goto outer1;
					}
					if (child == parent) break;
					child = child->parent;
				}
			}
			current = current->parent;
		} while (current);
		internal->boneCacheCounts[0]++;
		outer1: {}
	}

	for (i = 0; i < internal->boneCacheCount; ++i)
		internal->boneCache[i] = MALLOC(sp21Bone*, internal->boneCacheCounts[i]);
	memset(internal->boneCacheCounts, 0, internal->boneCacheCount * sizeof(int));

	/* Populate arrays. */
	for (i = 0; i < self->bonesCount; ++i) {
		sp21Bone* bone = self->bones[i];
		sp21Bone* current = bone;
		do {
			for (ii = 0; ii < self->ikConstraintsCount; ++ii) {
				sp21IkConstraint* ikConstraint = self->ikConstraints[ii];
				sp21Bone* parent = ikConstraint->bones[0];
				sp21Bone* child = ikConstraint->bones[ikConstraint->bonesCount - 1];
				while (1) {
					if (current == child) {
						internal->boneCache[ii][internal->boneCacheCounts[ii]++] = bone;
						internal->boneCache[ii + 1][internal->boneCacheCounts[ii + 1]++] = bone;
						goto outer2;
					}
					if (child == parent) break;
					child = child->parent;
				}
			}
			current = current->parent;
		} while (current);
		internal->boneCache[0][internal->boneCacheCounts[0]++] = bone;
		outer2: {}
	}
}

void sp21Skeleton_updateWorldTransform (const sp21Skeleton* self) {
	int i, ii, nn, last;
	_sp21Skeleton* internal = SUB_CAST(_sp21Skeleton, self);

	for (i = 0; i < self->bonesCount; ++i)
		self->bones[i]->rotationIK = self->bones[i]->rotation;

	i = 0;
	last = internal->boneCacheCount - 1;
	while (1) {
		for (ii = 0, nn = internal->boneCacheCounts[i]; ii < nn; ++ii)
			sp21Bone_updateWorldTransform(internal->boneCache[i][ii]);
		if (i == last) break;
		sp21IkConstraint_apply(self->ikConstraints[i]);
		i++;
	}
}

void sp21Skeleton_setToSetupPose (const sp21Skeleton* self) {
	sp21Skeleton_setBonesToSetupPose(self);
	sp21Skeleton_setSlotsToSetupPose(self);
}

void sp21Skeleton_setBonesToSetupPose (const sp21Skeleton* self) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		sp21Bone_setToSetupPose(self->bones[i]);

	for (i = 0; i < self->ikConstraintsCount; ++i) {
		sp21IkConstraint* ikConstraint = self->ikConstraints[i];
		ikConstraint->bendDirection = ikConstraint->data->bendDirection;
		ikConstraint->mix = ikConstraint->data->mix;
	}
}

void sp21Skeleton_setSlotsToSetupPose (const sp21Skeleton* self) {
	int i;
	memcpy(self->drawOrder, self->slots, self->slotsCount * sizeof(sp21Slot*));
	for (i = 0; i < self->slotsCount; ++i)
		sp21Slot_setToSetupPose(self->slots[i]);
}

sp21Bone* sp21Skeleton_findBone (const sp21Skeleton* self, const char* boneName) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		if (strcmp(self->data->bones[i]->name, boneName) == 0) return self->bones[i];
	return 0;
}

int sp21Skeleton_findBoneIndex (const sp21Skeleton* self, const char* boneName) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		if (strcmp(self->data->bones[i]->name, boneName) == 0) return i;
	return -1;
}

sp21Slot* sp21Skeleton_findSlot (const sp21Skeleton* self, const char* slotName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i)
		if (strcmp(self->data->slots[i]->name, slotName) == 0) return self->slots[i];
	return 0;
}

int sp21Skeleton_findSlotIndex (const sp21Skeleton* self, const char* slotName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i)
		if (strcmp(self->data->slots[i]->name, slotName) == 0) return i;
	return -1;
}

int sp21Skeleton_setSkinByName (sp21Skeleton* self, const char* skinName) {
	sp21Skin *skin;
	if (!skinName) {
		sp21Skeleton_setSkin(self, 0);
		return 1;
	}
	skin = sp21SkeletonData_findSkin(self->data, skinName);
	if (!skin) return 0;
	sp21Skeleton_setSkin(self, skin);
	return 1;
}

void sp21Skeleton_setSkin (sp21Skeleton* self, sp21Skin* newSkin) {
	if (newSkin) {
		if (self->skin)
			sp21Skin_attachAll(newSkin, self, self->skin);
		else {
			/* No previous skin, attach setup pose attachments. */
			int i;
			for (i = 0; i < self->slotsCount; ++i) {
				sp21Slot* slot = self->slots[i];
				if (slot->data->attachmentName) {
					sp21Attachment* attachment = sp21Skin_getAttachment(newSkin, i, slot->data->attachmentName);
					if (attachment) sp21Slot_setAttachment(slot, attachment);
				}
			}
		}
	}
	CONST_CAST(sp21Skin*, self->skin) = newSkin;
}

sp21Attachment* sp21Skeleton_getAttachmentForSlotName (const sp21Skeleton* self, const char* slotName, const char* attachmentName) {
	int slotIndex = sp21SkeletonData_findSlotIndex(self->data, slotName);
	return sp21Skeleton_getAttachmentForSlotIndex(self, slotIndex, attachmentName);
}

sp21Attachment* sp21Skeleton_getAttachmentForSlotIndex (const sp21Skeleton* self, int slotIndex, const char* attachmentName) {
	if (slotIndex == -1) return 0;
	if (self->skin) {
		sp21Attachment *attachment = sp21Skin_getAttachment(self->skin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	if (self->data->defaultSkin) {
		sp21Attachment *attachment = sp21Skin_getAttachment(self->data->defaultSkin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	return 0;
}

int sp21Skeleton_setAttachment (sp21Skeleton* self, const char* slotName, const char* attachmentName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i) {
		sp21Slot *slot = self->slots[i];
		if (strcmp(slot->data->name, slotName) == 0) {
			if (!attachmentName)
				sp21Slot_setAttachment(slot, 0);
			else {
				sp21Attachment* attachment = sp21Skeleton_getAttachmentForSlotIndex(self, i, attachmentName);
				if (!attachment) return 0;
				sp21Slot_setAttachment(slot, attachment);
			}
			return 1;
		}
	}
	return 0;
}

sp21IkConstraint* sp21Skeleton_findIkConstraint (const sp21Skeleton* self, const char* ikConstraintName) {
	int i;
	for (i = 0; i < self->ikConstraintsCount; ++i)
		if (strcmp(self->ikConstraints[i]->data->name, ikConstraintName) == 0) return self->ikConstraints[i];
	return 0;
}

void sp21Skeleton_update (sp21Skeleton* self, float deltaTime) {
	self->time += deltaTime;
}

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

#include <spine/Skeleton.h>
#include <stdlib.h>
#include <string.h>
#include <spine/extension.h>
#include <spine/Skin.h>

typedef enum {
	SP_UPDATE_BONE, SP_UPDATE_IK_CONSTRAINT, SP_UPDATE_PATH_CONSTRAINT, SP_UPDATE_TRANSFORM_CONSTRAINT
} _sp34UpdateType;

typedef struct {
	_sp34UpdateType type;
	void* object;
} _sp34Update;

typedef struct {
	sp34Skeleton super;

	int updateCacheCount;
	int updateCacheCapacity;
	_sp34Update* updateCache;
} _sp34Skeleton;

sp34Skeleton* sp34Skeleton_create (sp34SkeletonData* data) {
	int i;
	int* childrenCounts;

	_sp34Skeleton* internal = NEW(_sp34Skeleton);
	sp34Skeleton* self = SUPER(internal);
	CONST_CAST(sp34SkeletonData*, self->data) = data;

	self->bonesCount = self->data->bonesCount;
	self->bones = MALLOC(sp34Bone*, self->bonesCount);
	childrenCounts = CALLOC(int, self->bonesCount);

	for (i = 0; i < self->bonesCount; ++i) {
		sp34BoneData* boneData = self->data->bones[i];
		sp34Bone* bone;
		if (!boneData->parent)
			bone = sp34Bone_create(boneData, self, 0);
		else {
			sp34Bone* parent = self->bones[boneData->parent->index];
			bone = sp34Bone_create(boneData, self, parent);
			++childrenCounts[boneData->parent->index];
		}
		self->bones[i] = bone;
	}
	for (i = 0; i < self->bonesCount; ++i) {
		sp34BoneData* boneData = self->data->bones[i];
		sp34Bone* bone = self->bones[i];
		CONST_CAST(sp34Bone**, bone->children) = MALLOC(sp34Bone*, childrenCounts[boneData->index]);
	}
	for (i = 0; i < self->bonesCount; ++i) {
		sp34Bone* bone = self->bones[i];
		sp34Bone* parent = bone->parent;
		if (parent)
			parent->children[parent->childrenCount++] = bone;
	}
	CONST_CAST(sp34Bone*, self->root) = (self->bonesCount > 0 ? self->bones[0] : NULL);

	self->slotsCount = data->slotsCount;
	self->slots = MALLOC(sp34Slot*, self->slotsCount);
	for (i = 0; i < self->slotsCount; ++i) {
		sp34SlotData *slotData = data->slots[i];
		sp34Bone* bone = self->bones[slotData->boneData->index];
		self->slots[i] = sp34Slot_create(slotData, bone);
	}

	self->drawOrder = MALLOC(sp34Slot*, self->slotsCount);
	memcpy(self->drawOrder, self->slots, sizeof(sp34Slot*) * self->slotsCount);

	self->ikConstraintsCount = data->ikConstraintsCount;
	self->ikConstraints = MALLOC(sp34IkConstraint*, self->ikConstraintsCount);
	self->ikConstraintsSorted = MALLOC(sp34IkConstraint*, self->ikConstraintsCount);
	for (i = 0; i < self->data->ikConstraintsCount; ++i)
		self->ikConstraints[i] = sp34IkConstraint_create(self->data->ikConstraints[i], self);

	self->transformConstraintsCount = data->transformConstraintsCount;
	self->transformConstraints = MALLOC(sp34TransformConstraint*, self->transformConstraintsCount);
	for (i = 0; i < self->data->transformConstraintsCount; ++i)
		self->transformConstraints[i] = sp34TransformConstraint_create(self->data->transformConstraints[i], self);

	self->pathConstraintsCount = data->pathConstraintsCount;
	self->pathConstraints = MALLOC(sp34PathConstraint*, self->pathConstraintsCount);
	for (i = 0; i < self->data->pathConstraintsCount; i++)
		self->pathConstraints[i] = sp34PathConstraint_create(self->data->pathConstraints[i], self);

	self->r = 1; self->g = 1; self->b = 1; self->a = 1;

	sp34Skeleton_updateCache(self);

	FREE(childrenCounts);

	return self;
}

void sp34Skeleton_dispose (sp34Skeleton* self) {
	int i;
	_sp34Skeleton* internal = SUB_CAST(_sp34Skeleton, self);

	FREE(internal->updateCache);

	for (i = 0; i < self->bonesCount; ++i)
		sp34Bone_dispose(self->bones[i]);
	FREE(self->bones);

	for (i = 0; i < self->slotsCount; ++i)
		sp34Slot_dispose(self->slots[i]);
	FREE(self->slots);

	for (i = 0; i < self->ikConstraintsCount; ++i)
		sp34IkConstraint_dispose(self->ikConstraints[i]);
	FREE(self->ikConstraints);
	FREE(self->ikConstraintsSorted);

	for (i = 0; i < self->transformConstraintsCount; ++i)
		sp34TransformConstraint_dispose(self->transformConstraints[i]);
	FREE(self->transformConstraints);

	for (i = 0; i < self->pathConstraintsCount; i++)
		sp34PathConstraint_dispose(self->pathConstraints[i]);
	FREE(self->pathConstraints);

	FREE(self->drawOrder);
	FREE(self);
}

static void _addToUpdateCache(_sp34Skeleton* const internal, _sp34UpdateType type, void *object) {
	_sp34Update* update;
	if (internal->updateCacheCount == internal->updateCacheCapacity) {
		internal->updateCacheCapacity *= 2;
		internal->updateCache = realloc(internal->updateCache, sizeof(_sp34Update) * internal->updateCacheCapacity);
	}
	update = internal->updateCache + internal->updateCacheCount;
	update->type = type;
	update->object = object;
	++internal->updateCacheCount;
}

static void _sortBone(_sp34Skeleton* const internal, sp34Bone* bone) {
	if (bone->sorted) return;
	if (bone->parent) _sortBone(internal, bone->parent);
	bone->sorted = 1;
	_addToUpdateCache(internal, SP_UPDATE_BONE, bone);
}

static void _sortPathConstraintAttachmentBones(_sp34Skeleton* const internal, sp34Attachment* attachment, sp34Bone* slotBone) {
	sp34PathAttachment* pathAttachment = (sp34PathAttachment*)attachment;
	int* pathBones;
	int pathBonesCount;
	if (pathAttachment->super.super.type != SP_ATTACHMENT_PATH) return;
	pathBones = pathAttachment->super.bones;
	pathBonesCount = pathAttachment->super.bonesCount;
	if (pathBones == 0)
		_sortBone(internal, slotBone);
	else {
		sp34Bone** bones = internal->super.bones;
		int i = 0;
		while (i < pathBonesCount) {
			int boneCount = pathBones[i++];
			for (int n = i + boneCount; i < n; i++)
				_sortBone(internal, bones[pathBones[i]]);
		}
	}
}

static void _sortPathConstraintAttachment(_sp34Skeleton* const internal, sp34Skin* skin, int slotIndex, sp34Bone* slotBone) {
	_Entry* entry = SUB_CAST(_sp34Skin, skin)->entries;
	while (entry) {
		if (entry->slotIndex == slotIndex) _sortPathConstraintAttachmentBones(internal, entry->attachment, slotBone);
		entry = entry->next;
	}
}

static void _sortReset(sp34Bone** bones, int bonesCount) {
	int i;
	for (i = 0; i < bonesCount; ++i) {
		sp34Bone* bone = bones[i];
		if (bone->sorted) _sortReset(bone->children, bone->childrenCount);
		bone->sorted = 0;
	}
}

void sp34Skeleton_updateCache (sp34Skeleton* self) {
	int i, ii, n, nn, level;
	sp34Bone** bones;
	sp34IkConstraint** ikConstraints;
	sp34PathConstraint** pathConstraints;
	sp34TransformConstraint** transformConstraints;
	_sp34Skeleton* internal = SUB_CAST(_sp34Skeleton, self);
	internal->updateCacheCapacity = self->bonesCount + self->ikConstraintsCount + self->transformConstraintsCount + self->pathConstraintsCount;

	FREE(internal->updateCache);
	internal->updateCache = MALLOC(_sp34Update, internal->updateCacheCapacity);
	internal->updateCacheCount = 0;

	bones = self->bones;
	for (i = 0; i < self->bonesCount; ++i)
		bones[i]->sorted = 0;

	/* IK first, lowest hierarchy depth first. */
	if (self->ikConstraintsSorted) FREE(self->ikConstraintsSorted);
	self->ikConstraintsSorted = MALLOC(sp34IkConstraint*, self->ikConstraintsCount);
	ikConstraints = self->ikConstraintsSorted;
	for (i = 0; i < self->ikConstraintsCount; ++i)
		ikConstraints[i] = self->ikConstraints[i];
	for (i = 0; i < self->ikConstraintsCount; ++i) {
		sp34IkConstraint* ik = ikConstraints[i];
		sp34Bone* bone = ik->bones[0]->parent;
		for (level = 0; bone; ++level)
			bone = bone->parent;
		ik->level = level;
	}
	for (i = 1; i < self->ikConstraintsCount; ++i) {
		sp34IkConstraint* ik = ikConstraints[i];
		level = ik->level;
		for (ii = i - 1; ii >= 0; --ii) {
			sp34IkConstraint* other = ikConstraints[ii];
			if (other->level < level) break;
			ikConstraints[ii + 1] = other;
		}
		ikConstraints[ii + 1] = ik;
	}
	for (i = 0; i < self->ikConstraintsCount; ++i) {
		sp34Bone** constrained;
		sp34Bone* parent;
		sp34IkConstraint* constraint = ikConstraints[i];
		sp34Bone* target = constraint->target;
		_sortBone(internal, target);

		constrained = constraint->bones;
		parent = constrained[0];
		_sortBone(internal, parent);

		_addToUpdateCache(internal, SP_UPDATE_IK_CONSTRAINT, constraint);

		_sortReset(parent->children, parent->childrenCount);
		constrained[constraint->bonesCount - 1]->sorted = 1;
	}

	pathConstraints = self->pathConstraints;
	for (i = 0, n = self->pathConstraintsCount; i < n; i++) {
		sp34Attachment* attachment;
		sp34Bone** constrained;
		int boneCount;
		sp34PathConstraint* constraint = pathConstraints[i];

		sp34Slot* slot = constraint->target;
		int slotIndex = slot->data->index;
		sp34Bone* slotBone = slot->bone;
		if (self->skin) _sortPathConstraintAttachment(internal, self->skin, slotIndex, slotBone);
		if (self->data->defaultSkin && self->data->defaultSkin != self->skin)
			_sortPathConstraintAttachment(internal, self->data->defaultSkin, slotIndex, slotBone);
		for (ii = 0, nn = self->data->skinsCount; ii < nn; ii++)
			_sortPathConstraintAttachment(internal, self->data->skins[ii], slotIndex, slotBone);

		attachment = slot->attachment;
		if (attachment->type == SP_ATTACHMENT_PATH) _sortPathConstraintAttachmentBones(internal, attachment, slotBone);

		constrained = constraint->bones;
		boneCount = constraint->bonesCount;
		for (ii = 0; ii < boneCount; ii++)
			_sortBone(internal, constrained[ii]);

		_addToUpdateCache(internal, SP_UPDATE_PATH_CONSTRAINT, constraint);

		for (ii = 0; ii < boneCount; ii++)
			_sortReset(constrained[ii]->children, constrained[ii]->childrenCount);
		for (ii = 0; ii < boneCount; ii++)
			constrained[ii]->sorted = 1;
	}

	transformConstraints = self->transformConstraints;
	for (i = 0, n = self->transformConstraintsCount; i < n; ++i) {
		sp34TransformConstraint* constraint = transformConstraints[i];
		sp34Bone** constrained = constraint->bones;

		_sortBone(internal, constraint->target);

		for (ii = 0; ii < constraint->bonesCount; ++ii)
			_sortBone(internal, constrained[ii]);

		_addToUpdateCache(internal, SP_UPDATE_TRANSFORM_CONSTRAINT, constraint);

		for (ii = 0; ii < constraint->bonesCount; ++ii) {
			sp34Bone* bone = constrained[ii];
			_sortReset(bone->children, bone->childrenCount);
		}
		for (ii = 0; ii < constraint->bonesCount; ++ii)
			constrained[ii]->sorted = 1;
	}

	for (i = 0; i < self->bonesCount; ++i)
		_sortBone(internal, self->bones[i]);
}

void sp34Skeleton_updateWorldTransform (const sp34Skeleton* self) {
	int i;
	_sp34Skeleton* internal = SUB_CAST(_sp34Skeleton, self);

	for (i = 0; i < internal->updateCacheCount; ++i) {
		_sp34Update* update = internal->updateCache + i;
		switch (update->type) {
		case SP_UPDATE_BONE:
			sp34Bone_updateWorldTransform((sp34Bone*)update->object);
			break;
		case SP_UPDATE_IK_CONSTRAINT:
			sp34IkConstraint_apply((sp34IkConstraint*)update->object);
			break;
		case SP_UPDATE_TRANSFORM_CONSTRAINT:
			sp34TransformConstraint_apply((sp34TransformConstraint*)update->object);
			break;
		case SP_UPDATE_PATH_CONSTRAINT:
			sp34PathConstraint_apply((sp34PathConstraint*)update->object);
			break;
		}
	}
}

void sp34Skeleton_setToSetupPose (const sp34Skeleton* self) {
	sp34Skeleton_setBonesToSetupPose(self);
	sp34Skeleton_setSlotsToSetupPose(self);
}

void sp34Skeleton_setBonesToSetupPose (const sp34Skeleton* self) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		sp34Bone_setToSetupPose(self->bones[i]);

	for (i = 0; i < self->ikConstraintsCount; ++i) {
		sp34IkConstraint* ikConstraint = self->ikConstraints[i];
		ikConstraint->bendDirection = ikConstraint->data->bendDirection;
		ikConstraint->mix = ikConstraint->data->mix;
	}

	for (i = 0; i < self->transformConstraintsCount; ++i) {
		sp34TransformConstraint* constraint = self->transformConstraints[i];
		sp34TransformConstraintData* data = constraint->data;
		constraint->rotateMix = data->rotateMix;
		constraint->translateMix = data->translateMix;
		constraint->scaleMix = data->scaleMix;
		constraint->shearMix = data->shearMix;
	}

	for (i = 0; i < self->pathConstraintsCount; ++i) {
		sp34PathConstraint* constraint = self->pathConstraints[i];
		sp34PathConstraintData* data = constraint->data;
		constraint->position = data->position;
		constraint->spacing = data->spacing;
		constraint->rotateMix = data->rotateMix;
		constraint->translateMix = data->translateMix;
	}
}

void sp34Skeleton_setSlotsToSetupPose (const sp34Skeleton* self) {
	int i;
	memcpy(self->drawOrder, self->slots, self->slotsCount * sizeof(sp34Slot*));
	for (i = 0; i < self->slotsCount; ++i)
		sp34Slot_setToSetupPose(self->slots[i]);
}

sp34Bone* sp34Skeleton_findBone (const sp34Skeleton* self, const char* boneName) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		if (strcmp(self->data->bones[i]->name, boneName) == 0) return self->bones[i];
	return 0;
}

int sp34Skeleton_findBoneIndex (const sp34Skeleton* self, const char* boneName) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		if (strcmp(self->data->bones[i]->name, boneName) == 0) return i;
	return -1;
}

sp34Slot* sp34Skeleton_findSlot (const sp34Skeleton* self, const char* slotName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i)
		if (strcmp(self->data->slots[i]->name, slotName) == 0) return self->slots[i];
	return 0;
}

int sp34Skeleton_findSlotIndex (const sp34Skeleton* self, const char* slotName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i)
		if (strcmp(self->data->slots[i]->name, slotName) == 0) return i;
	return -1;
}

int sp34Skeleton_setSkinByName (sp34Skeleton* self, const char* skinName) {
	sp34Skin *skin;
	if (!skinName) {
		sp34Skeleton_setSkin(self, 0);
		return 1;
	}
	skin = sp34SkeletonData_findSkin(self->data, skinName);
	if (!skin) return 0;
	sp34Skeleton_setSkin(self, skin);
	return 1;
}

void sp34Skeleton_setSkin (sp34Skeleton* self, sp34Skin* newSkin) {
	if (newSkin) {
		if (self->skin)
			sp34Skin_attachAll(newSkin, self, self->skin);
		else {
			/* No previous skin, attach setup pose attachments. */
			int i;
			for (i = 0; i < self->slotsCount; ++i) {
				sp34Slot* slot = self->slots[i];
				if (slot->data->attachmentName) {
					sp34Attachment* attachment = sp34Skin_getAttachment(newSkin, i, slot->data->attachmentName);
					if (attachment) sp34Slot_setAttachment(slot, attachment);
				}
			}
		}
	}
	CONST_CAST(sp34Skin*, self->skin) = newSkin;
}

sp34Attachment* sp34Skeleton_getAttachmentForSlotName (const sp34Skeleton* self, const char* slotName, const char* attachmentName) {
	int slotIndex = sp34SkeletonData_findSlotIndex(self->data, slotName);
	return sp34Skeleton_getAttachmentForSlotIndex(self, slotIndex, attachmentName);
}

sp34Attachment* sp34Skeleton_getAttachmentForSlotIndex (const sp34Skeleton* self, int slotIndex, const char* attachmentName) {
	if (slotIndex == -1) return 0;
	if (self->skin) {
		sp34Attachment *attachment = sp34Skin_getAttachment(self->skin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	if (self->data->defaultSkin) {
		sp34Attachment *attachment = sp34Skin_getAttachment(self->data->defaultSkin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	return 0;
}

int sp34Skeleton_setAttachment (sp34Skeleton* self, const char* slotName, const char* attachmentName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i) {
		sp34Slot *slot = self->slots[i];
		if (strcmp(slot->data->name, slotName) == 0) {
			if (!attachmentName)
				sp34Slot_setAttachment(slot, 0);
			else {
				sp34Attachment* attachment = sp34Skeleton_getAttachmentForSlotIndex(self, i, attachmentName);
				if (!attachment) return 0;
				sp34Slot_setAttachment(slot, attachment);
			}
			return 1;
		}
	}
	return 0;
}

sp34IkConstraint* sp34Skeleton_findIkConstraint (const sp34Skeleton* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->ikConstraintsCount; ++i)
		if (strcmp(self->ikConstraints[i]->data->name, constraintName) == 0) return self->ikConstraints[i];
	return 0;
}

sp34TransformConstraint* sp34Skeleton_findTransformConstraint (const sp34Skeleton* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->transformConstraintsCount; ++i)
		if (strcmp(self->transformConstraints[i]->data->name, constraintName) == 0) return self->transformConstraints[i];
	return 0;
}

sp34PathConstraint* sp34Skeleton_findPathConstraint (const sp34Skeleton* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->pathConstraintsCount; ++i)
		if (strcmp(self->pathConstraints[i]->data->name, constraintName) == 0) return self->pathConstraints[i];
	return 0;
}

void sp34Skeleton_update (sp34Skeleton* self, float deltaTime) {
	self->time += deltaTime;
}

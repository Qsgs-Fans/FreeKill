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

typedef enum {
	SP_UPDATE_BONE, SP_UPDATE_IK_CONSTRAINT, SP_UPDATE_PATH_CONSTRAINT, SP_UPDATE_TRANSFORM_CONSTRAINT
} _sp35UpdateType;

typedef struct {
	_sp35UpdateType type;
	void* object;
} _sp35Update;

typedef struct {
	sp35Skeleton super;

	int updateCacheCount;
	int updateCacheCapacity;
	_sp35Update* updateCache;

	int updateCacheResetCount;
	int updateCacheResetCapacity;
	sp35Bone** updateCacheReset;
} _sp35Skeleton;

sp35Skeleton* sp35Skeleton_create (sp35SkeletonData* data) {
	int i;
	int* childrenCounts;

	_sp35Skeleton* internal = NEW(_sp35Skeleton);
	sp35Skeleton* self = SUPER(internal);
	CONST_CAST(sp35SkeletonData*, self->data) = data;

	self->bonesCount = self->data->bonesCount;
	self->bones = MALLOC(sp35Bone*, self->bonesCount);
	childrenCounts = CALLOC(int, self->bonesCount);

	for (i = 0; i < self->bonesCount; ++i) {
		sp35BoneData* boneData = self->data->bones[i];
		sp35Bone* newBone;
		if (!boneData->parent)
			newBone = sp35Bone_create(boneData, self, 0);
		else {
			sp35Bone* parent = self->bones[boneData->parent->index];
			newBone = sp35Bone_create(boneData, self, parent);
			++childrenCounts[boneData->parent->index];
		}
		self->bones[i] = newBone;
	}
	for (i = 0; i < self->bonesCount; ++i) {
		sp35BoneData* boneData = self->data->bones[i];
		sp35Bone* bone = self->bones[i];
		CONST_CAST(sp35Bone**, bone->children) = MALLOC(sp35Bone*, childrenCounts[boneData->index]);
	}
	for (i = 0; i < self->bonesCount; ++i) {
		sp35Bone* bone = self->bones[i];
		sp35Bone* parent = bone->parent;
		if (parent)
			parent->children[parent->childrenCount++] = bone;
	}
	CONST_CAST(sp35Bone*, self->root) = (self->bonesCount > 0 ? self->bones[0] : NULL);

	self->slotsCount = data->slotsCount;
	self->slots = MALLOC(sp35Slot*, self->slotsCount);
	for (i = 0; i < self->slotsCount; ++i) {
		sp35SlotData *slotData = data->slots[i];
		sp35Bone* bone = self->bones[slotData->boneData->index];
		self->slots[i] = sp35Slot_create(slotData, bone);
	}

	self->drawOrder = MALLOC(sp35Slot*, self->slotsCount);
	memcpy(self->drawOrder, self->slots, sizeof(sp35Slot*) * self->slotsCount);

	self->ikConstraintsCount = data->ikConstraintsCount;
	self->ikConstraints = MALLOC(sp35IkConstraint*, self->ikConstraintsCount);
	for (i = 0; i < self->data->ikConstraintsCount; ++i)
		self->ikConstraints[i] = sp35IkConstraint_create(self->data->ikConstraints[i], self);

	self->transformConstraintsCount = data->transformConstraintsCount;
	self->transformConstraints = MALLOC(sp35TransformConstraint*, self->transformConstraintsCount);
	for (i = 0; i < self->data->transformConstraintsCount; ++i)
		self->transformConstraints[i] = sp35TransformConstraint_create(self->data->transformConstraints[i], self);

	self->pathConstraintsCount = data->pathConstraintsCount;
	self->pathConstraints = MALLOC(sp35PathConstraint*, self->pathConstraintsCount);
	for (i = 0; i < self->data->pathConstraintsCount; i++)
		self->pathConstraints[i] = sp35PathConstraint_create(self->data->pathConstraints[i], self);

	self->r = 1; self->g = 1; self->b = 1; self->a = 1;

	sp35Skeleton_updateCache(self);

	FREE(childrenCounts);

	return self;
}

void sp35Skeleton_dispose (sp35Skeleton* self) {
	int i;
	_sp35Skeleton* internal = SUB_CAST(_sp35Skeleton, self);

	FREE(internal->updateCache);
	FREE(internal->updateCacheReset);

	for (i = 0; i < self->bonesCount; ++i)
		sp35Bone_dispose(self->bones[i]);
	FREE(self->bones);

	for (i = 0; i < self->slotsCount; ++i)
		sp35Slot_dispose(self->slots[i]);
	FREE(self->slots);

	for (i = 0; i < self->ikConstraintsCount; ++i)
		sp35IkConstraint_dispose(self->ikConstraints[i]);
	FREE(self->ikConstraints);

	for (i = 0; i < self->transformConstraintsCount; ++i)
		sp35TransformConstraint_dispose(self->transformConstraints[i]);
	FREE(self->transformConstraints);

	for (i = 0; i < self->pathConstraintsCount; i++)
		sp35PathConstraint_dispose(self->pathConstraints[i]);
	FREE(self->pathConstraints);

	FREE(self->drawOrder);
	FREE(self);
}

static void _addToUpdateCache(_sp35Skeleton* const internal, _sp35UpdateType type, void *object) {
	_sp35Update* update;
	if (internal->updateCacheCount == internal->updateCacheCapacity) {
		internal->updateCacheCapacity *= 2;
		internal->updateCache = (_sp35Update*)realloc(internal->updateCache, sizeof(_sp35Update) * internal->updateCacheCapacity);
	}
	update = internal->updateCache + internal->updateCacheCount;
	update->type = type;
	update->object = object;
	++internal->updateCacheCount;
}

static void _addToUpdateCacheReset(_sp35Skeleton* const internal, sp35Bone* bone) {
	if (internal->updateCacheResetCount == internal->updateCacheResetCapacity) {
		internal->updateCacheResetCapacity *= 2;
		internal->updateCacheReset = (sp35Bone**)realloc(internal->updateCacheReset, sizeof(sp35Bone*) * internal->updateCacheResetCapacity);
	}
	internal->updateCacheReset[internal->updateCacheResetCount] = bone;
	++internal->updateCacheResetCount;
}

static void _sortBone(_sp35Skeleton* const internal, sp35Bone* bone) {
	if (bone->sorted) return;
	if (bone->parent) _sortBone(internal, bone->parent);
	bone->sorted = 1;
	_addToUpdateCache(internal, SP_UPDATE_BONE, bone);
}

static void _sortPathConstraintAttachmentBones(_sp35Skeleton* const internal, sp35Attachment* attachment, sp35Bone* slotBone) {
	sp35PathAttachment* pathAttachment = (sp35PathAttachment*)attachment;
	int* pathBones;
	int pathBonesCount;
	if (pathAttachment->super.super.type != SP_ATTACHMENT_PATH) return;
	pathBones = pathAttachment->super.bones;
	pathBonesCount = pathAttachment->super.bonesCount;
	if (pathBones == 0)
		_sortBone(internal, slotBone);
	else {
		sp35Bone** bones = internal->super.bones;
		int i = 0, n;
		while (i < pathBonesCount) {
			int boneCount = pathBones[i++];
			for (n = i + boneCount; i < n; i++)
				_sortBone(internal, bones[pathBones[i]]);
		}
	}
}

static void _sortPathConstraintAttachment(_sp35Skeleton* const internal, sp35Skin* skin, int slotIndex, sp35Bone* slotBone) {
	_Entry* entry = SUB_CAST(_sp35Skin, skin)->entries;
	while (entry) {
		if (entry->slotIndex == slotIndex) _sortPathConstraintAttachmentBones(internal, entry->attachment, slotBone);
		entry = entry->next;
	}
}

static void _sortReset(sp35Bone** bones, int bonesCount) {
	int i;
	for (i = 0; i < bonesCount; ++i) {
		sp35Bone* bone = bones[i];
		if (bone->sorted) _sortReset(bone->children, bone->childrenCount);
		bone->sorted = 0;
	}
}

static void _sortIkConstraint (_sp35Skeleton* const internal, sp35IkConstraint* constraint) {
	int /*bool*/ contains = 0;
	int i;
	sp35Bone* target = constraint->target;
	sp35Bone** constrained;
	sp35Bone* parent;
	_sortBone(internal, target);

	constrained = constraint->bones;
	parent = constrained[0];
	_sortBone(internal, parent);

	if (constraint->bonesCount > 1) {
		sp35Bone* child = constrained[constraint->bonesCount - 1];
		contains = 0;
		for (i = 0; i < internal->updateCacheCount; i++) {
			_sp35Update update = internal->updateCache[i];
			if (update.object == child) {
				contains = -1;
				break;
			}
		}
		if (!contains)
			_addToUpdateCacheReset(internal, child);
	}

	_addToUpdateCache(internal, SP_UPDATE_IK_CONSTRAINT, constraint);

	_sortReset(parent->children, parent->childrenCount);
	constrained[constraint->bonesCount-1]->sorted = 1;
}

static void _sortPathConstraint(_sp35Skeleton* const internal, sp35PathConstraint* constraint) {
	sp35Slot* slot = constraint->target;
	int slotIndex = slot->data->index;
	sp35Bone* slotBone = slot->bone;
	int ii, nn, boneCount;
	sp35Attachment* attachment;
	sp35Bone** constrained;
	sp35Skeleton* skeleton = SUPER_CAST(sp35Skeleton, internal);
	if (skeleton->skin) _sortPathConstraintAttachment(internal, skeleton->skin, slotIndex, slotBone);
	if (skeleton->data->defaultSkin && skeleton->data->defaultSkin != skeleton->skin)
		_sortPathConstraintAttachment(internal, skeleton->data->defaultSkin, slotIndex, slotBone);
	for (ii = 0, nn = skeleton->data->skinsCount; ii < nn; ii++)
		_sortPathConstraintAttachment(internal, skeleton->data->skins[ii], slotIndex, slotBone);

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

static void _sortTransformConstraint(_sp35Skeleton* const internal, sp35TransformConstraint* constraint) {
	int ii, boneCount;
	sp35Bone** constrained;
	_sortBone(internal, constraint->target);

	constrained = constraint->bones;
	boneCount = constraint->bonesCount;
	for (ii = 0; ii < boneCount; ii++)
		_sortBone(internal, constrained[ii]);

	_addToUpdateCache(internal, SP_UPDATE_TRANSFORM_CONSTRAINT, constraint);

	for (ii = 0; ii < boneCount; ii++)
		_sortReset(constrained[ii]->children, constrained[ii]->childrenCount);
	for (ii = 0; ii < boneCount; ii++)
		constrained[ii]->sorted = 1;
}

void sp35Skeleton_updateCache (sp35Skeleton* self) {
	int i, ii;
	sp35Bone** bones;
	sp35IkConstraint** ikConstraints;
	sp35PathConstraint** pathConstraints;
	sp35TransformConstraint** transformConstraints;
	int ikCount, transformCount, pathCount, constraintCount;
	_sp35Skeleton* internal = SUB_CAST(_sp35Skeleton, self);

	internal->updateCacheCapacity = self->bonesCount + self->ikConstraintsCount + self->transformConstraintsCount + self->pathConstraintsCount;
	FREE(internal->updateCache);
	internal->updateCache = MALLOC(_sp35Update, internal->updateCacheCapacity);
	internal->updateCacheCount = 0;

	internal->updateCacheResetCapacity = self->bonesCount;
	FREE(internal->updateCacheReset);
	internal->updateCacheReset = MALLOC(sp35Bone*, internal->updateCacheResetCapacity);
	internal->updateCacheResetCount = 0;

	bones = self->bones;
	for (i = 0; i < self->bonesCount; ++i)
		bones[i]->sorted = 0;

	/* IK first, lowest hierarchy depth first. */
	ikConstraints = self->ikConstraints;
	transformConstraints = self->transformConstraints;
	pathConstraints = self->pathConstraints;
	ikCount = self->ikConstraintsCount; transformCount = self->transformConstraintsCount; pathCount = self->pathConstraintsCount;
	constraintCount = ikCount + transformCount + pathCount;

	i = 0;
	outer:
	for (; i < constraintCount; i++) {
		for (ii = 0; ii < ikCount; ii++) {
			sp35IkConstraint* ikConstraint = ikConstraints[ii];
			if (ikConstraint->data->order == i) {
				_sortIkConstraint(internal, ikConstraint);
				i++;
				goto outer;
			}
		}

		for (ii = 0; ii < transformCount; ii++) {
			sp35TransformConstraint* transformConstraint = transformConstraints[ii];
			if (transformConstraint->data->order == i) {
				_sortTransformConstraint(internal, transformConstraint);
				i++;
				goto outer;
			}
		}

		for (ii = 0; ii < pathCount; ii++) {
			sp35PathConstraint* pathConstraint = pathConstraints[ii];
			if (pathConstraint->data->order == i) {
				_sortPathConstraint(internal, pathConstraint);
				i++;
				goto outer;
			}
		}
	}

	for (i = 0; i < self->bonesCount; ++i)
		_sortBone(internal, self->bones[i]);
}

void sp35Skeleton_updateWorldTransform (const sp35Skeleton* self) {
	int i;
	_sp35Skeleton* internal = SUB_CAST(_sp35Skeleton, self);
	sp35Bone** updateCacheReset = internal->updateCacheReset;
	for (i = 0; i < internal->updateCacheResetCount; i++) {
		sp35Bone* bone = updateCacheReset[i];
		CONST_CAST(float, bone->ax) = bone->x;
		CONST_CAST(float, bone->ay) = bone->y;
		CONST_CAST(float, bone->arotation) = bone->rotation;
		CONST_CAST(float, bone->ascaleX) = bone->scaleX;
		CONST_CAST(float, bone->ascaleY) = bone->scaleY;
		CONST_CAST(float, bone->ashearX) = bone->shearX;
		CONST_CAST(float, bone->ashearY) = bone->shearY;
		CONST_CAST(int, bone->appliedValid) = 1;
	}

	for (i = 0; i < internal->updateCacheCount; ++i) {
		_sp35Update* update = internal->updateCache + i;
		switch (update->type) {
		case SP_UPDATE_BONE:
			sp35Bone_updateWorldTransform((sp35Bone*)update->object);
			break;
		case SP_UPDATE_IK_CONSTRAINT:
			sp35IkConstraint_apply((sp35IkConstraint*)update->object);
			break;
		case SP_UPDATE_TRANSFORM_CONSTRAINT:
			sp35TransformConstraint_apply((sp35TransformConstraint*)update->object);
			break;
		case SP_UPDATE_PATH_CONSTRAINT:
			sp35PathConstraint_apply((sp35PathConstraint*)update->object);
			break;
		}
	}
}

void sp35Skeleton_setToSetupPose (const sp35Skeleton* self) {
	sp35Skeleton_setBonesToSetupPose(self);
	sp35Skeleton_setSlotsToSetupPose(self);
}

void sp35Skeleton_setBonesToSetupPose (const sp35Skeleton* self) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		sp35Bone_setToSetupPose(self->bones[i]);

	for (i = 0; i < self->ikConstraintsCount; ++i) {
		sp35IkConstraint* ikConstraint = self->ikConstraints[i];
		ikConstraint->bendDirection = ikConstraint->data->bendDirection;
		ikConstraint->mix = ikConstraint->data->mix;
	}

	for (i = 0; i < self->transformConstraintsCount; ++i) {
		sp35TransformConstraint* constraint = self->transformConstraints[i];
		sp35TransformConstraintData* data = constraint->data;
		constraint->rotateMix = data->rotateMix;
		constraint->translateMix = data->translateMix;
		constraint->scaleMix = data->scaleMix;
		constraint->shearMix = data->shearMix;
	}

	for (i = 0; i < self->pathConstraintsCount; ++i) {
		sp35PathConstraint* constraint = self->pathConstraints[i];
		sp35PathConstraintData* data = constraint->data;
		constraint->position = data->position;
		constraint->spacing = data->spacing;
		constraint->rotateMix = data->rotateMix;
		constraint->translateMix = data->translateMix;
	}
}

void sp35Skeleton_setSlotsToSetupPose (const sp35Skeleton* self) {
	int i;
	memcpy(self->drawOrder, self->slots, self->slotsCount * sizeof(sp35Slot*));
	for (i = 0; i < self->slotsCount; ++i)
		sp35Slot_setToSetupPose(self->slots[i]);
}

sp35Bone* sp35Skeleton_findBone (const sp35Skeleton* self, const char* boneName) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		if (strcmp(self->data->bones[i]->name, boneName) == 0) return self->bones[i];
	return 0;
}

int sp35Skeleton_findBoneIndex (const sp35Skeleton* self, const char* boneName) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		if (strcmp(self->data->bones[i]->name, boneName) == 0) return i;
	return -1;
}

sp35Slot* sp35Skeleton_findSlot (const sp35Skeleton* self, const char* slotName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i)
		if (strcmp(self->data->slots[i]->name, slotName) == 0) return self->slots[i];
	return 0;
}

int sp35Skeleton_findSlotIndex (const sp35Skeleton* self, const char* slotName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i)
		if (strcmp(self->data->slots[i]->name, slotName) == 0) return i;
	return -1;
}

int sp35Skeleton_setSkinByName (sp35Skeleton* self, const char* skinName) {
	sp35Skin *skin;
	if (!skinName) {
		sp35Skeleton_setSkin(self, 0);
		return 1;
	}
	skin = sp35SkeletonData_findSkin(self->data, skinName);
	if (!skin) return 0;
	sp35Skeleton_setSkin(self, skin);
	return 1;
}

void sp35Skeleton_setSkin (sp35Skeleton* self, sp35Skin* newSkin) {
	if (newSkin) {
		if (self->skin)
			sp35Skin_attachAll(newSkin, self, self->skin);
		else {
			/* No previous skin, attach setup pose attachments. */
			int i;
			for (i = 0; i < self->slotsCount; ++i) {
				sp35Slot* slot = self->slots[i];
				if (slot->data->attachmentName) {
					sp35Attachment* attachment = sp35Skin_getAttachment(newSkin, i, slot->data->attachmentName);
					if (attachment) sp35Slot_setAttachment(slot, attachment);
				}
			}
		}
	}
	CONST_CAST(sp35Skin*, self->skin) = newSkin;
}

sp35Attachment* sp35Skeleton_getAttachmentForSlotName (const sp35Skeleton* self, const char* slotName, const char* attachmentName) {
	int slotIndex = sp35SkeletonData_findSlotIndex(self->data, slotName);
	return sp35Skeleton_getAttachmentForSlotIndex(self, slotIndex, attachmentName);
}

sp35Attachment* sp35Skeleton_getAttachmentForSlotIndex (const sp35Skeleton* self, int slotIndex, const char* attachmentName) {
	if (slotIndex == -1) return 0;
	if (self->skin) {
		sp35Attachment *attachment = sp35Skin_getAttachment(self->skin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	if (self->data->defaultSkin) {
		sp35Attachment *attachment = sp35Skin_getAttachment(self->data->defaultSkin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	return 0;
}

int sp35Skeleton_setAttachment (sp35Skeleton* self, const char* slotName, const char* attachmentName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i) {
		sp35Slot *slot = self->slots[i];
		if (strcmp(slot->data->name, slotName) == 0) {
			if (!attachmentName)
				sp35Slot_setAttachment(slot, 0);
			else {
				sp35Attachment* attachment = sp35Skeleton_getAttachmentForSlotIndex(self, i, attachmentName);
				if (!attachment) return 0;
				sp35Slot_setAttachment(slot, attachment);
			}
			return 1;
		}
	}
	return 0;
}

sp35IkConstraint* sp35Skeleton_findIkConstraint (const sp35Skeleton* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->ikConstraintsCount; ++i)
		if (strcmp(self->ikConstraints[i]->data->name, constraintName) == 0) return self->ikConstraints[i];
	return 0;
}

sp35TransformConstraint* sp35Skeleton_findTransformConstraint (const sp35Skeleton* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->transformConstraintsCount; ++i)
		if (strcmp(self->transformConstraints[i]->data->name, constraintName) == 0) return self->transformConstraints[i];
	return 0;
}

sp35PathConstraint* sp35Skeleton_findPathConstraint (const sp35Skeleton* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->pathConstraintsCount; ++i)
		if (strcmp(self->pathConstraints[i]->data->name, constraintName) == 0) return self->pathConstraints[i];
	return 0;
}

void sp35Skeleton_update (sp35Skeleton* self, float deltaTime) {
	self->time += deltaTime;
}

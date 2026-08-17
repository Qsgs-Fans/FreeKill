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

#include <spine/Skeleton.h>
#include <stdlib.h>
#include <string.h>
#include <spine/extension.h>

typedef enum {
	SP_UPDATE_BONE, SP_UPDATE_IK_CONSTRAINT, SP_UPDATE_PATH_CONSTRAINT, SP_UPDATE_TRANSFORM_CONSTRAINT
} _sp38UpdateType;

typedef struct {
	_sp38UpdateType type;
	void* object;
} _sp38Update;

typedef struct {
	sp38Skeleton super;

	int updateCacheCount;
	int updateCacheCapacity;
	_sp38Update* updateCache;

	int updateCacheResetCount;
	int updateCacheResetCapacity;
	sp38Bone** updateCacheReset;
} _sp38Skeleton;

sp38Skeleton* sp38Skeleton_create (sp38SkeletonData* data) {
	int i;
	int* childrenCounts;

	_sp38Skeleton* internal = NEW(_sp38Skeleton);
	sp38Skeleton* self = SUPER(internal);
	CONST_CAST(sp38SkeletonData*, self->data) = data;

	self->bonesCount = self->data->bonesCount;
	self->bones = MALLOC(sp38Bone*, self->bonesCount);
	childrenCounts = CALLOC(int, self->bonesCount);

	for (i = 0; i < self->bonesCount; ++i) {
		sp38BoneData* boneData = self->data->bones[i];
		sp38Bone* newBone;
		if (!boneData->parent)
			newBone = sp38Bone_create(boneData, self, 0);
		else {
			sp38Bone* parent = self->bones[boneData->parent->index];
			newBone = sp38Bone_create(boneData, self, parent);
			++childrenCounts[boneData->parent->index];
		}
		self->bones[i] = newBone;
	}
	for (i = 0; i < self->bonesCount; ++i) {
		sp38BoneData* boneData = self->data->bones[i];
		sp38Bone* bone = self->bones[i];
		CONST_CAST(sp38Bone**, bone->children) = MALLOC(sp38Bone*, childrenCounts[boneData->index]);
	}
	for (i = 0; i < self->bonesCount; ++i) {
		sp38Bone* bone = self->bones[i];
		sp38Bone* parent = bone->parent;
		if (parent)
			parent->children[parent->childrenCount++] = bone;
	}
	CONST_CAST(sp38Bone*, self->root) = (self->bonesCount > 0 ? self->bones[0] : NULL);

	self->slotsCount = data->slotsCount;
	self->slots = MALLOC(sp38Slot*, self->slotsCount);
	for (i = 0; i < self->slotsCount; ++i) {
		sp38SlotData *slotData = data->slots[i];
		sp38Bone* bone = self->bones[slotData->boneData->index];
		self->slots[i] = sp38Slot_create(slotData, bone);
	}

	self->drawOrder = MALLOC(sp38Slot*, self->slotsCount);
	memcpy(self->drawOrder, self->slots, sizeof(sp38Slot*) * self->slotsCount);

	self->ikConstraintsCount = data->ikConstraintsCount;
	self->ikConstraints = MALLOC(sp38IkConstraint*, self->ikConstraintsCount);
	for (i = 0; i < self->data->ikConstraintsCount; ++i)
		self->ikConstraints[i] = sp38IkConstraint_create(self->data->ikConstraints[i], self);

	self->transformConstraintsCount = data->transformConstraintsCount;
	self->transformConstraints = MALLOC(sp38TransformConstraint*, self->transformConstraintsCount);
	for (i = 0; i < self->data->transformConstraintsCount; ++i)
		self->transformConstraints[i] = sp38TransformConstraint_create(self->data->transformConstraints[i], self);

	self->pathConstraintsCount = data->pathConstraintsCount;
	self->pathConstraints = MALLOC(sp38PathConstraint*, self->pathConstraintsCount);
	for (i = 0; i < self->data->pathConstraintsCount; i++)
		self->pathConstraints[i] = sp38PathConstraint_create(self->data->pathConstraints[i], self);

	sp38Color_setFromFloats(&self->color, 1, 1, 1, 1);

	self->scaleX = 1;
	self->scaleY = 1;

	sp38Skeleton_updateCache(self);

	FREE(childrenCounts);

	return self;
}

void sp38Skeleton_dispose (sp38Skeleton* self) {
	int i;
	_sp38Skeleton* internal = SUB_CAST(_sp38Skeleton, self);

	FREE(internal->updateCache);
	FREE(internal->updateCacheReset);

	for (i = 0; i < self->bonesCount; ++i)
		sp38Bone_dispose(self->bones[i]);
	FREE(self->bones);

	for (i = 0; i < self->slotsCount; ++i)
		sp38Slot_dispose(self->slots[i]);
	FREE(self->slots);

	for (i = 0; i < self->ikConstraintsCount; ++i)
		sp38IkConstraint_dispose(self->ikConstraints[i]);
	FREE(self->ikConstraints);

	for (i = 0; i < self->transformConstraintsCount; ++i)
		sp38TransformConstraint_dispose(self->transformConstraints[i]);
	FREE(self->transformConstraints);

	for (i = 0; i < self->pathConstraintsCount; i++)
		sp38PathConstraint_dispose(self->pathConstraints[i]);
	FREE(self->pathConstraints);

	FREE(self->drawOrder);
	FREE(self);
}

static void _addToUpdateCache(_sp38Skeleton* const internal, _sp38UpdateType type, void *object) {
	_sp38Update* update;
	if (internal->updateCacheCount == internal->updateCacheCapacity) {
		internal->updateCacheCapacity *= 2;
		internal->updateCache = (_sp38Update*)realloc(internal->updateCache, sizeof(_sp38Update) * internal->updateCacheCapacity);
	}
	update = internal->updateCache + internal->updateCacheCount;
	update->type = type;
	update->object = object;
	++internal->updateCacheCount;
}

static void _addToUpdateCacheReset(_sp38Skeleton* const internal, sp38Bone* bone) {
	if (internal->updateCacheResetCount == internal->updateCacheResetCapacity) {
		internal->updateCacheResetCapacity *= 2;
		internal->updateCacheReset = (sp38Bone**)realloc(internal->updateCacheReset, sizeof(sp38Bone*) * internal->updateCacheResetCapacity);
	}
	internal->updateCacheReset[internal->updateCacheResetCount] = bone;
	++internal->updateCacheResetCount;
}

static void _sortBone(_sp38Skeleton* const internal, sp38Bone* bone) {
	if (bone->sorted) return;
	if (bone->parent) _sortBone(internal, bone->parent);
	bone->sorted = 1;
	_addToUpdateCache(internal, SP_UPDATE_BONE, bone);
}

static void _sortPathConstraintAttachmentBones(_sp38Skeleton* const internal, sp38Attachment* attachment, sp38Bone* slotBone) {
	sp38PathAttachment* pathAttachment = (sp38PathAttachment*)attachment;
	int* pathBones;
	int pathBonesCount;
	if (pathAttachment->super.super.type != SP_ATTACHMENT_PATH) return;
	pathBones = pathAttachment->super.bones;
	pathBonesCount = pathAttachment->super.bonesCount;
	if (pathBones == 0)
		_sortBone(internal, slotBone);
	else {
		sp38Bone** bones = internal->super.bones;
		int i = 0, n;
		while (i < pathBonesCount) {
			int boneCount = pathBones[i++];
			for (n = i + boneCount; i < n; i++)
				_sortBone(internal, bones[pathBones[i]]);
		}
	}
}

static void _sortPathConstraintAttachment(_sp38Skeleton* const internal, sp38Skin* skin, int slotIndex, sp38Bone* slotBone) {
	_Entry* entry = SUB_CAST(_sp38Skin, skin)->entries;
	while (entry) {
		if (entry->slotIndex == slotIndex) _sortPathConstraintAttachmentBones(internal, entry->attachment, slotBone);
		entry = entry->next;
	}
}

static void _sortReset(sp38Bone** bones, int bonesCount) {
	int i;
	for (i = 0; i < bonesCount; ++i) {
		sp38Bone* bone = bones[i];
		if (!bone->active) continue;
		if (bone->sorted) _sortReset(bone->children, bone->childrenCount);
		bone->sorted = 0;
	}
}

static void _sortIkConstraint (_sp38Skeleton* const internal, sp38IkConstraint* constraint) {
	int /*bool*/ contains = 0;
	int i;
	sp38Bone* target = constraint->target;
	sp38Bone** constrained;
	sp38Bone* parent;

	constraint->active = constraint->target->active && (!constraint->data->skinRequired || (internal->super.skin != 0 && sp38IkConstraintDataArray_contains(internal->super.skin->ikConstraints, constraint->data)));
	if (!constraint->active) return;

	_sortBone(internal, target);

	constrained = constraint->bones;
	parent = constrained[0];
	_sortBone(internal, parent);

	if (constraint->bonesCount > 1) {
		sp38Bone* child = constrained[constraint->bonesCount - 1];
		contains = 0;
		for (i = 0; i < internal->updateCacheCount; i++) {
			_sp38Update update = internal->updateCache[i];
			if (update.object == child) {
				contains = -1;
				break;
			}
		}
		if (!contains) _addToUpdateCacheReset(internal, child);
	}

	_addToUpdateCache(internal, SP_UPDATE_IK_CONSTRAINT, constraint);

	_sortReset(parent->children, parent->childrenCount);
	constrained[constraint->bonesCount-1]->sorted = 1;
}

static void _sortPathConstraint(_sp38Skeleton* const internal, sp38PathConstraint* constraint) {
	sp38Slot* slot = constraint->target;
	int slotIndex = slot->data->index;
	sp38Bone* slotBone = slot->bone;
	int i, n, boneCount;
	sp38Attachment* attachment;
	sp38Bone** constrained;
	sp38Skeleton* skeleton = SUPER_CAST(sp38Skeleton, internal);

	constraint->active = constraint->target->bone->active && (!constraint->data->skinRequired || (internal->super.skin != 0 && sp38PathConstraintDataArray_contains(internal->super.skin->pathConstraints, constraint->data)));
	if (!constraint->active) return;

	if (skeleton->skin) _sortPathConstraintAttachment(internal, skeleton->skin, slotIndex, slotBone);
	if (skeleton->data->defaultSkin && skeleton->data->defaultSkin != skeleton->skin)
		_sortPathConstraintAttachment(internal, skeleton->data->defaultSkin, slotIndex, slotBone);
	for (i = 0, n = skeleton->data->skinsCount; i < n; i++)
		_sortPathConstraintAttachment(internal, skeleton->data->skins[i], slotIndex, slotBone);

	attachment = slot->attachment;
	if (attachment && attachment->type == SP_ATTACHMENT_PATH) _sortPathConstraintAttachmentBones(internal, attachment, slotBone);

	constrained = constraint->bones;
	boneCount = constraint->bonesCount;
	for (i = 0; i < boneCount; i++)
		_sortBone(internal, constrained[i]);

	_addToUpdateCache(internal, SP_UPDATE_PATH_CONSTRAINT, constraint);

	for (i = 0; i < boneCount; i++)
		_sortReset(constrained[i]->children, constrained[i]->childrenCount);
	for (i = 0; i < boneCount; i++)
		constrained[i]->sorted = 1;
}

static void _sortTransformConstraint(_sp38Skeleton* const internal, sp38TransformConstraint* constraint) {
	int i, boneCount;
	sp38Bone** constrained;
	sp38Bone* child;
	int /*boolean*/ contains = 0;

	constraint->active = constraint->target->active && (!constraint->data->skinRequired || (internal->super.skin != 0 && sp38TransformConstraintDataArray_contains(internal->super.skin->transformConstraints, constraint->data)));
	if (!constraint->active) return;

	_sortBone(internal, constraint->target);

	constrained = constraint->bones;
	boneCount = constraint->bonesCount;
	if (constraint->data->local) {
		for (i = 0; i < boneCount; i++) {
			child = constrained[i];
			_sortBone(internal, child);
			contains = 0;
			for (i = 0; i < internal->updateCacheCount; i++) {
				_sp38Update update = internal->updateCache[i];
				if (update.object == child) {
					contains = -1;
					break;
				}
			}
			if (!contains) _addToUpdateCacheReset(internal, child);
		}
	} else {
		for (i = 0; i < boneCount; i++)
			_sortBone(internal, constrained[i]);
	}

	_addToUpdateCache(internal, SP_UPDATE_TRANSFORM_CONSTRAINT, constraint);

	for (i = 0; i < boneCount; i++)
		_sortReset(constrained[i]->children, constrained[i]->childrenCount);
	for (i = 0; i < boneCount; i++)
		constrained[i]->sorted = 1;
}

void sp38Skeleton_updateCache (sp38Skeleton* self) {
	int i, ii;
	sp38Bone** bones;
	sp38IkConstraint** ikConstraints;
	sp38PathConstraint** pathConstraints;
	sp38TransformConstraint** transformConstraints;
	int ikCount, transformCount, pathCount, constraintCount;
	_sp38Skeleton* internal = SUB_CAST(_sp38Skeleton, self);

	internal->updateCacheCapacity = self->bonesCount + self->ikConstraintsCount + self->transformConstraintsCount + self->pathConstraintsCount;
	FREE(internal->updateCache);
	internal->updateCache = MALLOC(_sp38Update, internal->updateCacheCapacity);
	internal->updateCacheCount = 0;

	internal->updateCacheResetCapacity = self->bonesCount;
	FREE(internal->updateCacheReset);
	internal->updateCacheReset = MALLOC(sp38Bone*, internal->updateCacheResetCapacity);
	internal->updateCacheResetCount = 0;

	bones = self->bones;
	for (i = 0; i < self->bonesCount; ++i) {
		sp38Bone* bone = bones[i];
		bone->sorted = bone->data->skinRequired;
		bone->active = !bone->sorted;
	}

	if (self->skin) {
		sp38BoneDataArray* skinBones = self->skin->bones;
		for(i = 0; i < skinBones->size; i++) {
			sp38Bone* bone = self->bones[skinBones->items[i]->index];
			do {
				bone->sorted = 0;
				bone->active = -1;
				bone = bone->parent;
			} while (bone != 0);
		}
	}

	/* IK first, lowest hierarchy depth first. */
	ikConstraints = self->ikConstraints;
	transformConstraints = self->transformConstraints;
	pathConstraints = self->pathConstraints;
	ikCount = self->ikConstraintsCount; transformCount = self->transformConstraintsCount; pathCount = self->pathConstraintsCount;
	constraintCount = ikCount + transformCount + pathCount;

	i = 0;
	continue_outer:
	for (; i < constraintCount; i++) {
		for (ii = 0; ii < ikCount; ii++) {
			sp38IkConstraint* ikConstraint = ikConstraints[ii];
			if (ikConstraint->data->order == i) {
				_sortIkConstraint(internal, ikConstraint);
				i++;
				goto continue_outer;
			}
		}

		for (ii = 0; ii < transformCount; ii++) {
			sp38TransformConstraint* transformConstraint = transformConstraints[ii];
			if (transformConstraint->data->order == i) {
				_sortTransformConstraint(internal, transformConstraint);
				i++;
				goto continue_outer;
			}
		}

		for (ii = 0; ii < pathCount; ii++) {
			sp38PathConstraint* pathConstraint = pathConstraints[ii];
			if (pathConstraint->data->order == i) {
				_sortPathConstraint(internal, pathConstraint);
				i++;
				goto continue_outer;
			}
		}
	}

	for (i = 0; i < self->bonesCount; ++i)
		_sortBone(internal, self->bones[i]);
}

void sp38Skeleton_updateWorldTransform (const sp38Skeleton* self) {
	int i;
	_sp38Skeleton* internal = SUB_CAST(_sp38Skeleton, self);
	sp38Bone** updateCacheReset = internal->updateCacheReset;
	for (i = 0; i < internal->updateCacheResetCount; i++) {
		sp38Bone* bone = updateCacheReset[i];
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
		_sp38Update* update = internal->updateCache + i;
		switch (update->type) {
		case SP_UPDATE_BONE:
			sp38Bone_updateWorldTransform((sp38Bone*)update->object);
			break;
		case SP_UPDATE_IK_CONSTRAINT:
			sp38IkConstraint_apply((sp38IkConstraint*)update->object);
			break;
		case SP_UPDATE_TRANSFORM_CONSTRAINT:
			sp38TransformConstraint_apply((sp38TransformConstraint*)update->object);
			break;
		case SP_UPDATE_PATH_CONSTRAINT:
			sp38PathConstraint_apply((sp38PathConstraint*)update->object);
			break;
		}
	}
}

void sp38Skeleton_setToSetupPose (const sp38Skeleton* self) {
	sp38Skeleton_setBonesToSetupPose(self);
	sp38Skeleton_setSlotsToSetupPose(self);
}

void sp38Skeleton_setBonesToSetupPose (const sp38Skeleton* self) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		sp38Bone_setToSetupPose(self->bones[i]);

	for (i = 0; i < self->ikConstraintsCount; ++i) {
		sp38IkConstraint* ikConstraint = self->ikConstraints[i];
		ikConstraint->bendDirection = ikConstraint->data->bendDirection;
		ikConstraint->compress = ikConstraint->data->compress;
		ikConstraint->stretch = ikConstraint->data->stretch;
		ikConstraint->softness = ikConstraint->data->softness;
		ikConstraint->mix = ikConstraint->data->mix;
	}

	for (i = 0; i < self->transformConstraintsCount; ++i) {
		sp38TransformConstraint* constraint = self->transformConstraints[i];
		sp38TransformConstraintData* data = constraint->data;
		constraint->rotateMix = data->rotateMix;
		constraint->translateMix = data->translateMix;
		constraint->scaleMix = data->scaleMix;
		constraint->shearMix = data->shearMix;
	}

	for (i = 0; i < self->pathConstraintsCount; ++i) {
		sp38PathConstraint* constraint = self->pathConstraints[i];
		sp38PathConstraintData* data = constraint->data;
		constraint->position = data->position;
		constraint->spacing = data->spacing;
		constraint->rotateMix = data->rotateMix;
		constraint->translateMix = data->translateMix;
	}
}

void sp38Skeleton_setSlotsToSetupPose (const sp38Skeleton* self) {
	int i;
	memcpy(self->drawOrder, self->slots, self->slotsCount * sizeof(sp38Slot*));
	for (i = 0; i < self->slotsCount; ++i)
		sp38Slot_setToSetupPose(self->slots[i]);
}

sp38Bone* sp38Skeleton_findBone (const sp38Skeleton* self, const char* boneName) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		if (strcmp(self->data->bones[i]->name, boneName) == 0) return self->bones[i];
	return 0;
}

int sp38Skeleton_findBoneIndex (const sp38Skeleton* self, const char* boneName) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		if (strcmp(self->data->bones[i]->name, boneName) == 0) return i;
	return -1;
}

sp38Slot* sp38Skeleton_findSlot (const sp38Skeleton* self, const char* slotName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i)
		if (strcmp(self->data->slots[i]->name, slotName) == 0) return self->slots[i];
	return 0;
}

int sp38Skeleton_findSlotIndex (const sp38Skeleton* self, const char* slotName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i)
		if (strcmp(self->data->slots[i]->name, slotName) == 0) return i;
	return -1;
}

int sp38Skeleton_setSkinByName (sp38Skeleton* self, const char* skinName) {
	sp38Skin *skin;
	if (!skinName) {
		sp38Skeleton_setSkin(self, 0);
		return 1;
	}
	skin = sp38SkeletonData_findSkin(self->data, skinName);
	if (!skin) return 0;
	sp38Skeleton_setSkin(self, skin);
	return 1;
}

void sp38Skeleton_setSkin (sp38Skeleton* self, sp38Skin* newSkin) {
	if (self->skin == newSkin) return;
	if (newSkin) {
		if (self->skin)
			sp38Skin_attachAll(newSkin, self, self->skin);
		else {
			/* No previous skin, attach setup pose attachments. */
			int i;
			for (i = 0; i < self->slotsCount; ++i) {
				sp38Slot* slot = self->slots[i];
				if (slot->data->attachmentName) {
					sp38Attachment* attachment = sp38Skin_getAttachment(newSkin, i, slot->data->attachmentName);
					if (attachment) sp38Slot_setAttachment(slot, attachment);
				}
			}
		}
	}
	CONST_CAST(sp38Skin*, self->skin) = newSkin;
	sp38Skeleton_updateCache(self);
}

sp38Attachment* sp38Skeleton_getAttachmentForSlotName (const sp38Skeleton* self, const char* slotName, const char* attachmentName) {
	int slotIndex = sp38SkeletonData_findSlotIndex(self->data, slotName);
	return sp38Skeleton_getAttachmentForSlotIndex(self, slotIndex, attachmentName);
}

sp38Attachment* sp38Skeleton_getAttachmentForSlotIndex (const sp38Skeleton* self, int slotIndex, const char* attachmentName) {
	if (slotIndex == -1) return 0;
	if (self->skin) {
		sp38Attachment *attachment = sp38Skin_getAttachment(self->skin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	if (self->data->defaultSkin) {
		sp38Attachment *attachment = sp38Skin_getAttachment(self->data->defaultSkin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	return 0;
}

int sp38Skeleton_setAttachment (sp38Skeleton* self, const char* slotName, const char* attachmentName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i) {
		sp38Slot *slot = self->slots[i];
		if (strcmp(slot->data->name, slotName) == 0) {
			if (!attachmentName)
				sp38Slot_setAttachment(slot, 0);
			else {
				sp38Attachment* attachment = sp38Skeleton_getAttachmentForSlotIndex(self, i, attachmentName);
				if (!attachment) return 0;
				sp38Slot_setAttachment(slot, attachment);
			}
			return 1;
		}
	}
	return 0;
}

sp38IkConstraint* sp38Skeleton_findIkConstraint (const sp38Skeleton* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->ikConstraintsCount; ++i)
		if (strcmp(self->ikConstraints[i]->data->name, constraintName) == 0) return self->ikConstraints[i];
	return 0;
}

sp38TransformConstraint* sp38Skeleton_findTransformConstraint (const sp38Skeleton* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->transformConstraintsCount; ++i)
		if (strcmp(self->transformConstraints[i]->data->name, constraintName) == 0) return self->transformConstraints[i];
	return 0;
}

sp38PathConstraint* sp38Skeleton_findPathConstraint (const sp38Skeleton* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->pathConstraintsCount; ++i)
		if (strcmp(self->pathConstraints[i]->data->name, constraintName) == 0) return self->pathConstraints[i];
	return 0;
}

void sp38Skeleton_update (sp38Skeleton* self, float deltaTime) {
	self->time += deltaTime;
}

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
} _sp36UpdateType;

typedef struct {
	_sp36UpdateType type;
	void* object;
} _sp36Update;

typedef struct {
	sp36Skeleton super;

	int updateCacheCount;
	int updateCacheCapacity;
	_sp36Update* updateCache;

	int updateCacheResetCount;
	int updateCacheResetCapacity;
	sp36Bone** updateCacheReset;
} _sp36Skeleton;

sp36Skeleton* sp36Skeleton_create (sp36SkeletonData* data) {
	int i;
	int* childrenCounts;

	_sp36Skeleton* internal = NEW(_sp36Skeleton);
	sp36Skeleton* self = SUPER(internal);
	CONST_CAST(sp36SkeletonData*, self->data) = data;

	self->bonesCount = self->data->bonesCount;
	self->bones = MALLOC(sp36Bone*, self->bonesCount);
	childrenCounts = CALLOC(int, self->bonesCount);

	for (i = 0; i < self->bonesCount; ++i) {
		sp36BoneData* boneData = self->data->bones[i];
		sp36Bone* newBone;
		if (!boneData->parent)
			newBone = sp36Bone_create(boneData, self, 0);
		else {
			sp36Bone* parent = self->bones[boneData->parent->index];
			newBone = sp36Bone_create(boneData, self, parent);
			++childrenCounts[boneData->parent->index];
		}
		self->bones[i] = newBone;
	}
	for (i = 0; i < self->bonesCount; ++i) {
		sp36BoneData* boneData = self->data->bones[i];
		sp36Bone* bone = self->bones[i];
		CONST_CAST(sp36Bone**, bone->children) = MALLOC(sp36Bone*, childrenCounts[boneData->index]);
	}
	for (i = 0; i < self->bonesCount; ++i) {
		sp36Bone* bone = self->bones[i];
		sp36Bone* parent = bone->parent;
		if (parent)
			parent->children[parent->childrenCount++] = bone;
	}
	CONST_CAST(sp36Bone*, self->root) = (self->bonesCount > 0 ? self->bones[0] : NULL);

	self->slotsCount = data->slotsCount;
	self->slots = MALLOC(sp36Slot*, self->slotsCount);
	for (i = 0; i < self->slotsCount; ++i) {
		sp36SlotData *slotData = data->slots[i];
		sp36Bone* bone = self->bones[slotData->boneData->index];
		self->slots[i] = sp36Slot_create(slotData, bone);
	}

	self->drawOrder = MALLOC(sp36Slot*, self->slotsCount);
	memcpy(self->drawOrder, self->slots, sizeof(sp36Slot*) * self->slotsCount);

	self->ikConstraintsCount = data->ikConstraintsCount;
	self->ikConstraints = MALLOC(sp36IkConstraint*, self->ikConstraintsCount);
	for (i = 0; i < self->data->ikConstraintsCount; ++i)
		self->ikConstraints[i] = sp36IkConstraint_create(self->data->ikConstraints[i], self);

	self->transformConstraintsCount = data->transformConstraintsCount;
	self->transformConstraints = MALLOC(sp36TransformConstraint*, self->transformConstraintsCount);
	for (i = 0; i < self->data->transformConstraintsCount; ++i)
		self->transformConstraints[i] = sp36TransformConstraint_create(self->data->transformConstraints[i], self);

	self->pathConstraintsCount = data->pathConstraintsCount;
	self->pathConstraints = MALLOC(sp36PathConstraint*, self->pathConstraintsCount);
	for (i = 0; i < self->data->pathConstraintsCount; i++)
		self->pathConstraints[i] = sp36PathConstraint_create(self->data->pathConstraints[i], self);

	sp36Color_setFromFloats(&self->color, 1, 1, 1, 1);

	sp36Skeleton_updateCache(self);

	FREE(childrenCounts);

	return self;
}

void sp36Skeleton_dispose (sp36Skeleton* self) {
	int i;
	_sp36Skeleton* internal = SUB_CAST(_sp36Skeleton, self);

	FREE(internal->updateCache);
	FREE(internal->updateCacheReset);

	for (i = 0; i < self->bonesCount; ++i)
		sp36Bone_dispose(self->bones[i]);
	FREE(self->bones);

	for (i = 0; i < self->slotsCount; ++i)
		sp36Slot_dispose(self->slots[i]);
	FREE(self->slots);

	for (i = 0; i < self->ikConstraintsCount; ++i)
		sp36IkConstraint_dispose(self->ikConstraints[i]);
	FREE(self->ikConstraints);

	for (i = 0; i < self->transformConstraintsCount; ++i)
		sp36TransformConstraint_dispose(self->transformConstraints[i]);
	FREE(self->transformConstraints);

	for (i = 0; i < self->pathConstraintsCount; i++)
		sp36PathConstraint_dispose(self->pathConstraints[i]);
	FREE(self->pathConstraints);

	FREE(self->drawOrder);
	FREE(self);
}

static void _addToUpdateCache(_sp36Skeleton* const internal, _sp36UpdateType type, void *object) {
	_sp36Update* update;
	if (internal->updateCacheCount == internal->updateCacheCapacity) {
		internal->updateCacheCapacity *= 2;
		internal->updateCache = (_sp36Update*)realloc(internal->updateCache, sizeof(_sp36Update) * internal->updateCacheCapacity);
	}
	update = internal->updateCache + internal->updateCacheCount;
	update->type = type;
	update->object = object;
	++internal->updateCacheCount;
}

static void _addToUpdateCacheReset(_sp36Skeleton* const internal, sp36Bone* bone) {
	if (internal->updateCacheResetCount == internal->updateCacheResetCapacity) {
		internal->updateCacheResetCapacity *= 2;
		internal->updateCacheReset = (sp36Bone**)realloc(internal->updateCacheReset, sizeof(sp36Bone*) * internal->updateCacheResetCapacity);
	}
	internal->updateCacheReset[internal->updateCacheResetCount] = bone;
	++internal->updateCacheResetCount;
}

static void _sortBone(_sp36Skeleton* const internal, sp36Bone* bone) {
	if (bone->sorted) return;
	if (bone->parent) _sortBone(internal, bone->parent);
	bone->sorted = 1;
	_addToUpdateCache(internal, SP_UPDATE_BONE, bone);
}

static void _sortPathConstraintAttachmentBones(_sp36Skeleton* const internal, sp36Attachment* attachment, sp36Bone* slotBone) {
	sp36PathAttachment* pathAttachment = (sp36PathAttachment*)attachment;
	int* pathBones;
	int pathBonesCount;
	if (pathAttachment->super.super.type != SP_ATTACHMENT_PATH) return;
	pathBones = pathAttachment->super.bones;
	pathBonesCount = pathAttachment->super.bonesCount;
	if (pathBones == 0)
		_sortBone(internal, slotBone);
	else {
		sp36Bone** bones = internal->super.bones;
		int i = 0, n;
		while (i < pathBonesCount) {
			int boneCount = pathBones[i++];
			for (n = i + boneCount; i < n; i++)
				_sortBone(internal, bones[pathBones[i]]);
		}
	}
}

static void _sortPathConstraintAttachment(_sp36Skeleton* const internal, sp36Skin* skin, int slotIndex, sp36Bone* slotBone) {
	_Entry* entry = SUB_CAST(_sp36Skin, skin)->entries;
	while (entry) {
		if (entry->slotIndex == slotIndex) _sortPathConstraintAttachmentBones(internal, entry->attachment, slotBone);
		entry = entry->next;
	}
}

static void _sortReset(sp36Bone** bones, int bonesCount) {
	int i;
	for (i = 0; i < bonesCount; ++i) {
		sp36Bone* bone = bones[i];
		if (bone->sorted) _sortReset(bone->children, bone->childrenCount);
		bone->sorted = 0;
	}
}

static void _sortIkConstraint (_sp36Skeleton* const internal, sp36IkConstraint* constraint) {
	int /*bool*/ contains = 0;
	int i;
	sp36Bone* target = constraint->target;
	sp36Bone** constrained;
	sp36Bone* parent;
	_sortBone(internal, target);

	constrained = constraint->bones;
	parent = constrained[0];
	_sortBone(internal, parent);

	if (constraint->bonesCount > 1) {
		sp36Bone* child = constrained[constraint->bonesCount - 1];
		contains = 0;
		for (i = 0; i < internal->updateCacheCount; i++) {
			_sp36Update update = internal->updateCache[i];
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

static void _sortPathConstraint(_sp36Skeleton* const internal, sp36PathConstraint* constraint) {
	sp36Slot* slot = constraint->target;
	int slotIndex = slot->data->index;
	sp36Bone* slotBone = slot->bone;
	int i, n, boneCount;
	sp36Attachment* attachment;
	sp36Bone** constrained;
	sp36Skeleton* skeleton = SUPER_CAST(sp36Skeleton, internal);
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

static void _sortTransformConstraint(_sp36Skeleton* const internal, sp36TransformConstraint* constraint) {
	int i, boneCount;
	sp36Bone** constrained;
	sp36Bone* child;
	int /*boolean*/ contains = 0;
	_sortBone(internal, constraint->target);

	constrained = constraint->bones;
	boneCount = constraint->bonesCount;
	if (constraint->data->local) {
		for (i = 0; i < boneCount; i++) {
			child = constrained[i];
			_sortBone(internal, child);
			contains = 0;
			for (i = 0; i < internal->updateCacheCount; i++) {
				_sp36Update update = internal->updateCache[i];
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

void sp36Skeleton_updateCache (sp36Skeleton* self) {
	int i, ii;
	sp36Bone** bones;
	sp36IkConstraint** ikConstraints;
	sp36PathConstraint** pathConstraints;
	sp36TransformConstraint** transformConstraints;
	int ikCount, transformCount, pathCount, constraintCount;
	_sp36Skeleton* internal = SUB_CAST(_sp36Skeleton, self);

	internal->updateCacheCapacity = self->bonesCount + self->ikConstraintsCount + self->transformConstraintsCount + self->pathConstraintsCount;
	FREE(internal->updateCache);
	internal->updateCache = MALLOC(_sp36Update, internal->updateCacheCapacity);
	internal->updateCacheCount = 0;

	internal->updateCacheResetCapacity = self->bonesCount;
	FREE(internal->updateCacheReset);
	internal->updateCacheReset = MALLOC(sp36Bone*, internal->updateCacheResetCapacity);
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
	continue_outer:
	for (; i < constraintCount; i++) {
		for (ii = 0; ii < ikCount; ii++) {
			sp36IkConstraint* ikConstraint = ikConstraints[ii];
			if (ikConstraint->data->order == i) {
				_sortIkConstraint(internal, ikConstraint);
				i++;
				goto continue_outer;
			}
		}

		for (ii = 0; ii < transformCount; ii++) {
			sp36TransformConstraint* transformConstraint = transformConstraints[ii];
			if (transformConstraint->data->order == i) {
				_sortTransformConstraint(internal, transformConstraint);
				i++;
				goto continue_outer;
			}
		}

		for (ii = 0; ii < pathCount; ii++) {
			sp36PathConstraint* pathConstraint = pathConstraints[ii];
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

void sp36Skeleton_updateWorldTransform (const sp36Skeleton* self) {
	int i;
	_sp36Skeleton* internal = SUB_CAST(_sp36Skeleton, self);
	sp36Bone** updateCacheReset = internal->updateCacheReset;
	for (i = 0; i < internal->updateCacheResetCount; i++) {
		sp36Bone* bone = updateCacheReset[i];
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
		_sp36Update* update = internal->updateCache + i;
		switch (update->type) {
		case SP_UPDATE_BONE:
			sp36Bone_updateWorldTransform((sp36Bone*)update->object);
			break;
		case SP_UPDATE_IK_CONSTRAINT:
			sp36IkConstraint_apply((sp36IkConstraint*)update->object);
			break;
		case SP_UPDATE_TRANSFORM_CONSTRAINT:
			sp36TransformConstraint_apply((sp36TransformConstraint*)update->object);
			break;
		case SP_UPDATE_PATH_CONSTRAINT:
			sp36PathConstraint_apply((sp36PathConstraint*)update->object);
			break;
		}
	}
}

void sp36Skeleton_setToSetupPose (const sp36Skeleton* self) {
	sp36Skeleton_setBonesToSetupPose(self);
	sp36Skeleton_setSlotsToSetupPose(self);
}

void sp36Skeleton_setBonesToSetupPose (const sp36Skeleton* self) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		sp36Bone_setToSetupPose(self->bones[i]);

	for (i = 0; i < self->ikConstraintsCount; ++i) {
		sp36IkConstraint* ikConstraint = self->ikConstraints[i];
		ikConstraint->bendDirection = ikConstraint->data->bendDirection;
		ikConstraint->mix = ikConstraint->data->mix;
	}

	for (i = 0; i < self->transformConstraintsCount; ++i) {
		sp36TransformConstraint* constraint = self->transformConstraints[i];
		sp36TransformConstraintData* data = constraint->data;
		constraint->rotateMix = data->rotateMix;
		constraint->translateMix = data->translateMix;
		constraint->scaleMix = data->scaleMix;
		constraint->shearMix = data->shearMix;
	}

	for (i = 0; i < self->pathConstraintsCount; ++i) {
		sp36PathConstraint* constraint = self->pathConstraints[i];
		sp36PathConstraintData* data = constraint->data;
		constraint->position = data->position;
		constraint->spacing = data->spacing;
		constraint->rotateMix = data->rotateMix;
		constraint->translateMix = data->translateMix;
	}
}

void sp36Skeleton_setSlotsToSetupPose (const sp36Skeleton* self) {
	int i;
	memcpy(self->drawOrder, self->slots, self->slotsCount * sizeof(sp36Slot*));
	for (i = 0; i < self->slotsCount; ++i)
		sp36Slot_setToSetupPose(self->slots[i]);
}

sp36Bone* sp36Skeleton_findBone (const sp36Skeleton* self, const char* boneName) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		if (strcmp(self->data->bones[i]->name, boneName) == 0) return self->bones[i];
	return 0;
}

int sp36Skeleton_findBoneIndex (const sp36Skeleton* self, const char* boneName) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		if (strcmp(self->data->bones[i]->name, boneName) == 0) return i;
	return -1;
}

sp36Slot* sp36Skeleton_findSlot (const sp36Skeleton* self, const char* slotName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i)
		if (strcmp(self->data->slots[i]->name, slotName) == 0) return self->slots[i];
	return 0;
}

int sp36Skeleton_findSlotIndex (const sp36Skeleton* self, const char* slotName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i)
		if (strcmp(self->data->slots[i]->name, slotName) == 0) return i;
	return -1;
}

int sp36Skeleton_setSkinByName (sp36Skeleton* self, const char* skinName) {
	sp36Skin *skin;
	if (!skinName) {
		sp36Skeleton_setSkin(self, 0);
		return 1;
	}
	skin = sp36SkeletonData_findSkin(self->data, skinName);
	if (!skin) return 0;
	sp36Skeleton_setSkin(self, skin);
	return 1;
}

void sp36Skeleton_setSkin (sp36Skeleton* self, sp36Skin* newSkin) {
	if (newSkin) {
		if (self->skin)
			sp36Skin_attachAll(newSkin, self, self->skin);
		else {
			/* No previous skin, attach setup pose attachments. */
			int i;
			for (i = 0; i < self->slotsCount; ++i) {
				sp36Slot* slot = self->slots[i];
				if (slot->data->attachmentName) {
					sp36Attachment* attachment = sp36Skin_getAttachment(newSkin, i, slot->data->attachmentName);
					if (attachment) sp36Slot_setAttachment(slot, attachment);
				}
			}
		}
	}
	CONST_CAST(sp36Skin*, self->skin) = newSkin;
}

sp36Attachment* sp36Skeleton_getAttachmentForSlotName (const sp36Skeleton* self, const char* slotName, const char* attachmentName) {
	int slotIndex = sp36SkeletonData_findSlotIndex(self->data, slotName);
	return sp36Skeleton_getAttachmentForSlotIndex(self, slotIndex, attachmentName);
}

sp36Attachment* sp36Skeleton_getAttachmentForSlotIndex (const sp36Skeleton* self, int slotIndex, const char* attachmentName) {
	if (slotIndex == -1) return 0;
	if (self->skin) {
		sp36Attachment *attachment = sp36Skin_getAttachment(self->skin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	if (self->data->defaultSkin) {
		sp36Attachment *attachment = sp36Skin_getAttachment(self->data->defaultSkin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	return 0;
}

int sp36Skeleton_setAttachment (sp36Skeleton* self, const char* slotName, const char* attachmentName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i) {
		sp36Slot *slot = self->slots[i];
		if (strcmp(slot->data->name, slotName) == 0) {
			if (!attachmentName)
				sp36Slot_setAttachment(slot, 0);
			else {
				sp36Attachment* attachment = sp36Skeleton_getAttachmentForSlotIndex(self, i, attachmentName);
				if (!attachment) return 0;
				sp36Slot_setAttachment(slot, attachment);
			}
			return 1;
		}
	}
	return 0;
}

sp36IkConstraint* sp36Skeleton_findIkConstraint (const sp36Skeleton* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->ikConstraintsCount; ++i)
		if (strcmp(self->ikConstraints[i]->data->name, constraintName) == 0) return self->ikConstraints[i];
	return 0;
}

sp36TransformConstraint* sp36Skeleton_findTransformConstraint (const sp36Skeleton* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->transformConstraintsCount; ++i)
		if (strcmp(self->transformConstraints[i]->data->name, constraintName) == 0) return self->transformConstraints[i];
	return 0;
}

sp36PathConstraint* sp36Skeleton_findPathConstraint (const sp36Skeleton* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->pathConstraintsCount; ++i)
		if (strcmp(self->pathConstraints[i]->data->name, constraintName) == 0) return self->pathConstraints[i];
	return 0;
}

void sp36Skeleton_update (sp36Skeleton* self, float deltaTime) {
	self->time += deltaTime;
}

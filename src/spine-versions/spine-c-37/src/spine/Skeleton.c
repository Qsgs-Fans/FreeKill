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

#include <spine/Skeleton.h>
#include <stdlib.h>
#include <string.h>
#include <spine/extension.h>

typedef enum {
	SP_UPDATE_BONE, SP_UPDATE_IK_CONSTRAINT, SP_UPDATE_PATH_CONSTRAINT, SP_UPDATE_TRANSFORM_CONSTRAINT
} _sp37UpdateType;

typedef struct {
	_sp37UpdateType type;
	void* object;
} _sp37Update;

typedef struct {
	sp37Skeleton super;

	int updateCacheCount;
	int updateCacheCapacity;
	_sp37Update* updateCache;

	int updateCacheResetCount;
	int updateCacheResetCapacity;
	sp37Bone** updateCacheReset;
} _sp37Skeleton;

sp37Skeleton* sp37Skeleton_create (sp37SkeletonData* data) {
	int i;
	int* childrenCounts;

	_sp37Skeleton* internal = NEW(_sp37Skeleton);
	sp37Skeleton* self = SUPER(internal);
	CONST_CAST(sp37SkeletonData*, self->data) = data;

	self->bonesCount = self->data->bonesCount;
	self->bones = MALLOC(sp37Bone*, self->bonesCount);
	childrenCounts = CALLOC(int, self->bonesCount);

	for (i = 0; i < self->bonesCount; ++i) {
		sp37BoneData* boneData = self->data->bones[i];
		sp37Bone* newBone;
		if (!boneData->parent)
			newBone = sp37Bone_create(boneData, self, 0);
		else {
			sp37Bone* parent = self->bones[boneData->parent->index];
			newBone = sp37Bone_create(boneData, self, parent);
			++childrenCounts[boneData->parent->index];
		}
		self->bones[i] = newBone;
	}
	for (i = 0; i < self->bonesCount; ++i) {
		sp37BoneData* boneData = self->data->bones[i];
		sp37Bone* bone = self->bones[i];
		CONST_CAST(sp37Bone**, bone->children) = MALLOC(sp37Bone*, childrenCounts[boneData->index]);
	}
	for (i = 0; i < self->bonesCount; ++i) {
		sp37Bone* bone = self->bones[i];
		sp37Bone* parent = bone->parent;
		if (parent)
			parent->children[parent->childrenCount++] = bone;
	}
	CONST_CAST(sp37Bone*, self->root) = (self->bonesCount > 0 ? self->bones[0] : NULL);

	self->slotsCount = data->slotsCount;
	self->slots = MALLOC(sp37Slot*, self->slotsCount);
	for (i = 0; i < self->slotsCount; ++i) {
		sp37SlotData *slotData = data->slots[i];
		sp37Bone* bone = self->bones[slotData->boneData->index];
		self->slots[i] = sp37Slot_create(slotData, bone);
	}

	self->drawOrder = MALLOC(sp37Slot*, self->slotsCount);
	memcpy(self->drawOrder, self->slots, sizeof(sp37Slot*) * self->slotsCount);

	self->ikConstraintsCount = data->ikConstraintsCount;
	self->ikConstraints = MALLOC(sp37IkConstraint*, self->ikConstraintsCount);
	for (i = 0; i < self->data->ikConstraintsCount; ++i)
		self->ikConstraints[i] = sp37IkConstraint_create(self->data->ikConstraints[i], self);

	self->transformConstraintsCount = data->transformConstraintsCount;
	self->transformConstraints = MALLOC(sp37TransformConstraint*, self->transformConstraintsCount);
	for (i = 0; i < self->data->transformConstraintsCount; ++i)
		self->transformConstraints[i] = sp37TransformConstraint_create(self->data->transformConstraints[i], self);

	self->pathConstraintsCount = data->pathConstraintsCount;
	self->pathConstraints = MALLOC(sp37PathConstraint*, self->pathConstraintsCount);
	for (i = 0; i < self->data->pathConstraintsCount; i++)
		self->pathConstraints[i] = sp37PathConstraint_create(self->data->pathConstraints[i], self);

	sp37Color_setFromFloats(&self->color, 1, 1, 1, 1);

	self->scaleX = 1;
	self->scaleY = 1;

	sp37Skeleton_updateCache(self);

	FREE(childrenCounts);

	return self;
}

void sp37Skeleton_dispose (sp37Skeleton* self) {
	int i;
	_sp37Skeleton* internal = SUB_CAST(_sp37Skeleton, self);

	FREE(internal->updateCache);
	FREE(internal->updateCacheReset);

	for (i = 0; i < self->bonesCount; ++i)
		sp37Bone_dispose(self->bones[i]);
	FREE(self->bones);

	for (i = 0; i < self->slotsCount; ++i)
		sp37Slot_dispose(self->slots[i]);
	FREE(self->slots);

	for (i = 0; i < self->ikConstraintsCount; ++i)
		sp37IkConstraint_dispose(self->ikConstraints[i]);
	FREE(self->ikConstraints);

	for (i = 0; i < self->transformConstraintsCount; ++i)
		sp37TransformConstraint_dispose(self->transformConstraints[i]);
	FREE(self->transformConstraints);

	for (i = 0; i < self->pathConstraintsCount; i++)
		sp37PathConstraint_dispose(self->pathConstraints[i]);
	FREE(self->pathConstraints);

	FREE(self->drawOrder);
	FREE(self);
}

static void _addToUpdateCache(_sp37Skeleton* const internal, _sp37UpdateType type, void *object) {
	_sp37Update* update;
	if (internal->updateCacheCount == internal->updateCacheCapacity) {
		internal->updateCacheCapacity *= 2;
		internal->updateCache = (_sp37Update*)realloc(internal->updateCache, sizeof(_sp37Update) * internal->updateCacheCapacity);
	}
	update = internal->updateCache + internal->updateCacheCount;
	update->type = type;
	update->object = object;
	++internal->updateCacheCount;
}

static void _addToUpdateCacheReset(_sp37Skeleton* const internal, sp37Bone* bone) {
	if (internal->updateCacheResetCount == internal->updateCacheResetCapacity) {
		internal->updateCacheResetCapacity *= 2;
		internal->updateCacheReset = (sp37Bone**)realloc(internal->updateCacheReset, sizeof(sp37Bone*) * internal->updateCacheResetCapacity);
	}
	internal->updateCacheReset[internal->updateCacheResetCount] = bone;
	++internal->updateCacheResetCount;
}

static void _sortBone(_sp37Skeleton* const internal, sp37Bone* bone) {
	if (bone->sorted) return;
	if (bone->parent) _sortBone(internal, bone->parent);
	bone->sorted = 1;
	_addToUpdateCache(internal, SP_UPDATE_BONE, bone);
}

static void _sortPathConstraintAttachmentBones(_sp37Skeleton* const internal, sp37Attachment* attachment, sp37Bone* slotBone) {
	sp37PathAttachment* pathAttachment = (sp37PathAttachment*)attachment;
	int* pathBones;
	int pathBonesCount;
	if (pathAttachment->super.super.type != SP_ATTACHMENT_PATH) return;
	pathBones = pathAttachment->super.bones;
	pathBonesCount = pathAttachment->super.bonesCount;
	if (pathBones == 0)
		_sortBone(internal, slotBone);
	else {
		sp37Bone** bones = internal->super.bones;
		int i = 0, n;
		while (i < pathBonesCount) {
			int boneCount = pathBones[i++];
			for (n = i + boneCount; i < n; i++)
				_sortBone(internal, bones[pathBones[i]]);
		}
	}
}

static void _sortPathConstraintAttachment(_sp37Skeleton* const internal, sp37Skin* skin, int slotIndex, sp37Bone* slotBone) {
	_Entry* entry = SUB_CAST(_sp37Skin, skin)->entries;
	while (entry) {
		if (entry->slotIndex == slotIndex) _sortPathConstraintAttachmentBones(internal, entry->attachment, slotBone);
		entry = entry->next;
	}
}

static void _sortReset(sp37Bone** bones, int bonesCount) {
	int i;
	for (i = 0; i < bonesCount; ++i) {
		sp37Bone* bone = bones[i];
		if (bone->sorted) _sortReset(bone->children, bone->childrenCount);
		bone->sorted = 0;
	}
}

static void _sortIkConstraint (_sp37Skeleton* const internal, sp37IkConstraint* constraint) {
	int /*bool*/ contains = 0;
	int i;
	sp37Bone* target = constraint->target;
	sp37Bone** constrained;
	sp37Bone* parent;
	_sortBone(internal, target);

	constrained = constraint->bones;
	parent = constrained[0];
	_sortBone(internal, parent);

	if (constraint->bonesCount > 1) {
		sp37Bone* child = constrained[constraint->bonesCount - 1];
		contains = 0;
		for (i = 0; i < internal->updateCacheCount; i++) {
			_sp37Update update = internal->updateCache[i];
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

static void _sortPathConstraint(_sp37Skeleton* const internal, sp37PathConstraint* constraint) {
	sp37Slot* slot = constraint->target;
	int slotIndex = slot->data->index;
	sp37Bone* slotBone = slot->bone;
	int i, n, boneCount;
	sp37Attachment* attachment;
	sp37Bone** constrained;
	sp37Skeleton* skeleton = SUPER_CAST(sp37Skeleton, internal);
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

static void _sortTransformConstraint(_sp37Skeleton* const internal, sp37TransformConstraint* constraint) {
	int i, boneCount;
	sp37Bone** constrained;
	sp37Bone* child;
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
				_sp37Update update = internal->updateCache[i];
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

void sp37Skeleton_updateCache (sp37Skeleton* self) {
	int i, ii;
	sp37Bone** bones;
	sp37IkConstraint** ikConstraints;
	sp37PathConstraint** pathConstraints;
	sp37TransformConstraint** transformConstraints;
	int ikCount, transformCount, pathCount, constraintCount;
	_sp37Skeleton* internal = SUB_CAST(_sp37Skeleton, self);

	internal->updateCacheCapacity = self->bonesCount + self->ikConstraintsCount + self->transformConstraintsCount + self->pathConstraintsCount;
	FREE(internal->updateCache);
	internal->updateCache = MALLOC(_sp37Update, internal->updateCacheCapacity);
	internal->updateCacheCount = 0;

	internal->updateCacheResetCapacity = self->bonesCount;
	FREE(internal->updateCacheReset);
	internal->updateCacheReset = MALLOC(sp37Bone*, internal->updateCacheResetCapacity);
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
			sp37IkConstraint* ikConstraint = ikConstraints[ii];
			if (ikConstraint->data->order == i) {
				_sortIkConstraint(internal, ikConstraint);
				i++;
				goto continue_outer;
			}
		}

		for (ii = 0; ii < transformCount; ii++) {
			sp37TransformConstraint* transformConstraint = transformConstraints[ii];
			if (transformConstraint->data->order == i) {
				_sortTransformConstraint(internal, transformConstraint);
				i++;
				goto continue_outer;
			}
		}

		for (ii = 0; ii < pathCount; ii++) {
			sp37PathConstraint* pathConstraint = pathConstraints[ii];
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

void sp37Skeleton_updateWorldTransform (const sp37Skeleton* self) {
	int i;
	_sp37Skeleton* internal = SUB_CAST(_sp37Skeleton, self);
	sp37Bone** updateCacheReset = internal->updateCacheReset;
	for (i = 0; i < internal->updateCacheResetCount; i++) {
		sp37Bone* bone = updateCacheReset[i];
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
		_sp37Update* update = internal->updateCache + i;
		switch (update->type) {
		case SP_UPDATE_BONE:
			sp37Bone_updateWorldTransform((sp37Bone*)update->object);
			break;
		case SP_UPDATE_IK_CONSTRAINT:
			sp37IkConstraint_apply((sp37IkConstraint*)update->object);
			break;
		case SP_UPDATE_TRANSFORM_CONSTRAINT:
			sp37TransformConstraint_apply((sp37TransformConstraint*)update->object);
			break;
		case SP_UPDATE_PATH_CONSTRAINT:
			sp37PathConstraint_apply((sp37PathConstraint*)update->object);
			break;
		}
	}
}

void sp37Skeleton_setToSetupPose (const sp37Skeleton* self) {
	sp37Skeleton_setBonesToSetupPose(self);
	sp37Skeleton_setSlotsToSetupPose(self);
}

void sp37Skeleton_setBonesToSetupPose (const sp37Skeleton* self) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		sp37Bone_setToSetupPose(self->bones[i]);

	for (i = 0; i < self->ikConstraintsCount; ++i) {
		sp37IkConstraint* ikConstraint = self->ikConstraints[i];
		ikConstraint->bendDirection = ikConstraint->data->bendDirection;
		ikConstraint->compress = ikConstraint->data->compress;
		ikConstraint->stretch = ikConstraint->data->stretch;
		ikConstraint->mix = ikConstraint->data->mix;
	}

	for (i = 0; i < self->transformConstraintsCount; ++i) {
		sp37TransformConstraint* constraint = self->transformConstraints[i];
		sp37TransformConstraintData* data = constraint->data;
		constraint->rotateMix = data->rotateMix;
		constraint->translateMix = data->translateMix;
		constraint->scaleMix = data->scaleMix;
		constraint->shearMix = data->shearMix;
	}

	for (i = 0; i < self->pathConstraintsCount; ++i) {
		sp37PathConstraint* constraint = self->pathConstraints[i];
		sp37PathConstraintData* data = constraint->data;
		constraint->position = data->position;
		constraint->spacing = data->spacing;
		constraint->rotateMix = data->rotateMix;
		constraint->translateMix = data->translateMix;
	}
}

void sp37Skeleton_setSlotsToSetupPose (const sp37Skeleton* self) {
	int i;
	memcpy(self->drawOrder, self->slots, self->slotsCount * sizeof(sp37Slot*));
	for (i = 0; i < self->slotsCount; ++i)
		sp37Slot_setToSetupPose(self->slots[i]);
}

sp37Bone* sp37Skeleton_findBone (const sp37Skeleton* self, const char* boneName) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		if (strcmp(self->data->bones[i]->name, boneName) == 0) return self->bones[i];
	return 0;
}

int sp37Skeleton_findBoneIndex (const sp37Skeleton* self, const char* boneName) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		if (strcmp(self->data->bones[i]->name, boneName) == 0) return i;
	return -1;
}

sp37Slot* sp37Skeleton_findSlot (const sp37Skeleton* self, const char* slotName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i)
		if (strcmp(self->data->slots[i]->name, slotName) == 0) return self->slots[i];
	return 0;
}

int sp37Skeleton_findSlotIndex (const sp37Skeleton* self, const char* slotName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i)
		if (strcmp(self->data->slots[i]->name, slotName) == 0) return i;
	return -1;
}

int sp37Skeleton_setSkinByName (sp37Skeleton* self, const char* skinName) {
	sp37Skin *skin;
	if (!skinName) {
		sp37Skeleton_setSkin(self, 0);
		return 1;
	}
	skin = sp37SkeletonData_findSkin(self->data, skinName);
	if (!skin) return 0;
	sp37Skeleton_setSkin(self, skin);
	return 1;
}

void sp37Skeleton_setSkin (sp37Skeleton* self, sp37Skin* newSkin) {
	if (newSkin) {
		if (self->skin)
			sp37Skin_attachAll(newSkin, self, self->skin);
		else {
			/* No previous skin, attach setup pose attachments. */
			int i;
			for (i = 0; i < self->slotsCount; ++i) {
				sp37Slot* slot = self->slots[i];
				if (slot->data->attachmentName) {
					sp37Attachment* attachment = sp37Skin_getAttachment(newSkin, i, slot->data->attachmentName);
					if (attachment) sp37Slot_setAttachment(slot, attachment);
				}
			}
		}
	}
	CONST_CAST(sp37Skin*, self->skin) = newSkin;
}

sp37Attachment* sp37Skeleton_getAttachmentForSlotName (const sp37Skeleton* self, const char* slotName, const char* attachmentName) {
	int slotIndex = sp37SkeletonData_findSlotIndex(self->data, slotName);
	return sp37Skeleton_getAttachmentForSlotIndex(self, slotIndex, attachmentName);
}

sp37Attachment* sp37Skeleton_getAttachmentForSlotIndex (const sp37Skeleton* self, int slotIndex, const char* attachmentName) {
	if (slotIndex == -1) return 0;
	if (self->skin) {
		sp37Attachment *attachment = sp37Skin_getAttachment(self->skin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	if (self->data->defaultSkin) {
		sp37Attachment *attachment = sp37Skin_getAttachment(self->data->defaultSkin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	return 0;
}

int sp37Skeleton_setAttachment (sp37Skeleton* self, const char* slotName, const char* attachmentName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i) {
		sp37Slot *slot = self->slots[i];
		if (strcmp(slot->data->name, slotName) == 0) {
			if (!attachmentName)
				sp37Slot_setAttachment(slot, 0);
			else {
				sp37Attachment* attachment = sp37Skeleton_getAttachmentForSlotIndex(self, i, attachmentName);
				if (!attachment) return 0;
				sp37Slot_setAttachment(slot, attachment);
			}
			return 1;
		}
	}
	return 0;
}

sp37IkConstraint* sp37Skeleton_findIkConstraint (const sp37Skeleton* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->ikConstraintsCount; ++i)
		if (strcmp(self->ikConstraints[i]->data->name, constraintName) == 0) return self->ikConstraints[i];
	return 0;
}

sp37TransformConstraint* sp37Skeleton_findTransformConstraint (const sp37Skeleton* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->transformConstraintsCount; ++i)
		if (strcmp(self->transformConstraints[i]->data->name, constraintName) == 0) return self->transformConstraints[i];
	return 0;
}

sp37PathConstraint* sp37Skeleton_findPathConstraint (const sp37Skeleton* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->pathConstraintsCount; ++i)
		if (strcmp(self->pathConstraints[i]->data->name, constraintName) == 0) return self->pathConstraints[i];
	return 0;
}

void sp37Skeleton_update (sp37Skeleton* self, float deltaTime) {
	self->time += deltaTime;
}

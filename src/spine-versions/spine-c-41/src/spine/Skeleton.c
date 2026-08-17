/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated September 24, 2021. Replaces all prior versions.
 *
 * Copyright (c) 2013-2021, Esoteric Software LLC
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
#include <spine/extension.h>
#include <stdlib.h>
#include <string.h>

typedef enum {
	SP_UPDATE_BONE,
	SP_UPDATE_IK_CONSTRAINT,
	SP_UPDATE_PATH_CONSTRAINT,
	SP_UPDATE_TRANSFORM_CONSTRAINT
} _sp41UpdateType;

typedef struct {
	_sp41UpdateType type;
	void *object;
} _sp41Update;

typedef struct {
	sp41Skeleton super;

	int updateCacheCount;
	int updateCacheCapacity;
	_sp41Update *updateCache;
} _sp41Skeleton;

sp41Skeleton *sp41Skeleton_create(sp41SkeletonData *data) {
	int i;
	int *childrenCounts;

	_sp41Skeleton *internal = NEW(_sp41Skeleton);
	sp41Skeleton *self = SUPER(internal);
	CONST_CAST(sp41SkeletonData *, self->data) = data;

	self->bonesCount = self->data->bonesCount;
	self->bones = MALLOC(sp41Bone *, self->bonesCount);
	childrenCounts = CALLOC(int, self->bonesCount);

	for (i = 0; i < self->bonesCount; ++i) {
		sp41BoneData *boneData = self->data->bones[i];
		sp41Bone *newBone;
		if (!boneData->parent)
			newBone = sp41Bone_create(boneData, self, 0);
		else {
			sp41Bone *parent = self->bones[boneData->parent->index];
			newBone = sp41Bone_create(boneData, self, parent);
			++childrenCounts[boneData->parent->index];
		}
		self->bones[i] = newBone;
	}
	for (i = 0; i < self->bonesCount; ++i) {
		sp41BoneData *boneData = self->data->bones[i];
		sp41Bone *bone = self->bones[i];
		CONST_CAST(sp41Bone **, bone->children) = MALLOC(sp41Bone *, childrenCounts[boneData->index]);
	}
	for (i = 0; i < self->bonesCount; ++i) {
		sp41Bone *bone = self->bones[i];
		sp41Bone *parent = bone->parent;
		if (parent)
			parent->children[parent->childrenCount++] = bone;
	}
	CONST_CAST(sp41Bone *, self->root) = (self->bonesCount > 0 ? self->bones[0] : NULL);

	self->slotsCount = data->slotsCount;
	self->slots = MALLOC(sp41Slot *, self->slotsCount);
	for (i = 0; i < self->slotsCount; ++i) {
		sp41SlotData *slotData = data->slots[i];
		sp41Bone *bone = self->bones[slotData->boneData->index];
		self->slots[i] = sp41Slot_create(slotData, bone);
	}

	self->drawOrder = MALLOC(sp41Slot *, self->slotsCount);
	memcpy(self->drawOrder, self->slots, sizeof(sp41Slot *) * self->slotsCount);

	self->ikConstraintsCount = data->ikConstraintsCount;
	self->ikConstraints = MALLOC(sp41IkConstraint *, self->ikConstraintsCount);
	for (i = 0; i < self->data->ikConstraintsCount; ++i)
		self->ikConstraints[i] = sp41IkConstraint_create(self->data->ikConstraints[i], self);

	self->transformConstraintsCount = data->transformConstraintsCount;
	self->transformConstraints = MALLOC(sp41TransformConstraint *, self->transformConstraintsCount);
	for (i = 0; i < self->data->transformConstraintsCount; ++i)
		self->transformConstraints[i] = sp41TransformConstraint_create(self->data->transformConstraints[i], self);

	self->pathConstraintsCount = data->pathConstraintsCount;
	self->pathConstraints = MALLOC(sp41PathConstraint *, self->pathConstraintsCount);
	for (i = 0; i < self->data->pathConstraintsCount; i++)
		self->pathConstraints[i] = sp41PathConstraint_create(self->data->pathConstraints[i], self);

	sp41Color_setFromFloats(&self->color, 1, 1, 1, 1);

	self->scaleX = 1;
	self->scaleY = 1;

	sp41Skeleton_updateCache(self);

	FREE(childrenCounts);

	return self;
}

void sp41Skeleton_dispose(sp41Skeleton *self) {
	int i;
	_sp41Skeleton *internal = SUB_CAST(_sp41Skeleton, self);

	FREE(internal->updateCache);

	for (i = 0; i < self->bonesCount; ++i)
		sp41Bone_dispose(self->bones[i]);
	FREE(self->bones);

	for (i = 0; i < self->slotsCount; ++i)
		sp41Slot_dispose(self->slots[i]);
	FREE(self->slots);

	for (i = 0; i < self->ikConstraintsCount; ++i)
		sp41IkConstraint_dispose(self->ikConstraints[i]);
	FREE(self->ikConstraints);

	for (i = 0; i < self->transformConstraintsCount; ++i)
		sp41TransformConstraint_dispose(self->transformConstraints[i]);
	FREE(self->transformConstraints);

	for (i = 0; i < self->pathConstraintsCount; i++)
		sp41PathConstraint_dispose(self->pathConstraints[i]);
	FREE(self->pathConstraints);

	FREE(self->drawOrder);
	FREE(self);
}

static void _addToUpdateCache(_sp41Skeleton *const internal, _sp41UpdateType type, void *object) {
	_sp41Update *update;
	if (internal->updateCacheCount == internal->updateCacheCapacity) {
		internal->updateCacheCapacity *= 2;
		internal->updateCache = (_sp41Update *) REALLOC(internal->updateCache, _sp41Update, internal->updateCacheCapacity);
	}
	update = internal->updateCache + internal->updateCacheCount;
	update->type = type;
	update->object = object;
	++internal->updateCacheCount;
}

static void _sortBone(_sp41Skeleton *const internal, sp41Bone *bone) {
	if (bone->sorted) return;
	if (bone->parent) _sortBone(internal, bone->parent);
	bone->sorted = 1;
	_addToUpdateCache(internal, SP_UPDATE_BONE, bone);
}

static void
_sortPathConstraintAttachmentBones(_sp41Skeleton *const internal, sp41Attachment *attachment, sp41Bone *slotBone) {
	sp41PathAttachment *pathAttachment = (sp41PathAttachment *) attachment;
	int *pathBones;
	int pathBonesCount;
	if (pathAttachment->super.super.type != SP_ATTACHMENT_PATH) return;
	pathBones = pathAttachment->super.bones;
	pathBonesCount = pathAttachment->super.bonesCount;
	if (pathBones == 0)
		_sortBone(internal, slotBone);
	else {
		sp41Bone **bones = internal->super.bones;
		int i = 0, n;

		for (i = 0, n = pathBonesCount; i < n;) {
			int nn = pathBones[i++];
			nn += i;
			while (i < nn)
				_sortBone(internal, bones[pathBones[i++]]);
		}
	}
}

static void _sortPathConstraintAttachment(_sp41Skeleton *const internal, sp41Skin *skin, int slotIndex, sp41Bone *slotBone) {
	_Entry *entry = SUB_CAST(_sp41Skin, skin)->entries;
	while (entry) {
		if (entry->slotIndex == slotIndex) _sortPathConstraintAttachmentBones(internal, entry->attachment, slotBone);
		entry = entry->next;
	}
}

static void _sortReset(sp41Bone **bones, int bonesCount) {
	int i;
	for (i = 0; i < bonesCount; ++i) {
		sp41Bone *bone = bones[i];
		if (!bone->active) continue;
		if (bone->sorted) _sortReset(bone->children, bone->childrenCount);
		bone->sorted = 0;
	}
}

static void _sortIkConstraint(_sp41Skeleton *const internal, sp41IkConstraint *constraint) {
	sp41Bone *target = constraint->target;
	sp41Bone **constrained;
	sp41Bone *parent;

	constraint->active = constraint->target->active && (!constraint->data->skinRequired || (internal->super.skin != 0 &&
																							sp41IkConstraintDataArray_contains(
																									internal->super.skin->ikConstraints,
																									constraint->data)));
	if (!constraint->active) return;

	_sortBone(internal, target);

	constrained = constraint->bones;
	parent = constrained[0];
	_sortBone(internal, parent);

	if (constraint->bonesCount == 1) {
		_addToUpdateCache(internal, SP_UPDATE_IK_CONSTRAINT, constraint);
		_sortReset(parent->children, parent->childrenCount);
	} else {
		sp41Bone *child = constrained[constraint->bonesCount - 1];
		_sortBone(internal, child);

		_addToUpdateCache(internal, SP_UPDATE_IK_CONSTRAINT, constraint);

		_sortReset(parent->children, parent->childrenCount);
		child->sorted = 1;
	}
}

static void _sortPathConstraint(_sp41Skeleton *const internal, sp41PathConstraint *constraint) {
	sp41Slot *slot = constraint->target;
	int slotIndex = slot->data->index;
	sp41Bone *slotBone = slot->bone;
	int i, n, boneCount;
	sp41Attachment *attachment;
	sp41Bone **constrained;
	sp41Skeleton *skeleton = SUPER_CAST(sp41Skeleton, internal);

	constraint->active = constraint->target->bone->active && (!constraint->data->skinRequired ||
															  (internal->super.skin != 0 &&
															   sp41PathConstraintDataArray_contains(
																	   internal->super.skin->pathConstraints,
																	   constraint->data)));
	if (!constraint->active) return;

	if (skeleton->skin) _sortPathConstraintAttachment(internal, skeleton->skin, slotIndex, slotBone);
	if (skeleton->data->defaultSkin && skeleton->data->defaultSkin != skeleton->skin)
		_sortPathConstraintAttachment(internal, skeleton->data->defaultSkin, slotIndex, slotBone);
	for (i = 0, n = skeleton->data->skinsCount; i < n; i++)
		_sortPathConstraintAttachment(internal, skeleton->data->skins[i], slotIndex, slotBone);

	attachment = slot->attachment;
	if (attachment && attachment->type == SP_ATTACHMENT_PATH)
		_sortPathConstraintAttachmentBones(internal, attachment, slotBone);

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

static void _sortTransformConstraint(_sp41Skeleton *const internal, sp41TransformConstraint *constraint) {
	int i, boneCount;
	sp41Bone **constrained;
	sp41Bone *child;

	constraint->active = constraint->target->active && (!constraint->data->skinRequired || (internal->super.skin != 0 &&
																							sp41TransformConstraintDataArray_contains(
																									internal->super.skin->transformConstraints,
																									constraint->data)));
	if (!constraint->active) return;

	_sortBone(internal, constraint->target);

	constrained = constraint->bones;
	boneCount = constraint->bonesCount;
	if (constraint->data->local) {
		for (i = 0; i < boneCount; i++) {
			child = constrained[i];
			_sortBone(internal, child->parent);
			_sortBone(internal, child);
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

void sp41Skeleton_updateCache(sp41Skeleton *self) {
	int i, ii;
	sp41Bone **bones;
	sp41IkConstraint **ikConstraints;
	sp41PathConstraint **pathConstraints;
	sp41TransformConstraint **transformConstraints;
	int ikCount, transformCount, pathCount, constraintCount;
	_sp41Skeleton *internal = SUB_CAST(_sp41Skeleton, self);

	internal->updateCacheCapacity =
			self->bonesCount + self->ikConstraintsCount + self->transformConstraintsCount + self->pathConstraintsCount;
	FREE(internal->updateCache);
	internal->updateCache = MALLOC(_sp41Update, internal->updateCacheCapacity);
	internal->updateCacheCount = 0;

	bones = self->bones;
	for (i = 0; i < self->bonesCount; ++i) {
		sp41Bone *bone = bones[i];
		bone->sorted = bone->data->skinRequired;
		bone->active = !bone->sorted;
	}

	if (self->skin) {
		sp41BoneDataArray *skinBones = self->skin->bones;
		for (i = 0; i < skinBones->size; i++) {
			sp41Bone *bone = self->bones[skinBones->items[i]->index];
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
	ikCount = self->ikConstraintsCount;
	transformCount = self->transformConstraintsCount;
	pathCount = self->pathConstraintsCount;
	constraintCount = ikCount + transformCount + pathCount;

	i = 0;
continue_outer:
	for (; i < constraintCount; i++) {
		for (ii = 0; ii < ikCount; ii++) {
			sp41IkConstraint *ikConstraint = ikConstraints[ii];
			if (ikConstraint->data->order == i) {
				_sortIkConstraint(internal, ikConstraint);
				i++;
				goto continue_outer;
			}
		}

		for (ii = 0; ii < transformCount; ii++) {
			sp41TransformConstraint *transformConstraint = transformConstraints[ii];
			if (transformConstraint->data->order == i) {
				_sortTransformConstraint(internal, transformConstraint);
				i++;
				goto continue_outer;
			}
		}

		for (ii = 0; ii < pathCount; ii++) {
			sp41PathConstraint *pathConstraint = pathConstraints[ii];
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

void sp41Skeleton_updateWorldTransform(const sp41Skeleton *self) {
	int i, n;
	_sp41Skeleton *internal = SUB_CAST(_sp41Skeleton, self);

	for (i = 0, n = self->bonesCount; i < n; i++) {
		sp41Bone *bone = self->bones[i];
		bone->ax = bone->x;
		bone->ay = bone->y;
		bone->arotation = bone->rotation;
		bone->ascaleX = bone->scaleX;
		bone->ascaleY = bone->scaleY;
		bone->ashearX = bone->shearX;
		bone->ashearY = bone->shearY;
	}

	for (i = 0; i < internal->updateCacheCount; ++i) {
		_sp41Update *update = internal->updateCache + i;
		switch (update->type) {
			case SP_UPDATE_BONE:
				sp41Bone_update((sp41Bone *) update->object);
				break;
			case SP_UPDATE_IK_CONSTRAINT:
				sp41IkConstraint_update((sp41IkConstraint *) update->object);
				break;
			case SP_UPDATE_TRANSFORM_CONSTRAINT:
				sp41TransformConstraint_update((sp41TransformConstraint *) update->object);
				break;
			case SP_UPDATE_PATH_CONSTRAINT:
				sp41PathConstraint_update((sp41PathConstraint *) update->object);
				break;
		}
	}
}

void sp41Skeleton_updateWorldTransformWith(const sp41Skeleton *self, const sp41Bone *parent) {
	/* Apply the parent bone transform to the root bone. The root bone always inherits scale, rotation and reflection. */
	int i;
	float rotationY, la, lb, lc, ld;
	_sp41Update *updateCache;
	_sp41Skeleton *internal = SUB_CAST(_sp41Skeleton, self);
	sp41Bone *rootBone = self->root;
	float pa = parent->a, pb = parent->b, pc = parent->c, pd = parent->d;
	CONST_CAST(float, rootBone->worldX) = pa * self->x + pb * self->y + parent->worldX;
	CONST_CAST(float, rootBone->worldY) = pc * self->x + pd * self->y + parent->worldY;

	rotationY = rootBone->rotation + 90 + rootBone->shearY;
	la = COS_DEG(rootBone->rotation + rootBone->shearX) * rootBone->scaleX;
	lb = COS_DEG(rotationY) * rootBone->scaleY;
	lc = SIN_DEG(rootBone->rotation + rootBone->shearX) * rootBone->scaleX;
	ld = SIN_DEG(rotationY) * rootBone->scaleY;
	CONST_CAST(float, rootBone->a) = (pa * la + pb * lc) * self->scaleX;
	CONST_CAST(float, rootBone->b) = (pa * lb + pb * ld) * self->scaleX;
	CONST_CAST(float, rootBone->c) = (pc * la + pd * lc) * self->scaleY;
	CONST_CAST(float, rootBone->d) = (pc * lb + pd * ld) * self->scaleY;

	/* Update everything except root bone. */
	updateCache = internal->updateCache;
	for (i = 0; i < internal->updateCacheCount; ++i) {
		_sp41Update *update = internal->updateCache + i;
		switch (update->type) {
			case SP_UPDATE_BONE:
				if ((sp41Bone *) update->object != rootBone) sp41Bone_updateWorldTransform((sp41Bone *) update->object);
				break;
			case SP_UPDATE_IK_CONSTRAINT:
				sp41IkConstraint_update((sp41IkConstraint *) update->object);
				break;
			case SP_UPDATE_TRANSFORM_CONSTRAINT:
				sp41TransformConstraint_update((sp41TransformConstraint *) update->object);
				break;
			case SP_UPDATE_PATH_CONSTRAINT:
				sp41PathConstraint_update((sp41PathConstraint *) update->object);
				break;
		}
	}
}

void sp41Skeleton_setToSetupPose(const sp41Skeleton *self) {
	sp41Skeleton_setBonesToSetupPose(self);
	sp41Skeleton_setSlotsToSetupPose(self);
}

void sp41Skeleton_setBonesToSetupPose(const sp41Skeleton *self) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		sp41Bone_setToSetupPose(self->bones[i]);

	for (i = 0; i < self->ikConstraintsCount; ++i) {
		sp41IkConstraint *ikConstraint = self->ikConstraints[i];
		ikConstraint->bendDirection = ikConstraint->data->bendDirection;
		ikConstraint->compress = ikConstraint->data->compress;
		ikConstraint->stretch = ikConstraint->data->stretch;
		ikConstraint->softness = ikConstraint->data->softness;
		ikConstraint->mix = ikConstraint->data->mix;
	}

	for (i = 0; i < self->transformConstraintsCount; ++i) {
		sp41TransformConstraint *constraint = self->transformConstraints[i];
		sp41TransformConstraintData *data = constraint->data;
		constraint->mixRotate = data->mixRotate;
		constraint->mixX = data->mixX;
		constraint->mixY = data->mixY;
		constraint->mixScaleX = data->mixScaleX;
		constraint->mixScaleY = data->mixScaleY;
		constraint->mixShearY = data->mixShearY;
	}

	for (i = 0; i < self->pathConstraintsCount; ++i) {
		sp41PathConstraint *constraint = self->pathConstraints[i];
		sp41PathConstraintData *data = constraint->data;
		constraint->position = data->position;
		constraint->spacing = data->spacing;
		constraint->mixRotate = data->mixRotate;
		constraint->mixX = data->mixX;
		constraint->mixY = data->mixY;
	}
}

void sp41Skeleton_setSlotsToSetupPose(const sp41Skeleton *self) {
	int i;
	memcpy(self->drawOrder, self->slots, self->slotsCount * sizeof(sp41Slot *));
	for (i = 0; i < self->slotsCount; ++i)
		sp41Slot_setToSetupPose(self->slots[i]);
}

sp41Bone *sp41Skeleton_findBone(const sp41Skeleton *self, const char *boneName) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		if (strcmp(self->data->bones[i]->name, boneName) == 0) return self->bones[i];
	return 0;
}

sp41Slot *sp41Skeleton_findSlot(const sp41Skeleton *self, const char *slotName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i)
		if (strcmp(self->data->slots[i]->name, slotName) == 0) return self->slots[i];
	return 0;
}

int sp41Skeleton_setSkinByName(sp41Skeleton *self, const char *skinName) {
	sp41Skin *skin;
	if (!skinName) {
		sp41Skeleton_setSkin(self, 0);
		return 1;
	}
	skin = sp41SkeletonData_findSkin(self->data, skinName);
	if (!skin) return 0;
	sp41Skeleton_setSkin(self, skin);
	return 1;
}

void sp41Skeleton_setSkin(sp41Skeleton *self, sp41Skin *newSkin) {
	if (self->skin == newSkin) return;
	if (newSkin) {
		if (self->skin)
			sp41Skin_attachAll(newSkin, self, self->skin);
		else {
			/* No previous skin, attach setup pose attachments. */
			int i;
			for (i = 0; i < self->slotsCount; ++i) {
				sp41Slot *slot = self->slots[i];
				if (slot->data->attachmentName) {
					sp41Attachment *attachment = sp41Skin_getAttachment(newSkin, i, slot->data->attachmentName);
					if (attachment) sp41Slot_setAttachment(slot, attachment);
				}
			}
		}
	}
	CONST_CAST(sp41Skin *, self->skin) = newSkin;
	sp41Skeleton_updateCache(self);
}

sp41Attachment *
sp41Skeleton_getAttachmentForSlotName(const sp41Skeleton *self, const char *slotName, const char *attachmentName) {
	int slotIndex = sp41SkeletonData_findSlot(self->data, slotName)->index;
	return sp41Skeleton_getAttachmentForSlotIndex(self, slotIndex, attachmentName);
}

sp41Attachment *sp41Skeleton_getAttachmentForSlotIndex(const sp41Skeleton *self, int slotIndex, const char *attachmentName) {
	if (slotIndex == -1) return 0;
	if (self->skin) {
		sp41Attachment *attachment = sp41Skin_getAttachment(self->skin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	if (self->data->defaultSkin) {
		sp41Attachment *attachment = sp41Skin_getAttachment(self->data->defaultSkin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	return 0;
}

int sp41Skeleton_setAttachment(sp41Skeleton *self, const char *slotName, const char *attachmentName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i) {
		sp41Slot *slot = self->slots[i];
		if (strcmp(slot->data->name, slotName) == 0) {
			if (!attachmentName)
				sp41Slot_setAttachment(slot, 0);
			else {
				sp41Attachment *attachment = sp41Skeleton_getAttachmentForSlotIndex(self, i, attachmentName);
				if (!attachment) return 0;
				sp41Slot_setAttachment(slot, attachment);
			}
			return 1;
		}
	}
	return 0;
}

sp41IkConstraint *sp41Skeleton_findIkConstraint(const sp41Skeleton *self, const char *constraintName) {
	int i;
	for (i = 0; i < self->ikConstraintsCount; ++i)
		if (strcmp(self->ikConstraints[i]->data->name, constraintName) == 0) return self->ikConstraints[i];
	return 0;
}

sp41TransformConstraint *sp41Skeleton_findTransformConstraint(const sp41Skeleton *self, const char *constraintName) {
	int i;
	for (i = 0; i < self->transformConstraintsCount; ++i)
		if (strcmp(self->transformConstraints[i]->data->name, constraintName) == 0)
			return self->transformConstraints[i];
	return 0;
}

sp41PathConstraint *sp41Skeleton_findPathConstraint(const sp41Skeleton *self, const char *constraintName) {
	int i;
	for (i = 0; i < self->pathConstraintsCount; ++i)
		if (strcmp(self->pathConstraints[i]->data->name, constraintName) == 0) return self->pathConstraints[i];
	return 0;
}

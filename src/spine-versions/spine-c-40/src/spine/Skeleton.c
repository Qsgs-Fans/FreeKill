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
#include <spine/extension.h>
#include <stdlib.h>
#include <string.h>

typedef enum {
	SP_UPDATE_BONE,
	SP_UPDATE_IK_CONSTRAINT,
	SP_UPDATE_PATH_CONSTRAINT,
	SP_UPDATE_TRANSFORM_CONSTRAINT
} _sp40UpdateType;

typedef struct {
	_sp40UpdateType type;
	void *object;
} _sp40Update;

typedef struct {
	sp40Skeleton super;

	int updateCacheCount;
	int updateCacheCapacity;
	_sp40Update *updateCache;
} _sp40Skeleton;

sp40Skeleton *sp40Skeleton_create(sp40SkeletonData *data) {
	int i;
	int *childrenCounts;

	_sp40Skeleton *internal = NEW(_sp40Skeleton);
	sp40Skeleton *self = SUPER(internal);
	CONST_CAST(sp40SkeletonData *, self->data) = data;

	self->bonesCount = self->data->bonesCount;
	self->bones = MALLOC(sp40Bone *, self->bonesCount);
	childrenCounts = CALLOC(int, self->bonesCount);

	for (i = 0; i < self->bonesCount; ++i) {
		sp40BoneData *boneData = self->data->bones[i];
		sp40Bone *newBone;
		if (!boneData->parent)
			newBone = sp40Bone_create(boneData, self, 0);
		else {
			sp40Bone *parent = self->bones[boneData->parent->index];
			newBone = sp40Bone_create(boneData, self, parent);
			++childrenCounts[boneData->parent->index];
		}
		self->bones[i] = newBone;
	}
	for (i = 0; i < self->bonesCount; ++i) {
		sp40BoneData *boneData = self->data->bones[i];
		sp40Bone *bone = self->bones[i];
		CONST_CAST(sp40Bone **, bone->children) = MALLOC(sp40Bone *, childrenCounts[boneData->index]);
	}
	for (i = 0; i < self->bonesCount; ++i) {
		sp40Bone *bone = self->bones[i];
		sp40Bone *parent = bone->parent;
		if (parent)
			parent->children[parent->childrenCount++] = bone;
	}
	CONST_CAST(sp40Bone *, self->root) = (self->bonesCount > 0 ? self->bones[0] : NULL);

	self->slotsCount = data->slotsCount;
	self->slots = MALLOC(sp40Slot *, self->slotsCount);
	for (i = 0; i < self->slotsCount; ++i) {
		sp40SlotData *slotData = data->slots[i];
		sp40Bone *bone = self->bones[slotData->boneData->index];
		self->slots[i] = sp40Slot_create(slotData, bone);
	}

	self->drawOrder = MALLOC(sp40Slot *, self->slotsCount);
	memcpy(self->drawOrder, self->slots, sizeof(sp40Slot *) * self->slotsCount);

	self->ikConstraintsCount = data->ikConstraintsCount;
	self->ikConstraints = MALLOC(sp40IkConstraint *, self->ikConstraintsCount);
	for (i = 0; i < self->data->ikConstraintsCount; ++i)
		self->ikConstraints[i] = sp40IkConstraint_create(self->data->ikConstraints[i], self);

	self->transformConstraintsCount = data->transformConstraintsCount;
	self->transformConstraints = MALLOC(sp40TransformConstraint *, self->transformConstraintsCount);
	for (i = 0; i < self->data->transformConstraintsCount; ++i)
		self->transformConstraints[i] = sp40TransformConstraint_create(self->data->transformConstraints[i], self);

	self->pathConstraintsCount = data->pathConstraintsCount;
	self->pathConstraints = MALLOC(sp40PathConstraint *, self->pathConstraintsCount);
	for (i = 0; i < self->data->pathConstraintsCount; i++)
		self->pathConstraints[i] = sp40PathConstraint_create(self->data->pathConstraints[i], self);

	sp40Color_setFromFloats(&self->color, 1, 1, 1, 1);

	self->scaleX = 1;
	self->scaleY = 1;

	sp40Skeleton_updateCache(self);

	FREE(childrenCounts);

	return self;
}

void sp40Skeleton_dispose(sp40Skeleton *self) {
	int i;
	_sp40Skeleton *internal = SUB_CAST(_sp40Skeleton, self);

	FREE(internal->updateCache);

	for (i = 0; i < self->bonesCount; ++i)
		sp40Bone_dispose(self->bones[i]);
	FREE(self->bones);

	for (i = 0; i < self->slotsCount; ++i)
		sp40Slot_dispose(self->slots[i]);
	FREE(self->slots);

	for (i = 0; i < self->ikConstraintsCount; ++i)
		sp40IkConstraint_dispose(self->ikConstraints[i]);
	FREE(self->ikConstraints);

	for (i = 0; i < self->transformConstraintsCount; ++i)
		sp40TransformConstraint_dispose(self->transformConstraints[i]);
	FREE(self->transformConstraints);

	for (i = 0; i < self->pathConstraintsCount; i++)
		sp40PathConstraint_dispose(self->pathConstraints[i]);
	FREE(self->pathConstraints);

	FREE(self->drawOrder);
	FREE(self);
}

static void _addToUpdateCache(_sp40Skeleton *const internal, _sp40UpdateType type, void *object) {
	_sp40Update *update;
	if (internal->updateCacheCount == internal->updateCacheCapacity) {
		internal->updateCacheCapacity *= 2;
		internal->updateCache = (_sp40Update *) REALLOC(internal->updateCache, _sp40Update, internal->updateCacheCapacity);
	}
	update = internal->updateCache + internal->updateCacheCount;
	update->type = type;
	update->object = object;
	++internal->updateCacheCount;
}

static void _sortBone(_sp40Skeleton *const internal, sp40Bone *bone) {
	if (bone->sorted) return;
	if (bone->parent) _sortBone(internal, bone->parent);
	bone->sorted = 1;
	_addToUpdateCache(internal, SP_UPDATE_BONE, bone);
}

static void
_sortPathConstraintAttachmentBones(_sp40Skeleton *const internal, sp40Attachment *attachment, sp40Bone *slotBone) {
	sp40PathAttachment *pathAttachment = (sp40PathAttachment *) attachment;
	int *pathBones;
	int pathBonesCount;
	if (pathAttachment->super.super.type != SP_ATTACHMENT_PATH) return;
	pathBones = pathAttachment->super.bones;
	pathBonesCount = pathAttachment->super.bonesCount;
	if (pathBones == 0)
		_sortBone(internal, slotBone);
	else {
		sp40Bone **bones = internal->super.bones;
		int i = 0, n;

		for (i = 0, n = pathBonesCount; i < n;) {
			int nn = pathBones[i++];
			nn += i;
			while (i < nn)
				_sortBone(internal, bones[pathBones[i++]]);
		}
	}
}

static void _sortPathConstraintAttachment(_sp40Skeleton *const internal, sp40Skin *skin, int slotIndex, sp40Bone *slotBone) {
	_Entry *entry = SUB_CAST(_sp40Skin, skin)->entries;
	while (entry) {
		if (entry->slotIndex == slotIndex) _sortPathConstraintAttachmentBones(internal, entry->attachment, slotBone);
		entry = entry->next;
	}
}

static void _sortReset(sp40Bone **bones, int bonesCount) {
	int i;
	for (i = 0; i < bonesCount; ++i) {
		sp40Bone *bone = bones[i];
		if (!bone->active) continue;
		if (bone->sorted) _sortReset(bone->children, bone->childrenCount);
		bone->sorted = 0;
	}
}

static void _sortIkConstraint(_sp40Skeleton *const internal, sp40IkConstraint *constraint) {
	sp40Bone *target = constraint->target;
	sp40Bone **constrained;
	sp40Bone *parent;

	constraint->active = constraint->target->active && (!constraint->data->skinRequired || (internal->super.skin != 0 &&
																							sp40IkConstraintDataArray_contains(
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
		sp40Bone *child = constrained[constraint->bonesCount - 1];
		_sortBone(internal, child);

		_addToUpdateCache(internal, SP_UPDATE_IK_CONSTRAINT, constraint);

		_sortReset(parent->children, parent->childrenCount);
		child->sorted = 1;
	}
}

static void _sortPathConstraint(_sp40Skeleton *const internal, sp40PathConstraint *constraint) {
	sp40Slot *slot = constraint->target;
	int slotIndex = slot->data->index;
	sp40Bone *slotBone = slot->bone;
	int i, n, boneCount;
	sp40Attachment *attachment;
	sp40Bone **constrained;
	sp40Skeleton *skeleton = SUPER_CAST(sp40Skeleton, internal);

	constraint->active = constraint->target->bone->active && (!constraint->data->skinRequired ||
															  (internal->super.skin != 0 &&
															   sp40PathConstraintDataArray_contains(
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

static void _sortTransformConstraint(_sp40Skeleton *const internal, sp40TransformConstraint *constraint) {
	int i, boneCount;
	sp40Bone **constrained;
	sp40Bone *child;

	constraint->active = constraint->target->active && (!constraint->data->skinRequired || (internal->super.skin != 0 &&
																							sp40TransformConstraintDataArray_contains(
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

void sp40Skeleton_updateCache(sp40Skeleton *self) {
	int i, ii;
	sp40Bone **bones;
	sp40IkConstraint **ikConstraints;
	sp40PathConstraint **pathConstraints;
	sp40TransformConstraint **transformConstraints;
	int ikCount, transformCount, pathCount, constraintCount;
	_sp40Skeleton *internal = SUB_CAST(_sp40Skeleton, self);

	internal->updateCacheCapacity =
			self->bonesCount + self->ikConstraintsCount + self->transformConstraintsCount + self->pathConstraintsCount;
	FREE(internal->updateCache);
	internal->updateCache = MALLOC(_sp40Update, internal->updateCacheCapacity);
	internal->updateCacheCount = 0;

	bones = self->bones;
	for (i = 0; i < self->bonesCount; ++i) {
		sp40Bone *bone = bones[i];
		bone->sorted = bone->data->skinRequired;
		bone->active = !bone->sorted;
	}

	if (self->skin) {
		sp40BoneDataArray *skinBones = self->skin->bones;
		for (i = 0; i < skinBones->size; i++) {
			sp40Bone *bone = self->bones[skinBones->items[i]->index];
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
			sp40IkConstraint *ikConstraint = ikConstraints[ii];
			if (ikConstraint->data->order == i) {
				_sortIkConstraint(internal, ikConstraint);
				i++;
				goto continue_outer;
			}
		}

		for (ii = 0; ii < transformCount; ii++) {
			sp40TransformConstraint *transformConstraint = transformConstraints[ii];
			if (transformConstraint->data->order == i) {
				_sortTransformConstraint(internal, transformConstraint);
				i++;
				goto continue_outer;
			}
		}

		for (ii = 0; ii < pathCount; ii++) {
			sp40PathConstraint *pathConstraint = pathConstraints[ii];
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

void sp40Skeleton_updateWorldTransform(const sp40Skeleton *self) {
	int i, n;
	_sp40Skeleton *internal = SUB_CAST(_sp40Skeleton, self);

	for (i = 0, n = self->bonesCount; i < n; i++) {
		sp40Bone *bone = self->bones[i];
		bone->ax = bone->x;
		bone->ay = bone->y;
		bone->arotation = bone->rotation;
		bone->ascaleX = bone->scaleX;
		bone->ascaleY = bone->scaleY;
		bone->ashearX = bone->shearX;
		bone->ashearY = bone->shearY;
	}

	for (i = 0; i < internal->updateCacheCount; ++i) {
		_sp40Update *update = internal->updateCache + i;
		switch (update->type) {
			case SP_UPDATE_BONE:
				sp40Bone_update((sp40Bone *) update->object);
				break;
			case SP_UPDATE_IK_CONSTRAINT:
				sp40IkConstraint_update((sp40IkConstraint *) update->object);
				break;
			case SP_UPDATE_TRANSFORM_CONSTRAINT:
				sp40TransformConstraint_update((sp40TransformConstraint *) update->object);
				break;
			case SP_UPDATE_PATH_CONSTRAINT:
				sp40PathConstraint_update((sp40PathConstraint *) update->object);
				break;
		}
	}
}

void sp40Skeleton_updateWorldTransformWith(const sp40Skeleton *self, const sp40Bone *parent) {
	/* Apply the parent bone transform to the root bone. The root bone always inherits scale, rotation and reflection. */
	int i;
	float rotationY, la, lb, lc, ld;
	_sp40Update *updateCache;
	_sp40Skeleton *internal = SUB_CAST(_sp40Skeleton, self);
	sp40Bone *rootBone = self->root;
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
		_sp40Update *update = internal->updateCache + i;
		switch (update->type) {
			case SP_UPDATE_BONE:
				if ((sp40Bone *) update->object != rootBone) sp40Bone_updateWorldTransform((sp40Bone *) update->object);
				break;
			case SP_UPDATE_IK_CONSTRAINT:
				sp40IkConstraint_update((sp40IkConstraint *) update->object);
				break;
			case SP_UPDATE_TRANSFORM_CONSTRAINT:
				sp40TransformConstraint_update((sp40TransformConstraint *) update->object);
				break;
			case SP_UPDATE_PATH_CONSTRAINT:
				sp40PathConstraint_update((sp40PathConstraint *) update->object);
				break;
		}
	}
}

void sp40Skeleton_setToSetupPose(const sp40Skeleton *self) {
	sp40Skeleton_setBonesToSetupPose(self);
	sp40Skeleton_setSlotsToSetupPose(self);
}

void sp40Skeleton_setBonesToSetupPose(const sp40Skeleton *self) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		sp40Bone_setToSetupPose(self->bones[i]);

	for (i = 0; i < self->ikConstraintsCount; ++i) {
		sp40IkConstraint *ikConstraint = self->ikConstraints[i];
		ikConstraint->bendDirection = ikConstraint->data->bendDirection;
		ikConstraint->compress = ikConstraint->data->compress;
		ikConstraint->stretch = ikConstraint->data->stretch;
		ikConstraint->softness = ikConstraint->data->softness;
		ikConstraint->mix = ikConstraint->data->mix;
	}

	for (i = 0; i < self->transformConstraintsCount; ++i) {
		sp40TransformConstraint *constraint = self->transformConstraints[i];
		sp40TransformConstraintData *data = constraint->data;
		constraint->mixRotate = data->mixRotate;
		constraint->mixX = data->mixX;
		constraint->mixY = data->mixY;
		constraint->mixScaleX = data->mixScaleX;
		constraint->mixScaleY = data->mixScaleY;
		constraint->mixShearY = data->mixShearY;
	}

	for (i = 0; i < self->pathConstraintsCount; ++i) {
		sp40PathConstraint *constraint = self->pathConstraints[i];
		sp40PathConstraintData *data = constraint->data;
		constraint->position = data->position;
		constraint->spacing = data->spacing;
		constraint->mixRotate = data->mixRotate;
		constraint->mixX = data->mixX;
		constraint->mixY = data->mixY;
	}
}

void sp40Skeleton_setSlotsToSetupPose(const sp40Skeleton *self) {
	int i;
	memcpy(self->drawOrder, self->slots, self->slotsCount * sizeof(sp40Slot *));
	for (i = 0; i < self->slotsCount; ++i)
		sp40Slot_setToSetupPose(self->slots[i]);
}

sp40Bone *sp40Skeleton_findBone(const sp40Skeleton *self, const char *boneName) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		if (strcmp(self->data->bones[i]->name, boneName) == 0) return self->bones[i];
	return 0;
}

sp40Slot *sp40Skeleton_findSlot(const sp40Skeleton *self, const char *slotName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i)
		if (strcmp(self->data->slots[i]->name, slotName) == 0) return self->slots[i];
	return 0;
}

int sp40Skeleton_setSkinByName(sp40Skeleton *self, const char *skinName) {
	sp40Skin *skin;
	if (!skinName) {
		sp40Skeleton_setSkin(self, 0);
		return 1;
	}
	skin = sp40SkeletonData_findSkin(self->data, skinName);
	if (!skin) return 0;
	sp40Skeleton_setSkin(self, skin);
	return 1;
}

void sp40Skeleton_setSkin(sp40Skeleton *self, sp40Skin *newSkin) {
	if (self->skin == newSkin) return;
	if (newSkin) {
		if (self->skin)
			sp40Skin_attachAll(newSkin, self, self->skin);
		else {
			/* No previous skin, attach setup pose attachments. */
			int i;
			for (i = 0; i < self->slotsCount; ++i) {
				sp40Slot *slot = self->slots[i];
				if (slot->data->attachmentName) {
					sp40Attachment *attachment = sp40Skin_getAttachment(newSkin, i, slot->data->attachmentName);
					if (attachment) sp40Slot_setAttachment(slot, attachment);
				}
			}
		}
	}
	CONST_CAST(sp40Skin *, self->skin) = newSkin;
	sp40Skeleton_updateCache(self);
}

sp40Attachment *
sp40Skeleton_getAttachmentForSlotName(const sp40Skeleton *self, const char *slotName, const char *attachmentName) {
	int slotIndex = sp40SkeletonData_findSlot(self->data, slotName)->index;
	return sp40Skeleton_getAttachmentForSlotIndex(self, slotIndex, attachmentName);
}

sp40Attachment *sp40Skeleton_getAttachmentForSlotIndex(const sp40Skeleton *self, int slotIndex, const char *attachmentName) {
	if (slotIndex == -1) return 0;
	if (self->skin) {
		sp40Attachment *attachment = sp40Skin_getAttachment(self->skin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	if (self->data->defaultSkin) {
		sp40Attachment *attachment = sp40Skin_getAttachment(self->data->defaultSkin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	return 0;
}

int sp40Skeleton_setAttachment(sp40Skeleton *self, const char *slotName, const char *attachmentName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i) {
		sp40Slot *slot = self->slots[i];
		if (strcmp(slot->data->name, slotName) == 0) {
			if (!attachmentName)
				sp40Slot_setAttachment(slot, 0);
			else {
				sp40Attachment *attachment = sp40Skeleton_getAttachmentForSlotIndex(self, i, attachmentName);
				if (!attachment) return 0;
				sp40Slot_setAttachment(slot, attachment);
			}
			return 1;
		}
	}
	return 0;
}

sp40IkConstraint *sp40Skeleton_findIkConstraint(const sp40Skeleton *self, const char *constraintName) {
	int i;
	for (i = 0; i < self->ikConstraintsCount; ++i)
		if (strcmp(self->ikConstraints[i]->data->name, constraintName) == 0) return self->ikConstraints[i];
	return 0;
}

sp40TransformConstraint *sp40Skeleton_findTransformConstraint(const sp40Skeleton *self, const char *constraintName) {
	int i;
	for (i = 0; i < self->transformConstraintsCount; ++i)
		if (strcmp(self->transformConstraints[i]->data->name, constraintName) == 0)
			return self->transformConstraints[i];
	return 0;
}

sp40PathConstraint *sp40Skeleton_findPathConstraint(const sp40Skeleton *self, const char *constraintName) {
	int i;
	for (i = 0; i < self->pathConstraintsCount; ++i)
		if (strcmp(self->pathConstraints[i]->data->name, constraintName) == 0) return self->pathConstraints[i];
	return 0;
}

void sp40Skeleton_update(sp40Skeleton *self, float deltaTime) {
	self->time += deltaTime;
}

/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated July 28, 2023. Replaces all prior versions.
 *
 * Copyright (c) 2013-2023, Esoteric Software LLC
 *
 * Integration of the Spine Runtimes into software or otherwise creating
 * derivative works of the Spine Runtimes is permitted under the terms and
 * conditions of Section 2 of the Spine Editor License Agreement:
 * http://esotericsoftware.com/spine-editor-license
 *
 * Otherwise, it is permitted to integrate the Spine Runtimes into software or
 * otherwise create derivative works of the Spine Runtimes (collectively,
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
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE
 * SPINE RUNTIMES, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#include <spine/Skeleton.h>
#include <spine/extension.h>
#include <stdlib.h>
#include <string.h>

typedef enum {
	SP_UPDATE_BONE,
	SP_UPDATE_IK_CONSTRAINT,
	SP_UPDATE_PATH_CONSTRAINT,
	SP_UPDATE_TRANSFORM_CONSTRAINT,
	SP_UPDATE_PHYSICS_CONSTRAINT
} _sp42UpdateType;

typedef struct {
	_sp42UpdateType type;
	void *object;
} _sp42Update;

typedef struct {
	sp42Skeleton super;

	int updateCacheCount;
	int updateCacheCapacity;
	_sp42Update *updateCache;
} _sp42Skeleton;

sp42Skeleton *sp42Skeleton_create(sp42SkeletonData *data) {
	int i;
	int *childrenCounts;

	_sp42Skeleton *internal = NEW(_sp42Skeleton);
	sp42Skeleton *self = SUPER(internal);
	self->data = data;
	self->skin = NULL;
	sp42Color_setFromFloats(&self->color, 1, 1, 1, 1);
	self->scaleX = 1;
	self->scaleY = 1;
	self->time = 0;

	self->bonesCount = self->data->bonesCount;
	self->bones = MALLOC(sp42Bone *, self->bonesCount);
	childrenCounts = CALLOC(int, self->bonesCount);

	for (i = 0; i < self->bonesCount; ++i) {
		sp42BoneData *boneData = self->data->bones[i];
		sp42Bone *newBone;
		if (!boneData->parent)
			newBone = sp42Bone_create(boneData, self, 0);
		else {
			sp42Bone *parent = self->bones[boneData->parent->index];
			newBone = sp42Bone_create(boneData, self, parent);
			++childrenCounts[boneData->parent->index];
		}
		self->bones[i] = newBone;
	}
	for (i = 0; i < self->bonesCount; ++i) {
		sp42BoneData *boneData = self->data->bones[i];
		sp42Bone *bone = self->bones[i];
		bone->children = MALLOC(sp42Bone *, childrenCounts[boneData->index]);
	}
	for (i = 0; i < self->bonesCount; ++i) {
		sp42Bone *bone = self->bones[i];
		sp42Bone *parent = bone->parent;
		if (parent)
			parent->children[parent->childrenCount++] = bone;
	}
	self->root = (self->bonesCount > 0 ? self->bones[0] : NULL);

	self->slotsCount = data->slotsCount;
	self->slots = MALLOC(sp42Slot *, self->slotsCount);
	for (i = 0; i < self->slotsCount; ++i) {
		sp42SlotData *slotData = data->slots[i];
		sp42Bone *bone = self->bones[slotData->boneData->index];
		self->slots[i] = sp42Slot_create(slotData, bone);
	}

	self->drawOrder = MALLOC(sp42Slot *, self->slotsCount);
	memcpy(self->drawOrder, self->slots, sizeof(sp42Slot *) * self->slotsCount);

	self->ikConstraintsCount = data->ikConstraintsCount;
	self->ikConstraints = MALLOC(sp42IkConstraint *, self->ikConstraintsCount);
	for (i = 0; i < self->data->ikConstraintsCount; ++i)
		self->ikConstraints[i] = sp42IkConstraint_create(self->data->ikConstraints[i], self);

	self->transformConstraintsCount = data->transformConstraintsCount;
	self->transformConstraints = MALLOC(sp42TransformConstraint *, self->transformConstraintsCount);
	for (i = 0; i < self->data->transformConstraintsCount; ++i)
		self->transformConstraints[i] = sp42TransformConstraint_create(self->data->transformConstraints[i], self);

	self->pathConstraintsCount = data->pathConstraintsCount;
	self->pathConstraints = MALLOC(sp42PathConstraint *, self->pathConstraintsCount);
	for (i = 0; i < self->data->pathConstraintsCount; i++)
		self->pathConstraints[i] = sp42PathConstraint_create(self->data->pathConstraints[i], self);

	self->physicsConstraintsCount = data->physicsConstraintsCount;
	self->physicsConstraints = MALLOC(sp42PhysicsConstraint *, self->physicsConstraintsCount);
	for (i = 0; i < self->data->physicsConstraintsCount; i++)
		self->physicsConstraints[i] = sp42PhysicsConstraint_create(self->data->physicsConstraints[i], self);


	sp42Color_setFromFloats(&self->color, 1, 1, 1, 1);

	self->scaleX = 1;
	self->scaleY = 1;

	self->time = 0;

	sp42Skeleton_updateCache(self);

	FREE(childrenCounts);

	return self;
}

void sp42Skeleton_dispose(sp42Skeleton *self) {
	int i;
	_sp42Skeleton *internal = SUB_CAST(_sp42Skeleton, self);

	FREE(internal->updateCache);

	for (i = 0; i < self->bonesCount; ++i)
		sp42Bone_dispose(self->bones[i]);
	FREE(self->bones);

	for (i = 0; i < self->slotsCount; ++i)
		sp42Slot_dispose(self->slots[i]);
	FREE(self->slots);

	for (i = 0; i < self->ikConstraintsCount; ++i)
		sp42IkConstraint_dispose(self->ikConstraints[i]);
	FREE(self->ikConstraints);

	for (i = 0; i < self->transformConstraintsCount; ++i)
		sp42TransformConstraint_dispose(self->transformConstraints[i]);
	FREE(self->transformConstraints);

	for (i = 0; i < self->pathConstraintsCount; i++)
		sp42PathConstraint_dispose(self->pathConstraints[i]);
	FREE(self->pathConstraints);

	for (i = 0; i < self->physicsConstraintsCount; i++)
		sp42PhysicsConstraint_dispose(self->physicsConstraints[i]);
	FREE(self->physicsConstraints);

	FREE(self->drawOrder);
	FREE(self);
}

static void _addToUpdateCache(_sp42Skeleton *const internal, _sp42UpdateType type, void *object) {
	_sp42Update *update;
	if (internal->updateCacheCount == internal->updateCacheCapacity) {
		internal->updateCacheCapacity *= 2;
		internal->updateCache = (_sp42Update *) REALLOC(internal->updateCache, _sp42Update, internal->updateCacheCapacity);
	}
	update = internal->updateCache + internal->updateCacheCount;
	update->type = type;
	update->object = object;
	++internal->updateCacheCount;
}

static void _sortBone(_sp42Skeleton *const internal, sp42Bone *bone) {
	if (bone->sorted) return;
	if (bone->parent) _sortBone(internal, bone->parent);
	bone->sorted = 1;
	_addToUpdateCache(internal, SP_UPDATE_BONE, bone);
}

static void
_sortPathConstraintAttachmentBones(_sp42Skeleton *const internal, sp42Attachment *attachment, sp42Bone *slotBone) {
	sp42PathAttachment *pathAttachment = (sp42PathAttachment *) attachment;
	int *pathBones;
	int pathBonesCount;
	if (pathAttachment->super.super.type != SP_ATTACHMENT_PATH) return;
	pathBones = pathAttachment->super.bones;
	pathBonesCount = pathAttachment->super.bonesCount;
	if (pathBones == 0)
		_sortBone(internal, slotBone);
	else {
		sp42Bone **bones = internal->super.bones;
		int i = 0, n;

		for (i = 0, n = pathBonesCount; i < n;) {
			int nn = pathBones[i++];
			nn += i;
			while (i < nn)
				_sortBone(internal, bones[pathBones[i++]]);
		}
	}
}

static void _sortPathConstraintAttachment(_sp42Skeleton *const internal, sp42Skin *skin, int slotIndex, sp42Bone *slotBone) {
	_Entry *entry = SUB_CAST(_sp42Skin, skin)->entries;
	while (entry) {
		if (entry->slotIndex == slotIndex) _sortPathConstraintAttachmentBones(internal, entry->attachment, slotBone);
		entry = entry->next;
	}
}

static void _sortReset(sp42Bone **bones, int bonesCount) {
	int i;
	for (i = 0; i < bonesCount; ++i) {
		sp42Bone *bone = bones[i];
		if (!bone->active) continue;
		if (bone->sorted) _sortReset(bone->children, bone->childrenCount);
		bone->sorted = 0;
	}
}

static void _sortIkConstraint(_sp42Skeleton *const internal, sp42IkConstraint *constraint) {
	sp42Bone *target = constraint->target;
	sp42Bone **constrained;
	sp42Bone *parent;

	constraint->active = constraint->target->active && (!constraint->data->skinRequired || (internal->super.skin != 0 &&
																							sp42IkConstraintDataArray_contains(
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
		sp42Bone *child = constrained[constraint->bonesCount - 1];
		_sortBone(internal, child);

		_addToUpdateCache(internal, SP_UPDATE_IK_CONSTRAINT, constraint);

		_sortReset(parent->children, parent->childrenCount);
		child->sorted = 1;
	}
}

static void _sortPathConstraint(_sp42Skeleton *const internal, sp42PathConstraint *constraint) {
	sp42Slot *slot = constraint->target;
	int slotIndex = slot->data->index;
	sp42Bone *slotBone = slot->bone;
	int i, n, boneCount;
	sp42Attachment *attachment;
	sp42Bone **constrained;
	sp42Skeleton *skeleton = SUPER_CAST(sp42Skeleton, internal);

	constraint->active = constraint->target->bone->active && (!constraint->data->skinRequired ||
															  (internal->super.skin != 0 &&
															   sp42PathConstraintDataArray_contains(
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

static void _sortTransformConstraint(_sp42Skeleton *const internal, sp42TransformConstraint *constraint) {
	int i, boneCount;
	sp42Bone **constrained;
	sp42Bone *child;

	constraint->active = constraint->target->active && (!constraint->data->skinRequired || (internal->super.skin != 0 &&
																							sp42TransformConstraintDataArray_contains(
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

static void _sortPhysicsConstraint(_sp42Skeleton *const internal, sp42PhysicsConstraint *constraint) {
	sp42Bone *bone = constraint->bone;
	constraint->active = constraint->bone->active && (!constraint->data->skinRequired || (internal->super.skin != 0 &&
																						  sp42PhysicsConstraintDataArray_contains(
																								  internal->super.skin->physicsConstraints,
																								  constraint->data)));
	if (!constraint->active)
		return;

	_sortBone(internal, bone);
	_addToUpdateCache(internal, SP_UPDATE_PHYSICS_CONSTRAINT, constraint);

	_sortReset(bone->children, bone->childrenCount);
	bone->sorted = -1;
}

void sp42Skeleton_updateCache(sp42Skeleton *self) {
	int i, ii;
	sp42Bone **bones;
	sp42IkConstraint **ikConstraints;
	sp42PathConstraint **pathConstraints;
	sp42TransformConstraint **transformConstraints;
	sp42PhysicsConstraint **physicsConstraints;
	int ikCount, transformCount, pathCount, physicsCount, constraintCount;
	_sp42Skeleton *internal = SUB_CAST(_sp42Skeleton, self);

	internal->updateCacheCapacity =
			self->bonesCount + self->ikConstraintsCount + self->transformConstraintsCount + self->pathConstraintsCount +
			self->physicsConstraintsCount;
	FREE(internal->updateCache);
	internal->updateCache = MALLOC(_sp42Update, internal->updateCacheCapacity);
	internal->updateCacheCount = 0;

	bones = self->bones;
	for (i = 0; i < self->bonesCount; ++i) {
		sp42Bone *bone = bones[i];
		bone->sorted = bone->data->skinRequired;
		bone->active = !bone->sorted;
	}

	if (self->skin) {
		sp42BoneDataArray *skinBones = self->skin->bones;
		for (i = 0; i < skinBones->size; i++) {
			sp42Bone *bone = self->bones[skinBones->items[i]->index];
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
	physicsConstraints = self->physicsConstraints;
	ikCount = self->ikConstraintsCount;
	transformCount = self->transformConstraintsCount;
	pathCount = self->pathConstraintsCount;
	physicsCount = self->physicsConstraintsCount;
	constraintCount = ikCount + transformCount + pathCount + physicsCount;

	i = 0;
continue_outer:
	for (; i < constraintCount; i++) {
		for (ii = 0; ii < ikCount; ii++) {
			sp42IkConstraint *ikConstraint = ikConstraints[ii];
			if (ikConstraint->data->order == i) {
				_sortIkConstraint(internal, ikConstraint);
				i++;
				goto continue_outer;
			}
		}

		for (ii = 0; ii < transformCount; ii++) {
			sp42TransformConstraint *transformConstraint = transformConstraints[ii];
			if (transformConstraint->data->order == i) {
				_sortTransformConstraint(internal, transformConstraint);
				i++;
				goto continue_outer;
			}
		}

		for (ii = 0; ii < pathCount; ii++) {
			sp42PathConstraint *pathConstraint = pathConstraints[ii];
			if (pathConstraint->data->order == i) {
				_sortPathConstraint(internal, pathConstraint);
				i++;
				goto continue_outer;
			}
		}

		for (ii = 0; ii < physicsCount; ii++) {
			sp42PhysicsConstraint *physicsConstraint = physicsConstraints[ii];
			if (physicsConstraint->data->order == i) {
				_sortPhysicsConstraint(internal, physicsConstraint);
				i++;
				goto continue_outer;
			}
		}
	}

	for (i = 0; i < self->bonesCount; ++i)
		_sortBone(internal, self->bones[i]);
}

void sp42Skeleton_updateWorldTransform(const sp42Skeleton *self, sp42Physics physics) {
	int i, n;
	_sp42Skeleton *internal = SUB_CAST(_sp42Skeleton, self);

	for (i = 0, n = self->bonesCount; i < n; i++) {
		sp42Bone *bone = self->bones[i];
		bone->ax = bone->x;
		bone->ay = bone->y;
		bone->arotation = bone->rotation;
		bone->ascaleX = bone->scaleX;
		bone->ascaleY = bone->scaleY;
		bone->ashearX = bone->shearX;
		bone->ashearY = bone->shearY;
	}

	for (i = 0; i < internal->updateCacheCount; ++i) {
		_sp42Update *update = internal->updateCache + i;
		switch (update->type) {
			case SP_UPDATE_BONE:
				sp42Bone_update((sp42Bone *) update->object);
				break;
			case SP_UPDATE_IK_CONSTRAINT:
				sp42IkConstraint_update((sp42IkConstraint *) update->object);
				break;
			case SP_UPDATE_TRANSFORM_CONSTRAINT:
				sp42TransformConstraint_update((sp42TransformConstraint *) update->object);
				break;
			case SP_UPDATE_PATH_CONSTRAINT:
				sp42PathConstraint_update((sp42PathConstraint *) update->object);
				break;
			case SP_UPDATE_PHYSICS_CONSTRAINT:
				sp42PhysicsConstraint_update((sp42PhysicsConstraint *) update->object, physics);
		}
	}
}

void sp42Skeleton_update(sp42Skeleton *self, float delta) {
	self->time += delta;
}

void sp42Skeleton_updateWorldTransformWith(const sp42Skeleton *self, const sp42Bone *parent, sp42Physics physics) {
	/* Apply the parent bone transform to the root bone. The root bone always inherits scale, rotation and reflection. */
	int i;
	float rotationY, la, lb, lc, ld;
	_sp42Skeleton *internal = SUB_CAST(_sp42Skeleton, self);
	sp42Bone *rootBone = self->root;
	float pa = parent->a, pb = parent->b, pc = parent->c, pd = parent->d;
	rootBone->worldX = pa * self->x + pb * self->y + parent->worldX;
	rootBone->worldY = pc * self->x + pd * self->y + parent->worldY;

	rotationY = rootBone->rotation + 90 + rootBone->shearY;
	la = COS_DEG(rootBone->rotation + rootBone->shearX) * rootBone->scaleX;
	lb = COS_DEG(rotationY) * rootBone->scaleY;
	lc = SIN_DEG(rootBone->rotation + rootBone->shearX) * rootBone->scaleX;
	ld = SIN_DEG(rotationY) * rootBone->scaleY;
	rootBone->a = (pa * la + pb * lc) * self->scaleX;
	rootBone->b = (pa * lb + pb * ld) * self->scaleX;
	rootBone->c = (pc * la + pd * lc) * self->scaleY;
	rootBone->d = (pc * lb + pd * ld) * self->scaleY;

	/* Update everything except root bone. */
	for (i = 0; i < internal->updateCacheCount; ++i) {
		_sp42Update *update = internal->updateCache + i;
		switch (update->type) {
			case SP_UPDATE_BONE:
				if ((sp42Bone *) update->object != rootBone) sp42Bone_updateWorldTransform((sp42Bone *) update->object);
				break;
			case SP_UPDATE_IK_CONSTRAINT:
				sp42IkConstraint_update((sp42IkConstraint *) update->object);
				break;
			case SP_UPDATE_TRANSFORM_CONSTRAINT:
				sp42TransformConstraint_update((sp42TransformConstraint *) update->object);
				break;
			case SP_UPDATE_PATH_CONSTRAINT:
				sp42PathConstraint_update((sp42PathConstraint *) update->object);
				break;
			case SP_UPDATE_PHYSICS_CONSTRAINT:
				sp42PhysicsConstraint_update((sp42PhysicsConstraint *) update->object, physics);
		}
	}
}

void sp42Skeleton_setToSetupPose(const sp42Skeleton *self) {
	sp42Skeleton_setBonesToSetupPose(self);
	sp42Skeleton_setSlotsToSetupPose(self);
}

void sp42Skeleton_setBonesToSetupPose(const sp42Skeleton *self) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		sp42Bone_setToSetupPose(self->bones[i]);

	for (i = 0; i < self->ikConstraintsCount; ++i) {
		sp42IkConstraint_setToSetupPose(self->ikConstraints[i]);
	}

	for (i = 0; i < self->transformConstraintsCount; ++i) {
		sp42TransformConstraint_setToSetupPose(self->transformConstraints[i]);
	}

	for (i = 0; i < self->pathConstraintsCount; ++i) {
		sp42PathConstraint_setToSetupPose(self->pathConstraints[i]);
	}

	for (i = 0; i < self->physicsConstraintsCount; ++i) {
		sp42PhysicsConstraint_setToSetupPose(self->physicsConstraints[i]);
	}
}

void sp42Skeleton_setSlotsToSetupPose(const sp42Skeleton *self) {
	int i;
	memcpy(self->drawOrder, self->slots, self->slotsCount * sizeof(sp42Slot *));
	for (i = 0; i < self->slotsCount; ++i)
		sp42Slot_setToSetupPose(self->slots[i]);
}

sp42Bone *sp42Skeleton_findBone(const sp42Skeleton *self, const char *boneName) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		if (strcmp(self->data->bones[i]->name, boneName) == 0) return self->bones[i];
	return 0;
}

sp42Slot *sp42Skeleton_findSlot(const sp42Skeleton *self, const char *slotName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i)
		if (strcmp(self->data->slots[i]->name, slotName) == 0) return self->slots[i];
	return 0;
}

int sp42Skeleton_setSkinByName(sp42Skeleton *self, const char *skinName) {
	sp42Skin *skin;
	if (!skinName) {
		sp42Skeleton_setSkin(self, 0);
		return 1;
	}
	skin = sp42SkeletonData_findSkin(self->data, skinName);
	if (!skin) return 0;
	sp42Skeleton_setSkin(self, skin);
	return 1;
}

void sp42Skeleton_setSkin(sp42Skeleton *self, sp42Skin *newSkin) {
	if (self->skin == newSkin) return;
	if (newSkin) {
		if (self->skin)
			sp42Skin_attachAll(newSkin, self, self->skin);
		else {
			/* No previous skin, attach setup pose attachments. */
			int i;
			for (i = 0; i < self->slotsCount; ++i) {
				sp42Slot *slot = self->slots[i];
				if (slot->data->attachmentName) {
					sp42Attachment *attachment = sp42Skin_getAttachment(newSkin, i, slot->data->attachmentName);
					if (attachment) sp42Slot_setAttachment(slot, attachment);
				}
			}
		}
	}
	self->skin = newSkin;
	sp42Skeleton_updateCache(self);
}

sp42Attachment *
sp42Skeleton_getAttachmentForSlotName(const sp42Skeleton *self, const char *slotName, const char *attachmentName) {
	int slotIndex = sp42SkeletonData_findSlot(self->data, slotName)->index;
	return sp42Skeleton_getAttachmentForSlotIndex(self, slotIndex, attachmentName);
}

sp42Attachment *sp42Skeleton_getAttachmentForSlotIndex(const sp42Skeleton *self, int slotIndex, const char *attachmentName) {
	if (slotIndex == -1) return 0;
	if (self->skin) {
		sp42Attachment *attachment = sp42Skin_getAttachment(self->skin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	if (self->data->defaultSkin) {
		sp42Attachment *attachment = sp42Skin_getAttachment(self->data->defaultSkin, slotIndex, attachmentName);
		if (attachment) return attachment;
	}
	return 0;
}

int sp42Skeleton_setAttachment(sp42Skeleton *self, const char *slotName, const char *attachmentName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i) {
		sp42Slot *slot = self->slots[i];
		if (strcmp(slot->data->name, slotName) == 0) {
			if (!attachmentName)
				sp42Slot_setAttachment(slot, 0);
			else {
				sp42Attachment *attachment = sp42Skeleton_getAttachmentForSlotIndex(self, i, attachmentName);
				if (!attachment) return 0;
				sp42Slot_setAttachment(slot, attachment);
			}
			return 1;
		}
	}
	return 0;
}

sp42IkConstraint *sp42Skeleton_findIkConstraint(const sp42Skeleton *self, const char *constraintName) {
	int i;
	for (i = 0; i < self->ikConstraintsCount; ++i)
		if (strcmp(self->ikConstraints[i]->data->name, constraintName) == 0) return self->ikConstraints[i];
	return 0;
}

sp42TransformConstraint *sp42Skeleton_findTransformConstraint(const sp42Skeleton *self, const char *constraintName) {
	int i;
	for (i = 0; i < self->transformConstraintsCount; ++i)
		if (strcmp(self->transformConstraints[i]->data->name, constraintName) == 0)
			return self->transformConstraints[i];
	return 0;
}

sp42PathConstraint *sp42Skeleton_findPathConstraint(const sp42Skeleton *self, const char *constraintName) {
	int i;
	for (i = 0; i < self->pathConstraintsCount; ++i)
		if (strcmp(self->pathConstraints[i]->data->name, constraintName) == 0) return self->pathConstraints[i];
	return 0;
}


sp42PhysicsConstraint *sp42Skeleton_findPhysicsConstraint(const sp42Skeleton *self, const char *constraintName) {
	int i;
	for (i = 0; i < self->physicsConstraintsCount; ++i)
		if (strcmp(self->physicsConstraints[i]->data->name, constraintName) == 0) return self->physicsConstraints[i];
	return 0;
}

void sp42Skeleton_physicsTranslate(sp42Skeleton *self, float x, float y) {
	for (int i = 0; i < (int) self->physicsConstraintsCount; i++) {
		sp42PhysicsConstraint_translate(self->physicsConstraints[i], x, y);
	}
}

void sp42Skeleton_physicsRotate(sp42Skeleton *self, float x, float y, float degrees) {
	for (int i = 0; i < (int) self->physicsConstraintsCount; i++) {
		sp42PhysicsConstraint_rotate(self->physicsConstraints[i], x, y, degrees);
	}
}

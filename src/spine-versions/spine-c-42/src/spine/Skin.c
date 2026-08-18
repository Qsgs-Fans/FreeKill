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

#include <spine/Skin.h>
#include <spine/extension.h>
#include <stdio.h>

_SP_ARRAY_IMPLEMENT_TYPE(sp42BoneDataArray, sp42BoneData *)

_SP_ARRAY_IMPLEMENT_TYPE(sp42IkConstraintDataArray, sp42IkConstraintData *)

_SP_ARRAY_IMPLEMENT_TYPE(sp42TransformConstraintDataArray, sp42TransformConstraintData *)

_SP_ARRAY_IMPLEMENT_TYPE(sp42PathConstraintDataArray, sp42PathConstraintData *)

_SP_ARRAY_IMPLEMENT_TYPE(sp42PhysicsConstraintDataArray, sp42PhysicsConstraintData *)

static _Entry *_Entry_create(int slotIndex, const char *name, sp42Attachment *attachment) {
	_Entry *self = NEW(_Entry);
	self->slotIndex = slotIndex;
	MALLOC_STR(self->name, (char *) name);
	self->attachment = attachment;
	return self;
}

static void _Entry_dispose(_Entry *self) {
	sp42Attachment_dispose(self->attachment);
	FREE(self->name);
	FREE(self);
}

static _SkinHashTableEntry *_SkinHashTableEntry_create(_Entry *entry) {
	_SkinHashTableEntry *self = NEW(_SkinHashTableEntry);
	self->entry = entry;
	return self;
}

static void _SkinHashTableEntry_dispose(_SkinHashTableEntry *self) {
	FREE(self);
}

/**/

sp42Skin *sp42Skin_create(const char *name) {
	sp42Skin *self = SUPER(NEW(_sp42Skin));
	MALLOC_STR(self->name, (char *) name);
	self->bones = sp42BoneDataArray_create(4);
	self->ikConstraints = sp42IkConstraintDataArray_create(4);
	self->transformConstraints = sp42TransformConstraintDataArray_create(4);
	self->pathConstraints = sp42PathConstraintDataArray_create(4);
	self->physicsConstraints = sp42PhysicsConstraintDataArray_create(4);
	sp42Color_setFromFloats(&self->color, 0.99607843f, 0.61960787f, 0.30980393f, 1);
	return self;
}

void sp42Skin_dispose(sp42Skin *self) {
	_Entry *entry = SUB_CAST(_sp42Skin, self)->entries;

	while (entry) {
		_Entry *nextEntry = entry->next;
		_Entry_dispose(entry);
		entry = nextEntry;
	}

	{
		_SkinHashTableEntry **currentHashtableEntry = SUB_CAST(_sp42Skin, self)->entriesHashTable;
		int i;

		for (i = 0; i < SKIN_ENTRIES_HASH_TABLE_SIZE; ++i, ++currentHashtableEntry) {
			_SkinHashTableEntry *hashtableEntry = *currentHashtableEntry;

			while (hashtableEntry) {
				_SkinHashTableEntry *nextEntry = hashtableEntry->next;
				_SkinHashTableEntry_dispose(hashtableEntry);
				hashtableEntry = nextEntry;
			}
		}
	}

	sp42BoneDataArray_dispose(self->bones);
	sp42IkConstraintDataArray_dispose(self->ikConstraints);
	sp42TransformConstraintDataArray_dispose(self->transformConstraints);
	sp42PathConstraintDataArray_dispose(self->pathConstraints);
	sp42PhysicsConstraintDataArray_dispose(self->physicsConstraints);
	FREE(self->name);
	FREE(self);
}

void sp42Skin_setAttachment(sp42Skin *self, int slotIndex, const char *name, sp42Attachment *attachment) {
	_SkinHashTableEntry *existingEntry = 0;
	_SkinHashTableEntry *hashEntry = SUB_CAST(_sp42Skin, self)->entriesHashTable[(unsigned int) slotIndex % SKIN_ENTRIES_HASH_TABLE_SIZE];
	while (hashEntry) {
		if (hashEntry->entry->slotIndex == slotIndex && strcmp(hashEntry->entry->name, name) == 0) {
			existingEntry = hashEntry;
			break;
		}
		hashEntry = hashEntry->next;
	}

	if (attachment) attachment->refCount++;

	if (existingEntry) {
		if (hashEntry->entry->attachment) sp42Attachment_dispose(hashEntry->entry->attachment);
		hashEntry->entry->attachment = attachment;
	} else {
		_Entry *newEntry = _Entry_create(slotIndex, name, attachment);
		newEntry->next = SUB_CAST(_sp42Skin, self)->entries;
		SUB_CAST(_sp42Skin, self)->entries = newEntry;
		{
			unsigned int hashTableIndex = (unsigned int) slotIndex % SKIN_ENTRIES_HASH_TABLE_SIZE;
			_SkinHashTableEntry **hashTable = SUB_CAST(_sp42Skin, self)->entriesHashTable;

			_SkinHashTableEntry *newHashEntry = _SkinHashTableEntry_create(newEntry);
			newHashEntry->next = hashTable[hashTableIndex];
			SUB_CAST(_sp42Skin, self)->entriesHashTable[hashTableIndex] = newHashEntry;
		}
	}
}

sp42Attachment *sp42Skin_getAttachment(const sp42Skin *self, int slotIndex, const char *name) {
	const _SkinHashTableEntry *hashEntry = SUB_CAST(_sp42Skin, self)->entriesHashTable[(unsigned int) slotIndex % SKIN_ENTRIES_HASH_TABLE_SIZE];
	while (hashEntry) {
		if (hashEntry->entry->slotIndex == slotIndex && strcmp(hashEntry->entry->name, name) == 0)
			return hashEntry->entry->attachment;
		hashEntry = hashEntry->next;
	}
	return 0;
}

const char *sp42Skin_getAttachmentName(const sp42Skin *self, int slotIndex, int attachmentIndex) {
	const _Entry *entry = SUB_CAST(_sp42Skin, self)->entries;
	int i = 0;
	while (entry) {
		if (entry->slotIndex == slotIndex) {
			if (i == attachmentIndex) return entry->name;
			i++;
		}
		entry = entry->next;
	}
	return 0;
}

void sp42Skin_attachAll(const sp42Skin *self, sp42Skeleton *skeleton, const sp42Skin *oldSkin) {
	const _Entry *entry = SUB_CAST(_sp42Skin, oldSkin)->entries;
	while (entry) {
		sp42Slot *slot = skeleton->slots[entry->slotIndex];
		if (slot->attachment == entry->attachment) {
			sp42Attachment *attachment = sp42Skin_getAttachment(self, entry->slotIndex, entry->name);
			if (attachment) sp42Slot_setAttachment(slot, attachment);
		}
		entry = entry->next;
	}
}

void sp42Skin_addSkin(sp42Skin *self, const sp42Skin *other) {
	int i = 0;
	sp42SkinEntry *entry;

	for (i = 0; i < other->bones->size; i++) {
		if (!sp42BoneDataArray_contains(self->bones, other->bones->items[i]))
			sp42BoneDataArray_add(self->bones, other->bones->items[i]);
	}

	for (i = 0; i < other->ikConstraints->size; i++) {
		if (!sp42IkConstraintDataArray_contains(self->ikConstraints, other->ikConstraints->items[i]))
			sp42IkConstraintDataArray_add(self->ikConstraints, other->ikConstraints->items[i]);
	}

	for (i = 0; i < other->transformConstraints->size; i++) {
		if (!sp42TransformConstraintDataArray_contains(self->transformConstraints, other->transformConstraints->items[i]))
			sp42TransformConstraintDataArray_add(self->transformConstraints, other->transformConstraints->items[i]);
	}

	for (i = 0; i < other->pathConstraints->size; i++) {
		if (!sp42PathConstraintDataArray_contains(self->pathConstraints, other->pathConstraints->items[i]))
			sp42PathConstraintDataArray_add(self->pathConstraints, other->pathConstraints->items[i]);
	}

	for (i = 0; i < other->physicsConstraints->size; i++) {
		if (!sp42PhysicsConstraintDataArray_contains(self->physicsConstraints, other->physicsConstraints->items[i]))
			sp42PhysicsConstraintDataArray_add(self->physicsConstraints, other->physicsConstraints->items[i]);
	}

	entry = sp42Skin_getAttachments(other);
	while (entry) {
		sp42Skin_setAttachment(self, entry->slotIndex, entry->name, entry->attachment);
		entry = entry->next;
	}
}

void sp42Skin_copySkin(sp42Skin *self, const sp42Skin *other) {
	int i = 0;
	sp42SkinEntry *entry;

	for (i = 0; i < other->bones->size; i++) {
		if (!sp42BoneDataArray_contains(self->bones, other->bones->items[i]))
			sp42BoneDataArray_add(self->bones, other->bones->items[i]);
	}

	for (i = 0; i < other->ikConstraints->size; i++) {
		if (!sp42IkConstraintDataArray_contains(self->ikConstraints, other->ikConstraints->items[i]))
			sp42IkConstraintDataArray_add(self->ikConstraints, other->ikConstraints->items[i]);
	}

	for (i = 0; i < other->transformConstraints->size; i++) {
		if (!sp42TransformConstraintDataArray_contains(self->transformConstraints, other->transformConstraints->items[i]))
			sp42TransformConstraintDataArray_add(self->transformConstraints, other->transformConstraints->items[i]);
	}

	for (i = 0; i < other->pathConstraints->size; i++) {
		if (!sp42PathConstraintDataArray_contains(self->pathConstraints, other->pathConstraints->items[i]))
			sp42PathConstraintDataArray_add(self->pathConstraints, other->pathConstraints->items[i]);
	}

	for (i = 0; i < other->physicsConstraints->size; i++) {
		if (!sp42PhysicsConstraintDataArray_contains(self->physicsConstraints, other->physicsConstraints->items[i]))
			sp42PhysicsConstraintDataArray_add(self->physicsConstraints, other->physicsConstraints->items[i]);
	}

	entry = sp42Skin_getAttachments(other);
	while (entry) {
		if (entry->attachment->type == SP_ATTACHMENT_MESH) {
			sp42MeshAttachment *attachment = sp42MeshAttachment_newLinkedMesh(
					SUB_CAST(sp42MeshAttachment, entry->attachment));
			sp42Skin_setAttachment(self, entry->slotIndex, entry->name, SUPER(SUPER(attachment)));
		} else {
			sp42Attachment *attachment = entry->attachment ? sp42Attachment_copy(entry->attachment) : 0;
			sp42Skin_setAttachment(self, entry->slotIndex, entry->name, attachment);
		}
		entry = entry->next;
	}
}

sp42SkinEntry *sp42Skin_getAttachments(const sp42Skin *self) {
	return SUB_CAST(_sp42Skin, self)->entries;
}

void sp42Skin_clear(sp42Skin *self) {
	_Entry *entry = SUB_CAST(_sp42Skin, self)->entries;

	while (entry) {
		_Entry *nextEntry = entry->next;
		_Entry_dispose(entry);
		entry = nextEntry;
	}

	SUB_CAST(_sp42Skin, self)->entries = 0;

	{
		_SkinHashTableEntry **currentHashtableEntry = SUB_CAST(_sp42Skin, self)->entriesHashTable;
		int i;

		for (i = 0; i < SKIN_ENTRIES_HASH_TABLE_SIZE; ++i, ++currentHashtableEntry) {
			_SkinHashTableEntry *hashtableEntry = *currentHashtableEntry;

			while (hashtableEntry) {
				_SkinHashTableEntry *nextEntry = hashtableEntry->next;
				_SkinHashTableEntry_dispose(hashtableEntry);
				hashtableEntry = nextEntry;
			}

			SUB_CAST(_sp42Skin, self)->entriesHashTable[i] = 0;
		}
	}

	sp42BoneDataArray_clear(self->bones);
	sp42IkConstraintDataArray_clear(self->ikConstraints);
	sp42TransformConstraintDataArray_clear(self->transformConstraints);
	sp42PathConstraintDataArray_clear(self->pathConstraints);
	sp42PhysicsConstraintDataArray_clear(self->physicsConstraints);
}

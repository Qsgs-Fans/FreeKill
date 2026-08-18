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

#include <spine/Skin.h>
#include <spine/extension.h>
#include <stdio.h>

_SP_ARRAY_IMPLEMENT_TYPE(sp41BoneDataArray, sp41BoneData *)

_SP_ARRAY_IMPLEMENT_TYPE(sp41IkConstraintDataArray, sp41IkConstraintData *)

_SP_ARRAY_IMPLEMENT_TYPE(sp41TransformConstraintDataArray, sp41TransformConstraintData *)

_SP_ARRAY_IMPLEMENT_TYPE(sp41PathConstraintDataArray, sp41PathConstraintData *)

static _Entry *_Entry_create(int slotIndex, const char *name, sp41Attachment *attachment) {
	_Entry *self = NEW(_Entry);
	self->slotIndex = slotIndex;
	MALLOC_STR(self->name, name);
	self->attachment = attachment;
	return self;
}

static void _Entry_dispose(_Entry *self) {
	sp41Attachment_dispose(self->attachment);
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

sp41Skin *sp41Skin_create(const char *name) {
	sp41Skin *self = SUPER(NEW(_sp41Skin));
	MALLOC_STR(self->name, name);
	self->bones = sp41BoneDataArray_create(4);
	self->ikConstraints = sp41IkConstraintDataArray_create(4);
	self->transformConstraints = sp41TransformConstraintDataArray_create(4);
	self->pathConstraints = sp41PathConstraintDataArray_create(4);
	return self;
}

void sp41Skin_dispose(sp41Skin *self) {
	_Entry *entry = SUB_CAST(_sp41Skin, self)->entries;

	while (entry) {
		_Entry *nextEntry = entry->next;
		_Entry_dispose(entry);
		entry = nextEntry;
	}

	{
		_SkinHashTableEntry **currentHashtableEntry = SUB_CAST(_sp41Skin, self)->entriesHashTable;
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

	sp41BoneDataArray_dispose(self->bones);
	sp41IkConstraintDataArray_dispose(self->ikConstraints);
	sp41TransformConstraintDataArray_dispose(self->transformConstraints);
	sp41PathConstraintDataArray_dispose(self->pathConstraints);
	FREE(self->name);
	FREE(self);
}

void sp41Skin_setAttachment(sp41Skin *self, int slotIndex, const char *name, sp41Attachment *attachment) {
	_SkinHashTableEntry *existingEntry = 0;
	_SkinHashTableEntry *hashEntry = SUB_CAST(_sp41Skin, self)->entriesHashTable[(unsigned int) slotIndex % SKIN_ENTRIES_HASH_TABLE_SIZE];
	while (hashEntry) {
		if (hashEntry->entry->slotIndex == slotIndex && strcmp(hashEntry->entry->name, name) == 0) {
			existingEntry = hashEntry;
			break;
		}
		hashEntry = hashEntry->next;
	}

	if (attachment) attachment->refCount++;

	if (existingEntry) {
		if (hashEntry->entry->attachment) sp41Attachment_dispose(hashEntry->entry->attachment);
		hashEntry->entry->attachment = attachment;
	} else {
		_Entry *newEntry = _Entry_create(slotIndex, name, attachment);
		newEntry->next = SUB_CAST(_sp41Skin, self)->entries;
		SUB_CAST(_sp41Skin, self)->entries = newEntry;
		{
			unsigned int hashTableIndex = (unsigned int) slotIndex % SKIN_ENTRIES_HASH_TABLE_SIZE;
			_SkinHashTableEntry **hashTable = SUB_CAST(_sp41Skin, self)->entriesHashTable;

			_SkinHashTableEntry *newHashEntry = _SkinHashTableEntry_create(newEntry);
			newHashEntry->next = hashTable[hashTableIndex];
			SUB_CAST(_sp41Skin, self)->entriesHashTable[hashTableIndex] = newHashEntry;
		}
	}
}

sp41Attachment *sp41Skin_getAttachment(const sp41Skin *self, int slotIndex, const char *name) {
	const _SkinHashTableEntry *hashEntry = SUB_CAST(_sp41Skin, self)->entriesHashTable[(unsigned int) slotIndex % SKIN_ENTRIES_HASH_TABLE_SIZE];
	while (hashEntry) {
		if (hashEntry->entry->slotIndex == slotIndex && strcmp(hashEntry->entry->name, name) == 0)
			return hashEntry->entry->attachment;
		hashEntry = hashEntry->next;
	}
	return 0;
}

const char *sp41Skin_getAttachmentName(const sp41Skin *self, int slotIndex, int attachmentIndex) {
	const _Entry *entry = SUB_CAST(_sp41Skin, self)->entries;
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

void sp41Skin_attachAll(const sp41Skin *self, sp41Skeleton *skeleton, const sp41Skin *oldSkin) {
	const _Entry *entry = SUB_CAST(_sp41Skin, oldSkin)->entries;
	while (entry) {
		sp41Slot *slot = skeleton->slots[entry->slotIndex];
		if (slot->attachment == entry->attachment) {
			sp41Attachment *attachment = sp41Skin_getAttachment(self, entry->slotIndex, entry->name);
			if (attachment) sp41Slot_setAttachment(slot, attachment);
		}
		entry = entry->next;
	}
}

void sp41Skin_addSkin(sp41Skin *self, const sp41Skin *other) {
	int i = 0;
	sp41SkinEntry *entry;

	for (i = 0; i < other->bones->size; i++) {
		if (!sp41BoneDataArray_contains(self->bones, other->bones->items[i]))
			sp41BoneDataArray_add(self->bones, other->bones->items[i]);
	}

	for (i = 0; i < other->ikConstraints->size; i++) {
		if (!sp41IkConstraintDataArray_contains(self->ikConstraints, other->ikConstraints->items[i]))
			sp41IkConstraintDataArray_add(self->ikConstraints, other->ikConstraints->items[i]);
	}

	for (i = 0; i < other->transformConstraints->size; i++) {
		if (!sp41TransformConstraintDataArray_contains(self->transformConstraints, other->transformConstraints->items[i]))
			sp41TransformConstraintDataArray_add(self->transformConstraints, other->transformConstraints->items[i]);
	}

	for (i = 0; i < other->pathConstraints->size; i++) {
		if (!sp41PathConstraintDataArray_contains(self->pathConstraints, other->pathConstraints->items[i]))
			sp41PathConstraintDataArray_add(self->pathConstraints, other->pathConstraints->items[i]);
	}

	entry = sp41Skin_getAttachments(other);
	while (entry) {
		sp41Skin_setAttachment(self, entry->slotIndex, entry->name, entry->attachment);
		entry = entry->next;
	}
}

void sp41Skin_copySkin(sp41Skin *self, const sp41Skin *other) {
	int i = 0;
	sp41SkinEntry *entry;

	for (i = 0; i < other->bones->size; i++) {
		if (!sp41BoneDataArray_contains(self->bones, other->bones->items[i]))
			sp41BoneDataArray_add(self->bones, other->bones->items[i]);
	}

	for (i = 0; i < other->ikConstraints->size; i++) {
		if (!sp41IkConstraintDataArray_contains(self->ikConstraints, other->ikConstraints->items[i]))
			sp41IkConstraintDataArray_add(self->ikConstraints, other->ikConstraints->items[i]);
	}

	for (i = 0; i < other->transformConstraints->size; i++) {
		if (!sp41TransformConstraintDataArray_contains(self->transformConstraints, other->transformConstraints->items[i]))
			sp41TransformConstraintDataArray_add(self->transformConstraints, other->transformConstraints->items[i]);
	}

	for (i = 0; i < other->pathConstraints->size; i++) {
		if (!sp41PathConstraintDataArray_contains(self->pathConstraints, other->pathConstraints->items[i]))
			sp41PathConstraintDataArray_add(self->pathConstraints, other->pathConstraints->items[i]);
	}

	entry = sp41Skin_getAttachments(other);
	while (entry) {
		if (entry->attachment->type == SP_ATTACHMENT_MESH) {
			sp41MeshAttachment *attachment = sp41MeshAttachment_newLinkedMesh(
					SUB_CAST(sp41MeshAttachment, entry->attachment));
			sp41Skin_setAttachment(self, entry->slotIndex, entry->name, SUPER(SUPER(attachment)));
		} else {
			sp41Attachment *attachment = entry->attachment ? sp41Attachment_copy(entry->attachment) : 0;
			sp41Skin_setAttachment(self, entry->slotIndex, entry->name, attachment);
		}
		entry = entry->next;
	}
}

sp41SkinEntry *sp41Skin_getAttachments(const sp41Skin *self) {
	return SUB_CAST(_sp41Skin, self)->entries;
}

void sp41Skin_clear(sp41Skin *self) {
	_Entry *entry = SUB_CAST(_sp41Skin, self)->entries;

	while (entry) {
		_Entry *nextEntry = entry->next;
		_Entry_dispose(entry);
		entry = nextEntry;
	}

	SUB_CAST(_sp41Skin, self)->entries = 0;

	{
		_SkinHashTableEntry **currentHashtableEntry = SUB_CAST(_sp41Skin, self)->entriesHashTable;
		int i;

		for (i = 0; i < SKIN_ENTRIES_HASH_TABLE_SIZE; ++i, ++currentHashtableEntry) {
			_SkinHashTableEntry *hashtableEntry = *currentHashtableEntry;

			while (hashtableEntry) {
				_SkinHashTableEntry *nextEntry = hashtableEntry->next;
				_SkinHashTableEntry_dispose(hashtableEntry);
				hashtableEntry = nextEntry;
			}

			SUB_CAST(_sp41Skin, self)->entriesHashTable[i] = 0;
		}
	}

	sp41BoneDataArray_clear(self->bones);
	sp41IkConstraintDataArray_clear(self->ikConstraints);
	sp41TransformConstraintDataArray_clear(self->transformConstraints);
	sp41PathConstraintDataArray_clear(self->pathConstraints);
}

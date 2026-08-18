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

#include <spine/Skin.h>
#include <spine/extension.h>
#include <stdio.h>

_SP_ARRAY_IMPLEMENT_TYPE(sp40BoneDataArray, sp40BoneData *)

_SP_ARRAY_IMPLEMENT_TYPE(sp40IkConstraintDataArray, sp40IkConstraintData *)

_SP_ARRAY_IMPLEMENT_TYPE(sp40TransformConstraintDataArray, sp40TransformConstraintData *)

_SP_ARRAY_IMPLEMENT_TYPE(sp40PathConstraintDataArray, sp40PathConstraintData *)

static _Entry *_Entry_create(int slotIndex, const char *name, sp40Attachment *attachment) {
	_Entry *self = NEW(_Entry);
	self->slotIndex = slotIndex;
	MALLOC_STR(self->name, name);
	self->attachment = attachment;
	return self;
}

static void _Entry_dispose(_Entry *self) {
	sp40Attachment_dispose(self->attachment);
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

sp40Skin *sp40Skin_create(const char *name) {
	sp40Skin *self = SUPER(NEW(_sp40Skin));
	MALLOC_STR(self->name, name);
	self->bones = sp40BoneDataArray_create(4);
	self->ikConstraints = sp40IkConstraintDataArray_create(4);
	self->transformConstraints = sp40TransformConstraintDataArray_create(4);
	self->pathConstraints = sp40PathConstraintDataArray_create(4);
	return self;
}

void sp40Skin_dispose(sp40Skin *self) {
	_Entry *entry = SUB_CAST(_sp40Skin, self)->entries;

	while (entry) {
		_Entry *nextEntry = entry->next;
		_Entry_dispose(entry);
		entry = nextEntry;
	}

	{
		_SkinHashTableEntry **currentHashtableEntry = SUB_CAST(_sp40Skin, self)->entriesHashTable;
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

	sp40BoneDataArray_dispose(self->bones);
	sp40IkConstraintDataArray_dispose(self->ikConstraints);
	sp40TransformConstraintDataArray_dispose(self->transformConstraints);
	sp40PathConstraintDataArray_dispose(self->pathConstraints);
	FREE(self->name);
	FREE(self);
}

void sp40Skin_setAttachment(sp40Skin *self, int slotIndex, const char *name, sp40Attachment *attachment) {
	_SkinHashTableEntry *existingEntry = 0;
	_SkinHashTableEntry *hashEntry = SUB_CAST(_sp40Skin, self)->entriesHashTable[(unsigned int) slotIndex % SKIN_ENTRIES_HASH_TABLE_SIZE];
	while (hashEntry) {
		if (hashEntry->entry->slotIndex == slotIndex && strcmp(hashEntry->entry->name, name) == 0) {
			existingEntry = hashEntry;
			break;
		}
		hashEntry = hashEntry->next;
	}

	if (attachment) attachment->refCount++;

	if (existingEntry) {
		if (hashEntry->entry->attachment) sp40Attachment_dispose(hashEntry->entry->attachment);
		hashEntry->entry->attachment = attachment;
	} else {
		_Entry *newEntry = _Entry_create(slotIndex, name, attachment);
		newEntry->next = SUB_CAST(_sp40Skin, self)->entries;
		SUB_CAST(_sp40Skin, self)->entries = newEntry;
		{
			unsigned int hashTableIndex = (unsigned int) slotIndex % SKIN_ENTRIES_HASH_TABLE_SIZE;
			_SkinHashTableEntry **hashTable = SUB_CAST(_sp40Skin, self)->entriesHashTable;

			_SkinHashTableEntry *newHashEntry = _SkinHashTableEntry_create(newEntry);
			newHashEntry->next = hashTable[hashTableIndex];
			SUB_CAST(_sp40Skin, self)->entriesHashTable[hashTableIndex] = newHashEntry;
		}
	}
}

sp40Attachment *sp40Skin_getAttachment(const sp40Skin *self, int slotIndex, const char *name) {
	const _SkinHashTableEntry *hashEntry = SUB_CAST(_sp40Skin, self)->entriesHashTable[(unsigned int) slotIndex % SKIN_ENTRIES_HASH_TABLE_SIZE];
	while (hashEntry) {
		if (hashEntry->entry->slotIndex == slotIndex && strcmp(hashEntry->entry->name, name) == 0)
			return hashEntry->entry->attachment;
		hashEntry = hashEntry->next;
	}
	return 0;
}

const char *sp40Skin_getAttachmentName(const sp40Skin *self, int slotIndex, int attachmentIndex) {
	const _Entry *entry = SUB_CAST(_sp40Skin, self)->entries;
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

void sp40Skin_attachAll(const sp40Skin *self, sp40Skeleton *skeleton, const sp40Skin *oldSkin) {
	const _Entry *entry = SUB_CAST(_sp40Skin, oldSkin)->entries;
	while (entry) {
		sp40Slot *slot = skeleton->slots[entry->slotIndex];
		if (slot->attachment == entry->attachment) {
			sp40Attachment *attachment = sp40Skin_getAttachment(self, entry->slotIndex, entry->name);
			if (attachment) sp40Slot_setAttachment(slot, attachment);
		}
		entry = entry->next;
	}
}

void sp40Skin_addSkin(sp40Skin *self, const sp40Skin *other) {
	int i = 0;
	sp40SkinEntry *entry;

	for (i = 0; i < other->bones->size; i++) {
		if (!sp40BoneDataArray_contains(self->bones, other->bones->items[i]))
			sp40BoneDataArray_add(self->bones, other->bones->items[i]);
	}

	for (i = 0; i < other->ikConstraints->size; i++) {
		if (!sp40IkConstraintDataArray_contains(self->ikConstraints, other->ikConstraints->items[i]))
			sp40IkConstraintDataArray_add(self->ikConstraints, other->ikConstraints->items[i]);
	}

	for (i = 0; i < other->transformConstraints->size; i++) {
		if (!sp40TransformConstraintDataArray_contains(self->transformConstraints, other->transformConstraints->items[i]))
			sp40TransformConstraintDataArray_add(self->transformConstraints, other->transformConstraints->items[i]);
	}

	for (i = 0; i < other->pathConstraints->size; i++) {
		if (!sp40PathConstraintDataArray_contains(self->pathConstraints, other->pathConstraints->items[i]))
			sp40PathConstraintDataArray_add(self->pathConstraints, other->pathConstraints->items[i]);
	}

	entry = sp40Skin_getAttachments(other);
	while (entry) {
		sp40Skin_setAttachment(self, entry->slotIndex, entry->name, entry->attachment);
		entry = entry->next;
	}
}

void sp40Skin_copySkin(sp40Skin *self, const sp40Skin *other) {
	int i = 0;
	sp40SkinEntry *entry;

	for (i = 0; i < other->bones->size; i++) {
		if (!sp40BoneDataArray_contains(self->bones, other->bones->items[i]))
			sp40BoneDataArray_add(self->bones, other->bones->items[i]);
	}

	for (i = 0; i < other->ikConstraints->size; i++) {
		if (!sp40IkConstraintDataArray_contains(self->ikConstraints, other->ikConstraints->items[i]))
			sp40IkConstraintDataArray_add(self->ikConstraints, other->ikConstraints->items[i]);
	}

	for (i = 0; i < other->transformConstraints->size; i++) {
		if (!sp40TransformConstraintDataArray_contains(self->transformConstraints, other->transformConstraints->items[i]))
			sp40TransformConstraintDataArray_add(self->transformConstraints, other->transformConstraints->items[i]);
	}

	for (i = 0; i < other->pathConstraints->size; i++) {
		if (!sp40PathConstraintDataArray_contains(self->pathConstraints, other->pathConstraints->items[i]))
			sp40PathConstraintDataArray_add(self->pathConstraints, other->pathConstraints->items[i]);
	}

	entry = sp40Skin_getAttachments(other);
	while (entry) {
		if (entry->attachment->type == SP_ATTACHMENT_MESH) {
			sp40MeshAttachment *attachment = sp40MeshAttachment_newLinkedMesh(
					SUB_CAST(sp40MeshAttachment, entry->attachment));
			sp40Skin_setAttachment(self, entry->slotIndex, entry->name, SUPER(SUPER(attachment)));
		} else {
			sp40Attachment *attachment = entry->attachment ? sp40Attachment_copy(entry->attachment) : 0;
			sp40Skin_setAttachment(self, entry->slotIndex, entry->name, attachment);
		}
		entry = entry->next;
	}
}

sp40SkinEntry *sp40Skin_getAttachments(const sp40Skin *self) {
	return SUB_CAST(_sp40Skin, self)->entries;
}

void sp40Skin_clear(sp40Skin *self) {
	_Entry *entry = SUB_CAST(_sp40Skin, self)->entries;

	while (entry) {
		_Entry *nextEntry = entry->next;
		_Entry_dispose(entry);
		entry = nextEntry;
	}

	SUB_CAST(_sp40Skin, self)->entries = 0;

	{
		_SkinHashTableEntry **currentHashtableEntry = SUB_CAST(_sp40Skin, self)->entriesHashTable;
		int i;

		for (i = 0; i < SKIN_ENTRIES_HASH_TABLE_SIZE; ++i, ++currentHashtableEntry) {
			_SkinHashTableEntry *hashtableEntry = *currentHashtableEntry;

			while (hashtableEntry) {
				_SkinHashTableEntry *nextEntry = hashtableEntry->next;
				_SkinHashTableEntry_dispose(hashtableEntry);
				hashtableEntry = nextEntry;
			}

			SUB_CAST(_sp40Skin, self)->entriesHashTable[i] = 0;
		}
	}

	sp40BoneDataArray_clear(self->bones);
	sp40IkConstraintDataArray_clear(self->ikConstraints);
	sp40TransformConstraintDataArray_clear(self->transformConstraints);
	sp40PathConstraintDataArray_clear(self->pathConstraints);
}

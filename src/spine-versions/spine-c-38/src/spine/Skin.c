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

_SP_ARRAY_IMPLEMENT_TYPE(sp38BoneDataArray, sp38BoneData*)
_SP_ARRAY_IMPLEMENT_TYPE(sp38IkConstraintDataArray, sp38IkConstraintData*)
_SP_ARRAY_IMPLEMENT_TYPE(sp38TransformConstraintDataArray, sp38TransformConstraintData*)
_SP_ARRAY_IMPLEMENT_TYPE(sp38PathConstraintDataArray, sp38PathConstraintData*)

static _Entry* _Entry_create (int slotIndex, const char* name, sp38Attachment* attachment) {
	_Entry* self = NEW(_Entry);
	self->slotIndex = slotIndex;
	MALLOC_STR(self->name, name);
	self->attachment = attachment;
	return self;
}

static void _Entry_dispose (_Entry* self) {
	sp38Attachment_dispose(self->attachment);
	FREE(self->name);
	FREE(self);
}

static _SkinHashTableEntry* _SkinHashTableEntry_create (_Entry* entry) {
	_SkinHashTableEntry* self = NEW(_SkinHashTableEntry);
	self->entry = entry;
	return self;
}

static void _SkinHashTableEntry_dispose (_SkinHashTableEntry* self) {
	FREE(self);
}

/**/

sp38Skin* sp38Skin_create (const char* name) {
	sp38Skin* self = SUPER(NEW(_sp38Skin));
	MALLOC_STR(self->name, name);
	self->bones = sp38BoneDataArray_create(4);
	self->ikConstraints = sp38IkConstraintDataArray_create(4);
	self->transformConstraints = sp38TransformConstraintDataArray_create(4);
	self->pathConstraints = sp38PathConstraintDataArray_create(4);
	return self;
}

void sp38Skin_dispose (sp38Skin* self) {
	_Entry* entry = SUB_CAST(_sp38Skin, self)->entries;

	while (entry) {
		_Entry* nextEntry = entry->next;
		_Entry_dispose(entry);
		entry = nextEntry;
	}

	{
		_SkinHashTableEntry** currentHashtableEntry = SUB_CAST(_sp38Skin, self)->entriesHashTable;
		int i;

		for (i = 0; i < SKIN_ENTRIES_HASH_TABLE_SIZE; ++i, ++currentHashtableEntry) {
			_SkinHashTableEntry* hashtableEntry = *currentHashtableEntry;

			while (hashtableEntry) {
				_SkinHashTableEntry* nextEntry = hashtableEntry->next;
				_SkinHashTableEntry_dispose(hashtableEntry);
				hashtableEntry = nextEntry;
			}
		}
	}

	sp38BoneDataArray_dispose(self->bones);
	sp38IkConstraintDataArray_dispose(self->ikConstraints);
	sp38TransformConstraintDataArray_dispose(self->transformConstraints);
	sp38PathConstraintDataArray_dispose(self->pathConstraints);
	FREE(self->name);
	FREE(self);
}

void sp38Skin_setAttachment (sp38Skin* self, int slotIndex, const char* name, sp38Attachment* attachment) {
	_SkinHashTableEntry* existingEntry = 0;
	_SkinHashTableEntry* hashEntry = SUB_CAST(_sp38Skin, self)->entriesHashTable[(unsigned int)slotIndex % SKIN_ENTRIES_HASH_TABLE_SIZE];
	while (hashEntry) {
		if (hashEntry->entry->slotIndex == slotIndex && strcmp(hashEntry->entry->name, name) == 0) {
			existingEntry = hashEntry;
			break;
		}
		hashEntry = hashEntry->next;
	}

	if (attachment) attachment->refCount++;

	if (existingEntry) {
		if (hashEntry->entry->attachment) sp38Attachment_dispose(hashEntry->entry->attachment);
		hashEntry->entry->attachment = attachment;
	} else {
		_Entry* newEntry = _Entry_create(slotIndex, name, attachment);
		newEntry->next = SUB_CAST(_sp38Skin, self)->entries;
		SUB_CAST(_sp38Skin, self)->entries = newEntry;
		{
			unsigned int hashTableIndex = (unsigned int)slotIndex % SKIN_ENTRIES_HASH_TABLE_SIZE;
			_SkinHashTableEntry** hashTable = SUB_CAST(_sp38Skin, self)->entriesHashTable;

			_SkinHashTableEntry* newHashEntry = _SkinHashTableEntry_create(newEntry);
			newHashEntry->next = hashTable[hashTableIndex];
			SUB_CAST(_sp38Skin, self)->entriesHashTable[hashTableIndex] = newHashEntry;
		}
	}
}

sp38Attachment* sp38Skin_getAttachment (const sp38Skin* self, int slotIndex, const char* name) {
	const _SkinHashTableEntry* hashEntry = SUB_CAST(_sp38Skin, self)->entriesHashTable[(unsigned int)slotIndex % SKIN_ENTRIES_HASH_TABLE_SIZE];
	while (hashEntry) {
		if (hashEntry->entry->slotIndex == slotIndex && strcmp(hashEntry->entry->name, name) == 0) return hashEntry->entry->attachment;
		hashEntry = hashEntry->next;
	}
	return 0;
}

const char* sp38Skin_getAttachmentName (const sp38Skin* self, int slotIndex, int attachmentIndex) {
	const _Entry* entry = SUB_CAST(_sp38Skin, self)->entries;
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

void sp38Skin_attachAll (const sp38Skin* self, sp38Skeleton* skeleton, const sp38Skin* oldSkin) {
	const _Entry *entry = SUB_CAST(_sp38Skin, oldSkin)->entries;
	while (entry) {
		sp38Slot *slot = skeleton->slots[entry->slotIndex];
		if (slot->attachment == entry->attachment) {
			sp38Attachment *attachment = sp38Skin_getAttachment(self, entry->slotIndex, entry->name);
			if (attachment) sp38Slot_setAttachment(slot, attachment);
		}
		entry = entry->next;
	}
}

void sp38Skin_addSkin(sp38Skin* self, const sp38Skin* other) {
	int i = 0;
	sp38SkinEntry* entry;

	for (i = 0; i < other->bones->size; i++) {
		if (!sp38BoneDataArray_contains(self->bones, other->bones->items[i]))
			sp38BoneDataArray_add(self->bones, other->bones->items[i]);
	}

	for (i = 0; i < other->ikConstraints->size; i++) {
		if (!sp38IkConstraintDataArray_contains(self->ikConstraints, other->ikConstraints->items[i]))
			sp38IkConstraintDataArray_add(self->ikConstraints, other->ikConstraints->items[i]);
	}

	for (i = 0; i < other->transformConstraints->size; i++) {
		if (!sp38TransformConstraintDataArray_contains(self->transformConstraints, other->transformConstraints->items[i]))
			sp38TransformConstraintDataArray_add(self->transformConstraints, other->transformConstraints->items[i]);
	}

	for (i = 0; i < other->pathConstraints->size; i++) {
		if (!sp38PathConstraintDataArray_contains(self->pathConstraints, other->pathConstraints->items[i]))
			sp38PathConstraintDataArray_add(self->pathConstraints, other->pathConstraints->items[i]);
	}

	entry = sp38Skin_getAttachments(other);
	while (entry) {
		sp38Skin_setAttachment(self, entry->slotIndex, entry->name, entry->attachment);
		entry = entry->next;
	}
}

void sp38Skin_copySkin(sp38Skin* self, const sp38Skin* other) {
	int i = 0;
	sp38SkinEntry* entry;

	for (i = 0; i < other->bones->size; i++) {
		if (!sp38BoneDataArray_contains(self->bones, other->bones->items[i]))
			sp38BoneDataArray_add(self->bones, other->bones->items[i]);
	}

	for (i = 0; i < other->ikConstraints->size; i++) {
		if (!sp38IkConstraintDataArray_contains(self->ikConstraints, other->ikConstraints->items[i]))
			sp38IkConstraintDataArray_add(self->ikConstraints, other->ikConstraints->items[i]);
	}

	for (i = 0; i < other->transformConstraints->size; i++) {
		if (!sp38TransformConstraintDataArray_contains(self->transformConstraints, other->transformConstraints->items[i]))
			sp38TransformConstraintDataArray_add(self->transformConstraints, other->transformConstraints->items[i]);
	}

	for (i = 0; i < other->pathConstraints->size; i++) {
		if (!sp38PathConstraintDataArray_contains(self->pathConstraints, other->pathConstraints->items[i]))
			sp38PathConstraintDataArray_add(self->pathConstraints, other->pathConstraints->items[i]);
	}

	entry = sp38Skin_getAttachments(other);
	while (entry) {
		if (entry->attachment->type == SP_ATTACHMENT_MESH) {
			sp38MeshAttachment* attachment = sp38MeshAttachment_newLinkedMesh(SUB_CAST(sp38MeshAttachment, entry->attachment));
			sp38Skin_setAttachment(self, entry->slotIndex, entry->name, SUPER(SUPER(attachment)));
		} else {
			sp38Attachment* attachment = entry->attachment ? sp38Attachment_copy(entry->attachment) : 0;
			sp38Skin_setAttachment(self, entry->slotIndex, entry->name, attachment);
		}
		entry = entry->next;
	}
}

sp38SkinEntry* sp38Skin_getAttachments(const sp38Skin* self) {
	return SUB_CAST(_sp38Skin, self)->entries;
}

void sp38Skin_clear(sp38Skin* self) {
	_Entry* entry = SUB_CAST(_sp38Skin, self)->entries;

	while (entry) {
		_Entry* nextEntry = entry->next;
		_Entry_dispose(entry);
		entry = nextEntry;
	}

	SUB_CAST(_sp38Skin, self)->entries = 0;

	{
		_SkinHashTableEntry** currentHashtableEntry = SUB_CAST(_sp38Skin, self)->entriesHashTable;
		int i;

		for (i = 0; i < SKIN_ENTRIES_HASH_TABLE_SIZE; ++i, ++currentHashtableEntry) {
			_SkinHashTableEntry* hashtableEntry = *currentHashtableEntry;

			while (hashtableEntry) {
				_SkinHashTableEntry* nextEntry = hashtableEntry->next;
				_SkinHashTableEntry_dispose(hashtableEntry);
				hashtableEntry = nextEntry;
			}

			SUB_CAST(_sp38Skin, self)->entriesHashTable[i] = 0;
		}
	}

	sp38BoneDataArray_clear(self->bones);
	sp38IkConstraintDataArray_clear(self->ikConstraints);
	sp38TransformConstraintDataArray_clear(self->transformConstraints);
	sp38PathConstraintDataArray_clear(self->pathConstraints);
}

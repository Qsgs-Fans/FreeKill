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

#include <spine/Skin.h>
#include <spine/extension.h>

static _Entry* _Entry_create (int slotIndex, const char* name, sp36Attachment* attachment) {
	_Entry* self = NEW(_Entry);
	self->slotIndex = slotIndex;
	MALLOC_STR(self->name, name);
	self->attachment = attachment;
	return self;
}

static void _Entry_dispose (_Entry* self) {
	sp36Attachment_dispose(self->attachment);
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

sp36Skin* sp36Skin_create (const char* name) {
	sp36Skin* self = SUPER(NEW(_sp36Skin));
	MALLOC_STR(self->name, name);
	return self;
}

void sp36Skin_dispose (sp36Skin* self) {
	_Entry* entry = SUB_CAST(_sp36Skin, self)->entries;

	while (entry) {
		_Entry* nextEntry = entry->next;
		_Entry_dispose(entry);
		entry = nextEntry;
	}

	{
		_SkinHashTableEntry** currentHashtableEntry = SUB_CAST(_sp36Skin, self)->entriesHashTable;
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

	FREE(self->name);
	FREE(self);
}

void sp36Skin_addAttachment (sp36Skin* self, int slotIndex, const char* name, sp36Attachment* attachment) {
	_Entry* newEntry = _Entry_create(slotIndex, name, attachment);
	newEntry->next = SUB_CAST(_sp36Skin, self)->entries;
	SUB_CAST(_sp36Skin, self)->entries = newEntry;

	{
		unsigned int hashTableIndex = (unsigned int)slotIndex % SKIN_ENTRIES_HASH_TABLE_SIZE;

		_SkinHashTableEntry* newHashEntry = _SkinHashTableEntry_create(newEntry);
		newHashEntry->next = SUB_CAST(_sp36Skin, self)->entriesHashTable[hashTableIndex];
		SUB_CAST(_sp36Skin, self)->entriesHashTable[hashTableIndex] = newHashEntry;
	}
}

sp36Attachment* sp36Skin_getAttachment (const sp36Skin* self, int slotIndex, const char* name) {
	const _SkinHashTableEntry* hashEntry = SUB_CAST(_sp36Skin, self)->entriesHashTable[(unsigned int)slotIndex % SKIN_ENTRIES_HASH_TABLE_SIZE];
	while (hashEntry) {
		if (hashEntry->entry->slotIndex == slotIndex && strcmp(hashEntry->entry->name, name) == 0) return hashEntry->entry->attachment;
		hashEntry = hashEntry->next;
	}
	return 0;
}

const char* sp36Skin_getAttachmentName (const sp36Skin* self, int slotIndex, int attachmentIndex) {
	const _Entry* entry = SUB_CAST(_sp36Skin, self)->entries;
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

void sp36Skin_attachAll (const sp36Skin* self, sp36Skeleton* skeleton, const sp36Skin* oldSkin) {
	const _Entry *entry = SUB_CAST(_sp36Skin, oldSkin)->entries;
	while (entry) {
		sp36Slot *slot = skeleton->slots[entry->slotIndex];
		if (slot->attachment == entry->attachment) {
			sp36Attachment *attachment = sp36Skin_getAttachment(self, entry->slotIndex, entry->name);
			if (attachment) sp36Slot_setAttachment(slot, attachment);
		}
		entry = entry->next;
	}
}

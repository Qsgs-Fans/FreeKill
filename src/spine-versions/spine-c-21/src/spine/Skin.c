/******************************************************************************
 * Spine Runtimes Software License
 * Version 2.1
 * 
 * Copyright (c) 2013, Esoteric Software
 * All rights reserved.
 * 
 * You are granted a perpetual, non-exclusive, non-sublicensable and
 * non-transferable license to install, execute and perform the Spine Runtimes
 * Software (the "Software") solely for internal use. Without the written
 * permission of Esoteric Software (typically granted by licensing Spine), you
 * may not (a) modify, translate, adapt or otherwise create derivative works,
 * improvements of the Software or develop new applications using the Software
 * or (b) remove, delete, alter or obscure any trademarks or any copyright,
 * trademark, patent or other intellectual property or proprietary rights
 * notices on or in the Software, including any copy thereof. Redistributions
 * in binary or source form must include this license and terms.
 * 
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#include <spine/Skin.h>
#include <spine/extension.h>

typedef struct _Entry _Entry;
struct _Entry {
	int slotIndex;
	const char* name;
	sp21Attachment* attachment;
	_Entry* next;
};

static _Entry* _Entry_create (int slotIndex, const char* name, sp21Attachment* attachment) {
	_Entry* self = NEW(_Entry);
	self->slotIndex = slotIndex;
	MALLOC_STR(self->name, name);
	self->attachment = attachment;
	return self;
}

static void _Entry_dispose (_Entry* self) {
	sp21Attachment_dispose(self->attachment);
	FREE(self->name);
	FREE(self);
}

/**/

typedef struct {
	sp21Skin super;
	_Entry* entries;
} _sp21Skin;

sp21Skin* sp21Skin_create (const char* name) {
	sp21Skin* self = SUPER(NEW(_sp21Skin));
	MALLOC_STR(self->name, name);
	return self;
}

void sp21Skin_dispose (sp21Skin* self) {
	_Entry* entry = SUB_CAST(_sp21Skin, self)->entries;
	while (entry) {
		_Entry* nextEntry = entry->next;
		_Entry_dispose(entry);
		entry = nextEntry;
	}

	FREE(self->name);
	FREE(self);
}

void sp21Skin_addAttachment (sp21Skin* self, int slotIndex, const char* name, sp21Attachment* attachment) {
	_Entry* newEntry = _Entry_create(slotIndex, name, attachment);
	newEntry->next = SUB_CAST(_sp21Skin, self)->entries;
	SUB_CAST(_sp21Skin, self)->entries = newEntry;
}

sp21Attachment* sp21Skin_getAttachment (const sp21Skin* self, int slotIndex, const char* name) {
	const _Entry* entry = SUB_CAST(_sp21Skin, self)->entries;
	while (entry) {
		if (entry->slotIndex == slotIndex && strcmp(entry->name, name) == 0) return entry->attachment;
		entry = entry->next;
	}
	return 0;
}

const char* sp21Skin_getAttachmentName (const sp21Skin* self, int slotIndex, int attachmentIndex) {
	const _Entry* entry = SUB_CAST(_sp21Skin, self)->entries;
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

void sp21Skin_attachAll (const sp21Skin* self, sp21Skeleton* skeleton, const sp21Skin* oldSkin) {
	const _Entry *entry = SUB_CAST(_sp21Skin, oldSkin)->entries;
	while (entry) {
		sp21Slot *slot = skeleton->slots[entry->slotIndex];
		if (slot->attachment == entry->attachment) {
			sp21Attachment *attachment = sp21Skin_getAttachment(self, entry->slotIndex, entry->name);
			if (attachment) sp21Slot_setAttachment(slot, attachment);
		}
		entry = entry->next;
	}
}

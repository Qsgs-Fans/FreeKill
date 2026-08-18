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

#include <spine/Attachment.h>
#include <spine/extension.h>
#include <spine/Slot.h>

typedef struct _sp38AttachmentVtable {
	void (*dispose) (sp38Attachment* self);
	sp38Attachment* (*copy) (sp38Attachment* self);
} _sp38AttachmentVtable;

void _sp38Attachment_init (sp38Attachment* self, const char* name, sp38AttachmentType type, /**/
		void (*dispose) (sp38Attachment* self), sp38Attachment* (*copy) (sp38Attachment* self)) {

	CONST_CAST(_sp38AttachmentVtable*, self->vtable) = NEW(_sp38AttachmentVtable);
	VTABLE(sp38Attachment, self)->dispose = dispose;
	VTABLE(sp38Attachment, self)->copy = copy;

	MALLOC_STR(self->name, name);
	CONST_CAST(sp38AttachmentType, self->type) = type;
}

void _sp38Attachment_deinit (sp38Attachment* self) {
	if (self->attachmentLoader) sp38AttachmentLoader_disposeAttachment(self->attachmentLoader, self);
	FREE(self->vtable);
	FREE(self->name);
}

sp38Attachment* sp38Attachment_copy (sp38Attachment* self) {
	return VTABLE(sp38Attachment, self) ->copy(self);
}

void sp38Attachment_dispose (sp38Attachment* self) {
	self->refCount--;
	if (self->refCount <= 0)
		VTABLE(sp38Attachment, self) ->dispose(self);
}

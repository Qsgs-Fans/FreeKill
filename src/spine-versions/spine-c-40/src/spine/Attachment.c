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
#include <spine/Slot.h>
#include <spine/extension.h>

typedef struct _sp40AttachmentVtable {
	void (*dispose)(sp40Attachment *self);

	sp40Attachment *(*copy)(sp40Attachment *self);
} _sp40AttachmentVtable;

void _sp40Attachment_init(sp40Attachment *self, const char *name, sp40AttachmentType type, /**/
						void (*dispose)(sp40Attachment *self), sp40Attachment *(*copy)(sp40Attachment *self)) {

	CONST_CAST(_sp40AttachmentVtable *, self->vtable) = NEW(_sp40AttachmentVtable);
	VTABLE(sp40Attachment, self)->dispose = dispose;
	VTABLE(sp40Attachment, self)->copy = copy;

	MALLOC_STR(self->name, name);
	CONST_CAST(sp40AttachmentType, self->type) = type;
}

void _sp40Attachment_deinit(sp40Attachment *self) {
	if (self->attachmentLoader) sp40AttachmentLoader_disposeAttachment(self->attachmentLoader, self);
	FREE(self->vtable);
	FREE(self->name);
}

sp40Attachment *sp40Attachment_copy(sp40Attachment *self) {
	return VTABLE(sp40Attachment, self)->copy(self);
}

void sp40Attachment_dispose(sp40Attachment *self) {
	self->refCount--;
	if (self->refCount <= 0)
		VTABLE(sp40Attachment, self)->dispose(self);
}

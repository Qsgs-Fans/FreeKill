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

#include <spine/Attachment.h>
#include <spine/Slot.h>
#include <spine/extension.h>

typedef struct _sp41AttachmentVtable {
	void (*dispose)(sp41Attachment *self);

	sp41Attachment *(*copy)(sp41Attachment *self);
} _sp41AttachmentVtable;

void _sp41Attachment_init(sp41Attachment *self, const char *name, sp41AttachmentType type, /**/
						void (*dispose)(sp41Attachment *self), sp41Attachment *(*copy)(sp41Attachment *self)) {

	CONST_CAST(_sp41AttachmentVtable *, self->vtable) = NEW(_sp41AttachmentVtable);
	VTABLE(sp41Attachment, self)->dispose = dispose;
	VTABLE(sp41Attachment, self)->copy = copy;

	MALLOC_STR(self->name, name);
	CONST_CAST(sp41AttachmentType, self->type) = type;
}

void _sp41Attachment_deinit(sp41Attachment *self) {
	if (self->attachmentLoader) sp41AttachmentLoader_disposeAttachment(self->attachmentLoader, self);
	FREE(self->vtable);
	FREE(self->name);
}

sp41Attachment *sp41Attachment_copy(sp41Attachment *self) {
	return VTABLE(sp41Attachment, self)->copy(self);
}

void sp41Attachment_dispose(sp41Attachment *self) {
	self->refCount--;
	if (self->refCount <= 0)
		VTABLE(sp41Attachment, self)->dispose(self);
}

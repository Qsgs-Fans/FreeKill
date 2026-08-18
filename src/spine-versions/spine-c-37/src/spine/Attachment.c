/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated May 1, 2019. Replaces all prior versions.
 *
 * Copyright (c) 2013-2019, Esoteric Software LLC
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
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE LLC "AS IS" AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
 * NO EVENT SHALL ESOTERIC SOFTWARE LLC BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, BUSINESS
 * INTERRUPTION, OR LOSS OF USE, DATA, OR PROFITS) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#include <spine/Attachment.h>
#include <spine/extension.h>
#include <spine/Slot.h>

typedef struct _sp37AttachmentVtable {
	void (*dispose) (sp37Attachment* self);
} _sp37AttachmentVtable;

void _sp37Attachment_init (sp37Attachment* self, const char* name, sp37AttachmentType type, /**/
		void (*dispose) (sp37Attachment* self)) {

	CONST_CAST(_sp37AttachmentVtable*, self->vtable) = NEW(_sp37AttachmentVtable);
	VTABLE(sp37Attachment, self) ->dispose = dispose;

	MALLOC_STR(self->name, name);
	CONST_CAST(sp37AttachmentType, self->type) = type;
}

void _sp37Attachment_deinit (sp37Attachment* self) {
	if (self->attachmentLoader) sp37AttachmentLoader_disposeAttachment(self->attachmentLoader, self);
	FREE(self->vtable);
	FREE(self->name);
}

void sp37Attachment_dispose (sp37Attachment* self) {
	VTABLE(sp37Attachment, self) ->dispose(self);
}

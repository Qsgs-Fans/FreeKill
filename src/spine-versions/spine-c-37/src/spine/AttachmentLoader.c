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

#include <spine/AttachmentLoader.h>
#include <stdio.h>
#include <spine/extension.h>

typedef struct _sp37AttachmentLoaderVtable {
	sp37Attachment* (*createAttachment) (sp37AttachmentLoader* self, sp37Skin* skin, sp37AttachmentType type, const char* name,
			const char* path);
	void (*configureAttachment) (sp37AttachmentLoader* self, sp37Attachment*);
	void (*disposeAttachment) (sp37AttachmentLoader* self, sp37Attachment*);
	void (*dispose) (sp37AttachmentLoader* self);
} _sp37AttachmentLoaderVtable;

void _sp37AttachmentLoader_init (sp37AttachmentLoader* self,
	void (*dispose) (sp37AttachmentLoader* self),
	sp37Attachment* (*createAttachment) (sp37AttachmentLoader* self, sp37Skin* skin, sp37AttachmentType type, const char* name,
		const char* path),
	void (*configureAttachment) (sp37AttachmentLoader* self, sp37Attachment*),
	void (*disposeAttachment) (sp37AttachmentLoader* self, sp37Attachment*)
) {
	CONST_CAST(_sp37AttachmentLoaderVtable*, self->vtable) = NEW(_sp37AttachmentLoaderVtable);
	VTABLE(sp37AttachmentLoader, self)->dispose = dispose;
	VTABLE(sp37AttachmentLoader, self)->createAttachment = createAttachment;
	VTABLE(sp37AttachmentLoader, self)->configureAttachment = configureAttachment;
	VTABLE(sp37AttachmentLoader, self)->disposeAttachment = disposeAttachment;
}

void _sp37AttachmentLoader_deinit (sp37AttachmentLoader* self) {
	FREE(self->vtable);
	FREE(self->error1);
	FREE(self->error2);
}

void sp37AttachmentLoader_dispose (sp37AttachmentLoader* self) {
	VTABLE(sp37AttachmentLoader, self)->dispose(self);
	FREE(self);
}

sp37Attachment* sp37AttachmentLoader_createAttachment (sp37AttachmentLoader* self, sp37Skin* skin, sp37AttachmentType type, const char* name,
		const char* path) {
	FREE(self->error1);
	FREE(self->error2);
	self->error1 = 0;
	self->error2 = 0;
	return VTABLE(sp37AttachmentLoader, self)->createAttachment(self, skin, type, name, path);
}

void sp37AttachmentLoader_configureAttachment (sp37AttachmentLoader* self, sp37Attachment* attachment) {
	if (!VTABLE(sp37AttachmentLoader, self)->configureAttachment) return;
	VTABLE(sp37AttachmentLoader, self)->configureAttachment(self, attachment);
}

void sp37AttachmentLoader_disposeAttachment (sp37AttachmentLoader* self, sp37Attachment* attachment) {
	if (!VTABLE(sp37AttachmentLoader, self)->disposeAttachment) return;
	VTABLE(sp37AttachmentLoader, self)->disposeAttachment(self, attachment);
}

void _sp37AttachmentLoader_setError (sp37AttachmentLoader* self, const char* error1, const char* error2) {
	FREE(self->error1);
	FREE(self->error2);
	MALLOC_STR(self->error1, error1);
	MALLOC_STR(self->error2, error2);
}

void _sp37AttachmentLoader_setUnknownTypeError (sp37AttachmentLoader* self, sp37AttachmentType type) {
	char buffer[16];
	sprintf(buffer, "%d", type);
	_sp37AttachmentLoader_setError(self, "Unknown attachment type: ", buffer);
}

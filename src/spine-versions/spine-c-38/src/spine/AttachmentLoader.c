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

#include <spine/AttachmentLoader.h>
#include <stdio.h>
#include <spine/extension.h>

typedef struct _sp38AttachmentLoaderVtable {
	sp38Attachment* (*createAttachment) (sp38AttachmentLoader* self, sp38Skin* skin, sp38AttachmentType type, const char* name, const char* path);
	void (*configureAttachment) (sp38AttachmentLoader* self, sp38Attachment*);
	void (*disposeAttachment) (sp38AttachmentLoader* self, sp38Attachment*);
	void (*dispose) (sp38AttachmentLoader* self);
} _sp38AttachmentLoaderVtable;

void _sp38AttachmentLoader_init (sp38AttachmentLoader* self,
	void (*dispose) (sp38AttachmentLoader* self),
	sp38Attachment* (*createAttachment) (sp38AttachmentLoader* self, sp38Skin* skin, sp38AttachmentType type, const char* name,
		const char* path),
	void (*configureAttachment) (sp38AttachmentLoader* self, sp38Attachment*),
	void (*disposeAttachment) (sp38AttachmentLoader* self, sp38Attachment*)
) {
	CONST_CAST(_sp38AttachmentLoaderVtable*, self->vtable) = NEW(_sp38AttachmentLoaderVtable);
	VTABLE(sp38AttachmentLoader, self)->dispose = dispose;
	VTABLE(sp38AttachmentLoader, self)->createAttachment = createAttachment;
	VTABLE(sp38AttachmentLoader, self)->configureAttachment = configureAttachment;
	VTABLE(sp38AttachmentLoader, self)->disposeAttachment = disposeAttachment;
}

void _sp38AttachmentLoader_deinit (sp38AttachmentLoader* self) {
	FREE(self->vtable);
	FREE(self->error1);
	FREE(self->error2);
}

void sp38AttachmentLoader_dispose (sp38AttachmentLoader* self) {
	VTABLE(sp38AttachmentLoader, self)->dispose(self);
	FREE(self);
}

sp38Attachment* sp38AttachmentLoader_createAttachment (sp38AttachmentLoader* self, sp38Skin* skin, sp38AttachmentType type, const char* name,
		const char* path) {
	FREE(self->error1);
	FREE(self->error2);
	self->error1 = 0;
	self->error2 = 0;
	return VTABLE(sp38AttachmentLoader, self)->createAttachment(self, skin, type, name, path);
}

void sp38AttachmentLoader_configureAttachment (sp38AttachmentLoader* self, sp38Attachment* attachment) {
	if (!VTABLE(sp38AttachmentLoader, self)->configureAttachment) return;
	VTABLE(sp38AttachmentLoader, self)->configureAttachment(self, attachment);
}

void sp38AttachmentLoader_disposeAttachment (sp38AttachmentLoader* self, sp38Attachment* attachment) {
	if (!VTABLE(sp38AttachmentLoader, self)->disposeAttachment) return;
	VTABLE(sp38AttachmentLoader, self)->disposeAttachment(self, attachment);
}

void _sp38AttachmentLoader_setError (sp38AttachmentLoader* self, const char* error1, const char* error2) {
	FREE(self->error1);
	FREE(self->error2);
	MALLOC_STR(self->error1, error1);
	MALLOC_STR(self->error2, error2);
}

void _sp38AttachmentLoader_setUnknownTypeError (sp38AttachmentLoader* self, sp38AttachmentType type) {
	char buffer[16];
	sprintf(buffer, "%d", type);
	_sp38AttachmentLoader_setError(self, "Unknown attachment type: ", buffer);
}

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

#include <spine/AttachmentLoader.h>
#include <stdio.h>
#include <spine/extension.h>

typedef struct _sp35AttachmentLoaderVtable {
	sp35Attachment* (*createAttachment) (sp35AttachmentLoader* self, sp35Skin* skin, sp35AttachmentType type, const char* name,
			const char* path);
	void (*configureAttachment) (sp35AttachmentLoader* self, sp35Attachment*);
	void (*disposeAttachment) (sp35AttachmentLoader* self, sp35Attachment*);
	void (*dispose) (sp35AttachmentLoader* self);
} _sp35AttachmentLoaderVtable;

void _sp35AttachmentLoader_init (sp35AttachmentLoader* self,
	void (*dispose) (sp35AttachmentLoader* self),
	sp35Attachment* (*createAttachment) (sp35AttachmentLoader* self, sp35Skin* skin, sp35AttachmentType type, const char* name,
		const char* path),
	void (*configureAttachment) (sp35AttachmentLoader* self, sp35Attachment*),
	void (*disposeAttachment) (sp35AttachmentLoader* self, sp35Attachment*)
) {
	CONST_CAST(_sp35AttachmentLoaderVtable*, self->vtable) = NEW(_sp35AttachmentLoaderVtable);
	VTABLE(sp35AttachmentLoader, self)->dispose = dispose;
	VTABLE(sp35AttachmentLoader, self)->createAttachment = createAttachment;
	VTABLE(sp35AttachmentLoader, self)->configureAttachment = configureAttachment;
	VTABLE(sp35AttachmentLoader, self)->disposeAttachment = disposeAttachment;
}

void _sp35AttachmentLoader_deinit (sp35AttachmentLoader* self) {
	FREE(self->vtable);
	FREE(self->error1);
	FREE(self->error2);
}

void sp35AttachmentLoader_dispose (sp35AttachmentLoader* self) {
	VTABLE(sp35AttachmentLoader, self)->dispose(self);
	FREE(self);
}

sp35Attachment* sp35AttachmentLoader_createAttachment (sp35AttachmentLoader* self, sp35Skin* skin, sp35AttachmentType type, const char* name,
		const char* path) {
	FREE(self->error1);
	FREE(self->error2);
	self->error1 = 0;
	self->error2 = 0;
	return VTABLE(sp35AttachmentLoader, self)->createAttachment(self, skin, type, name, path);
}

void sp35AttachmentLoader_configureAttachment (sp35AttachmentLoader* self, sp35Attachment* attachment) {
	if (!VTABLE(sp35AttachmentLoader, self)->configureAttachment) return;
	VTABLE(sp35AttachmentLoader, self)->configureAttachment(self, attachment);
}

void sp35AttachmentLoader_disposeAttachment (sp35AttachmentLoader* self, sp35Attachment* attachment) {
	if (!VTABLE(sp35AttachmentLoader, self)->disposeAttachment) return;
	VTABLE(sp35AttachmentLoader, self)->disposeAttachment(self, attachment);
}

void _sp35AttachmentLoader_setError (sp35AttachmentLoader* self, const char* error1, const char* error2) {
	FREE(self->error1);
	FREE(self->error2);
	MALLOC_STR(self->error1, error1);
	MALLOC_STR(self->error2, error2);
}

void _sp35AttachmentLoader_setUnknownTypeError (sp35AttachmentLoader* self, sp35AttachmentType type) {
	char buffer[16];
	sprintf(buffer, "%d", type);
	_sp35AttachmentLoader_setError(self, "Unknown attachment type: ", buffer);
}

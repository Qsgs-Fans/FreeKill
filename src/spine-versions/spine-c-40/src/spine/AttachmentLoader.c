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
#include <spine/extension.h>
#include <stdio.h>

typedef struct _sp40AttachmentLoaderVtable {
	sp40Attachment *(*createAttachment)(sp40AttachmentLoader *self, sp40Skin *skin, sp40AttachmentType type, const char *name,
									  const char *path);

	void (*configureAttachment)(sp40AttachmentLoader *self, sp40Attachment *);

	void (*disposeAttachment)(sp40AttachmentLoader *self, sp40Attachment *);

	void (*dispose)(sp40AttachmentLoader *self);
} _sp40AttachmentLoaderVtable;

void _sp40AttachmentLoader_init(sp40AttachmentLoader *self,
							  void (*dispose)(sp40AttachmentLoader *self),
							  sp40Attachment *(*createAttachment)(sp40AttachmentLoader *self, sp40Skin *skin,
																sp40AttachmentType type, const char *name,
																const char *path),
							  void (*configureAttachment)(sp40AttachmentLoader *self, sp40Attachment *),
							  void (*disposeAttachment)(sp40AttachmentLoader *self, sp40Attachment *)) {
	CONST_CAST(_sp40AttachmentLoaderVtable *, self->vtable) = NEW(_sp40AttachmentLoaderVtable);
	VTABLE(sp40AttachmentLoader, self)->dispose = dispose;
	VTABLE(sp40AttachmentLoader, self)->createAttachment = createAttachment;
	VTABLE(sp40AttachmentLoader, self)->configureAttachment = configureAttachment;
	VTABLE(sp40AttachmentLoader, self)->disposeAttachment = disposeAttachment;
}

void _sp40AttachmentLoader_deinit(sp40AttachmentLoader *self) {
	FREE(self->vtable);
	FREE(self->error1);
	FREE(self->error2);
}

void sp40AttachmentLoader_dispose(sp40AttachmentLoader *self) {
	VTABLE(sp40AttachmentLoader, self)->dispose(self);
	FREE(self);
}

sp40Attachment *
sp40AttachmentLoader_createAttachment(sp40AttachmentLoader *self, sp40Skin *skin, sp40AttachmentType type, const char *name,
									const char *path) {
	FREE(self->error1);
	FREE(self->error2);
	self->error1 = 0;
	self->error2 = 0;
	return VTABLE(sp40AttachmentLoader, self)->createAttachment(self, skin, type, name, path);
}

void sp40AttachmentLoader_configureAttachment(sp40AttachmentLoader *self, sp40Attachment *attachment) {
	if (!VTABLE(sp40AttachmentLoader, self)->configureAttachment) return;
	VTABLE(sp40AttachmentLoader, self)->configureAttachment(self, attachment);
}

void sp40AttachmentLoader_disposeAttachment(sp40AttachmentLoader *self, sp40Attachment *attachment) {
	if (!VTABLE(sp40AttachmentLoader, self)->disposeAttachment) return;
	VTABLE(sp40AttachmentLoader, self)->disposeAttachment(self, attachment);
}

void _sp40AttachmentLoader_setError(sp40AttachmentLoader *self, const char *error1, const char *error2) {
	FREE(self->error1);
	FREE(self->error2);
	MALLOC_STR(self->error1, error1);
	MALLOC_STR(self->error2, error2);
}

void _sp40AttachmentLoader_setUnknownTypeError(sp40AttachmentLoader *self, sp40AttachmentType type) {
	char buffer[16];
	sprintf(buffer, "%d", type);
	_sp40AttachmentLoader_setError(self, "Unknown attachment type: ", buffer);
}

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

#include <spine/AttachmentLoader.h>
#include <spine/extension.h>
#include <stdio.h>

typedef struct _sp41AttachmentLoaderVtable {
	sp41Attachment *(*createAttachment)(sp41AttachmentLoader *self, sp41Skin *skin, sp41AttachmentType type, const char *name,
									  const char *path, sp41Sequence *sequence);

	void (*configureAttachment)(sp41AttachmentLoader *self, sp41Attachment *);

	void (*disposeAttachment)(sp41AttachmentLoader *self, sp41Attachment *);

	void (*dispose)(sp41AttachmentLoader *self);
} _sp41AttachmentLoaderVtable;

void _sp41AttachmentLoader_init(sp41AttachmentLoader *self,
							  void (*dispose)(sp41AttachmentLoader *self),
							  sp41Attachment *(*createAttachment)(sp41AttachmentLoader *self, sp41Skin *skin,
																sp41AttachmentType type, const char *name,
																const char *path, sp41Sequence *sequence),
							  void (*configureAttachment)(sp41AttachmentLoader *self, sp41Attachment *),
							  void (*disposeAttachment)(sp41AttachmentLoader *self, sp41Attachment *)) {
	CONST_CAST(_sp41AttachmentLoaderVtable *, self->vtable) = NEW(_sp41AttachmentLoaderVtable);
	VTABLE(sp41AttachmentLoader, self)->dispose = dispose;
	VTABLE(sp41AttachmentLoader, self)->createAttachment = createAttachment;
	VTABLE(sp41AttachmentLoader, self)->configureAttachment = configureAttachment;
	VTABLE(sp41AttachmentLoader, self)->disposeAttachment = disposeAttachment;
}

void _sp41AttachmentLoader_deinit(sp41AttachmentLoader *self) {
	FREE(self->vtable);
	FREE(self->error1);
	FREE(self->error2);
}

void sp41AttachmentLoader_dispose(sp41AttachmentLoader *self) {
	VTABLE(sp41AttachmentLoader, self)->dispose(self);
	FREE(self);
}

sp41Attachment *
sp41AttachmentLoader_createAttachment(sp41AttachmentLoader *self, sp41Skin *skin, sp41AttachmentType type, const char *name,
									const char *path, sp41Sequence *sequence) {
	FREE(self->error1);
	FREE(self->error2);
	self->error1 = 0;
	self->error2 = 0;
	return VTABLE(sp41AttachmentLoader, self)->createAttachment(self, skin, type, name, path, sequence);
}

void sp41AttachmentLoader_configureAttachment(sp41AttachmentLoader *self, sp41Attachment *attachment) {
	if (!VTABLE(sp41AttachmentLoader, self)->configureAttachment) return;
	VTABLE(sp41AttachmentLoader, self)->configureAttachment(self, attachment);
}

void sp41AttachmentLoader_disposeAttachment(sp41AttachmentLoader *self, sp41Attachment *attachment) {
	if (!VTABLE(sp41AttachmentLoader, self)->disposeAttachment) return;
	VTABLE(sp41AttachmentLoader, self)->disposeAttachment(self, attachment);
}

void _sp41AttachmentLoader_setError(sp41AttachmentLoader *self, const char *error1, const char *error2) {
	FREE(self->error1);
	FREE(self->error2);
	MALLOC_STR(self->error1, error1);
	MALLOC_STR(self->error2, error2);
}

void _sp41AttachmentLoader_setUnknownTypeError(sp41AttachmentLoader *self, sp41AttachmentType type) {
	char buffer[16];
	sprintf(buffer, "%d", type);
	_sp41AttachmentLoader_setError(self, "Unknown attachment type: ", buffer);
}

/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated July 28, 2023. Replaces all prior versions.
 *
 * Copyright (c) 2013-2023, Esoteric Software LLC
 *
 * Integration of the Spine Runtimes into software or otherwise creating
 * derivative works of the Spine Runtimes is permitted under the terms and
 * conditions of Section 2 of the Spine Editor License Agreement:
 * http://esotericsoftware.com/spine-editor-license
 *
 * Otherwise, it is permitted to integrate the Spine Runtimes into software or
 * otherwise create derivative works of the Spine Runtimes (collectively,
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
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE
 * SPINE RUNTIMES, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#include <spine/AttachmentLoader.h>
#include <spine/extension.h>
#include <stdio.h>

typedef struct _sp42AttachmentLoaderVtable {
	sp42Attachment *(*createAttachment)(sp42AttachmentLoader *self, sp42Skin *skin, sp42AttachmentType type, const char *name,
									  const char *path, sp42Sequence *sequence);

	void (*configureAttachment)(sp42AttachmentLoader *self, sp42Attachment *);

	void (*disposeAttachment)(sp42AttachmentLoader *self, sp42Attachment *);

	void (*dispose)(sp42AttachmentLoader *self);
} _sp42AttachmentLoaderVtable;

void _sp42AttachmentLoader_init(sp42AttachmentLoader *self,
							  void (*dispose)(sp42AttachmentLoader *self),
							  sp42Attachment *(*createAttachment)(sp42AttachmentLoader *self, sp42Skin *skin,
																sp42AttachmentType type, const char *name,
																const char *path, sp42Sequence *sequence),
							  void (*configureAttachment)(sp42AttachmentLoader *self, sp42Attachment *),
							  void (*disposeAttachment)(sp42AttachmentLoader *self, sp42Attachment *)) {
	self->vtable = NEW(_sp42AttachmentLoaderVtable);
	VTABLE(sp42AttachmentLoader, self)->dispose = dispose;
	VTABLE(sp42AttachmentLoader, self)->createAttachment = createAttachment;
	VTABLE(sp42AttachmentLoader, self)->configureAttachment = configureAttachment;
	VTABLE(sp42AttachmentLoader, self)->disposeAttachment = disposeAttachment;
}

void _sp42AttachmentLoader_deinit(sp42AttachmentLoader *self) {
	FREE(self->vtable);
	FREE(self->error1);
	FREE(self->error2);
}

void sp42AttachmentLoader_dispose(sp42AttachmentLoader *self) {
	VTABLE(sp42AttachmentLoader, self)->dispose(self);
	FREE(self);
}

sp42Attachment *
sp42AttachmentLoader_createAttachment(sp42AttachmentLoader *self, sp42Skin *skin, sp42AttachmentType type, const char *name,
									const char *path, sp42Sequence *sequence) {
	FREE(self->error1);
	FREE(self->error2);
	self->error1 = 0;
	self->error2 = 0;
	return VTABLE(sp42AttachmentLoader, self)->createAttachment(self, skin, type, name, path, sequence);
}

void sp42AttachmentLoader_configureAttachment(sp42AttachmentLoader *self, sp42Attachment *attachment) {
	if (!VTABLE(sp42AttachmentLoader, self)->configureAttachment) return;
	VTABLE(sp42AttachmentLoader, self)->configureAttachment(self, attachment);
}

void sp42AttachmentLoader_disposeAttachment(sp42AttachmentLoader *self, sp42Attachment *attachment) {
	if (!VTABLE(sp42AttachmentLoader, self)->disposeAttachment) return;
	VTABLE(sp42AttachmentLoader, self)->disposeAttachment(self, attachment);
}

void _sp42AttachmentLoader_setError(sp42AttachmentLoader *self, const char *error1, const char *error2) {
	FREE(self->error1);
	FREE(self->error2);
	MALLOC_STR(self->error1, error1);
	MALLOC_STR(self->error2, error2);
}

void _sp42AttachmentLoader_setUnknownTypeError(sp42AttachmentLoader *self, sp42AttachmentType type) {
	char buffer[16];
	snprintf(buffer, 16, "%d", type);
	_sp42AttachmentLoader_setError(self, "Unknown attachment type: ", buffer);
}

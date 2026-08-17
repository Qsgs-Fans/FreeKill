/******************************************************************************
 * Spine Runtimes Software License
 * Version 2.1
 * 
 * Copyright (c) 2013, Esoteric Software
 * All rights reserved.
 * 
 * You are granted a perpetual, non-exclusive, non-sublicensable and
 * non-transferable license to install, execute and perform the Spine Runtimes
 * Software (the "Software") solely for internal use. Without the written
 * permission of Esoteric Software (typically granted by licensing Spine), you
 * may not (a) modify, translate, adapt or otherwise create derivative works,
 * improvements of the Software or develop new applications using the Software
 * or (b) remove, delete, alter or obscure any trademarks or any copyright,
 * trademark, patent or other intellectual property or proprietary rights
 * notices on or in the Software, including any copy thereof. Redistributions
 * in binary or source form must include this license and terms.
 * 
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#include <spine/AttachmentLoader.h>
#include <stdio.h>
#include <spine/extension.h>

typedef struct _sp21AttachmentLoaderVtable {
	sp21Attachment* (*newAttachment) (sp21AttachmentLoader* self, sp21Skin* skin, sp21AttachmentType type, const char* name,
			const char* path);
	void (*dispose) (sp21AttachmentLoader* self);
} _sp21AttachmentLoaderVtable;

void _sp21AttachmentLoader_init (sp21AttachmentLoader* self, /**/
void (*dispose) (sp21AttachmentLoader* self), /**/
		sp21Attachment* (*newAttachment) (sp21AttachmentLoader* self, sp21Skin* skin, sp21AttachmentType type, const char* name,
				const char* path)) {
	CONST_CAST(_sp21AttachmentLoaderVtable*, self->vtable) = NEW(_sp21AttachmentLoaderVtable);
	VTABLE(sp21AttachmentLoader, self)->dispose = dispose;
	VTABLE(sp21AttachmentLoader, self)->newAttachment = newAttachment;
}

void _sp21AttachmentLoader_deinit (sp21AttachmentLoader* self) {
	FREE(self->vtable);
	FREE(self->error1);
	FREE(self->error2);
}

void sp21AttachmentLoader_dispose (sp21AttachmentLoader* self) {
	VTABLE(sp21AttachmentLoader, self)->dispose(self);
	FREE(self);
}

sp21Attachment* sp21AttachmentLoader_newAttachment (sp21AttachmentLoader* self, sp21Skin* skin, sp21AttachmentType type, const char* name,
		const char* path) {
	FREE(self->error1);
	FREE(self->error2);
	self->error1 = 0;
	self->error2 = 0;
	return VTABLE(sp21AttachmentLoader, self)->newAttachment(self, skin, type, name, path);
}

void _sp21AttachmentLoader_setError (sp21AttachmentLoader* self, const char* error1, const char* error2) {
	FREE(self->error1);
	FREE(self->error2);
	MALLOC_STR(self->error1, error1);
	MALLOC_STR(self->error2, error2);
}

void _sp21AttachmentLoader_setUnknownTypeError (sp21AttachmentLoader* self, sp21AttachmentType type) {
	char buffer[16];
	sprintf(buffer, "%d", type);
	_sp21AttachmentLoader_setError(self, "Unknown attachment type: ", buffer);
}

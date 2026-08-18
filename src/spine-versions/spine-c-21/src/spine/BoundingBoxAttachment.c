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

#include <spine/BoundingBoxAttachment.h>
#include <spine/extension.h>

void _sp21BoundingBoxAttachment_dispose (sp21Attachment* attachment) {
	sp21BoundingBoxAttachment* self = SUB_CAST(sp21BoundingBoxAttachment, attachment);

	_sp21Attachment_deinit(attachment);

	FREE(self->vertices);
	FREE(self);
}

sp21BoundingBoxAttachment* sp21BoundingBoxAttachment_create (const char* name) {
	sp21BoundingBoxAttachment* self = NEW(sp21BoundingBoxAttachment);
	_sp21Attachment_init(SUPER(self), name, SP_ATTACHMENT_BOUNDING_BOX, _sp21BoundingBoxAttachment_dispose);
	return self;
}

void sp21BoundingBoxAttachment_computeWorldVertices (sp21BoundingBoxAttachment* self, sp21Bone* bone, float* worldVertices) {
	int i;
	float px, py;
	float* vertices = self->vertices;
	float x = bone->skeleton->x + bone->worldX, y = bone->skeleton->y + bone->worldY;
	for (i = 0; i < self->verticesCount; i += 2) {
		px = vertices[i];
		py = vertices[i + 1];
		worldVertices[i] = px * bone->m00 + py * bone->m01 + x;
		worldVertices[i + 1] = px * bone->m10 + py * bone->m11 + y;
	}
}

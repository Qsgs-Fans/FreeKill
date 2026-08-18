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

#include <spine/PathAttachment.h>
#include <spine/extension.h>

void _sp38PathAttachment_dispose (sp38Attachment* attachment) {
	sp38PathAttachment* self = SUB_CAST(sp38PathAttachment, attachment);

	_sp38VertexAttachment_deinit(SUPER(self));

	FREE(self->lengths);
	FREE(self);
}

sp38Attachment* _sp38PathAttachment_copy (sp38Attachment* attachment) {
	sp38PathAttachment* copy = sp38PathAttachment_create(attachment->name);
	sp38PathAttachment* self = SUB_CAST(sp38PathAttachment, attachment);
	sp38VertexAttachment_copyTo(SUPER(self), SUPER(copy));
	copy->lengthsLength = self->lengthsLength;
	copy->lengths = MALLOC(float, self->lengthsLength);
	memcpy(copy->lengths, self->lengths, self->lengthsLength * sizeof(float));
	copy->closed = self->closed;
	copy->constantSpeed = self->constantSpeed;
	return SUPER(SUPER(copy));
}

sp38PathAttachment* sp38PathAttachment_create (const char* name) {
	sp38PathAttachment* self = NEW(sp38PathAttachment);
	_sp38VertexAttachment_init(SUPER(self));
	_sp38Attachment_init(SUPER(SUPER(self)), name, SP_ATTACHMENT_PATH, _sp38PathAttachment_dispose, _sp38PathAttachment_copy);
	return self;
}

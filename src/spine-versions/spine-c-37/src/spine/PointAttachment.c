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

#include <spine/PointAttachment.h>
#include <spine/extension.h>

void _sp37PointAttachment_dispose (sp37Attachment* attachment) {
	sp37PathAttachment* self = SUB_CAST(sp37PathAttachment, attachment);

	_sp37VertexAttachment_deinit(SUPER(self));

	FREE(self);
}

sp37PointAttachment* sp37PointAttachment_create (const char* name) {
	sp37PointAttachment* self = NEW(sp37PointAttachment);
	_sp37VertexAttachment_init(SUPER(self));
	_sp37Attachment_init(SUPER(SUPER(self)), name, SP_ATTACHMENT_POINT, _sp37PointAttachment_dispose);
	return self;
}

void sp37PointAttachment_computeWorldPosition (sp37PointAttachment* self, sp37Bone* bone, float* x, float* y) {
	*x = self->x * bone->a + self->y * bone->b + bone->worldX;
	*y = self->x * bone->c + self->y * bone->d + bone->worldY;
}

float sp37PointAttachment_computeWorldRotation (sp37PointAttachment* self, sp37Bone* bone) {
	float cosine, sine, x, y;
	cosine = COS_DEG(self->rotation);
	sine = SIN_DEG(self->rotation);
	x = cosine * bone->a + sine * bone->b;
	y = cosine * bone->c + sine * bone->d;
	return ATAN2(y, x) * RAD_DEG;
}

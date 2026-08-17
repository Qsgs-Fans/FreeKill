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

#include <spine/PointAttachment.h>
#include <spine/extension.h>

void _sp40PointAttachment_dispose(sp40Attachment *attachment) {
	sp40PointAttachment *self = SUB_CAST(sp40PointAttachment, attachment);
	_sp40Attachment_deinit(attachment);
	FREE(self);
}

sp40Attachment *_sp40PointAttachment_copy(sp40Attachment *attachment) {
	sp40PointAttachment *self = SUB_CAST(sp40PointAttachment, attachment);
	sp40PointAttachment *copy = sp40PointAttachment_create(attachment->name);
	copy->x = self->x;
	copy->y = self->y;
	copy->rotation = self->rotation;
	sp40Color_setFromColor(&copy->color, &self->color);
	return SUPER(copy);
}

sp40PointAttachment *sp40PointAttachment_create(const char *name) {
	sp40PointAttachment *self = NEW(sp40PointAttachment);
	_sp40Attachment_init(SUPER(self), name, SP_ATTACHMENT_POINT, _sp40PointAttachment_dispose, _sp40PointAttachment_copy);
	return self;
}

void sp40PointAttachment_computeWorldPosition(sp40PointAttachment *self, sp40Bone *bone, float *x, float *y) {
	*x = self->x * bone->a + self->y * bone->b + bone->worldX;
	*y = self->x * bone->c + self->y * bone->d + bone->worldY;
}

float sp40PointAttachment_computeWorldRotation(sp40PointAttachment *self, sp40Bone *bone) {
	float cosine, sine, x, y;
	cosine = COS_DEG(self->rotation);
	sine = SIN_DEG(self->rotation);
	x = cosine * bone->a + sine * bone->b;
	y = cosine * bone->c + sine * bone->d;
	return ATAN2(y, x) * RAD_DEG;
}

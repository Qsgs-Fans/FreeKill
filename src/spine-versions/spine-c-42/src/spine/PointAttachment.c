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

#include <spine/PointAttachment.h>
#include <spine/extension.h>

void _sp42PointAttachment_dispose(sp42Attachment *attachment) {
	sp42PointAttachment *self = SUB_CAST(sp42PointAttachment, attachment);
	_sp42Attachment_deinit(attachment);
	FREE(self);
}

sp42Attachment *_sp42PointAttachment_copy(sp42Attachment *attachment) {
	sp42PointAttachment *self = SUB_CAST(sp42PointAttachment, attachment);
	sp42PointAttachment *copy = sp42PointAttachment_create(attachment->name);
	copy->x = self->x;
	copy->y = self->y;
	copy->rotation = self->rotation;
	sp42Color_setFromColor(&copy->color, &self->color);
	return SUPER(copy);
}

sp42PointAttachment *sp42PointAttachment_create(const char *name) {
	sp42PointAttachment *self = NEW(sp42PointAttachment);
	_sp42Attachment_init(SUPER(self), name, SP_ATTACHMENT_POINT, _sp42PointAttachment_dispose, _sp42PointAttachment_copy);
	return self;
}

void sp42PointAttachment_computeWorldPosition(sp42PointAttachment *self, sp42Bone *bone, float *x, float *y) {
	*x = self->x * bone->a + self->y * bone->b + bone->worldX;
	*y = self->x * bone->c + self->y * bone->d + bone->worldY;
}

float sp42PointAttachment_computeWorldRotation(sp42PointAttachment *self, sp42Bone *bone) {
	float r = self->rotation * DEG_RAD, cosine = COS(r), sine = SIN(r);
	float x = cosine * bone->a + sine * bone->b;
	float y = cosine * bone->c + sine * bone->d;
	return ATAN2DEG(y, x);
}

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

#include <spine/PointAttachment.h>
#include <spine/extension.h>

void _sp36PointAttachment_dispose (sp36Attachment* attachment) {
	sp36PathAttachment* self = SUB_CAST(sp36PathAttachment, attachment);

	_sp36VertexAttachment_deinit(SUPER(self));

	FREE(self);
}

sp36PointAttachment* sp36PointAttachment_create (const char* name) {
	sp36PointAttachment* self = NEW(sp36PointAttachment);
	_sp36VertexAttachment_init(SUPER(self));
	_sp36Attachment_init(SUPER(SUPER(self)), name, SP_ATTACHMENT_POINT, _sp36PointAttachment_dispose);
	return self;
}

void sp36PointAttachment_computeWorldPosition (sp36PointAttachment* self, sp36Bone* bone, float* x, float* y) {
	*x = self->x * bone->a + self->y * bone->b + bone->worldX;
	*y = self->x * bone->c + self->y * bone->d + bone->worldY;
}

float sp36PointAttachment_computeWorldRotation (sp36PointAttachment* self, sp36Bone* bone) {
	float cosine, sine, x, y;
	cosine = COS_DEG(self->rotation);
	sine = SIN_DEG(self->rotation);
	x = cosine * bone->a + sine * bone->b;
	y = cosine * bone->c + sine * bone->d;
	return ATAN2(y, x) * RAD_DEG;
}

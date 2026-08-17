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

#include <spine/VertexEffect.h>
#include <spine/extension.h>

void _sp40JitterVertexEffect_begin(sp40VertexEffect *self, sp40Skeleton *skeleton) {
	UNUSED(self);
	UNUSED(skeleton);
}

void _sp40JitterVertexEffect_transform(sp40VertexEffect *self, float *x, float *y, float *u, float *v, sp40Color *light,
									 sp40Color *dark) {
	sp40JitterVertexEffect *internal = (sp40JitterVertexEffect *) self;
	float jitterX = internal->jitterX;
	float jitterY = internal->jitterY;
	(*x) += _sp40Math_randomTriangular(-jitterX, jitterY);
	(*y) += _sp40Math_randomTriangular(-jitterX, jitterY);
	UNUSED(u);
	UNUSED(v);
	UNUSED(light);
	UNUSED(dark);
}

void _sp40JitterVertexEffect_end(sp40VertexEffect *self) {
	UNUSED(self);
}

sp40JitterVertexEffect *sp40JitterVertexEffect_create(float jitterX, float jitterY) {
	sp40JitterVertexEffect *effect = CALLOC(sp40JitterVertexEffect, 1);
	effect->super.begin = _sp40JitterVertexEffect_begin;
	effect->super.transform = _sp40JitterVertexEffect_transform;
	effect->super.end = _sp40JitterVertexEffect_end;
	effect->jitterX = jitterX;
	effect->jitterY = jitterY;
	return effect;
}

void sp40JitterVertexEffect_dispose(sp40JitterVertexEffect *effect) {
	FREE(effect);
}

void _sp40SwirlVertexEffect_begin(sp40VertexEffect *self, sp40Skeleton *skeleton) {
	sp40SwirlVertexEffect *internal = (sp40SwirlVertexEffect *) self;
	internal->worldX = skeleton->x + internal->centerX;
	internal->worldY = skeleton->y + internal->centerY;
}

void _sp40SwirlVertexEffect_transform(sp40VertexEffect *self, float *positionX, float *positionY, float *u, float *v,
									sp40Color *light, sp40Color *dark) {
	sp40SwirlVertexEffect *internal = (sp40SwirlVertexEffect *) self;
	float radAngle = internal->angle * DEG_RAD;
	float x = *positionX - internal->worldX;
	float y = *positionY - internal->worldY;
	float dist = SQRT(x * x + y * y);
	if (dist < internal->radius) {
		float theta = _sp40Math_interpolate(_sp40Math_pow2_apply, 0, radAngle,
										  (internal->radius - dist) / internal->radius);
		float cosine = COS(theta);
		float sine = SIN(theta);
		(*positionX) = cosine * x - sine * y + internal->worldX;
		(*positionY) = sine * x + cosine * y + internal->worldY;
	}
	UNUSED(self);
	UNUSED(u);
	UNUSED(v);
	UNUSED(light);
	UNUSED(dark);
}

void _sp40SwirlVertexEffect_end(sp40VertexEffect *self) {
	UNUSED(self);
}

sp40SwirlVertexEffect *sp40SwirlVertexEffect_create(float radius) {
	sp40SwirlVertexEffect *effect = CALLOC(sp40SwirlVertexEffect, 1);
	effect->super.begin = _sp40SwirlVertexEffect_begin;
	effect->super.transform = _sp40SwirlVertexEffect_transform;
	effect->super.end = _sp40SwirlVertexEffect_end;
	effect->radius = radius;
	return effect;
}

void sp40SwirlVertexEffect_dispose(sp40SwirlVertexEffect *effect) {
	FREE(effect);
}

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

void _sp38JitterVertexEffect_begin(sp38VertexEffect* self, sp38Skeleton* skeleton) {
	UNUSED(self);
	UNUSED(skeleton);
}

void _sp38JitterVertexEffect_transform(sp38VertexEffect* self, float* x, float* y, float* u, float* v, sp38Color* light, sp38Color* dark) {
	sp38JitterVertexEffect* internal = (sp38JitterVertexEffect*)self;
	float jitterX = internal->jitterX;
	float jitterY = internal->jitterY;
	(*x) += _sp38Math_randomTriangular(-jitterX, jitterY);
	(*y) += _sp38Math_randomTriangular(-jitterX, jitterY);
	UNUSED(u);
	UNUSED(v);
	UNUSED(light);
	UNUSED(dark);
}

void _sp38JitterVertexEffect_end(sp38VertexEffect* self) {
	UNUSED(self);
}

sp38JitterVertexEffect* sp38JitterVertexEffect_create(float jitterX, float jitterY) {
	sp38JitterVertexEffect* effect = CALLOC(sp38JitterVertexEffect, 1);
	effect->super.begin = _sp38JitterVertexEffect_begin;
	effect->super.transform = _sp38JitterVertexEffect_transform;
	effect->super.end = _sp38JitterVertexEffect_end;
	effect->jitterX = jitterX;
	effect->jitterY = jitterY;
	return effect;
}

void sp38JitterVertexEffect_dispose(sp38JitterVertexEffect* effect) {
	FREE(effect);
}

void _sp38SwirlVertexEffect_begin(sp38VertexEffect* self, sp38Skeleton* skeleton) {
	sp38SwirlVertexEffect* internal = (sp38SwirlVertexEffect*)self;
	internal->worldX = skeleton->x + internal->centerX;
	internal->worldY = skeleton->y + internal->centerY;
}

void _sp38SwirlVertexEffect_transform(sp38VertexEffect* self, float* positionX, float* positionY, float* u, float* v, sp38Color* light, sp38Color* dark) {
	sp38SwirlVertexEffect* internal = (sp38SwirlVertexEffect*)self;
	float radAngle = internal->angle * DEG_RAD;
	float x = *positionX - internal->worldX;
	float y = *positionY - internal->worldY;
	float dist = SQRT(x * x + y * y);
	if (dist < internal->radius) {
		float theta = _sp38Math_interpolate(_sp38Math_pow2_apply, 0, radAngle, (internal->radius - dist) / internal->radius);
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

void _sp38SwirlVertexEffect_end(sp38VertexEffect* self) {
	UNUSED(self);
}

sp38SwirlVertexEffect* sp38SwirlVertexEffect_create(float radius) {
	sp38SwirlVertexEffect* effect = CALLOC(sp38SwirlVertexEffect, 1);
	effect->super.begin = _sp38SwirlVertexEffect_begin;
	effect->super.transform = _sp38SwirlVertexEffect_transform;
	effect->super.end = _sp38SwirlVertexEffect_end;
	effect->radius = radius;
	return effect;
}

void sp38SwirlVertexEffect_dispose(sp38SwirlVertexEffect* effect) {
	FREE(effect);
}

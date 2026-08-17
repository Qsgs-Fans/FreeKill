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

#include <spine/VertexEffect.h>
#include <spine/extension.h>

void _sp37JitterVertexEffect_begin(sp37VertexEffect* self, sp37Skeleton* skeleton) {
	UNUSED(self);
	UNUSED(skeleton);
}

void _sp37JitterVertexEffect_transform(sp37VertexEffect* self, float* x, float* y, float* u, float* v, sp37Color* light, sp37Color* dark) {
	sp37JitterVertexEffect* internal = (sp37JitterVertexEffect*)self;
	float jitterX = internal->jitterX;
	float jitterY = internal->jitterY;
	(*x) += _sp37Math_randomTriangular(-jitterX, jitterY);
	(*y) += _sp37Math_randomTriangular(-jitterX, jitterY);
	UNUSED(u);
	UNUSED(v);
	UNUSED(light);
	UNUSED(dark);
}

void _sp37JitterVertexEffect_end(sp37VertexEffect* self) {
	UNUSED(self);
}

sp37JitterVertexEffect* sp37JitterVertexEffect_create(float jitterX, float jitterY) {
	sp37JitterVertexEffect* effect = CALLOC(sp37JitterVertexEffect, 1);
	effect->super.begin = _sp37JitterVertexEffect_begin;
	effect->super.transform = _sp37JitterVertexEffect_transform;
	effect->super.end = _sp37JitterVertexEffect_end;
	effect->jitterX = jitterX;
	effect->jitterY = jitterY;
	return effect;
}

void sp37JitterVertexEffect_dispose(sp37JitterVertexEffect* effect) {
	FREE(effect);
}

void _sp37SwirlVertexEffect_begin(sp37VertexEffect* self, sp37Skeleton* skeleton) {
	sp37SwirlVertexEffect* internal = (sp37SwirlVertexEffect*)self;
	internal->worldX = skeleton->x + internal->centerX;
	internal->worldY = skeleton->y + internal->centerY;
}

void _sp37SwirlVertexEffect_transform(sp37VertexEffect* self, float* positionX, float* positionY, float* u, float* v, sp37Color* light, sp37Color* dark) {
	sp37SwirlVertexEffect* internal = (sp37SwirlVertexEffect*)self;
	float radAngle = internal->angle * DEG_RAD;
	float x = *positionX - internal->worldX;
	float y = *positionY - internal->worldY;
	float dist = SQRT(x * x + y * y);
	if (dist < internal->radius) {
		float theta = _sp37Math_interpolate(_sp37Math_pow2_apply, 0, radAngle, (internal->radius - dist) / internal->radius);
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

void _sp37SwirlVertexEffect_end(sp37VertexEffect* self) {
}

sp37SwirlVertexEffect* sp37SwirlVertexEffect_create(float radius) {
	sp37SwirlVertexEffect* effect = CALLOC(sp37SwirlVertexEffect, 1);
	effect->super.begin = _sp37SwirlVertexEffect_begin;
	effect->super.transform = _sp37SwirlVertexEffect_transform;
	effect->super.end = _sp37SwirlVertexEffect_end;
	effect->radius = radius;
	return effect;
}

void sp37SwirlVertexEffect_dispose(sp37SwirlVertexEffect* effect) {
	FREE(effect);
}

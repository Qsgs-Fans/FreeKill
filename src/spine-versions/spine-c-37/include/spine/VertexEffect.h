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

#ifndef SPINE_VERTEXEFFECT_H_
#define SPINE_VERTEXEFFECT_H_

#include <spine/dll.h>
#include <spine/Skeleton.h>
#include <spine/Color.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp37VertexEffect;

typedef void (*sp37VertexEffectBegin)(struct sp37VertexEffect *self, sp37Skeleton *skeleton);

typedef void (*sp37VertexEffectTransform)(struct sp37VertexEffect *self, float *x, float *y, float *u, float *v,
										sp37Color *light, sp37Color *dark);

typedef void (*sp37VertexEffectEnd)(struct sp37VertexEffect *self);

typedef struct sp37VertexEffect {
	sp37VertexEffectBegin begin;
	sp37VertexEffectTransform transform;
	sp37VertexEffectEnd end;
} sp37VertexEffect;

typedef struct sp37JitterVertexEffect {
	sp37VertexEffect super;
	float jitterX;
	float jitterY;
} sp37JitterVertexEffect;

typedef struct sp37SwirlVertexEffect {
	sp37VertexEffect super;
	float centerX;
	float centerY;
	float radius;
	float angle;
	float worldX;
	float worldY;
} sp37SwirlVertexEffect;

SP_API sp37JitterVertexEffect *sp37JitterVertexEffect_create(float jitterX, float jitterY);

SP_API void sp37JitterVertexEffect_dispose(sp37JitterVertexEffect *effect);

SP_API sp37SwirlVertexEffect *sp37SwirlVertexEffect_create(float radius);

SP_API void sp37SwirlVertexEffect_dispose(sp37SwirlVertexEffect *effect);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_VERTEX_EFFECT_H_ */

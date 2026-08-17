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

#ifndef SPINE_VERTEXEFFECT_H_
#define SPINE_VERTEXEFFECT_H_

#include <spine/dll.h>
#include <spine/Skeleton.h>
#include <spine/Color.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp38VertexEffect;

typedef void (*sp38VertexEffectBegin)(struct sp38VertexEffect *self, sp38Skeleton *skeleton);

typedef void (*sp38VertexEffectTransform)(struct sp38VertexEffect *self, float *x, float *y, float *u, float *v,
	sp38Color *light, sp38Color *dark);

typedef void (*sp38VertexEffectEnd)(struct sp38VertexEffect *self);

typedef struct sp38VertexEffect {
	sp38VertexEffectBegin begin;
	sp38VertexEffectTransform transform;
	sp38VertexEffectEnd end;
} sp38VertexEffect;

typedef struct sp38JitterVertexEffect {
	sp38VertexEffect super;
	float jitterX;
	float jitterY;
} sp38JitterVertexEffect;

typedef struct sp38SwirlVertexEffect {
	sp38VertexEffect super;
	float centerX;
	float centerY;
	float radius;
	float angle;
	float worldX;
	float worldY;
} sp38SwirlVertexEffect;

SP_API sp38JitterVertexEffect *sp38JitterVertexEffect_create(float jitterX, float jitterY);

SP_API void sp38JitterVertexEffect_dispose(sp38JitterVertexEffect *effect);

SP_API sp38SwirlVertexEffect *sp38SwirlVertexEffect_create(float radius);

SP_API void sp38SwirlVertexEffect_dispose(sp38SwirlVertexEffect *effect);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_VERTEX_EFFECT_H_ */

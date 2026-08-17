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

struct sp40VertexEffect;

typedef void (*sp40VertexEffectBegin)(struct sp40VertexEffect *self, sp40Skeleton *skeleton);

typedef void (*sp40VertexEffectTransform)(struct sp40VertexEffect *self, float *x, float *y, float *u, float *v,
										sp40Color *light, sp40Color *dark);

typedef void (*sp40VertexEffectEnd)(struct sp40VertexEffect *self);

typedef struct sp40VertexEffect {
	sp40VertexEffectBegin begin;
	sp40VertexEffectTransform transform;
	sp40VertexEffectEnd end;
} sp40VertexEffect;

typedef struct sp40JitterVertexEffect {
	sp40VertexEffect super;
	float jitterX;
	float jitterY;
} sp40JitterVertexEffect;

typedef struct sp40SwirlVertexEffect {
	sp40VertexEffect super;
	float centerX;
	float centerY;
	float radius;
	float angle;
	float worldX;
	float worldY;
} sp40SwirlVertexEffect;

SP_API sp40JitterVertexEffect *sp40JitterVertexEffect_create(float jitterX, float jitterY);

SP_API void sp40JitterVertexEffect_dispose(sp40JitterVertexEffect *effect);

SP_API sp40SwirlVertexEffect *sp40SwirlVertexEffect_create(float radius);

SP_API void sp40SwirlVertexEffect_dispose(sp40SwirlVertexEffect *effect);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_VERTEX_EFFECT_H_ */

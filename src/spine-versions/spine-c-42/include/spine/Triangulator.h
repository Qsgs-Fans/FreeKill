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

#ifndef SPINE_TRIANGULATOR_H
#define SPINE_TRIANGULATOR_H

#include <spine/dll.h>
#include <spine/Array.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp42Triangulator {
	sp42ArrayFloatArray *convexPolygons;
	sp42ArrayShortArray *convexPolygonsIndices;

	sp42ShortArray *indicesArray;
	sp42IntArray *isConcaveArray;
	sp42ShortArray *triangles;

	sp42ArrayFloatArray *polygonPool;
	sp42ArrayShortArray *polygonIndicesPool;
} sp42Triangulator;

SP_API sp42Triangulator *sp42Triangulator_create(void);

SP_API sp42ShortArray *sp42Triangulator_triangulate(sp42Triangulator *self, sp42FloatArray *verticesArray);

SP_API sp42ArrayFloatArray *
sp42Triangulator_decompose(sp42Triangulator *self, sp42FloatArray *verticesArray, sp42ShortArray *triangles);

SP_API void sp42Triangulator_dispose(sp42Triangulator *self);


#ifdef __cplusplus
}
#endif

#endif /* SPINE_TRIANGULATOR_H_ */

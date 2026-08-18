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

#ifndef SPINE_TRIANGULATOR_H
#define SPINE_TRIANGULATOR_H

#include <spine/dll.h>
#include <spine/Array.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp37Triangulator {
	sp37ArrayFloatArray* convexPolygons;
	sp37ArrayShortArray* convexPolygonsIndices;

	sp37ShortArray* indicesArray;
	sp37IntArray* isConcaveArray;
	sp37ShortArray* triangles;

	sp37ArrayFloatArray* polygonPool;
	sp37ArrayShortArray* polygonIndicesPool;
} sp37Triangulator;

SP_API sp37Triangulator* sp37Triangulator_create();
SP_API sp37ShortArray* sp37Triangulator_triangulate(sp37Triangulator* self, sp37FloatArray* verticesArray);
SP_API sp37ArrayFloatArray* sp37Triangulator_decompose(sp37Triangulator* self, sp37FloatArray* verticesArray, sp37ShortArray* triangles);
SP_API void sp37Triangulator_dispose(sp37Triangulator* self);


#ifdef __cplusplus
}
#endif

#endif /* SPINE_TRIANGULATOR_H_ */

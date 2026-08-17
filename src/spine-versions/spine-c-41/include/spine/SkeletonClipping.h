/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated September 24, 2021. Replaces all prior versions.
 *
 * Copyright (c) 2013-2021, Esoteric Software LLC
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

#ifndef SPINE_SKELETONCLIPPING_H
#define SPINE_SKELETONCLIPPING_H

#include <spine/dll.h>
#include <spine/Array.h>
#include <spine/ClippingAttachment.h>
#include <spine/Slot.h>
#include <spine/Triangulator.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp41SkeletonClipping {
	sp41Triangulator *triangulator;
	sp41FloatArray *clippingPolygon;
	sp41FloatArray *clipOutput;
	sp41FloatArray *clippedVertices;
	sp41FloatArray *clippedUVs;
	sp41UnsignedShortArray *clippedTriangles;
	sp41FloatArray *scratch;
	sp41ClippingAttachment *clipAttachment;
	sp41ArrayFloatArray *clippingPolygons;
} sp41SkeletonClipping;

SP_API sp41SkeletonClipping *sp41SkeletonClipping_create();

SP_API int sp41SkeletonClipping_clipStart(sp41SkeletonClipping *self, sp41Slot *slot, sp41ClippingAttachment *clip);

SP_API void sp41SkeletonClipping_clipEnd(sp41SkeletonClipping *self, sp41Slot *slot);

SP_API void sp41SkeletonClipping_clipEnd2(sp41SkeletonClipping *self);

SP_API int /*boolean*/ sp41SkeletonClipping_isClipping(sp41SkeletonClipping *self);

SP_API void sp41SkeletonClipping_clipTriangles(sp41SkeletonClipping *self, float *vertices, int verticesLength,
											 unsigned short *triangles, int trianglesLength, float *uvs, int stride);

SP_API void sp41SkeletonClipping_dispose(sp41SkeletonClipping *self);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONCLIPPING_H */

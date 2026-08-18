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

typedef struct sp42SkeletonClipping {
	sp42Triangulator *triangulator;
	sp42FloatArray *clippingPolygon;
	sp42FloatArray *clipOutput;
	sp42FloatArray *clippedVertices;
	sp42FloatArray *clippedUVs;
	sp42UnsignedShortArray *clippedTriangles;
	sp42FloatArray *scratch;
	sp42ClippingAttachment *clipAttachment;
	sp42ArrayFloatArray *clippingPolygons;
} sp42SkeletonClipping;

SP_API sp42SkeletonClipping *sp42SkeletonClipping_create(void);

SP_API int sp42SkeletonClipping_clipStart(sp42SkeletonClipping *self, sp42Slot *slot, sp42ClippingAttachment *clip);

SP_API void sp42SkeletonClipping_clipEnd(sp42SkeletonClipping *self, sp42Slot *slot);

SP_API void sp42SkeletonClipping_clipEnd2(sp42SkeletonClipping *self);

SP_API int /*boolean*/ sp42SkeletonClipping_isClipping(sp42SkeletonClipping *self);

SP_API void sp42SkeletonClipping_clipTriangles(sp42SkeletonClipping *self, float *vertices, int verticesLength,
											 unsigned short *triangles, int trianglesLength, float *uvs, int stride);

SP_API void sp42SkeletonClipping_dispose(sp42SkeletonClipping *self);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONCLIPPING_H */

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

#ifndef SPINE_SKELETONBOUNDS_H_
#define SPINE_SKELETONBOUNDS_H_

#include <spine/dll.h>
#include <spine/BoundingBoxAttachment.h>
#include <spine/Skeleton.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp40Polygon {
	float *const vertices;
	int count;
	int capacity;
} sp40Polygon;

SP_API sp40Polygon *sp40Polygon_create(int capacity);

SP_API void sp40Polygon_dispose(sp40Polygon *self);

SP_API int/*bool*/sp40Polygon_containsPoint(sp40Polygon *polygon, float x, float y);

SP_API int/*bool*/sp40Polygon_intersectsSegment(sp40Polygon *polygon, float x1, float y1, float x2, float y2);

/**/

typedef struct sp40SkeletonBounds {
	int count;
	sp40BoundingBoxAttachment **boundingBoxes;
	sp40Polygon **polygons;

	float minX, minY, maxX, maxY;
} sp40SkeletonBounds;

SP_API sp40SkeletonBounds *sp40SkeletonBounds_create();

SP_API void sp40SkeletonBounds_dispose(sp40SkeletonBounds *self);

SP_API void sp40SkeletonBounds_update(sp40SkeletonBounds *self, sp40Skeleton *skeleton, int/*bool*/updateAabb);

/** Returns true if the axis aligned bounding box contains the point. */
SP_API int/*bool*/sp40SkeletonBounds_aabbContainsPoint(sp40SkeletonBounds *self, float x, float y);

/** Returns true if the axis aligned bounding box intersects the line segment. */
SP_API int/*bool*/
sp40SkeletonBounds_aabbIntersectsSegment(sp40SkeletonBounds *self, float x1, float y1, float x2, float y2);

/** Returns true if the axis aligned bounding box intersects the axis aligned bounding box of the specified bounds. */
SP_API int/*bool*/sp40SkeletonBounds_aabbIntersectsSkeleton(sp40SkeletonBounds *self, sp40SkeletonBounds *bounds);

/** Returns the first bounding box attachment that contains the point, or null. When doing many checks, it is usually more
 * efficient to only call this method if sp40SkeletonBounds_aabbContainsPoint returns true. */
SP_API sp40BoundingBoxAttachment *sp40SkeletonBounds_containsPoint(sp40SkeletonBounds *self, float x, float y);

/** Returns the first bounding box attachment that contains the line segment, or null. When doing many checks, it is usually
 * more efficient to only call this method if sp40SkeletonBounds_aabbIntersectsSegment returns true. */
SP_API sp40BoundingBoxAttachment *
sp40SkeletonBounds_intersectsSegment(sp40SkeletonBounds *self, float x1, float y1, float x2, float y2);

/** Returns the polygon for the specified bounding box, or null. */
SP_API sp40Polygon *sp40SkeletonBounds_getPolygon(sp40SkeletonBounds *self, sp40BoundingBoxAttachment *boundingBox);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONBOUNDS_H_ */

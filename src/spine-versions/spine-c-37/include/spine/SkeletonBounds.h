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

#ifndef SPINE_SKELETONBOUNDS_H_
#define SPINE_SKELETONBOUNDS_H_

#include <spine/dll.h>
#include <spine/BoundingBoxAttachment.h>
#include <spine/Skeleton.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp37Polygon {
	float* const vertices;
	int count;
	int capacity;
} sp37Polygon;

SP_API sp37Polygon* sp37Polygon_create (int capacity);
SP_API void sp37Polygon_dispose (sp37Polygon* self);

SP_API int/*bool*/sp37Polygon_containsPoint (sp37Polygon* polygon, float x, float y);
SP_API int/*bool*/sp37Polygon_intersectsSegment (sp37Polygon* polygon, float x1, float y1, float x2, float y2);

#ifdef SPINE_SHORT_NAMES
typedef sp37Polygon Polygon;
#define Polygon_create(...) sp37Polygon_create(__VA_ARGS__)
#define Polygon_dispose(...) sp37Polygon_dispose(__VA_ARGS__)
#define Polygon_containsPoint(...) sp37Polygon_containsPoint(__VA_ARGS__)
#define Polygon_intersectsSegment(...) sp37Polygon_intersectsSegment(__VA_ARGS__)
#endif

/**/

typedef struct sp37SkeletonBounds {
	int count;
	sp37BoundingBoxAttachment** boundingBoxes;
	sp37Polygon** polygons;

	float minX, minY, maxX, maxY;
} sp37SkeletonBounds;

SP_API sp37SkeletonBounds* sp37SkeletonBounds_create ();
SP_API void sp37SkeletonBounds_dispose (sp37SkeletonBounds* self);
SP_API void sp37SkeletonBounds_update (sp37SkeletonBounds* self, sp37Skeleton* skeleton, int/*bool*/updateAabb);

/** Returns true if the axis aligned bounding box contains the point. */
SP_API int/*bool*/sp37SkeletonBounds_aabbContainsPoint (sp37SkeletonBounds* self, float x, float y);

/** Returns true if the axis aligned bounding box intersects the line segment. */
SP_API int/*bool*/sp37SkeletonBounds_aabbIntersectsSegment (sp37SkeletonBounds* self, float x1, float y1, float x2, float y2);

/** Returns true if the axis aligned bounding box intersects the axis aligned bounding box of the specified bounds. */
SP_API int/*bool*/sp37SkeletonBounds_aabbIntersectsSkeleton (sp37SkeletonBounds* self, sp37SkeletonBounds* bounds);

/** Returns the first bounding box attachment that contains the point, or null. When doing many checks, it is usually more
 * efficient to only call this method if sp37SkeletonBounds_aabbContainsPoint returns true. */
SP_API sp37BoundingBoxAttachment* sp37SkeletonBounds_containsPoint (sp37SkeletonBounds* self, float x, float y);

/** Returns the first bounding box attachment that contains the line segment, or null. When doing many checks, it is usually
 * more efficient to only call this method if sp37SkeletonBounds_aabbIntersectsSegment returns true. */
SP_API sp37BoundingBoxAttachment* sp37SkeletonBounds_intersectsSegment (sp37SkeletonBounds* self, float x1, float y1, float x2, float y2);

/** Returns the polygon for the specified bounding box, or null. */
SP_API sp37Polygon* sp37SkeletonBounds_getPolygon (sp37SkeletonBounds* self, sp37BoundingBoxAttachment* boundingBox);

#ifdef SPINE_SHORT_NAMES
typedef sp37SkeletonBounds SkeletonBounds;
#define SkeletonBounds_create(...) sp37SkeletonBounds_create(__VA_ARGS__)
#define SkeletonBounds_dispose(...) sp37SkeletonBounds_dispose(__VA_ARGS__)
#define SkeletonBounds_update(...) sp37SkeletonBounds_update(__VA_ARGS__)
#define SkeletonBounds_aabbContainsPoint(...) sp37SkeletonBounds_aabbContainsPoint(__VA_ARGS__)
#define SkeletonBounds_aabbIntersectsSegment(...) sp37SkeletonBounds_aabbIntersectsSegment(__VA_ARGS__)
#define SkeletonBounds_aabbIntersectsSkeleton(...) sp37SkeletonBounds_aabbIntersectsSkeleton(__VA_ARGS__)
#define SkeletonBounds_containsPoint(...) sp37SkeletonBounds_containsPoint(__VA_ARGS__)
#define SkeletonBounds_intersectsSegment(...) sp37SkeletonBounds_intersectsSegment(__VA_ARGS__)
#define SkeletonBounds_getPolygon(...) sp37SkeletonBounds_getPolygon(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONBOUNDS_H_ */

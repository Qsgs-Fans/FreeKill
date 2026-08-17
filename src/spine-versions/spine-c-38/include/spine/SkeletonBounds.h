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

typedef struct sp38Polygon {
	float* const vertices;
	int count;
	int capacity;
} sp38Polygon;

SP_API sp38Polygon* sp38Polygon_create (int capacity);
SP_API void sp38Polygon_dispose (sp38Polygon* self);

SP_API int/*bool*/sp38Polygon_containsPoint (sp38Polygon* polygon, float x, float y);
SP_API int/*bool*/sp38Polygon_intersectsSegment (sp38Polygon* polygon, float x1, float y1, float x2, float y2);

#ifdef SPINE_SHORT_NAMES
typedef sp38Polygon Polygon;
#define Polygon_create(...) sp38Polygon_create(__VA_ARGS__)
#define Polygon_dispose(...) sp38Polygon_dispose(__VA_ARGS__)
#define Polygon_containsPoint(...) sp38Polygon_containsPoint(__VA_ARGS__)
#define Polygon_intersectsSegment(...) sp38Polygon_intersectsSegment(__VA_ARGS__)
#endif

/**/

typedef struct sp38SkeletonBounds {
	int count;
	sp38BoundingBoxAttachment** boundingBoxes;
	sp38Polygon** polygons;

	float minX, minY, maxX, maxY;
} sp38SkeletonBounds;

SP_API sp38SkeletonBounds* sp38SkeletonBounds_create ();
SP_API void sp38SkeletonBounds_dispose (sp38SkeletonBounds* self);
SP_API void sp38SkeletonBounds_update (sp38SkeletonBounds* self, sp38Skeleton* skeleton, int/*bool*/updateAabb);

/** Returns true if the axis aligned bounding box contains the point. */
SP_API int/*bool*/sp38SkeletonBounds_aabbContainsPoint (sp38SkeletonBounds* self, float x, float y);

/** Returns true if the axis aligned bounding box intersects the line segment. */
SP_API int/*bool*/sp38SkeletonBounds_aabbIntersectsSegment (sp38SkeletonBounds* self, float x1, float y1, float x2, float y2);

/** Returns true if the axis aligned bounding box intersects the axis aligned bounding box of the specified bounds. */
SP_API int/*bool*/sp38SkeletonBounds_aabbIntersectsSkeleton (sp38SkeletonBounds* self, sp38SkeletonBounds* bounds);

/** Returns the first bounding box attachment that contains the point, or null. When doing many checks, it is usually more
 * efficient to only call this method if sp38SkeletonBounds_aabbContainsPoint returns true. */
SP_API sp38BoundingBoxAttachment* sp38SkeletonBounds_containsPoint (sp38SkeletonBounds* self, float x, float y);

/** Returns the first bounding box attachment that contains the line segment, or null. When doing many checks, it is usually
 * more efficient to only call this method if sp38SkeletonBounds_aabbIntersectsSegment returns true. */
SP_API sp38BoundingBoxAttachment* sp38SkeletonBounds_intersectsSegment (sp38SkeletonBounds* self, float x1, float y1, float x2, float y2);

/** Returns the polygon for the specified bounding box, or null. */
SP_API sp38Polygon* sp38SkeletonBounds_getPolygon (sp38SkeletonBounds* self, sp38BoundingBoxAttachment* boundingBox);

#ifdef SPINE_SHORT_NAMES
typedef sp38SkeletonBounds SkeletonBounds;
#define SkeletonBounds_create(...) sp38SkeletonBounds_create(__VA_ARGS__)
#define SkeletonBounds_dispose(...) sp38SkeletonBounds_dispose(__VA_ARGS__)
#define SkeletonBounds_update(...) sp38SkeletonBounds_update(__VA_ARGS__)
#define SkeletonBounds_aabbContainsPoint(...) sp38SkeletonBounds_aabbContainsPoint(__VA_ARGS__)
#define SkeletonBounds_aabbIntersectsSegment(...) sp38SkeletonBounds_aabbIntersectsSegment(__VA_ARGS__)
#define SkeletonBounds_aabbIntersectsSkeleton(...) sp38SkeletonBounds_aabbIntersectsSkeleton(__VA_ARGS__)
#define SkeletonBounds_containsPoint(...) sp38SkeletonBounds_containsPoint(__VA_ARGS__)
#define SkeletonBounds_intersectsSegment(...) sp38SkeletonBounds_intersectsSegment(__VA_ARGS__)
#define SkeletonBounds_getPolygon(...) sp38SkeletonBounds_getPolygon(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONBOUNDS_H_ */

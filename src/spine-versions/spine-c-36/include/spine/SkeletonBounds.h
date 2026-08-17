/******************************************************************************
 * Spine Runtimes Software License v2.5
 *
 * Copyright (c) 2013-2016, Esoteric Software
 * All rights reserved.
 *
 * You are granted a perpetual, non-exclusive, non-sublicensable, and
 * non-transferable license to use, install, execute, and perform the Spine
 * Runtimes software and derivative works solely for personal or internal
 * use. Without the written permission of Esoteric Software (see Section 2 of
 * the Spine Software License Agreement), you may not (a) modify, translate,
 * adapt, or develop new applications using the Spine Runtimes or otherwise
 * create derivative works or improvements of the Spine Runtimes or (b) remove,
 * delete, alter, or obscure any trademarks or any copyright, trademark, patent,
 * or other intellectual property or proprietary rights notices on or in the
 * Software, including any copy thereof. Redistributions in binary or source
 * form must include this license and terms.
 *
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, BUSINESS INTERRUPTION, OR LOSS OF
 * USE, DATA, OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 * IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#ifndef SPINE_SKELETONBOUNDS_H_
#define SPINE_SKELETONBOUNDS_H_

#include <spine/dll.h>
#include <spine/BoundingBoxAttachment.h>
#include <spine/Skeleton.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp36Polygon {
	float* const vertices;
	int count;
	int capacity;
} sp36Polygon;

SP_API sp36Polygon* sp36Polygon_create (int capacity);
SP_API void sp36Polygon_dispose (sp36Polygon* self);

SP_API int/*bool*/sp36Polygon_containsPoint (sp36Polygon* polygon, float x, float y);
SP_API int/*bool*/sp36Polygon_intersectsSegment (sp36Polygon* polygon, float x1, float y1, float x2, float y2);

#ifdef SPINE_SHORT_NAMES
typedef sp36Polygon Polygon;
#define Polygon_create(...) sp36Polygon_create(__VA_ARGS__)
#define Polygon_dispose(...) sp36Polygon_dispose(__VA_ARGS__)
#define Polygon_containsPoint(...) sp36Polygon_containsPoint(__VA_ARGS__)
#define Polygon_intersectsSegment(...) sp36Polygon_intersectsSegment(__VA_ARGS__)
#endif

/**/

typedef struct sp36SkeletonBounds {
	int count;
	sp36BoundingBoxAttachment** boundingBoxes;
	sp36Polygon** polygons;

	float minX, minY, maxX, maxY;
} sp36SkeletonBounds;

SP_API sp36SkeletonBounds* sp36SkeletonBounds_create ();
SP_API void sp36SkeletonBounds_dispose (sp36SkeletonBounds* self);
SP_API void sp36SkeletonBounds_update (sp36SkeletonBounds* self, sp36Skeleton* skeleton, int/*bool*/updateAabb);

/** Returns true if the axis aligned bounding box contains the point. */
SP_API int/*bool*/sp36SkeletonBounds_aabbContainsPoint (sp36SkeletonBounds* self, float x, float y);

/** Returns true if the axis aligned bounding box intersects the line segment. */
SP_API int/*bool*/sp36SkeletonBounds_aabbIntersectsSegment (sp36SkeletonBounds* self, float x1, float y1, float x2, float y2);

/** Returns true if the axis aligned bounding box intersects the axis aligned bounding box of the specified bounds. */
SP_API int/*bool*/sp36SkeletonBounds_aabbIntersectsSkeleton (sp36SkeletonBounds* self, sp36SkeletonBounds* bounds);

/** Returns the first bounding box attachment that contains the point, or null. When doing many checks, it is usually more
 * efficient to only call this method if sp36SkeletonBounds_aabbContainsPoint returns true. */
SP_API sp36BoundingBoxAttachment* sp36SkeletonBounds_containsPoint (sp36SkeletonBounds* self, float x, float y);

/** Returns the first bounding box attachment that contains the line segment, or null. When doing many checks, it is usually
 * more efficient to only call this method if sp36SkeletonBounds_aabbIntersectsSegment returns true. */
SP_API sp36BoundingBoxAttachment* sp36SkeletonBounds_intersectsSegment (sp36SkeletonBounds* self, float x1, float y1, float x2, float y2);

/** Returns the polygon for the specified bounding box, or null. */
SP_API sp36Polygon* sp36SkeletonBounds_getPolygon (sp36SkeletonBounds* self, sp36BoundingBoxAttachment* boundingBox);

#ifdef SPINE_SHORT_NAMES
typedef sp36SkeletonBounds SkeletonBounds;
#define SkeletonBounds_create(...) sp36SkeletonBounds_create(__VA_ARGS__)
#define SkeletonBounds_dispose(...) sp36SkeletonBounds_dispose(__VA_ARGS__)
#define SkeletonBounds_update(...) sp36SkeletonBounds_update(__VA_ARGS__)
#define SkeletonBounds_aabbContainsPoint(...) sp36SkeletonBounds_aabbContainsPoint(__VA_ARGS__)
#define SkeletonBounds_aabbIntersectsSegment(...) sp36SkeletonBounds_aabbIntersectsSegment(__VA_ARGS__)
#define SkeletonBounds_aabbIntersectsSkeleton(...) sp36SkeletonBounds_aabbIntersectsSkeleton(__VA_ARGS__)
#define SkeletonBounds_containsPoint(...) sp36SkeletonBounds_containsPoint(__VA_ARGS__)
#define SkeletonBounds_intersectsSegment(...) sp36SkeletonBounds_intersectsSegment(__VA_ARGS__)
#define SkeletonBounds_getPolygon(...) sp36SkeletonBounds_getPolygon(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONBOUNDS_H_ */

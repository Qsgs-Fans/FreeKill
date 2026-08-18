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

#include <spine/BoundingBoxAttachment.h>
#include <spine/Skeleton.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp35Polygon {
	float* const vertices;
	int count;
	int capacity;
} sp35Polygon;

sp35Polygon* sp35Polygon_create (int capacity);
void sp35Polygon_dispose (sp35Polygon* self);

int/*bool*/sp35Polygon_containsPoint (sp35Polygon* polygon, float x, float y);
int/*bool*/sp35Polygon_intersectsSegment (sp35Polygon* polygon, float x1, float y1, float x2, float y2);

#ifdef SPINE_SHORT_NAMES
typedef sp35Polygon Polygon;
#define Polygon_create(...) sp35Polygon_create(__VA_ARGS__)
#define Polygon_dispose(...) sp35Polygon_dispose(__VA_ARGS__)
#define Polygon_containsPoint(...) sp35Polygon_containsPoint(__VA_ARGS__)
#define Polygon_intersectsSegment(...) sp35Polygon_intersectsSegment(__VA_ARGS__)
#endif

/**/

typedef struct sp35SkeletonBounds {
	int count;
	sp35BoundingBoxAttachment** boundingBoxes;
	sp35Polygon** polygons;

	float minX, minY, maxX, maxY;
} sp35SkeletonBounds;

sp35SkeletonBounds* sp35SkeletonBounds_create ();
void sp35SkeletonBounds_dispose (sp35SkeletonBounds* self);
void sp35SkeletonBounds_update (sp35SkeletonBounds* self, sp35Skeleton* skeleton, int/*bool*/updateAabb);

/** Returns true if the axis aligned bounding box contains the point. */
int/*bool*/sp35SkeletonBounds_aabbContainsPoint (sp35SkeletonBounds* self, float x, float y);

/** Returns true if the axis aligned bounding box intersects the line segment. */
int/*bool*/sp35SkeletonBounds_aabbIntersectsSegment (sp35SkeletonBounds* self, float x1, float y1, float x2, float y2);

/** Returns true if the axis aligned bounding box intersects the axis aligned bounding box of the specified bounds. */
int/*bool*/sp35SkeletonBounds_aabbIntersectsSkeleton (sp35SkeletonBounds* self, sp35SkeletonBounds* bounds);

/** Returns the first bounding box attachment that contains the point, or null. When doing many checks, it is usually more
 * efficient to only call this method if sp35SkeletonBounds_aabbContainsPoint returns true. */
sp35BoundingBoxAttachment* sp35SkeletonBounds_containsPoint (sp35SkeletonBounds* self, float x, float y);

/** Returns the first bounding box attachment that contains the line segment, or null. When doing many checks, it is usually
 * more efficient to only call this method if sp35SkeletonBounds_aabbIntersectsSegment returns true. */
sp35BoundingBoxAttachment* sp35SkeletonBounds_intersectsSegment (sp35SkeletonBounds* self, float x1, float y1, float x2, float y2);

/** Returns the polygon for the specified bounding box, or null. */
sp35Polygon* sp35SkeletonBounds_getPolygon (sp35SkeletonBounds* self, sp35BoundingBoxAttachment* boundingBox);

#ifdef SPINE_SHORT_NAMES
typedef sp35SkeletonBounds SkeletonBounds;
#define SkeletonBounds_create(...) sp35SkeletonBounds_create(__VA_ARGS__)
#define SkeletonBounds_dispose(...) sp35SkeletonBounds_dispose(__VA_ARGS__)
#define SkeletonBounds_update(...) sp35SkeletonBounds_update(__VA_ARGS__)
#define SkeletonBounds_aabbContainsPoint(...) sp35SkeletonBounds_aabbContainsPoint(__VA_ARGS__)
#define SkeletonBounds_aabbIntersectsSegment(...) sp35SkeletonBounds_aabbIntersectsSegment(__VA_ARGS__)
#define SkeletonBounds_aabbIntersectsSkeleton(...) sp35SkeletonBounds_aabbIntersectsSkeleton(__VA_ARGS__)
#define SkeletonBounds_containsPoint(...) sp35SkeletonBounds_containsPoint(__VA_ARGS__)
#define SkeletonBounds_intersectsSegment(...) sp35SkeletonBounds_intersectsSegment(__VA_ARGS__)
#define SkeletonBounds_getPolygon(...) sp35SkeletonBounds_getPolygon(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONBOUNDS_H_ */

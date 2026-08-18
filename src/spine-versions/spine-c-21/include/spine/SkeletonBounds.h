/******************************************************************************
 * Spine Runtimes Software License
 * Version 2.1
 * 
 * Copyright (c) 2013, Esoteric Software
 * All rights reserved.
 * 
 * You are granted a perpetual, non-exclusive, non-sublicensable and
 * non-transferable license to install, execute and perform the Spine Runtimes
 * Software (the "Software") solely for internal use. Without the written
 * permission of Esoteric Software (typically granted by licensing Spine), you
 * may not (a) modify, translate, adapt or otherwise create derivative works,
 * improvements of the Software or develop new applications using the Software
 * or (b) remove, delete, alter or obscure any trademarks or any copyright,
 * trademark, patent or other intellectual property or proprietary rights
 * notices on or in the Software, including any copy thereof. Redistributions
 * in binary or source form must include this license and terms.
 * 
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#ifndef SPINE_SKELETONBOUNDS_H_
#define SPINE_SKELETONBOUNDS_H_

#include <spine/BoundingBoxAttachment.h>
#include <spine/Skeleton.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp21Polygon {
	float* const vertices;
	int count;
	int capacity;
} sp21Polygon;

sp21Polygon* sp21Polygon_create (int capacity);
void sp21Polygon_dispose (sp21Polygon* self);

int/*bool*/sp21Polygon_containsPoint (sp21Polygon* polygon, float x, float y);
int/*bool*/sp21Polygon_intersectsSegment (sp21Polygon* polygon, float x1, float y1, float x2, float y2);

#ifdef SPINE_SHORT_NAMES
typedef sp21Polygon Polygon;
#define Polygon_create(...) sp21Polygon_create(__VA_ARGS__)
#define Polygon_dispose(...) sp21Polygon_dispose(__VA_ARGS__)
#define Polygon_containsPoint(...) sp21Polygon_containsPoint(__VA_ARGS__)
#define Polygon_intersectsSegment(...) sp21Polygon_intersectsSegment(__VA_ARGS__)
#endif

/**/

typedef struct sp21SkeletonBounds {
	int count;
	sp21BoundingBoxAttachment** boundingBoxes;
	sp21Polygon** polygons;

	float minX, minY, maxX, maxY;
} sp21SkeletonBounds;

sp21SkeletonBounds* sp21SkeletonBounds_create ();
void sp21SkeletonBounds_dispose (sp21SkeletonBounds* self);
void sp21SkeletonBounds_update (sp21SkeletonBounds* self, sp21Skeleton* skeleton, int/*bool*/updateAabb);

/** Returns true if the axis aligned bounding box contains the point. */
int/*bool*/sp21SkeletonBounds_aabbContainsPoint (sp21SkeletonBounds* self, float x, float y);

/** Returns true if the axis aligned bounding box intersects the line segment. */
int/*bool*/sp21SkeletonBounds_aabbIntersectsSegment (sp21SkeletonBounds* self, float x1, float y1, float x2, float y2);

/** Returns true if the axis aligned bounding box intersects the axis aligned bounding box of the specified bounds. */
int/*bool*/sp21SkeletonBounds_aabbIntersectsSkeleton (sp21SkeletonBounds* self, sp21SkeletonBounds* bounds);

/** Returns the first bounding box attachment that contains the point, or null. When doing many checks, it is usually more
 * efficient to only call this method if sp21SkeletonBounds_aabbContainsPoint returns true. */
sp21BoundingBoxAttachment* sp21SkeletonBounds_containsPoint (sp21SkeletonBounds* self, float x, float y);

/** Returns the first bounding box attachment that contains the line segment, or null. When doing many checks, it is usually
 * more efficient to only call this method if sp21SkeletonBounds_aabbIntersectsSegment returns true. */
sp21BoundingBoxAttachment* sp21SkeletonBounds_intersectsSegment (sp21SkeletonBounds* self, float x1, float y1, float x2, float y2);

/** Returns the polygon for the specified bounding box, or null. */
sp21Polygon* sp21SkeletonBounds_getPolygon (sp21SkeletonBounds* self, sp21BoundingBoxAttachment* boundingBox);

#ifdef SPINE_SHORT_NAMES
typedef sp21SkeletonBounds SkeletonBounds;
#define SkeletonBounds_create(...) sp21SkeletonBounds_create(__VA_ARGS__)
#define SkeletonBounds_dispose(...) sp21SkeletonBounds_dispose(__VA_ARGS__)
#define SkeletonBounds_update(...) sp21SkeletonBounds_update(__VA_ARGS__)
#define SkeletonBounds_aabbContainsPoint(...) sp21SkeletonBounds_aabbContainsPoint(__VA_ARGS__)
#define SkeletonBounds_aabbIntersectsSegment(...) sp21SkeletonBounds_aabbIntersectsSegment(__VA_ARGS__)
#define SkeletonBounds_aabbIntersectsSkeleton(...) sp21SkeletonBounds_aabbIntersectsSkeleton(__VA_ARGS__)
#define SkeletonBounds_containsPoint(...) sp21SkeletonBounds_containsPoint(__VA_ARGS__)
#define SkeletonBounds_intersectsSegment(...) sp21SkeletonBounds_intersectsSegment(__VA_ARGS__)
#define SkeletonBounds_getPolygon(...) sp21SkeletonBounds_getPolygon(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONBOUNDS_H_ */

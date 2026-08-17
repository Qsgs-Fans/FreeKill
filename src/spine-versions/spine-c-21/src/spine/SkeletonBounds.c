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

#include <spine/SkeletonBounds.h>
#include <limits.h>
#include <spine/extension.h>

sp21Polygon* sp21Polygon_create (int capacity) {
	sp21Polygon* self = NEW(sp21Polygon);
	self->capacity = capacity;
	CONST_CAST(float*, self->vertices) = MALLOC(float, capacity);
	return self;
}

void sp21Polygon_dispose (sp21Polygon* self) {
	FREE(self->vertices);
	FREE(self);
}

int/*bool*/sp21Polygon_containsPoint (sp21Polygon* self, float x, float y) {
	int prevIndex = self->count - 2;
	int inside = 0;
	int i;
	for (i = 0; i < self->count; i += 2) {
		float vertexY = self->vertices[i + 1];
		float prevY = self->vertices[prevIndex + 1];
		if ((vertexY < y && prevY >= y) || (prevY < y && vertexY >= y)) {
			float vertexX = self->vertices[i];
			if (vertexX + (y - vertexY) / (prevY - vertexY) * (self->vertices[prevIndex] - vertexX) < x) inside = !inside;
		}
		prevIndex = i;
	}
	return inside;
}

int/*bool*/sp21Polygon_intersectsSegment (sp21Polygon* self, float x1, float y1, float x2, float y2) {
	float width12 = x1 - x2, height12 = y1 - y2;
	float det1 = x1 * y2 - y1 * x2;
	float x3 = self->vertices[self->count - 2], y3 = self->vertices[self->count - 1];
	int i;
	for (i = 0; i < self->count; i += 2) {
		float x4 = self->vertices[i], y4 = self->vertices[i + 1];
		float det2 = x3 * y4 - y3 * x4;
		float width34 = x3 - x4, height34 = y3 - y4;
		float det3 = width12 * height34 - height12 * width34;
		float x = (det1 * width34 - width12 * det2) / det3;
		if (((x >= x3 && x <= x4) || (x >= x4 && x <= x3)) && ((x >= x1 && x <= x2) || (x >= x2 && x <= x1))) {
			float y = (det1 * height34 - height12 * det2) / det3;
			if (((y >= y3 && y <= y4) || (y >= y4 && y <= y3)) && ((y >= y1 && y <= y2) || (y >= y2 && y <= y1))) return 1;
		}
		x3 = x4;
		y3 = y4;
	}
	return 0;
}

/**/

typedef struct {
	sp21SkeletonBounds super;
	int capacity;
} _sp21SkeletonBounds;

sp21SkeletonBounds* sp21SkeletonBounds_create () {
	return SUPER(NEW(_sp21SkeletonBounds));
}

void sp21SkeletonBounds_dispose (sp21SkeletonBounds* self) {
	int i;
	for (i = 0; i < SUB_CAST(_sp21SkeletonBounds, self)->capacity; ++i)
		if (self->polygons[i]) sp21Polygon_dispose(self->polygons[i]);
	FREE(self->polygons);
	FREE(self->boundingBoxes);
	FREE(self);
}

void sp21SkeletonBounds_update (sp21SkeletonBounds* self, sp21Skeleton* skeleton, int/*bool*/updateAabb) {
	int i;

	_sp21SkeletonBounds* internal = SUB_CAST(_sp21SkeletonBounds, self);
	if (internal->capacity < skeleton->slotsCount) {
		sp21Polygon** newPolygons;

		FREE(self->boundingBoxes);
		self->boundingBoxes = MALLOC(sp21BoundingBoxAttachment*, skeleton->slotsCount);

		newPolygons = CALLOC(sp21Polygon*, skeleton->slotsCount);
		memcpy(newPolygons, self->polygons, internal->capacity);
		FREE(self->polygons);
		self->polygons = newPolygons;

		internal->capacity = skeleton->slotsCount;
	}

	self->minX = (float)INT_MAX;
	self->minY = (float)INT_MAX;
	self->maxX = (float)INT_MIN;
	self->maxY = (float)INT_MIN;

	self->count = 0;
	for (i = 0; i < skeleton->slotsCount; ++i) {
		sp21Polygon* polygon;
		sp21BoundingBoxAttachment* boundingBox;

		sp21Slot* slot = skeleton->slots[i];
		sp21Attachment* attachment = slot->attachment;
		if (!attachment || attachment->type != SP_ATTACHMENT_BOUNDING_BOX) continue;
		boundingBox = (sp21BoundingBoxAttachment*)attachment;
		self->boundingBoxes[self->count] = boundingBox;

		polygon = self->polygons[self->count];
		if (!polygon || polygon->capacity < boundingBox->verticesCount) {
			if (polygon) sp21Polygon_dispose(polygon);
			self->polygons[self->count] = polygon = sp21Polygon_create(boundingBox->verticesCount);
		}
		polygon->count = boundingBox->verticesCount;
		sp21BoundingBoxAttachment_computeWorldVertices(boundingBox, slot->bone, polygon->vertices);

		if (updateAabb) {
			int ii = 0;
			for (; ii < polygon->count; ii += 2) {
				float x = polygon->vertices[ii];
				float y = polygon->vertices[ii + 1];
				if (x < self->minX) self->minX = x;
				if (y < self->minY) self->minY = y;
				if (x > self->maxX) self->maxX = x;
				if (y > self->maxY) self->maxY = y;
			}
		}

		self->count++;
	}
}

int/*bool*/sp21SkeletonBounds_aabbContainsPoint (sp21SkeletonBounds* self, float x, float y) {
	return x >= self->minX && x <= self->maxX && y >= self->minY && y <= self->maxY;
}

int/*bool*/sp21SkeletonBounds_aabbIntersectsSegment (sp21SkeletonBounds* self, float x1, float y1, float x2, float y2) {
	float m, x, y;
	if ((x1 <= self->minX && x2 <= self->minX) || (y1 <= self->minY && y2 <= self->minY) || (x1 >= self->maxX && x2 >= self->maxX)
			|| (y1 >= self->maxY && y2 >= self->maxY)) return 0;
	m = (y2 - y1) / (x2 - x1);
	y = m * (self->minX - x1) + y1;
	if (y > self->minY && y < self->maxY) return 1;
	y = m * (self->maxX - x1) + y1;
	if (y > self->minY && y < self->maxY) return 1;
	x = (self->minY - y1) / m + x1;
	if (x > self->minX && x < self->maxX) return 1;
	x = (self->maxY - y1) / m + x1;
	if (x > self->minX && x < self->maxX) return 1;
	return 0;
}

int/*bool*/sp21SkeletonBounds_aabbIntersectsSkeleton (sp21SkeletonBounds* self, sp21SkeletonBounds* bounds) {
	return self->minX < bounds->maxX && self->maxX > bounds->minX && self->minY < bounds->maxY && self->maxY > bounds->minY;
}

sp21BoundingBoxAttachment* sp21SkeletonBounds_containsPoint (sp21SkeletonBounds* self, float x, float y) {
	int i;
	for (i = 0; i < self->count; ++i)
		if (sp21Polygon_containsPoint(self->polygons[i], x, y)) return self->boundingBoxes[i];
	return 0;
}

sp21BoundingBoxAttachment* sp21SkeletonBounds_intersectsSegment (sp21SkeletonBounds* self, float x1, float y1, float x2, float y2) {
	int i;
	for (i = 0; i < self->count; ++i)
		if (sp21Polygon_intersectsSegment(self->polygons[i], x1, y1, x2, y2)) return self->boundingBoxes[i];
	return 0;
}

sp21Polygon* sp21SkeletonBounds_getPolygon (sp21SkeletonBounds* self, sp21BoundingBoxAttachment* boundingBox) {
	int i;
	for (i = 0; i < self->count; ++i)
		if (self->boundingBoxes[i] == boundingBox) return self->polygons[i];
	return 0;
}

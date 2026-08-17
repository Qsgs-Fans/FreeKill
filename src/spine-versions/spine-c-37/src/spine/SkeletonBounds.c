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

#include <spine/SkeletonBounds.h>
#include <limits.h>
#include <spine/extension.h>

sp37Polygon* sp37Polygon_create (int capacity) {
	sp37Polygon* self = NEW(sp37Polygon);
	self->capacity = capacity;
	CONST_CAST(float*, self->vertices) = MALLOC(float, capacity);
	return self;
}

void sp37Polygon_dispose (sp37Polygon* self) {
	FREE(self->vertices);
	FREE(self);
}

int/*bool*/sp37Polygon_containsPoint (sp37Polygon* self, float x, float y) {
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

int/*bool*/sp37Polygon_intersectsSegment (sp37Polygon* self, float x1, float y1, float x2, float y2) {
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
	sp37SkeletonBounds super;
	int capacity;
} _sp37SkeletonBounds;

sp37SkeletonBounds* sp37SkeletonBounds_create () {
	return SUPER(NEW(_sp37SkeletonBounds));
}

void sp37SkeletonBounds_dispose (sp37SkeletonBounds* self) {
	int i;
	for (i = 0; i < SUB_CAST(_sp37SkeletonBounds, self)->capacity; ++i)
		if (self->polygons[i]) sp37Polygon_dispose(self->polygons[i]);
	FREE(self->polygons);
	FREE(self->boundingBoxes);
	FREE(self);
}

void sp37SkeletonBounds_update (sp37SkeletonBounds* self, sp37Skeleton* skeleton, int/*bool*/updateAabb) {
	int i;

	_sp37SkeletonBounds* internal = SUB_CAST(_sp37SkeletonBounds, self);
	if (internal->capacity < skeleton->slotsCount) {
		sp37Polygon** newPolygons;

		FREE(self->boundingBoxes);
		self->boundingBoxes = MALLOC(sp37BoundingBoxAttachment*, skeleton->slotsCount);

		newPolygons = CALLOC(sp37Polygon*, skeleton->slotsCount);
		memcpy(newPolygons, self->polygons, sizeof(sp37Polygon*) * internal->capacity);
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
		sp37Polygon* polygon;
		sp37BoundingBoxAttachment* boundingBox;

		sp37Slot* slot = skeleton->slots[i];
		sp37Attachment* attachment = slot->attachment;
		if (!attachment || attachment->type != SP_ATTACHMENT_BOUNDING_BOX) continue;
		boundingBox = (sp37BoundingBoxAttachment*)attachment;
		self->boundingBoxes[self->count] = boundingBox;

		polygon = self->polygons[self->count];
		if (!polygon || polygon->capacity < boundingBox->super.worldVerticesLength) {
			if (polygon) sp37Polygon_dispose(polygon);
			self->polygons[self->count] = polygon = sp37Polygon_create(boundingBox->super.worldVerticesLength);
		}
		polygon->count = boundingBox->super.worldVerticesLength;
		sp37VertexAttachment_computeWorldVertices(SUPER(boundingBox), slot, 0, polygon->count, polygon->vertices, 0, 2);

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

int/*bool*/sp37SkeletonBounds_aabbContainsPoint (sp37SkeletonBounds* self, float x, float y) {
	return x >= self->minX && x <= self->maxX && y >= self->minY && y <= self->maxY;
}

int/*bool*/sp37SkeletonBounds_aabbIntersectsSegment (sp37SkeletonBounds* self, float x1, float y1, float x2, float y2) {
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

int/*bool*/sp37SkeletonBounds_aabbIntersectsSkeleton (sp37SkeletonBounds* self, sp37SkeletonBounds* bounds) {
	return self->minX < bounds->maxX && self->maxX > bounds->minX && self->minY < bounds->maxY && self->maxY > bounds->minY;
}

sp37BoundingBoxAttachment* sp37SkeletonBounds_containsPoint (sp37SkeletonBounds* self, float x, float y) {
	int i;
	for (i = 0; i < self->count; ++i)
		if (sp37Polygon_containsPoint(self->polygons[i], x, y)) return self->boundingBoxes[i];
	return 0;
}

sp37BoundingBoxAttachment* sp37SkeletonBounds_intersectsSegment (sp37SkeletonBounds* self, float x1, float y1, float x2, float y2) {
	int i;
	for (i = 0; i < self->count; ++i)
		if (sp37Polygon_intersectsSegment(self->polygons[i], x1, y1, x2, y2)) return self->boundingBoxes[i];
	return 0;
}

sp37Polygon* sp37SkeletonBounds_getPolygon (sp37SkeletonBounds* self, sp37BoundingBoxAttachment* boundingBox) {
	int i;
	for (i = 0; i < self->count; ++i)
		if (self->boundingBoxes[i] == boundingBox) return self->polygons[i];
	return 0;
}

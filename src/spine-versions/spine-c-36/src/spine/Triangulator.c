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

#include <spine/Triangulator.h>
#include <spine/extension.h>
#include <stdio.h>

sp36Triangulator* sp36Triangulator_create() {
	sp36Triangulator* triangulator = CALLOC(sp36Triangulator, 1);

	triangulator->convexPolygons = sp36ArrayFloatArray_create(16);
	triangulator->convexPolygonsIndices = sp36ArrayShortArray_create(16);
	triangulator->indicesArray = sp36ShortArray_create(128);
	triangulator->isConcaveArray = sp36IntArray_create(128);
	triangulator->triangles = sp36ShortArray_create(128);
	triangulator->polygonPool = sp36ArrayFloatArray_create(16);
	triangulator->polygonIndicesPool = sp36ArrayShortArray_create(128);

	return triangulator;
}

void sp36Triangulator_dispose(sp36Triangulator* self) {
	int i;

	for (i = 0; i < self->convexPolygons->size; i++) {
		sp36FloatArray_dispose(self->convexPolygons->items[i]);
	}
	sp36ArrayFloatArray_dispose(self->convexPolygons);

	for (i = 0; i < self->convexPolygonsIndices->size; i++) {
		sp36ShortArray_dispose(self->convexPolygonsIndices->items[i]);
	}
	sp36ArrayShortArray_dispose(self->convexPolygonsIndices);

	sp36ShortArray_dispose(self->indicesArray);
	sp36IntArray_dispose(self->isConcaveArray);
	sp36ShortArray_dispose(self->triangles);

	for (i = 0; i < self->polygonPool->size; i++) {
		sp36FloatArray_dispose(self->polygonPool->items[i]);
	}
	sp36ArrayFloatArray_dispose(self->polygonPool);

	for (i = 0; i < self->polygonIndicesPool->size; i++) {
		sp36ShortArray_dispose(self->polygonIndicesPool->items[i]);
	}
	sp36ArrayShortArray_dispose(self->polygonIndicesPool);

	FREE(self);
}

static sp36FloatArray* _obtainPolygon(sp36Triangulator* self) {
	if (self->polygonPool->size == 0) return sp36FloatArray_create(16);
	else return sp36ArrayFloatArray_pop(self->polygonPool);
}

static void _freePolygon(sp36Triangulator* self, sp36FloatArray* polygon) {
	sp36ArrayFloatArray_add(self->polygonPool, polygon);
}

static void _freeAllPolygons(sp36Triangulator* self, sp36ArrayFloatArray* polygons) {
	int i;
	for (i = 0; i < polygons->size; i++) {
		_freePolygon(self, polygons->items[i]);
	}
}

static sp36ShortArray* _obtainPolygonIndices(sp36Triangulator* self) {
	if (self->polygonIndicesPool->size == 0) return sp36ShortArray_create(16);
	else return sp36ArrayShortArray_pop(self->polygonIndicesPool);
}

static void _freePolygonIndices(sp36Triangulator* self, sp36ShortArray* indices) {
	sp36ArrayShortArray_add(self->polygonIndicesPool, indices);
}

static void _freeAllPolygonIndices(sp36Triangulator* self, sp36ArrayShortArray* polygonIndices) {
	int i;
	for (i = 0; i < polygonIndices->size; i++) {
		_freePolygonIndices(self, polygonIndices->items[i]);
	}
}

static int _positiveArea(float p1x, float p1y, float p2x, float p2y, float p3x, float p3y) {
	return p1x * (p3y - p2y) + p2x * (p1y - p3y) + p3x * (p2y - p1y) >= 0;
}

static int _isConcave(int index, int vertexCount, float* vertices, short* indices) {
	int previous = indices[(vertexCount + index - 1) % vertexCount] << 1;
	int current = indices[index] << 1;
	int next = indices[(index + 1) % vertexCount] << 1;
	return !_positiveArea(vertices[previous], vertices[previous + 1], vertices[current], vertices[current + 1],
						 vertices[next],
						 vertices[next + 1]);
}

static int _winding (float p1x, float p1y, float p2x, float p2y, float p3x, float p3y) {
	float px = p2x - p1x, py = p2y - p1y;
	return p3x * py - p3y * px + px * p1y - p1x * py >= 0 ? 1 : -1;
}

sp36ShortArray* sp36Triangulator_triangulate(sp36Triangulator* self, sp36FloatArray* verticesArray) {
	float* vertices = verticesArray->items;
	int vertexCount = verticesArray->size >> 1;
	int i, n, ii;

	sp36ShortArray* indicesArray = self->indicesArray;
	short* indices;
	sp36IntArray* isConcaveArray;
	int* isConcave;
	sp36ShortArray* triangles;

	sp36ShortArray_clear(indicesArray);
	indices = sp36ShortArray_setSize(indicesArray, vertexCount)->items;
	for (i = 0; i < vertexCount; i++)
		indices[i] = (short)i;

	isConcaveArray = self->isConcaveArray;
	isConcave = sp36IntArray_setSize(isConcaveArray, vertexCount)->items;
	for (i = 0, n = vertexCount; i < n; ++i)
		isConcave[i] = _isConcave(i, vertexCount, vertices, indices);

	triangles = self->triangles;
	sp36ShortArray_clear(triangles);
	sp36ShortArray_ensureCapacity(triangles, MAX(0, vertexCount - 2) << 2);

	while (vertexCount > 3) {
		int previous = vertexCount - 1, i = 0, next = 1;
		int previousIndex, nextIndex;
		while (1) {
			if (!isConcave[i]) {
				int p1 = indices[previous] << 1, p2 = indices[i] << 1, p3 = indices[next] << 1;
				float p1x = vertices[p1], p1y = vertices[p1 + 1];
				float p2x = vertices[p2], p2y = vertices[p2 + 1];
				float p3x = vertices[p3], p3y = vertices[p3 + 1];
				for (ii = (next + 1) % vertexCount; ii != previous; ii = (ii + 1) % vertexCount) {
					int v;
					float vx, vy;
					if (!isConcave[ii]) continue;
					v = indices[ii] << 1;
					vx = vertices[v]; vy = vertices[v + 1];
					if (_positiveArea(p3x, p3y, p1x, p1y, vx, vy)) {
						if (_positiveArea(p1x, p1y, p2x, p2y, vx, vy)) {
							if (_positiveArea(p2x, p2y, p3x, p3y, vx, vy)) goto break_outer;
						}
					}
				}
				break;
			}
			break_outer:

			if (next == 0) {
				do {
					if (!isConcave[i]) break;
					i--;
				} while (i > 0);
				break;
			}

			previous = i;
			i = next;
			next = (next + 1) % vertexCount;
		}

		sp36ShortArray_add(triangles, indices[(vertexCount + i - 1) % vertexCount]);
		sp36ShortArray_add(triangles, indices[i]);
		sp36ShortArray_add(triangles, indices[(i + 1) % vertexCount]);
		sp36ShortArray_removeAt(indicesArray, i);
		sp36IntArray_removeAt(isConcaveArray, i);
		vertexCount--;

		previousIndex = (vertexCount + i - 1) % vertexCount;
		nextIndex = i == vertexCount ? 0 : i;
		isConcave[previousIndex] = _isConcave(previousIndex, vertexCount, vertices, indices);
		isConcave[nextIndex] = _isConcave(nextIndex, vertexCount, vertices, indices);
	}

	if (vertexCount == 3) {
		sp36ShortArray_add(triangles, indices[2]);
		sp36ShortArray_add(triangles, indices[0]);
		sp36ShortArray_add(triangles, indices[1]);
	}

	return triangles;
}

sp36ArrayFloatArray* sp36Triangulator_decompose(sp36Triangulator* self, sp36FloatArray* verticesArray, sp36ShortArray* triangles) {
	float* vertices = verticesArray->items;

	sp36ArrayFloatArray* convexPolygons = self->convexPolygons;
	sp36ArrayShortArray* convexPolygonsIndices;
	sp36ShortArray* polygonIndices;
	sp36FloatArray* polygon;

	int fanBaseIndex, lastWinding;
	short* trianglesItems;
	int i, n;

	_freeAllPolygons(self, convexPolygons);
	sp36ArrayFloatArray_clear(convexPolygons);

	convexPolygonsIndices = self->convexPolygonsIndices;
	_freeAllPolygonIndices(self, convexPolygonsIndices);
	sp36ArrayShortArray_clear(convexPolygonsIndices);

	polygonIndices = _obtainPolygonIndices(self);
	sp36ShortArray_clear(polygonIndices);

	polygon = _obtainPolygon(self);
	sp36FloatArray_clear(polygon);

	fanBaseIndex = -1; lastWinding = 0;
	trianglesItems = triangles->items;
	for (i = 0, n = triangles->size; i < n; i += 3) {
		int t1 = trianglesItems[i] << 1, t2 = trianglesItems[i + 1] << 1, t3 = trianglesItems[i + 2] << 1;
		float x1 = vertices[t1], y1 = vertices[t1 + 1];
		float x2 = vertices[t2], y2 = vertices[t2 + 1];
		float x3 = vertices[t3], y3 = vertices[t3 + 1];

		int merged = 0;
		if (fanBaseIndex == t1) {
			int o = polygon->size - 4;
			float* p = polygon->items;
			int winding1 = _winding(p[o], p[o + 1], p[o + 2], p[o + 3], x3, y3);
			int winding2 = _winding(x3, y3, p[0], p[1], p[2], p[3]);
			if (winding1 == lastWinding && winding2 == lastWinding) {
				sp36FloatArray_add(polygon, x3);
				sp36FloatArray_add(polygon, y3);
				sp36ShortArray_add(polygonIndices, t3);
				merged = 1;
			}
		}

		if (!merged) {
			if (polygon->size > 0) {
				sp36ArrayFloatArray_add(convexPolygons, polygon);
				sp36ArrayShortArray_add(convexPolygonsIndices, polygonIndices);
			} else {
				_freePolygon(self, polygon);
				_freePolygonIndices(self, polygonIndices);
			}
			polygon = _obtainPolygon(self);
			sp36FloatArray_clear(polygon);
			sp36FloatArray_add(polygon, x1);
			sp36FloatArray_add(polygon, y1);
			sp36FloatArray_add(polygon, x2);
			sp36FloatArray_add(polygon, y2);
			sp36FloatArray_add(polygon, x3);
			sp36FloatArray_add(polygon, y3);
			polygonIndices = _obtainPolygonIndices(self);
			sp36ShortArray_clear(polygonIndices);
			sp36ShortArray_add(polygonIndices, t1);
			sp36ShortArray_add(polygonIndices, t2);
			sp36ShortArray_add(polygonIndices, t3);
			lastWinding = _winding(x1, y1, x2, y2, x3, y3);
			fanBaseIndex = t1;
		}
	}

	if (polygon->size > 0) {
		sp36ArrayFloatArray_add(convexPolygons, polygon);
		sp36ArrayShortArray_add(convexPolygonsIndices, polygonIndices);
	}

	for (i = 0, n = convexPolygons->size; i < n; i++) {
		int firstIndex, lastIndex;
		int o;
		float* p;
		float prevPrevX, prevPrevY, prevX, prevY, firstX, firstY, secondX, secondY;
		int winding;
		int ii;

		polygonIndices = convexPolygonsIndices->items[i];
		if (polygonIndices->size == 0) continue;
		firstIndex = polygonIndices->items[0];
		lastIndex = polygonIndices->items[polygonIndices->size - 1];

		polygon = convexPolygons->items[i];
		o = polygon->size - 4;
		p = polygon->items;
		prevPrevX = p[o]; prevPrevY = p[o + 1];
		prevX = p[o + 2]; prevY = p[o + 3];
		firstX = p[0]; firstY = p[1];
		secondX = p[2]; secondY = p[3];
		winding = _winding(prevPrevX, prevPrevY, prevX, prevY, firstX, firstY);

		for (ii = 0; ii < n; ii++) {
			sp36ShortArray* otherIndices;
			int otherFirstIndex, otherSecondIndex, otherLastIndex;
			sp36FloatArray* otherPoly;
			float x3, y3;
			int winding1, winding2;

			if (ii == i) continue;
			otherIndices = convexPolygonsIndices->items[ii];
			if (otherIndices->size != 3) continue;
			otherFirstIndex = otherIndices->items[0];
			otherSecondIndex = otherIndices->items[1];
			otherLastIndex = otherIndices->items[2];

			otherPoly = convexPolygons->items[ii];
			x3 = otherPoly->items[otherPoly->size - 2]; y3 = otherPoly->items[otherPoly->size - 1];

			if (otherFirstIndex != firstIndex || otherSecondIndex != lastIndex) continue;
			winding1 = _winding(prevPrevX, prevPrevY, prevX, prevY, x3, y3);
			winding2 = _winding(x3, y3, firstX, firstY, secondX, secondY);
			if (winding1 == winding && winding2 == winding) {
				sp36FloatArray_clear(otherPoly);
				sp36ShortArray_clear(otherIndices);
				sp36FloatArray_add(polygon, x3);
				sp36FloatArray_add(polygon, y3);
				sp36ShortArray_add(polygonIndices, otherLastIndex);
				prevPrevX = prevX;
				prevPrevY = prevY;
				prevX = x3;
				prevY = y3;
				ii = 0;
			}
		}
	}

	for (i = convexPolygons->size - 1; i >= 0; i--) {
		polygon = convexPolygons->items[i];
		if (polygon->size == 0) {
			sp36ArrayFloatArray_removeAt(convexPolygons, i);
			_freePolygon(self, polygon);
			polygonIndices = convexPolygonsIndices->items[i];
			sp36ArrayShortArray_removeAt(convexPolygonsIndices, i);
			_freePolygonIndices(self, polygonIndices);
		}
	}

	return convexPolygons;
}

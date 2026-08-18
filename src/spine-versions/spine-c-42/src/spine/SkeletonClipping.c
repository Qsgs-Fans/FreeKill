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

#include <spine/SkeletonClipping.h>
#include <spine/extension.h>

sp42SkeletonClipping *sp42SkeletonClipping_create(void) {
	sp42SkeletonClipping *clipping = CALLOC(sp42SkeletonClipping, 1);

	clipping->triangulator = sp42Triangulator_create();
	clipping->clippingPolygon = sp42FloatArray_create(128);
	clipping->clipOutput = sp42FloatArray_create(128);
	clipping->clippedVertices = sp42FloatArray_create(128);
	clipping->clippedUVs = sp42FloatArray_create(128);
	clipping->clippedTriangles = sp42UnsignedShortArray_create(128);
	clipping->scratch = sp42FloatArray_create(128);

	return clipping;
}

void sp42SkeletonClipping_dispose(sp42SkeletonClipping *self) {
	sp42Triangulator_dispose(self->triangulator);
	sp42FloatArray_dispose(self->clippingPolygon);
	sp42FloatArray_dispose(self->clipOutput);
	sp42FloatArray_dispose(self->clippedVertices);
	sp42FloatArray_dispose(self->clippedUVs);
	sp42UnsignedShortArray_dispose(self->clippedTriangles);
	sp42FloatArray_dispose(self->scratch);
	FREE(self);
}

static void _makeClockwise(sp42FloatArray *polygon) {
	int i, n, lastX;
	float *vertices = polygon->items;
	int verticeslength = polygon->size;

	float area =
				  vertices[verticeslength - 2] * vertices[1] - vertices[0] * vertices[verticeslength - 1],
		  p1x, p1y, p2x, p2y;
	for (i = 0, n = verticeslength - 3; i < n; i += 2) {
		p1x = vertices[i];
		p1y = vertices[i + 1];
		p2x = vertices[i + 2];
		p2y = vertices[i + 3];
		area += p1x * p2y - p2x * p1y;
	}
	if (area < 0) return;

	for (i = 0, lastX = verticeslength - 2, n = verticeslength >> 1; i < n; i += 2) {
		float x = vertices[i], y = vertices[i + 1];
		int other = lastX - i;
		vertices[i] = vertices[other];
		vertices[i + 1] = vertices[other + 1];
		vertices[other] = x;
		vertices[other + 1] = y;
	}
}

int sp42SkeletonClipping_clipStart(sp42SkeletonClipping *self, sp42Slot *slot, sp42ClippingAttachment *clip) {
	int i, n;
	float *vertices;
	if (self->clipAttachment) return 0;
	self->clipAttachment = clip;

	n = clip->super.worldVerticesLength;
	vertices = sp42FloatArray_setSize(self->clippingPolygon, n)->items;
	sp42VertexAttachment_computeWorldVertices(SUPER(clip), slot, 0, n, vertices, 0, 2);
	_makeClockwise(self->clippingPolygon);
	self->clippingPolygons = sp42Triangulator_decompose(self->triangulator, self->clippingPolygon,
													  sp42Triangulator_triangulate(self->triangulator,
																				 self->clippingPolygon));
	for (i = 0, n = self->clippingPolygons->size; i < n; i++) {
		sp42FloatArray *polygon = self->clippingPolygons->items[i];
		_makeClockwise(polygon);
		sp42FloatArray_add(polygon, polygon->items[0]);
		sp42FloatArray_add(polygon, polygon->items[1]);
	}
	return self->clippingPolygons->size;
}

void sp42SkeletonClipping_clipEnd(sp42SkeletonClipping *self, sp42Slot *slot) {
	if (self->clipAttachment != 0 && self->clipAttachment->endSlot == slot->data) sp42SkeletonClipping_clipEnd2(self);
}

void sp42SkeletonClipping_clipEnd2(sp42SkeletonClipping *self) {
	if (!self->clipAttachment) return;
	self->clipAttachment = 0;
	self->clippingPolygons = 0;
	sp42FloatArray_clear(self->clippedVertices);
	sp42FloatArray_clear(self->clippedUVs);
	sp42UnsignedShortArray_clear(self->clippedTriangles);
	sp42FloatArray_clear(self->clippingPolygon);
}

int /*boolean*/ sp42SkeletonClipping_isClipping(sp42SkeletonClipping *self) {
	return self->clipAttachment != 0;
}

static int /*boolean*/
_clip(sp42SkeletonClipping *self, float x1, float y1, float x2, float y2, float x3, float y3, sp42FloatArray *clippingArea,
	  sp42FloatArray *output) {
	sp42FloatArray *originalOutput = output;
	int clipped = 0;
	float *clippingVertices;
	int clippingVerticesLast;

	sp42FloatArray *input = 0;
	if (clippingArea->size % 4 >= 2) {
		input = output;
		output = self->scratch;
	} else
		input = self->scratch;

	sp42FloatArray_clear(input);
	sp42FloatArray_add(input, x1);
	sp42FloatArray_add(input, y1);
	sp42FloatArray_add(input, x2);
	sp42FloatArray_add(input, y2);
	sp42FloatArray_add(input, x3);
	sp42FloatArray_add(input, y3);
	sp42FloatArray_add(input, x1);
	sp42FloatArray_add(input, y1);
	sp42FloatArray_clear(output);

	clippingVerticesLast = clippingArea->size - 4;
	clippingVertices = clippingArea->items;
	for (int i = 0;; i += 2) {
		sp42FloatArray *temp;
		float edgeX = clippingVertices[i], edgeY = clippingVertices[i + 1];
		float ex = edgeX - clippingVertices[i + 2], ey = edgeY - clippingVertices[i + 3];

		int outputStart = output->size;
		float *inputVertices = input->items;
		for (int ii = 0, nn = input->size - 2; ii < nn;) {
			float inputX = inputVertices[ii], inputY = inputVertices[ii + 1];
			ii += 2;
			float inputX2 = inputVertices[ii], inputY2 = inputVertices[ii + 1];
			float s2 = ey * (edgeX - inputX2) > ex * (edgeY - inputY2);
			float s1 = ey * (edgeX - inputX) - ex * (edgeY - inputY);
			if (s1 > 0) {
				if (s2) {// v1 inside, v2 inside
					sp42FloatArray_add(output, inputX2);
					sp42FloatArray_add(output, inputY2);
					continue;
				}
				// v1 inside, v2 outside
				float ix = inputX2 - inputX, iy = inputY2 - inputY, t = s1 / (ix * ey - iy * ex);
				if (t >= 0 && t <= 1) {
					sp42FloatArray_add(output, inputX + ix * t);
					sp42FloatArray_add(output, inputY + iy * t);
				} else {
					sp42FloatArray_add(output, inputX2);
					sp42FloatArray_add(output, inputY2);
				}
			} else if (s2) {// v1 outside, v2 inside
				float ix = inputX2 - inputX, iy = inputY2 - inputY, t = s1 / (ix * ey - iy * ex);
				if (t >= 0 && t <= 1) {
					sp42FloatArray_add(output, inputX + ix * t);
					sp42FloatArray_add(output, inputY + iy * t);
					sp42FloatArray_add(output, inputX2);
					sp42FloatArray_add(output, inputY2);
				} else {
					sp42FloatArray_add(output, inputX2);
					sp42FloatArray_add(output, inputY2);
					continue;
				}
			}
			clipped = -1;
		}

		if (outputStart == output->size) {
			sp42FloatArray_clear(originalOutput);
			return 1;
		}

		sp42FloatArray_add(output, output->items[0]);
		sp42FloatArray_add(output, output->items[1]);

		if (i == clippingVerticesLast) break;
		temp = output;
		output = input;
		sp42FloatArray_clear(output);
		input = temp;
	}

	if (originalOutput != output) {
		sp42FloatArray_clear(originalOutput);
		sp42FloatArray_addAllValues(originalOutput, output->items, 0, output->size - 2);
	} else
		sp42FloatArray_setSize(originalOutput, originalOutput->size - 2);

	return clipped;
}

void sp42SkeletonClipping_clipTriangles(sp42SkeletonClipping *self, float *vertices, int verticesLength,
									  unsigned short *triangles, int trianglesLength, float *uvs, int stride) {
	int i;
	sp42FloatArray *clipOutput = self->clipOutput;
	sp42FloatArray *clippedVertices = self->clippedVertices;
	sp42FloatArray *clippedUVs = self->clippedUVs;
	sp42UnsignedShortArray *clippedTriangles = self->clippedTriangles;
	sp42FloatArray **polygons = self->clippingPolygons->items;
	int polygonsCount = self->clippingPolygons->size;

	short index = 0;
	sp42FloatArray_clear(clippedVertices);
	sp42FloatArray_clear(clippedUVs);
	sp42UnsignedShortArray_clear(clippedTriangles);
	i = 0;
continue_outer:
	for (; i < trianglesLength; i += 3) {
		int p;
		int vertexOffset = triangles[i] * stride;
		float x2, y2, u2, v2, x3, y3, u3, v3;
		float x1 = vertices[vertexOffset], y1 = vertices[vertexOffset + 1];
		float u1 = uvs[vertexOffset], v1 = uvs[vertexOffset + 1];

		vertexOffset = triangles[i + 1] * stride;
		x2 = vertices[vertexOffset];
		y2 = vertices[vertexOffset + 1];
		u2 = uvs[vertexOffset];
		v2 = uvs[vertexOffset + 1];

		vertexOffset = triangles[i + 2] * stride;
		x3 = vertices[vertexOffset];
		y3 = vertices[vertexOffset + 1];
		u3 = uvs[vertexOffset];
		v3 = uvs[vertexOffset + 1];

		for (p = 0; p < polygonsCount; p++) {
			int s = clippedVertices->size;
			if (_clip(self, x1, y1, x2, y2, x3, y3, polygons[p], clipOutput)) {
				int ii;
				float d0, d1, d2, d4, d;
				unsigned short *clippedTrianglesItems;
				int clipOutputCount;
				float *clipOutputItems;
				float *clippedVerticesItems;
				float *clippedUVsItems;

				int clipOutputLength = clipOutput->size;
				if (clipOutputLength == 0) continue;
				d0 = y2 - y3;
				d1 = x3 - x2;
				d2 = x1 - x3;
				d4 = y3 - y1;
				d = 1 / (d0 * d2 + d1 * (y1 - y3));

				clipOutputCount = clipOutputLength >> 1;
				clipOutputItems = clipOutput->items;
				clippedVerticesItems = sp42FloatArray_setSize(clippedVertices, s + (clipOutputCount << 1))->items;
				clippedUVsItems = sp42FloatArray_setSize(clippedUVs, s + (clipOutputCount << 1))->items;
				for (ii = 0; ii < clipOutputLength; ii += 2) {
					float c0, c1, a, b, c;
					float x = clipOutputItems[ii], y = clipOutputItems[ii + 1];
					clippedVerticesItems[s] = x;
					clippedVerticesItems[s + 1] = y;
					c0 = x - x3;
					c1 = y - y3;
					a = (d0 * c0 + d1 * c1) * d;
					b = (d4 * c0 + d2 * c1) * d;
					c = 1 - a - b;
					clippedUVsItems[s] = u1 * a + u2 * b + u3 * c;
					clippedUVsItems[s + 1] = v1 * a + v2 * b + v3 * c;
					s += 2;
				}

				s = clippedTriangles->size;
				clippedTrianglesItems = sp42UnsignedShortArray_setSize(clippedTriangles,
																	 s + 3 * (clipOutputCount - 2))
												->items;
				clipOutputCount--;
				for (ii = 1; ii < clipOutputCount; ii++) {
					clippedTrianglesItems[s] = index;
					clippedTrianglesItems[s + 1] = (unsigned short) (index + ii);
					clippedTrianglesItems[s + 2] = (unsigned short) (index + ii + 1);
					s += 3;
				}
				index += clipOutputCount + 1;

			} else {
				unsigned short *clippedTrianglesItems;
				float *clippedVerticesItems = sp42FloatArray_setSize(clippedVertices, s + (3 << 1))->items;
				float *clippedUVsItems = sp42FloatArray_setSize(clippedUVs, s + (3 << 1))->items;
				clippedVerticesItems[s] = x1;
				clippedVerticesItems[s + 1] = y1;
				clippedVerticesItems[s + 2] = x2;
				clippedVerticesItems[s + 3] = y2;
				clippedVerticesItems[s + 4] = x3;
				clippedVerticesItems[s + 5] = y3;

				clippedUVsItems[s] = u1;
				clippedUVsItems[s + 1] = v1;
				clippedUVsItems[s + 2] = u2;
				clippedUVsItems[s + 3] = v2;
				clippedUVsItems[s + 4] = u3;
				clippedUVsItems[s + 5] = v3;

				s = clippedTriangles->size;
				clippedTrianglesItems = sp42UnsignedShortArray_setSize(clippedTriangles, s + 3)->items;
				clippedTrianglesItems[s] = index;
				clippedTrianglesItems[s + 1] = (unsigned short) (index + 1);
				clippedTrianglesItems[s + 2] = (unsigned short) (index + 2);
				index += 3;
				i += 3;
				goto continue_outer;
			}
		}
	}
	UNUSED(verticesLength);
}

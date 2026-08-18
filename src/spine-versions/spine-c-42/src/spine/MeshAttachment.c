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

#include <spine/MeshAttachment.h>
#include <spine/extension.h>
#include <stdio.h>

void _sp42MeshAttachment_dispose(sp42Attachment *attachment) {
	sp42MeshAttachment *self = SUB_CAST(sp42MeshAttachment, attachment);
	if (self->sequence) sp42Sequence_dispose(self->sequence);
	FREE(self->path);
	FREE(self->uvs);
	if (!self->parentMesh) {
		_sp42VertexAttachment_deinit(SUPER(self));
		FREE(self->regionUVs);
		FREE(self->triangles);
		FREE(self->edges);
	} else
		_sp42Attachment_deinit(attachment);
	FREE(self);
}

sp42Attachment *_sp42MeshAttachment_copy(sp42Attachment *attachment) {
	sp42MeshAttachment *copy;
	sp42MeshAttachment *self = SUB_CAST(sp42MeshAttachment, attachment);
	if (self->parentMesh)
		return SUPER(SUPER(sp42MeshAttachment_newLinkedMesh(self)));
	copy = sp42MeshAttachment_create(attachment->name);
	copy->rendererObject = self->rendererObject;
	copy->region = self->region;
	copy->sequence = self->sequence != NULL ? sp42Sequence_copy(self->sequence) : NULL;
	MALLOC_STR(copy->path, self->path);
	sp42Color_setFromColor(&copy->color, &self->color);

	sp42VertexAttachment_copyTo(SUPER(self), SUPER(copy));
	copy->regionUVs = MALLOC(float, SUPER(self)->worldVerticesLength);
	memcpy(copy->regionUVs, self->regionUVs, SUPER(self)->worldVerticesLength * sizeof(float));
	copy->uvs = MALLOC(float, SUPER(self)->worldVerticesLength);
	memcpy(copy->uvs, self->uvs, SUPER(self)->worldVerticesLength * sizeof(float));
	copy->trianglesCount = self->trianglesCount;
	copy->triangles = MALLOC(unsigned short, self->trianglesCount);
	memcpy(copy->triangles, self->triangles, self->trianglesCount * sizeof(short));
	copy->hullLength = self->hullLength;
	if (self->edgesCount > 0) {
		copy->edgesCount = self->edgesCount;
		copy->edges = MALLOC(unsigned short, self->edgesCount);
		memcpy(copy->edges, self->edges, self->edgesCount * sizeof(int));
	}
	copy->width = self->width;
	copy->height = self->height;

	return SUPER(SUPER(copy));
}

sp42MeshAttachment *sp42MeshAttachment_newLinkedMesh(sp42MeshAttachment *self) {
	sp42MeshAttachment *copy = sp42MeshAttachment_create(self->super.super.name);

	copy->rendererObject = self->rendererObject;
	copy->region = self->region;
	MALLOC_STR(copy->path, self->path);
	sp42Color_setFromColor(&copy->color, &self->color);
	copy->super.timelineAttachment = self->super.timelineAttachment;
	sp42MeshAttachment_setParentMesh(copy, self->parentMesh ? self->parentMesh : self);
	if (copy->region) sp42MeshAttachment_updateRegion(copy);
	return copy;
}

sp42MeshAttachment *sp42MeshAttachment_create(const char *name) {
	sp42MeshAttachment *self = NEW(sp42MeshAttachment);
	_sp42VertexAttachment_init(SUPER(self));
	sp42Color_setFromFloats(&self->color, 1, 1, 1, 1);
	_sp42Attachment_init(SUPER(SUPER(self)), name, SP_ATTACHMENT_MESH, _sp42MeshAttachment_dispose, _sp42MeshAttachment_copy);
	return self;
}

void sp42MeshAttachment_updateRegion(sp42MeshAttachment *self) {
	int i, n;
	float *uvs;
	float u, v, width, height;
	int verticesLength = SUPER(self)->worldVerticesLength;
	FREE(self->uvs);
	uvs = self->uvs = MALLOC(float, verticesLength);
	n = verticesLength;
	u = self->region->u;
	v = self->region->v;

	switch (self->region->degrees) {
		case 90: {
			float textureWidth = self->region->height / (self->region->u2 - self->region->u);
			float textureHeight = self->region->width / (self->region->v2 - self->region->v);
			u -= (self->region->originalHeight - self->region->offsetY - self->region->height) / textureWidth;
			v -= (self->region->originalWidth - self->region->offsetX - self->region->width) / textureHeight;
			width = self->region->originalHeight / textureWidth;
			height = self->region->originalWidth / textureHeight;
			for (i = 0; i < n; i += 2) {
				uvs[i] = u + self->regionUVs[i + 1] * width;
				uvs[i + 1] = v + (1 - self->regionUVs[i]) * height;
			}
			return;
		}
		case 180: {
			float textureWidth = self->region->width / (self->region->u2 - self->region->u);
			float textureHeight = self->region->height / (self->region->v2 - self->region->v);
			u -= (self->region->originalWidth - self->region->offsetX - self->region->width) / textureWidth;
			v -= self->region->offsetY / textureHeight;
			width = self->region->originalWidth / textureWidth;
			height = self->region->originalHeight / textureHeight;
			for (i = 0; i < n; i += 2) {
				uvs[i] = u + (1 - self->regionUVs[i]) * width;
				uvs[i + 1] = v + (1 - self->regionUVs[i + 1]) * height;
			}
			return;
		}
		case 270: {
			float textureHeight = self->region->height / (self->region->v2 - self->region->v);
			float textureWidth = self->region->width / (self->region->u2 - self->region->u);
			u -= self->region->offsetY / textureWidth;
			v -= self->region->offsetX / textureHeight;
			width = self->region->originalHeight / textureWidth;
			height = self->region->originalWidth / textureHeight;
			for (i = 0; i < n; i += 2) {
				uvs[i] = u + (1 - self->regionUVs[i + 1]) * width;
				uvs[i + 1] = v + self->regionUVs[i] * height;
			}
			return;
		}
		default: {
			float textureWidth = self->region->width / (self->region->u2 - self->region->u);
			float textureHeight = self->region->height / (self->region->v2 - self->region->v);
			u -= self->region->offsetX / textureWidth;
			v -= (self->region->originalHeight - self->region->offsetY - self->region->height) / textureHeight;
			width = self->region->originalWidth / textureWidth;
			height = self->region->originalHeight / textureHeight;
			for (i = 0; i < n; i += 2) {
				uvs[i] = u + self->regionUVs[i] * width;
				uvs[i + 1] = v + self->regionUVs[i + 1] * height;
			}
		}
	}
}

void sp42MeshAttachment_setParentMesh(sp42MeshAttachment *self, sp42MeshAttachment *parentMesh) {
	self->parentMesh = parentMesh;
	if (parentMesh) {
		self->super.bones = parentMesh->super.bones;
		self->super.bonesCount = parentMesh->super.bonesCount;

		self->super.vertices = parentMesh->super.vertices;
		self->super.verticesCount = parentMesh->super.verticesCount;

		self->regionUVs = parentMesh->regionUVs;

		self->triangles = parentMesh->triangles;
		self->trianglesCount = parentMesh->trianglesCount;

		self->hullLength = parentMesh->hullLength;

		self->super.worldVerticesLength = parentMesh->super.worldVerticesLength;

		self->edges = parentMesh->edges;
		self->edgesCount = parentMesh->edgesCount;

		self->width = parentMesh->width;
		self->height = parentMesh->height;
	}
}

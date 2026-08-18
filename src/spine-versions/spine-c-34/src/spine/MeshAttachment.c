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

#include <spine/MeshAttachment.h>
#include <spine/extension.h>

void _sp34MeshAttachment_dispose (sp34Attachment* attachment) {
	sp34MeshAttachment* self = SUB_CAST(sp34MeshAttachment, attachment);
	FREE(self->path);
	FREE(self->uvs);
	if (!self->parentMesh) {
		_sp34VertexAttachment_deinit(SUPER(self));
		FREE(self->regionUVs);
		FREE(self->triangles);
		FREE(self->edges);
	} else
		_sp34Attachment_deinit(attachment);
	FREE(self);
}

sp34MeshAttachment* sp34MeshAttachment_create (const char* name) {
	sp34MeshAttachment* self = NEW(sp34MeshAttachment);
	self->r = 1;
	self->g = 1;
	self->b = 1;
	self->a = 1;
	_sp34Attachment_init(SUPER(SUPER(self)), name, SP_ATTACHMENT_MESH, _sp34MeshAttachment_dispose);
	return self;
}

void sp34MeshAttachment_updateUVs (sp34MeshAttachment* self) {
	int i;
	float width = self->regionU2 - self->regionU, height = self->regionV2 - self->regionV;
	int verticesLength = SUPER(self)->worldVerticesLength;
	FREE(self->uvs);
	self->uvs = MALLOC(float, verticesLength);
	if (self->regionRotate) {
		for (i = 0; i < verticesLength; i += 2) {
			self->uvs[i] = self->regionU + self->regionUVs[i + 1] * width;
			self->uvs[i + 1] = self->regionV + height - self->regionUVs[i] * height;
		}
	} else {
		for (i = 0; i < verticesLength; i += 2) {
			self->uvs[i] = self->regionU + self->regionUVs[i] * width;
			self->uvs[i + 1] = self->regionV + self->regionUVs[i + 1] * height;
		}
	}
}

void sp34MeshAttachment_computeWorldVertices (sp34MeshAttachment* self, sp34Slot* slot, float* worldVertices) {
	sp34VertexAttachment_computeWorldVertices(SUPER(self), slot, worldVertices);
}

void sp34MeshAttachment_setParentMesh (sp34MeshAttachment* self, sp34MeshAttachment* parentMesh) {
	CONST_CAST(sp34MeshAttachment*, self->parentMesh) = parentMesh;
	if (parentMesh) {
		self->super.worldVerticesLength = parentMesh->super.worldVerticesLength;

		self->super.bones = parentMesh->super.bones;
		self->super.bonesCount = parentMesh->super.bonesCount;

		self->super.vertices = parentMesh->super.vertices;
		self->super.verticesCount = parentMesh->super.verticesCount;

		self->regionUVs = parentMesh->regionUVs;

		self->triangles = parentMesh->triangles;
		self->trianglesCount = parentMesh->trianglesCount;

		self->hullLength = parentMesh->hullLength;

		self->edges = parentMesh->edges;
		self->edgesCount = parentMesh->edgesCount;

		self->width = parentMesh->width;
		self->height = parentMesh->height;
	}
}

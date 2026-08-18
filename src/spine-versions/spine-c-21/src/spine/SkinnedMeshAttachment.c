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

#include <spine/SkinnedMeshAttachment.h>
#include <spine/extension.h>

void _sp21SkinnedMeshAttachment_dispose (sp21Attachment* attachment) {
	sp21SkinnedMeshAttachment* self = SUB_CAST(sp21SkinnedMeshAttachment, attachment);
	_sp21Attachment_deinit(attachment);
	FREE(self->path);
	FREE(self->bones);
	FREE(self->weights);
	FREE(self->regionUVs);
	FREE(self->uvs);
	FREE(self->triangles);
	FREE(self->edges);
	FREE(self);
}

sp21SkinnedMeshAttachment* sp21SkinnedMeshAttachment_create (const char* name) {
	sp21SkinnedMeshAttachment* self = NEW(sp21SkinnedMeshAttachment);
	self->r = 1;
	self->g = 1;
	self->b = 1;
	self->a = 1;
	_sp21Attachment_init(SUPER(self), name, SP_ATTACHMENT_SKINNED_MESH, _sp21SkinnedMeshAttachment_dispose);
	return self;
}

void sp21SkinnedMeshAttachment_updateUVs (sp21SkinnedMeshAttachment* self) {
	int i;
	float width = self->regionU2 - self->regionU, height = self->regionV2 - self->regionV;
	FREE(self->uvs);
	self->uvs = MALLOC(float, self->uvsCount);
	if (self->regionRotate) {
		for (i = 0; i < self->uvsCount; i += 2) {
			self->uvs[i] = self->regionU + self->regionUVs[i + 1] * width;
			self->uvs[i + 1] = self->regionV + height - self->regionUVs[i] * height;
		}
	} else {
		for (i = 0; i < self->uvsCount; i += 2) {
			self->uvs[i] = self->regionU + self->regionUVs[i] * width;
			self->uvs[i + 1] = self->regionV + self->regionUVs[i + 1] * height;
		}
	}
}

void sp21SkinnedMeshAttachment_computeWorldVertices (sp21SkinnedMeshAttachment* self, sp21Slot* slot, float* worldVertices) {
	int w = 0, v = 0, b = 0, f = 0;
	float x = slot->bone->skeleton->x, y = slot->bone->skeleton->y;
	sp21Bone** skeletonBones = slot->bone->skeleton->bones;
	if (slot->attachmentVerticesCount == 0) {
		for (; v < self->bonesCount; w += 2) {
			float wx = 0, wy = 0;
			const int nn = self->bones[v] + v;
			v++;
			for (; v <= nn; v++, b += 3) {
				const sp21Bone* bone = skeletonBones[self->bones[v]];
				const float vx = self->weights[b], vy = self->weights[b + 1], weight = self->weights[b + 2];
				wx += (vx * bone->m00 + vy * bone->m01 + bone->worldX) * weight;
				wy += (vx * bone->m10 + vy * bone->m11 + bone->worldY) * weight;
			}
			worldVertices[w] = wx + x;
			worldVertices[w + 1] = wy + y;
		}
	} else {
		const float* ffd = slot->attachmentVertices;
		for (; v < self->bonesCount; w += 2) {
			float wx = 0, wy = 0;
			const int nn = self->bones[v] + v;
			v++;
			for (; v <= nn; v++, b += 3, f += 2) {
				const sp21Bone* bone = skeletonBones[self->bones[v]];
				const float vx = self->weights[b] + ffd[f], vy = self->weights[b + 1] + ffd[f + 1], weight = self->weights[b + 2];
				wx += (vx * bone->m00 + vy * bone->m01 + bone->worldX) * weight;
				wy += (vx * bone->m10 + vy * bone->m11 + bone->worldY) * weight;
			}
			worldVertices[w] = wx + x;
			worldVertices[w + 1] = wy + y;
		}
	}
}

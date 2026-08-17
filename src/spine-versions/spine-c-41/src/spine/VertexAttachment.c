/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated September 24, 2021. Replaces all prior versions.
 *
 * Copyright (c) 2013-2021, Esoteric Software LLC
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
 * THE SPINE RUNTIMES ARE PROVIDED BY ESOTERIC SOFTWARE LLC "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL ESOTERIC SOFTWARE LLC BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES,
 * BUSINESS INTERRUPTION, OR LOSS OF USE, DATA, OR PROFITS) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THE SPINE RUNTIMES, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#include <spine/VertexAttachment.h>
#include <spine/extension.h>

/* FIXME this is not thread-safe */
static int nextID = 0;

void _sp41VertexAttachment_init(sp41VertexAttachment *attachment) {
	attachment->id = nextID++;
	attachment->timelineAttachment = SUPER(attachment);
}

void _sp41VertexAttachment_deinit(sp41VertexAttachment *attachment) {
	_sp41Attachment_deinit(SUPER(attachment));
	FREE(attachment->bones);
	FREE(attachment->vertices);
}

void sp41VertexAttachment_computeWorldVertices(sp41VertexAttachment *self, sp41Slot *slot, int start, int count,
											 float *worldVertices, int offset, int stride) {
	sp41Skeleton *skeleton;
	int deformLength;
	float *deformArray;
	float *vertices;
	int *bones;

	if (self->super.type == SP_ATTACHMENT_MESH || self->super.type == SP_ATTACHMENT_LINKED_MESH) {
		sp41MeshAttachment *mesh = SUB_CAST(sp41MeshAttachment, self);
		if (mesh->sequence) sp41Sequence_apply(mesh->sequence, slot, SUPER(self));
	}

	count = offset + (count >> 1) * stride;
	skeleton = slot->bone->skeleton;
	deformLength = slot->deformCount;
	deformArray = slot->deform;
	vertices = self->vertices;
	bones = self->bones;
	if (!bones) {
		sp41Bone *bone;
		int v, w;
		float x, y;
		if (deformLength > 0) vertices = deformArray;
		bone = slot->bone;
		x = bone->worldX;
		y = bone->worldY;
		for (v = start, w = offset; w < count; v += 2, w += stride) {
			float vx = vertices[v], vy = vertices[v + 1];
			worldVertices[w] = vx * bone->a + vy * bone->b + x;
			worldVertices[w + 1] = vx * bone->c + vy * bone->d + y;
		}
	} else {
		int v = 0, skip = 0, i;
		sp41Bone **skeletonBones;
		for (i = 0; i < start; i += 2) {
			int n = bones[v];
			v += n + 1;
			skip += n;
		}
		skeletonBones = skeleton->bones;
		if (deformLength == 0) {
			int w, b;
			for (w = offset, b = skip * 3; w < count; w += stride) {
				float wx = 0, wy = 0;
				int n = bones[v++];
				n += v;
				for (; v < n; v++, b += 3) {
					sp41Bone *bone = skeletonBones[bones[v]];
					float vx = vertices[b], vy = vertices[b + 1], weight = vertices[b + 2];
					wx += (vx * bone->a + vy * bone->b + bone->worldX) * weight;
					wy += (vx * bone->c + vy * bone->d + bone->worldY) * weight;
				}
				worldVertices[w] = wx;
				worldVertices[w + 1] = wy;
			}
		} else {
			int w, b, f;
			for (w = offset, b = skip * 3, f = skip << 1; w < count; w += stride) {
				float wx = 0, wy = 0;
				int n = bones[v++];
				n += v;
				for (; v < n; v++, b += 3, f += 2) {
					sp41Bone *bone = skeletonBones[bones[v]];
					float vx = vertices[b] + deformArray[f], vy = vertices[b + 1] + deformArray[f + 1], weight = vertices[b + 2];
					wx += (vx * bone->a + vy * bone->b + bone->worldX) * weight;
					wy += (vx * bone->c + vy * bone->d + bone->worldY) * weight;
				}
				worldVertices[w] = wx;
				worldVertices[w + 1] = wy;
			}
		}
	}
}

void sp41VertexAttachment_copyTo(sp41VertexAttachment *from, sp41VertexAttachment *to) {
	if (from->bonesCount) {
		to->bonesCount = from->bonesCount;
		to->bones = MALLOC(int, from->bonesCount);
		memcpy(to->bones, from->bones, from->bonesCount * sizeof(int));
	} else {
		to->bonesCount = 0;
		if (to->bones) {
			FREE(to->bones);
			to->bones = 0;
		}
	}

	if (from->verticesCount) {
		to->verticesCount = from->verticesCount;
		to->vertices = MALLOC(float, from->verticesCount);
		memcpy(to->vertices, from->vertices, from->verticesCount * sizeof(float));
	} else {
		to->verticesCount = 0;
		if (to->vertices) {
			FREE(to->vertices);
			to->vertices = 0;
		}
	}
	to->worldVerticesLength = from->worldVerticesLength;
}

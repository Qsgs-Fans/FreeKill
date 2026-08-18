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

#include <spine/RegionAttachment.h>
#include <spine/extension.h>

typedef enum {
	BLX = 0,
	BLY,
	ULX,
	ULY,
	URX,
	URY,
	BRX,
	BRY
} sp41VertexIndex;

void _sp41RegionAttachment_dispose(sp41Attachment *attachment) {
	sp41RegionAttachment *self = SUB_CAST(sp41RegionAttachment, attachment);
	if (self->sequence) sp41Sequence_dispose(self->sequence);
	_sp41Attachment_deinit(attachment);
	FREE(self->path);
	FREE(self);
}

sp41Attachment *_sp41RegionAttachment_copy(sp41Attachment *attachment) {
	sp41RegionAttachment *self = SUB_CAST(sp41RegionAttachment, attachment);
	sp41RegionAttachment *copy = sp41RegionAttachment_create(attachment->name);
	copy->region = self->region;
	copy->rendererObject = self->rendererObject;
	MALLOC_STR(copy->path, self->path);
	copy->x = self->x;
	copy->y = self->y;
	copy->scaleX = self->scaleX;
	copy->scaleY = self->scaleY;
	copy->rotation = self->rotation;
	copy->width = self->width;
	copy->height = self->height;
	memcpy(copy->uvs, self->uvs, sizeof(float) * 8);
	memcpy(copy->offset, self->offset, sizeof(float) * 8);
	sp41Color_setFromColor(&copy->color, &self->color);
	copy->sequence = self->sequence ? sp41Sequence_copy(self->sequence) : NULL;
	return SUPER(copy);
}

sp41RegionAttachment *sp41RegionAttachment_create(const char *name) {
	sp41RegionAttachment *self = NEW(sp41RegionAttachment);
	self->scaleX = 1;
	self->scaleY = 1;
	sp41Color_setFromFloats(&self->color, 1, 1, 1, 1);
	_sp41Attachment_init(SUPER(self), name, SP_ATTACHMENT_REGION, _sp41RegionAttachment_dispose, _sp41RegionAttachment_copy);
	return self;
}

void sp41RegionAttachment_updateRegion(sp41RegionAttachment *self) {
	float regionScaleX = self->width / self->region->originalWidth * self->scaleX;
	float regionScaleY = self->height / self->region->originalHeight * self->scaleY;
	float localX = -self->width / 2 * self->scaleX + self->region->offsetX * regionScaleX;
	float localY = -self->height / 2 * self->scaleY + self->region->offsetY * regionScaleY;
	float localX2 = localX + self->region->width * regionScaleX;
	float localY2 = localY + self->region->height * regionScaleY;
	float radians = self->rotation * DEG_RAD;
	float cosine = COS(radians), sine = SIN(radians);
	float localXCos = localX * cosine + self->x;
	float localXSin = localX * sine;
	float localYCos = localY * cosine + self->y;
	float localYSin = localY * sine;
	float localX2Cos = localX2 * cosine + self->x;
	float localX2Sin = localX2 * sine;
	float localY2Cos = localY2 * cosine + self->y;
	float localY2Sin = localY2 * sine;
	self->offset[BLX] = localXCos - localYSin;
	self->offset[BLY] = localYCos + localXSin;
	self->offset[ULX] = localXCos - localY2Sin;
	self->offset[ULY] = localY2Cos + localXSin;
	self->offset[URX] = localX2Cos - localY2Sin;
	self->offset[URY] = localY2Cos + localX2Sin;
	self->offset[BRX] = localX2Cos - localYSin;
	self->offset[BRY] = localYCos + localX2Sin;

	if (self->region->degrees == 90) {
		self->uvs[URX] = self->region->u;
		self->uvs[URY] = self->region->v2;
		self->uvs[BRX] = self->region->u;
		self->uvs[BRY] = self->region->v;
		self->uvs[BLX] = self->region->u2;
		self->uvs[BLY] = self->region->v;
		self->uvs[ULX] = self->region->u2;
		self->uvs[ULY] = self->region->v2;
	} else {
		self->uvs[ULX] = self->region->u;
		self->uvs[ULY] = self->region->v2;
		self->uvs[URX] = self->region->u;
		self->uvs[URY] = self->region->v;
		self->uvs[BRX] = self->region->u2;
		self->uvs[BRY] = self->region->v;
		self->uvs[BLX] = self->region->u2;
		self->uvs[BLY] = self->region->v2;
	}
}

void sp41RegionAttachment_computeWorldVertices(sp41RegionAttachment *self, sp41Slot *slot, float *vertices, int offset,
											 int stride) {
	const float *offsets = self->offset;
	sp41Bone *bone = slot->bone;
	float x = bone->worldX, y = bone->worldY;
	float offsetX, offsetY;

	if (self->sequence) sp41Sequence_apply(self->sequence, slot, SUPER(self));

	offsetX = offsets[BRX];
	offsetY = offsets[BRY];
	vertices[offset] = offsetX * bone->a + offsetY * bone->b + x; /* br */
	vertices[offset + 1] = offsetX * bone->c + offsetY * bone->d + y;
	offset += stride;

	offsetX = offsets[BLX];
	offsetY = offsets[BLY];
	vertices[offset] = offsetX * bone->a + offsetY * bone->b + x; /* bl */
	vertices[offset + 1] = offsetX * bone->c + offsetY * bone->d + y;
	offset += stride;

	offsetX = offsets[ULX];
	offsetY = offsets[ULY];
	vertices[offset] = offsetX * bone->a + offsetY * bone->b + x; /* ul */
	vertices[offset + 1] = offsetX * bone->c + offsetY * bone->d + y;
	offset += stride;

	offsetX = offsets[URX];
	offsetY = offsets[URY];
	vertices[offset] = offsetX * bone->a + offsetY * bone->b + x; /* ur */
	vertices[offset + 1] = offsetX * bone->c + offsetY * bone->d + y;
}

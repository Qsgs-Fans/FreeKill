/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated January 1, 2020. Replaces all prior versions.
 *
 * Copyright (c) 2013-2020, Esoteric Software LLC
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

#include <spine/AtlasAttachmentLoader.h>
#include <spine/extension.h>

sp38Attachment* _sp38AtlasAttachmentLoader_createAttachment (sp38AttachmentLoader* loader, sp38Skin* skin, sp38AttachmentType type,
		const char* name, const char* path) {
	sp38AtlasAttachmentLoader* self = SUB_CAST(sp38AtlasAttachmentLoader, loader);
	switch (type) {
	case SP_ATTACHMENT_REGION: {
		sp38RegionAttachment* attachment;
		sp38AtlasRegion* region = sp38Atlas_findRegion(self->atlas, path);
		if (!region) {
			_sp38AttachmentLoader_setError(loader, "Region not found: ", path);
			return 0;
		}
		attachment = sp38RegionAttachment_create(name);
		attachment->rendererObject = region;
		sp38RegionAttachment_setUVs(attachment, region->u, region->v, region->u2, region->v2, region->rotate);
		attachment->regionOffsetX = region->offsetX;
		attachment->regionOffsetY = region->offsetY;
		attachment->regionWidth = region->width;
		attachment->regionHeight = region->height;
		attachment->regionOriginalWidth = region->originalWidth;
		attachment->regionOriginalHeight = region->originalHeight;
		return SUPER(attachment);
	}
	case SP_ATTACHMENT_MESH:
	case SP_ATTACHMENT_LINKED_MESH: {
		sp38MeshAttachment* attachment;
		sp38AtlasRegion* region = sp38Atlas_findRegion(self->atlas, path);
		if (!region) {
			_sp38AttachmentLoader_setError(loader, "Region not found: ", path);
			return 0;
		}
		attachment = sp38MeshAttachment_create(name);
		attachment->rendererObject = region;
		attachment->regionU = region->u;
		attachment->regionV = region->v;
		attachment->regionU2 = region->u2;
		attachment->regionV2 = region->v2;
		attachment->regionRotate = region->rotate;
		attachment->regionDegrees = region->degrees;
		attachment->regionOffsetX = region->offsetX;
		attachment->regionOffsetY = region->offsetY;
		attachment->regionWidth = region->width;
		attachment->regionHeight = region->height;
		attachment->regionOriginalWidth = region->originalWidth;
		attachment->regionOriginalHeight = region->originalHeight;
		return SUPER(SUPER(attachment));
	}
	case SP_ATTACHMENT_BOUNDING_BOX:
		return SUPER(SUPER(sp38BoundingBoxAttachment_create(name)));
	case SP_ATTACHMENT_PATH:
		return SUPER(SUPER(sp38PathAttachment_create(name)));
	case SP_ATTACHMENT_POINT:
		return SUPER(sp38PointAttachment_create(name));
	case SP_ATTACHMENT_CLIPPING:
		return SUPER(SUPER(sp38ClippingAttachment_create(name)));
	default:
		_sp38AttachmentLoader_setUnknownTypeError(loader, type);
		return 0;
	}

	UNUSED(skin);
}

sp38AtlasAttachmentLoader* sp38AtlasAttachmentLoader_create (sp38Atlas* atlas) {
	sp38AtlasAttachmentLoader* self = NEW(sp38AtlasAttachmentLoader);
	_sp38AttachmentLoader_init(SUPER(self), _sp38AttachmentLoader_deinit, _sp38AtlasAttachmentLoader_createAttachment, 0, 0);
	self->atlas = atlas;
	return self;
}

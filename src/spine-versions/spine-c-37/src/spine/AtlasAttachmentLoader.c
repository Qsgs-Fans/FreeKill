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

#include <spine/AtlasAttachmentLoader.h>
#include <spine/extension.h>

sp37Attachment* _sp37AtlasAttachmentLoader_createAttachment (sp37AttachmentLoader* loader, sp37Skin* skin, sp37AttachmentType type,
		const char* name, const char* path) {
	sp37AtlasAttachmentLoader* self = SUB_CAST(sp37AtlasAttachmentLoader, loader);
	switch (type) {
	case SP_ATTACHMENT_REGION: {
		sp37RegionAttachment* attachment;
		sp37AtlasRegion* region = sp37Atlas_findRegion(self->atlas, path);
		if (!region) {
			_sp37AttachmentLoader_setError(loader, "Region not found: ", path);
			return 0;
		}
		attachment = sp37RegionAttachment_create(name);
		attachment->rendererObject = region;
		sp37RegionAttachment_setUVs(attachment, region->u, region->v, region->u2, region->v2, region->rotate);
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
		sp37MeshAttachment* attachment;
		sp37AtlasRegion* region = sp37Atlas_findRegion(self->atlas, path);
		if (!region) {
			_sp37AttachmentLoader_setError(loader, "Region not found: ", path);
			return 0;
		}
		attachment = sp37MeshAttachment_create(name);
		attachment->rendererObject = region;
		attachment->regionU = region->u;
		attachment->regionV = region->v;
		attachment->regionU2 = region->u2;
		attachment->regionV2 = region->v2;
		attachment->regionRotate = region->rotate;
		attachment->regionOffsetX = region->offsetX;
		attachment->regionOffsetY = region->offsetY;
		attachment->regionWidth = region->width;
		attachment->regionHeight = region->height;
		attachment->regionOriginalWidth = region->originalWidth;
		attachment->regionOriginalHeight = region->originalHeight;
		return SUPER(SUPER(attachment));
	}
	case SP_ATTACHMENT_BOUNDING_BOX:
		return SUPER(SUPER(sp37BoundingBoxAttachment_create(name)));
	case SP_ATTACHMENT_PATH:
		return SUPER(SUPER(sp37PathAttachment_create(name)));
	case SP_ATTACHMENT_POINT:
		return SUPER(SUPER(sp37PointAttachment_create(name)));
	case SP_ATTACHMENT_CLIPPING:
		return SUPER(SUPER(sp37ClippingAttachment_create(name)));
	default:
		_sp37AttachmentLoader_setUnknownTypeError(loader, type);
		return 0;
	}

	UNUSED(skin);
}

sp37AtlasAttachmentLoader* sp37AtlasAttachmentLoader_create (sp37Atlas* atlas) {
	sp37AtlasAttachmentLoader* self = NEW(sp37AtlasAttachmentLoader);
	_sp37AttachmentLoader_init(SUPER(self), _sp37AttachmentLoader_deinit, _sp37AtlasAttachmentLoader_createAttachment, 0, 0);
	self->atlas = atlas;
	return self;
}

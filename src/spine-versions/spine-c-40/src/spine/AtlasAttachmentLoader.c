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

sp40Attachment *_sp40AtlasAttachmentLoader_createAttachment(sp40AttachmentLoader *loader, sp40Skin *skin, sp40AttachmentType type,
														const char *name, const char *path) {
	sp40AtlasAttachmentLoader *self = SUB_CAST(sp40AtlasAttachmentLoader, loader);
	switch (type) {
		case SP_ATTACHMENT_REGION: {
			sp40RegionAttachment *attachment;
			sp40AtlasRegion *region = sp40Atlas_findRegion(self->atlas, path);
			if (!region) {
				_sp40AttachmentLoader_setError(loader, "Region not found: ", path);
				return 0;
			}
			attachment = sp40RegionAttachment_create(name);
			attachment->rendererObject = region;
			sp40RegionAttachment_setUVs(attachment, region->u, region->v, region->u2, region->v2, region->degrees);
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
			sp40MeshAttachment *attachment;
			sp40AtlasRegion *region = sp40Atlas_findRegion(self->atlas, path);
			if (!region) {
				_sp40AttachmentLoader_setError(loader, "Region not found: ", path);
				return 0;
			}
			attachment = sp40MeshAttachment_create(name);
			attachment->rendererObject = region;
			attachment->regionU = region->u;
			attachment->regionV = region->v;
			attachment->regionU2 = region->u2;
			attachment->regionV2 = region->v2;
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
			return SUPER(SUPER(sp40BoundingBoxAttachment_create(name)));
		case SP_ATTACHMENT_PATH:
			return SUPER(SUPER(sp40PathAttachment_create(name)));
		case SP_ATTACHMENT_POINT:
			return SUPER(sp40PointAttachment_create(name));
		case SP_ATTACHMENT_CLIPPING:
			return SUPER(SUPER(sp40ClippingAttachment_create(name)));
		default:
			_sp40AttachmentLoader_setUnknownTypeError(loader, type);
			return 0;
	}

	UNUSED(skin);
}

sp40AtlasAttachmentLoader *sp40AtlasAttachmentLoader_create(sp40Atlas *atlas) {
	sp40AtlasAttachmentLoader *self = NEW(sp40AtlasAttachmentLoader);
	_sp40AttachmentLoader_init(SUPER(self), _sp40AttachmentLoader_deinit, _sp40AtlasAttachmentLoader_createAttachment, 0, 0);
	self->atlas = atlas;
	return self;
}

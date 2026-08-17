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

#include <spine/AtlasAttachmentLoader.h>
#include <spine/extension.h>

sp21Attachment* _sp21AtlasAttachmentLoader_newAttachment (sp21AttachmentLoader* loader, sp21Skin* skin, sp21AttachmentType type,
		const char* name, const char* path) {
	sp21AtlasAttachmentLoader* self = SUB_CAST(sp21AtlasAttachmentLoader, loader);
	switch (type) {
	case SP_ATTACHMENT_REGION: {
		sp21RegionAttachment* attachment;
		sp21AtlasRegion* region = sp21Atlas_findRegion(self->atlas, path);
		if (!region) {
			_sp21AttachmentLoader_setError(loader, "Region not found: ", path);
			return 0;
		}
		attachment = sp21RegionAttachment_create(name);
		attachment->rendererObject = region;
		sp21RegionAttachment_setUVs(attachment, region->u, region->v, region->u2, region->v2, region->rotate);
		attachment->regionOffsetX = region->offsetX;
		attachment->regionOffsetY = region->offsetY;
		attachment->regionWidth = region->width;
		attachment->regionHeight = region->height;
		attachment->regionOriginalWidth = region->originalWidth;
		attachment->regionOriginalHeight = region->originalHeight;
		return SUPER(attachment);
	}
	case SP_ATTACHMENT_MESH: {
		sp21MeshAttachment* attachment;
		sp21AtlasRegion* region = sp21Atlas_findRegion(self->atlas, path);
		if (!region) {
			_sp21AttachmentLoader_setError(loader, "Region not found: ", path);
			return 0;
		}
		attachment = sp21MeshAttachment_create(name);
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
		return SUPER(attachment);
	}
	case SP_ATTACHMENT_SKINNED_MESH: {
		sp21SkinnedMeshAttachment* attachment;
		sp21AtlasRegion* region = sp21Atlas_findRegion(self->atlas, path);
		if (!region) {
			_sp21AttachmentLoader_setError(loader, "Region not found: ", path);
			return 0;
		}
		attachment = sp21SkinnedMeshAttachment_create(name);
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
		return SUPER(attachment);
	}
	case SP_ATTACHMENT_BOUNDING_BOX:
		return SUPER(sp21BoundingBoxAttachment_create(name));
	default:
		_sp21AttachmentLoader_setUnknownTypeError(loader, type);
		return 0;
	}
}

sp21AtlasAttachmentLoader* sp21AtlasAttachmentLoader_create (sp21Atlas* atlas) {
	sp21AtlasAttachmentLoader* self = NEW(sp21AtlasAttachmentLoader);
	_sp21AttachmentLoader_init(SUPER(self), _sp21AttachmentLoader_deinit, _sp21AtlasAttachmentLoader_newAttachment);
	self->atlas = atlas;
	return self;
}

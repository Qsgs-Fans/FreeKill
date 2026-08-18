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

#include <spine/AtlasAttachmentLoader.h>
#include <spine/extension.h>
#include <spine/Sequence.h>

static int /*bool*/ loadSequence(sp42Atlas *atlas, const char *basePath, sp42Sequence *sequence) {
	sp42TextureRegionArray *regions = sequence->regions;
	char *path = CALLOC(char, strlen(basePath) + sequence->digits + 2);
	int i;
	for (i = 0; i < regions->size; i++) {
		sp42Sequence_getPath(sequence, basePath, i, path);
		regions->items[i] = SUPER(sp42Atlas_findRegion(atlas, path));
		if (!regions->items[i]) {
			FREE(path);
			return 0;
		}
		regions->items[i]->rendererObject = regions->items[i];
	}
	FREE(path);
	return -1;
}

sp42Attachment *_sp42AtlasAttachmentLoader_createAttachment(sp42AttachmentLoader *loader, sp42Skin *skin, sp42AttachmentType type,
														const char *name, const char *path, sp42Sequence *sequence) {
	sp42AtlasAttachmentLoader *self = SUB_CAST(sp42AtlasAttachmentLoader, loader);
	switch (type) {
		case SP_ATTACHMENT_REGION: {
			sp42RegionAttachment *attachment = sp42RegionAttachment_create(name);
			if (sequence) {
				if (!loadSequence(self->atlas, path, sequence)) {
					sp42Attachment_dispose(SUPER(attachment));
					_sp42AttachmentLoader_setError(loader, "Couldn't load sequence for region attachment: ", path);
					return 0;
				}
			} else {
				sp42AtlasRegion *region = sp42Atlas_findRegion(self->atlas, path);
				if (!region) {
					sp42Attachment_dispose(SUPER(attachment));
					_sp42AttachmentLoader_setError(loader, "Region not found: ", path);
					return 0;
				}
				attachment->rendererObject = region;
				attachment->region = SUPER(region);
			}
			return SUPER(attachment);
		}
		case SP_ATTACHMENT_MESH:
		case SP_ATTACHMENT_LINKED_MESH: {
			sp42MeshAttachment *attachment = sp42MeshAttachment_create(name);

			if (sequence) {
				if (!loadSequence(self->atlas, path, sequence)) {
					sp42Attachment_dispose(SUPER(SUPER(attachment)));
					_sp42AttachmentLoader_setError(loader, "Couldn't load sequence for mesh attachment: ", path);
					return 0;
				}
			} else {
				sp42AtlasRegion *region = sp42Atlas_findRegion(self->atlas, path);
				if (!region) {
					_sp42AttachmentLoader_setError(loader, "Region not found: ", path);
					return 0;
				}
				attachment->rendererObject = region;
				attachment->region = SUPER(region);
			}
			return SUPER(SUPER(attachment));
		}
		case SP_ATTACHMENT_BOUNDING_BOX:
			return SUPER(SUPER(sp42BoundingBoxAttachment_create(name)));
		case SP_ATTACHMENT_PATH:
			return SUPER(SUPER(sp42PathAttachment_create(name)));
		case SP_ATTACHMENT_POINT:
			return SUPER(sp42PointAttachment_create(name));
		case SP_ATTACHMENT_CLIPPING:
			return SUPER(SUPER(sp42ClippingAttachment_create(name)));
		default:
			_sp42AttachmentLoader_setUnknownTypeError(loader, type);
			return 0;
	}

	UNUSED(skin);
}

sp42AtlasAttachmentLoader *sp42AtlasAttachmentLoader_create(sp42Atlas *atlas) {
	sp42AtlasAttachmentLoader *self = NEW(sp42AtlasAttachmentLoader);
	_sp42AttachmentLoader_init(SUPER(self), _sp42AttachmentLoader_deinit, _sp42AtlasAttachmentLoader_createAttachment, 0, 0);
	self->atlas = atlas;
	return self;
}

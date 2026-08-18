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

#include <spine/Sequence.h>
#include <spine/extension.h>
#include <stdio.h>

_SP_ARRAY_IMPLEMENT_TYPE(sp42TextureRegionArray, sp42TextureRegion *)

static int nextSequenceId = 0;

sp42Sequence *sp42Sequence_create(int numRegions) {
	sp42Sequence *self = NEW(sp42Sequence);
	self->id = nextSequenceId++;
	self->regions = sp42TextureRegionArray_create(numRegions);
	sp42TextureRegionArray_setSize(self->regions, numRegions);
	return self;
}

void sp42Sequence_dispose(sp42Sequence *self) {
	FREE(self->regions);
	FREE(self);
}

sp42Sequence *sp42Sequence_copy(sp42Sequence *self) {
	int i = 0;
	sp42Sequence *copy = sp42Sequence_create(self->regions->size);
	for (; i < self->regions->size; i++)
		copy->regions->items[i] = self->regions->items[i];
	copy->start = self->start;
	copy->digits = self->digits;
	copy->setupIndex = self->setupIndex;
	return copy;
}

void sp42Sequence_apply(sp42Sequence *self, sp42Slot *slot, sp42Attachment *attachment) {
	int index = slot->sequenceIndex;
	sp42TextureRegion *region = NULL;
	if (index == -1) index = self->setupIndex;
	if (index >= (int) self->regions->size) index = self->regions->size - 1;
	region = self->regions->items[index];

	if (attachment->type == SP_ATTACHMENT_REGION) {
		sp42RegionAttachment *regionAttachment = (sp42RegionAttachment *) attachment;
		if (regionAttachment->region != region) {
			regionAttachment->rendererObject = region;
			regionAttachment->region = region;
			sp42RegionAttachment_updateRegion(regionAttachment);
		}
	}

	if (attachment->type == SP_ATTACHMENT_MESH) {
		sp42MeshAttachment *meshAttachment = (sp42MeshAttachment *) attachment;
		if (meshAttachment->region != region) {
			meshAttachment->rendererObject = region;
			meshAttachment->region = region;
			sp42MeshAttachment_updateRegion(meshAttachment);
		}
	}
}

static int num_digits(int value) {
	int count = value < 0 ? 1 : 0;
	do {
		value /= 10;
		++count;
	} while (value != 0);
	return count;
}

static char *string_append(char *str, const char *b) {
	int lenB = strlen(b);
	memcpy(str, b, lenB + 1);
	return str + lenB;
}

static char *string_append_int(char *str, int value) {
	char intStr[20];
	snprintf(intStr, 20, "%i", value);
	return string_append(str, intStr);
}

void sp42Sequence_getPath(sp42Sequence *self, const char *basePath, int index, char *path) {
	int i;
	path = string_append(path, basePath);
	for (i = self->digits - num_digits(self->start + index); i > 0; i--)
		path = string_append(path, "0");
	path = string_append_int(path, self->start + index);
}

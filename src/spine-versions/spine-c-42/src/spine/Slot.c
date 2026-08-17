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

#include <spine/Slot.h>
#include <spine/extension.h>

sp42Slot *sp42Slot_create(sp42SlotData *data, sp42Bone *bone) {
	sp42Slot *self = NEW(sp42Slot);
	self->data = data;
	self->bone = bone;
	sp42Color_setFromFloats(&self->color, 1, 1, 1, 1);
	self->darkColor = data->darkColor == 0 ? 0 : sp42Color_create();
	sp42Slot_setToSetupPose(self);
	return self;
}

void sp42Slot_dispose(sp42Slot *self) {
	FREE(self->deform);
	FREE(self->darkColor);
	FREE(self);
}

static int isVertexAttachment(sp42Attachment *attachment) {
	if (attachment == NULL) return 0;
	switch (attachment->type) {
		case SP_ATTACHMENT_BOUNDING_BOX:
		case SP_ATTACHMENT_CLIPPING:
		case SP_ATTACHMENT_MESH:
		case SP_ATTACHMENT_PATH:
			return -1;
		default:
			return 0;
	}
}

void sp42Slot_setAttachment(sp42Slot *self, sp42Attachment *attachment) {
	if (attachment == self->attachment) return;

	if (!isVertexAttachment(attachment) ||
		!isVertexAttachment(self->attachment) || (SUB_CAST(sp42VertexAttachment, attachment)->timelineAttachment != SUB_CAST(sp42VertexAttachment, self->attachment)->timelineAttachment)) {
		self->deformCount = 0;
	}

	self->attachment = attachment;
	self->sequenceIndex = -1;
}

void sp42Slot_setToSetupPose(sp42Slot *self) {
	sp42Color_setFromColor(&self->color, &self->data->color);
	if (self->darkColor) sp42Color_setFromColor(self->darkColor, self->data->darkColor);

	if (!self->data->attachmentName)
		sp42Slot_setAttachment(self, 0);
	else {
		sp42Attachment *attachment = sp42Skeleton_getAttachmentForSlotIndex(
				self->bone->skeleton, self->data->index, self->data->attachmentName);
		self->attachment = 0;
		sp42Slot_setAttachment(self, attachment);
	}
}

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

#include <spine/Slot.h>
#include <spine/extension.h>

sp41Slot *sp41Slot_create(sp41SlotData *data, sp41Bone *bone) {
	sp41Slot *self = NEW(sp41Slot);
	CONST_CAST(sp41SlotData *, self->data) = data;
	CONST_CAST(sp41Bone *, self->bone) = bone;
	sp41Color_setFromFloats(&self->color, 1, 1, 1, 1);
	self->darkColor = data->darkColor == 0 ? 0 : sp41Color_create();
	sp41Slot_setToSetupPose(self);
	return self;
}

void sp41Slot_dispose(sp41Slot *self) {
	FREE(self->deform);
	FREE(self->darkColor);
	FREE(self);
}

static int isVertexAttachment(sp41Attachment *attachment) {
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

void sp41Slot_setAttachment(sp41Slot *self, sp41Attachment *attachment) {
	if (attachment == self->attachment) return;

	if (!isVertexAttachment(attachment) ||
		!isVertexAttachment(self->attachment) || (SUB_CAST(sp41VertexAttachment, attachment)->timelineAttachment != SUB_CAST(sp41VertexAttachment, self->attachment)->timelineAttachment)) {
		self->deformCount = 0;
	}

	CONST_CAST(sp41Attachment *, self->attachment) = attachment;
	self->sequenceIndex = -1;
}

void sp41Slot_setToSetupPose(sp41Slot *self) {
	sp41Color_setFromColor(&self->color, &self->data->color);
	if (self->darkColor) sp41Color_setFromColor(self->darkColor, self->data->darkColor);

	if (!self->data->attachmentName)
		sp41Slot_setAttachment(self, 0);
	else {
		sp41Attachment *attachment = sp41Skeleton_getAttachmentForSlotIndex(
				self->bone->skeleton, self->data->index, self->data->attachmentName);
		CONST_CAST(sp41Attachment *, self->attachment) = 0;
		sp41Slot_setAttachment(self, attachment);
	}
}

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

#include <spine/Slot.h>
#include <spine/extension.h>

typedef struct {
	sp40Slot super;
	float attachmentTime;
} _sp40Slot;

sp40Slot *sp40Slot_create(sp40SlotData *data, sp40Bone *bone) {
	sp40Slot *self = SUPER(NEW(_sp40Slot));
	CONST_CAST(sp40SlotData *, self->data) = data;
	CONST_CAST(sp40Bone *, self->bone) = bone;
	sp40Color_setFromFloats(&self->color, 1, 1, 1, 1);
	self->darkColor = data->darkColor == 0 ? 0 : sp40Color_create();
	sp40Slot_setToSetupPose(self);
	return self;
}

void sp40Slot_dispose(sp40Slot *self) {
	FREE(self->deform);
	FREE(self->darkColor);
	FREE(self);
}

static int isVertexAttachment(sp40Attachment *attachment) {
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

void sp40Slot_setAttachment(sp40Slot *self, sp40Attachment *attachment) {
	if (attachment == self->attachment) return;

	if (!isVertexAttachment(attachment) ||
		!isVertexAttachment(self->attachment) || (SUB_CAST(sp40VertexAttachment, attachment)->deformAttachment != SUB_CAST(sp40VertexAttachment, self->attachment)->deformAttachment)) {
		self->deformCount = 0;
	}

	CONST_CAST(sp40Attachment *, self->attachment) = attachment;
	SUB_CAST(_sp40Slot, self)->attachmentTime = self->bone->skeleton->time;
}

void sp40Slot_setAttachmentTime(sp40Slot *self, float time) {
	SUB_CAST(_sp40Slot, self)->attachmentTime = self->bone->skeleton->time - time;
}

float sp40Slot_getAttachmentTime(const sp40Slot *self) {
	return self->bone->skeleton->time - SUB_CAST(_sp40Slot, self)->attachmentTime;
}

void sp40Slot_setToSetupPose(sp40Slot *self) {
	sp40Color_setFromColor(&self->color, &self->data->color);
	if (self->darkColor) sp40Color_setFromColor(self->darkColor, self->data->darkColor);

	if (!self->data->attachmentName)
		sp40Slot_setAttachment(self, 0);
	else {
		sp40Attachment *attachment = sp40Skeleton_getAttachmentForSlotIndex(
				self->bone->skeleton, self->data->index, self->data->attachmentName);
		CONST_CAST(sp40Attachment *, self->attachment) = 0;
		sp40Slot_setAttachment(self, attachment);
	}
}

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
	sp38Slot super;
	float attachmentTime;
} _sp38Slot;

sp38Slot* sp38Slot_create (sp38SlotData* data, sp38Bone* bone) {
	sp38Slot* self = SUPER(NEW(_sp38Slot));
	CONST_CAST(sp38SlotData*, self->data) = data;
	CONST_CAST(sp38Bone*, self->bone) = bone;
	sp38Color_setFromFloats(&self->color, 1, 1, 1, 1);
	self->darkColor = data->darkColor == 0 ? 0 : sp38Color_create();
	sp38Slot_setToSetupPose(self);
	return self;
}

void sp38Slot_dispose (sp38Slot* self) {
	FREE(self->deform);
	FREE(self->darkColor);
	FREE(self);
}

void sp38Slot_setAttachment (sp38Slot* self, sp38Attachment* attachment) {
	if (attachment == self->attachment) return;
	CONST_CAST(sp38Attachment*, self->attachment) = attachment;
	SUB_CAST(_sp38Slot, self)->attachmentTime = self->bone->skeleton->time;
	self->deformCount = 0;
}

void sp38Slot_setAttachmentTime (sp38Slot* self, float time) {
	SUB_CAST(_sp38Slot, self)->attachmentTime = self->bone->skeleton->time - time;
}

float sp38Slot_getAttachmentTime (const sp38Slot* self) {
	return self->bone->skeleton->time - SUB_CAST(_sp38Slot, self) ->attachmentTime;
}

void sp38Slot_setToSetupPose (sp38Slot* self) {
	sp38Color_setFromColor(&self->color, &self->data->color);
	if (self->darkColor) sp38Color_setFromColor(self->darkColor, self->data->darkColor);

	if (!self->data->attachmentName)
		sp38Slot_setAttachment(self, 0);
	else {
		sp38Attachment* attachment = sp38Skeleton_getAttachmentForSlotIndex(
			self->bone->skeleton, self->data->index, self->data->attachmentName);
		CONST_CAST(sp38Attachment*, self->attachment) = 0;
		sp38Slot_setAttachment(self, attachment);
	}
}

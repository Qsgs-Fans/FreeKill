/******************************************************************************
 * Spine Runtimes Software License v2.5
 *
 * Copyright (c) 2013-2016, Esoteric Software
 * All rights reserved.
 *
 * You are granted a perpetual, non-exclusive, non-sublicensable, and
 * non-transferable license to use, install, execute, and perform the Spine
 * Runtimes software and derivative works solely for personal or internal
 * use. Without the written permission of Esoteric Software (see Section 2 of
 * the Spine Software License Agreement), you may not (a) modify, translate,
 * adapt, or develop new applications using the Spine Runtimes or otherwise
 * create derivative works or improvements of the Spine Runtimes or (b) remove,
 * delete, alter, or obscure any trademarks or any copyright, trademark, patent,
 * or other intellectual property or proprietary rights notices on or in the
 * Software, including any copy thereof. Redistributions in binary or source
 * form must include this license and terms.
 *
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, BUSINESS INTERRUPTION, OR LOSS OF
 * USE, DATA, OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 * IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#include <spine/Slot.h>
#include <spine/extension.h>

typedef struct {
	sp35Slot super;
	float attachmentTime;
} _sp35Slot;

sp35Slot* sp35Slot_create (sp35SlotData* data, sp35Bone* bone) {
	sp35Slot* self = SUPER(NEW(_sp35Slot));
	CONST_CAST(sp35SlotData*, self->data) = data;
	CONST_CAST(sp35Bone*, self->bone) = bone;
	sp35Slot_setToSetupPose(self);
	return self;
}

void sp35Slot_dispose (sp35Slot* self) {
	FREE(self->attachmentVertices);
	FREE(self);
}

void sp35Slot_setAttachment (sp35Slot* self, sp35Attachment* attachment) {
	if (attachment == self->attachment) return;
	CONST_CAST(sp35Attachment*, self->attachment) = attachment;
	SUB_CAST(_sp35Slot, self)->attachmentTime = self->bone->skeleton->time;
	self->attachmentVerticesCount = 0;
}

void sp35Slot_setAttachmentTime (sp35Slot* self, float time) {
	SUB_CAST(_sp35Slot, self)->attachmentTime = self->bone->skeleton->time - time;
}

float sp35Slot_getAttachmentTime (const sp35Slot* self) {
	return self->bone->skeleton->time - SUB_CAST(_sp35Slot, self) ->attachmentTime;
}

void sp35Slot_setToSetupPose (sp35Slot* self) {
	self->r = self->data->r;
	self->g = self->data->g;
	self->b = self->data->b;
	self->a = self->data->a;

	if (!self->data->attachmentName)
		sp35Slot_setAttachment(self, 0);
	else {
		sp35Attachment* attachment = sp35Skeleton_getAttachmentForSlotIndex(
				self->bone->skeleton, self->data->index, self->data->attachmentName);
		CONST_CAST(sp35Attachment*, self->attachment) = 0;
		sp35Slot_setAttachment(self, attachment);
	}
}

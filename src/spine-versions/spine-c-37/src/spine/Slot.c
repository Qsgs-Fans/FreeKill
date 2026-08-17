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

#include <spine/Slot.h>
#include <spine/extension.h>

typedef struct {
	sp37Slot super;
	float attachmentTime;
} _sp37Slot;

sp37Slot* sp37Slot_create (sp37SlotData* data, sp37Bone* bone) {
	sp37Slot* self = SUPER(NEW(_sp37Slot));
	CONST_CAST(sp37SlotData*, self->data) = data;
	CONST_CAST(sp37Bone*, self->bone) = bone;
	sp37Color_setFromFloats(&self->color, 1, 1, 1, 1);
	self->darkColor = data->darkColor == 0 ? 0 : sp37Color_create();
	sp37Slot_setToSetupPose(self);
	return self;
}

void sp37Slot_dispose (sp37Slot* self) {
	FREE(self->attachmentVertices);
	FREE(self->darkColor);
	FREE(self);
}

void sp37Slot_setAttachment (sp37Slot* self, sp37Attachment* attachment) {
	if (attachment == self->attachment) return;
	CONST_CAST(sp37Attachment*, self->attachment) = attachment;
	SUB_CAST(_sp37Slot, self)->attachmentTime = self->bone->skeleton->time;
	self->attachmentVerticesCount = 0;
}

void sp37Slot_setAttachmentTime (sp37Slot* self, float time) {
	SUB_CAST(_sp37Slot, self)->attachmentTime = self->bone->skeleton->time - time;
}

float sp37Slot_getAttachmentTime (const sp37Slot* self) {
	return self->bone->skeleton->time - SUB_CAST(_sp37Slot, self) ->attachmentTime;
}

void sp37Slot_setToSetupPose (sp37Slot* self) {
	sp37Color_setFromColor(&self->color, &self->data->color);
	if (self->darkColor) sp37Color_setFromColor(self->darkColor, self->data->darkColor);

	if (!self->data->attachmentName)
		sp37Slot_setAttachment(self, 0);
	else {
		sp37Attachment* attachment = sp37Skeleton_getAttachmentForSlotIndex(
				self->bone->skeleton, self->data->index, self->data->attachmentName);
		CONST_CAST(sp37Attachment*, self->attachment) = 0;
		sp37Slot_setAttachment(self, attachment);
	}
}

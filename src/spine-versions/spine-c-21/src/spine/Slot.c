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

#include <spine/Slot.h>
#include <spine/extension.h>

typedef struct {
	sp21Slot super;
	float attachmentTime;
} _sp21Slot;

sp21Slot* sp21Slot_create (sp21SlotData* data, sp21Bone* bone) {
	sp21Slot* self = SUPER(NEW(_sp21Slot));
	CONST_CAST(sp21SlotData*, self->data) = data;
	CONST_CAST(sp21Bone*, self->bone) = bone;
	sp21Slot_setToSetupPose(self);
	return self;
}

void sp21Slot_dispose (sp21Slot* self) {
	FREE(self->attachmentVertices);
	FREE(self);
}

void sp21Slot_setAttachment (sp21Slot* self, sp21Attachment* attachment) {
	CONST_CAST(sp21Attachment*, self->attachment) = attachment;
	SUB_CAST(_sp21Slot, self)->attachmentTime = self->bone->skeleton->time;
	self->attachmentVerticesCount = 0;
}

void sp21Slot_setAttachmentTime (sp21Slot* self, float time) {
	SUB_CAST(_sp21Slot, self)->attachmentTime = self->bone->skeleton->time - time;
}

float sp21Slot_getAttachmentTime (const sp21Slot* self) {
	return self->bone->skeleton->time - SUB_CAST(_sp21Slot, self) ->attachmentTime;
}

void sp21Slot_setToSetupPose (sp21Slot* self) {
	sp21Attachment* attachment = 0;

	self->r = self->data->r;
	self->g = self->data->g;
	self->b = self->data->b;
	self->a = self->data->a;

	if (self->data->attachmentName) {
		/* Find slot index. */
		int i;
		for (i = 0; i < self->bone->skeleton->data->slotsCount; ++i) {
			if (self->data == self->bone->skeleton->data->slots[i]) {
				attachment = sp21Skeleton_getAttachmentForSlotIndex(self->bone->skeleton, i, self->data->attachmentName);
				break;
			}
		}
	}
	sp21Slot_setAttachment(self, attachment);
}

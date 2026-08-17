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

#ifndef SPINE_SLOT_H_
#define SPINE_SLOT_H_

#include <spine/dll.h>
#include <spine/Bone.h>
#include <spine/Attachment.h>
#include <spine/SlotData.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp40Slot {
	sp40SlotData *const data;
	sp40Bone *const bone;
	sp40Color color;
	sp40Color *darkColor;
	sp40Attachment *attachment;
	int attachmentState;

	int deformCapacity;
	int deformCount;
	float *deform;
} sp40Slot;

SP_API sp40Slot *sp40Slot_create(sp40SlotData *data, sp40Bone *bone);

SP_API void sp40Slot_dispose(sp40Slot *self);

/* @param attachment May be 0 to clear the attachment for the slot. */
SP_API void sp40Slot_setAttachment(sp40Slot *self, sp40Attachment *attachment);

SP_API void sp40Slot_setAttachmentTime(sp40Slot *self, float time);

SP_API float sp40Slot_getAttachmentTime(const sp40Slot *self);

SP_API void sp40Slot_setToSetupPose(sp40Slot *self);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SLOT_H_ */

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

typedef struct sp38Slot {
	sp38SlotData* const data;
	sp38Bone* const bone;
	sp38Color color;
	sp38Color* darkColor;
	sp38Attachment* attachment;
	int attachmentState;

	int deformCapacity;
	int deformCount;
	float* deform;

#ifdef __cplusplus
	sp38Slot() :
		data(0),
		bone(0),
		color(),
		darkColor(0),
		attachment(0),
		attachmentState(0),
		deformCapacity(0),
		deformCount(0),
		deform(0) {
	}
#endif
} sp38Slot;

SP_API sp38Slot* sp38Slot_create (sp38SlotData* data, sp38Bone* bone);
SP_API void sp38Slot_dispose (sp38Slot* self);

/* @param attachment May be 0 to clear the attachment for the slot. */
SP_API void sp38Slot_setAttachment (sp38Slot* self, sp38Attachment* attachment);

SP_API void sp38Slot_setAttachmentTime (sp38Slot* self, float time);
SP_API float sp38Slot_getAttachmentTime (const sp38Slot* self);

SP_API void sp38Slot_setToSetupPose (sp38Slot* self);

#ifdef SPINE_SHORT_NAMES
typedef sp38Slot Slot;
#define Slot_create(...) sp38Slot_create(__VA_ARGS__)
#define Slot_dispose(...) sp38Slot_dispose(__VA_ARGS__)
#define Slot_setAttachment(...) sp38Slot_setAttachment(__VA_ARGS__)
#define Slot_setAttachmentTime(...) sp38Slot_setAttachmentTime(__VA_ARGS__)
#define Slot_getAttachmentTime(...) sp38Slot_getAttachmentTime(__VA_ARGS__)
#define Slot_setToSetupPose(...) sp38Slot_setToSetupPose(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SLOT_H_ */

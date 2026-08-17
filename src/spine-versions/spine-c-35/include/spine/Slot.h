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

#ifndef SPINE_SLOT_H_
#define SPINE_SLOT_H_

#include <spine/Bone.h>
#include <spine/Attachment.h>
#include <spine/SlotData.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp35Slot {
	sp35SlotData* const data;
	sp35Bone* const bone;
	float r, g, b, a;
	sp35Attachment* const attachment;

	int attachmentVerticesCapacity;
	int attachmentVerticesCount;
	float* attachmentVertices;

#ifdef __cplusplus
	sp35Slot() :
		data(0),
		bone(0),
		r(0), g(0), b(0), a(0),
		attachment(0),
		attachmentVerticesCapacity(0),
		attachmentVerticesCount(0),
		attachmentVertices(0) {
	}
#endif
} sp35Slot;

sp35Slot* sp35Slot_create (sp35SlotData* data, sp35Bone* bone);
void sp35Slot_dispose (sp35Slot* self);

/* @param attachment May be 0 to clear the attachment for the slot. */
void sp35Slot_setAttachment (sp35Slot* self, sp35Attachment* attachment);

void sp35Slot_setAttachmentTime (sp35Slot* self, float time);
float sp35Slot_getAttachmentTime (const sp35Slot* self);

void sp35Slot_setToSetupPose (sp35Slot* self);

#ifdef SPINE_SHORT_NAMES
typedef sp35Slot Slot;
#define Slot_create(...) sp35Slot_create(__VA_ARGS__)
#define Slot_dispose(...) sp35Slot_dispose(__VA_ARGS__)
#define Slot_setAttachment(...) sp35Slot_setAttachment(__VA_ARGS__)
#define Slot_setAttachmentTime(...) sp35Slot_setAttachmentTime(__VA_ARGS__)
#define Slot_getAttachmentTime(...) sp35Slot_getAttachmentTime(__VA_ARGS__)
#define Slot_setToSetupPose(...) sp35Slot_setToSetupPose(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SLOT_H_ */

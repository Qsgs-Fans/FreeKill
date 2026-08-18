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

#include <spine/dll.h>
#include <spine/Bone.h>
#include <spine/Attachment.h>
#include <spine/SlotData.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp36Slot {
	sp36SlotData* const data;
	sp36Bone* const bone;
	sp36Color color;
	sp36Color* darkColor;
	sp36Attachment* const attachment;

	int attachmentVerticesCapacity;
	int attachmentVerticesCount;
	float* attachmentVertices;

#ifdef __cplusplus
	sp36Slot() :
		data(0),
		bone(0),
		color(),
		darkColor(0),
		attachment(0),
		attachmentVerticesCapacity(0),
		attachmentVerticesCount(0),
		attachmentVertices(0) {
	}
#endif
} sp36Slot;

SP_API sp36Slot* sp36Slot_create (sp36SlotData* data, sp36Bone* bone);
SP_API void sp36Slot_dispose (sp36Slot* self);

/* @param attachment May be 0 to clear the attachment for the slot. */
SP_API void sp36Slot_setAttachment (sp36Slot* self, sp36Attachment* attachment);

SP_API void sp36Slot_setAttachmentTime (sp36Slot* self, float time);
SP_API float sp36Slot_getAttachmentTime (const sp36Slot* self);

SP_API void sp36Slot_setToSetupPose (sp36Slot* self);

#ifdef SPINE_SHORT_NAMES
typedef sp36Slot Slot;
#define Slot_create(...) sp36Slot_create(__VA_ARGS__)
#define Slot_dispose(...) sp36Slot_dispose(__VA_ARGS__)
#define Slot_setAttachment(...) sp36Slot_setAttachment(__VA_ARGS__)
#define Slot_setAttachmentTime(...) sp36Slot_setAttachmentTime(__VA_ARGS__)
#define Slot_getAttachmentTime(...) sp36Slot_getAttachmentTime(__VA_ARGS__)
#define Slot_setToSetupPose(...) sp36Slot_setToSetupPose(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SLOT_H_ */

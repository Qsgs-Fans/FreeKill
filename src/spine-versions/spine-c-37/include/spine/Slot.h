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

#ifndef SPINE_SLOT_H_
#define SPINE_SLOT_H_

#include <spine/dll.h>
#include <spine/Bone.h>
#include <spine/Attachment.h>
#include <spine/SlotData.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp37Slot {
	sp37SlotData* const data;
	sp37Bone* const bone;
	sp37Color color;
	sp37Color* darkColor;
	sp37Attachment* const attachment;

	int attachmentVerticesCapacity;
	int attachmentVerticesCount;
	float* attachmentVertices;

#ifdef __cplusplus
	sp37Slot() :
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
} sp37Slot;

SP_API sp37Slot* sp37Slot_create (sp37SlotData* data, sp37Bone* bone);
SP_API void sp37Slot_dispose (sp37Slot* self);

/* @param attachment May be 0 to clear the attachment for the slot. */
SP_API void sp37Slot_setAttachment (sp37Slot* self, sp37Attachment* attachment);

SP_API void sp37Slot_setAttachmentTime (sp37Slot* self, float time);
SP_API float sp37Slot_getAttachmentTime (const sp37Slot* self);

SP_API void sp37Slot_setToSetupPose (sp37Slot* self);

#ifdef SPINE_SHORT_NAMES
typedef sp37Slot Slot;
#define Slot_create(...) sp37Slot_create(__VA_ARGS__)
#define Slot_dispose(...) sp37Slot_dispose(__VA_ARGS__)
#define Slot_setAttachment(...) sp37Slot_setAttachment(__VA_ARGS__)
#define Slot_setAttachmentTime(...) sp37Slot_setAttachmentTime(__VA_ARGS__)
#define Slot_getAttachmentTime(...) sp37Slot_getAttachmentTime(__VA_ARGS__)
#define Slot_setToSetupPose(...) sp37Slot_setToSetupPose(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SLOT_H_ */

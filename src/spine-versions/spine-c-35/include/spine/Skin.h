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

#ifndef SPINE_SKIN_H_
#define SPINE_SKIN_H_

#include <spine/Attachment.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp35Skeleton;

typedef struct sp35Skin {
	const char* const name;

#ifdef __cplusplus
	sp35Skin() :
		name(0) {
	}
#endif
} sp35Skin;

/* Private structs, needed by Skeleton */
typedef struct _Entry _Entry;
struct _Entry {
	int slotIndex;
	const char* name;
	sp35Attachment* attachment;
	_Entry* next;
};

typedef struct {
	sp35Skin super;
	_Entry* entries;
} _sp35Skin;

sp35Skin* sp35Skin_create (const char* name);
void sp35Skin_dispose (sp35Skin* self);

/* The Skin owns the attachment. */
void sp35Skin_addAttachment (sp35Skin* self, int slotIndex, const char* name, sp35Attachment* attachment);
/* Returns 0 if the attachment was not found. */
sp35Attachment* sp35Skin_getAttachment (const sp35Skin* self, int slotIndex, const char* name);

/* Returns 0 if the slot or attachment was not found. */
const char* sp35Skin_getAttachmentName (const sp35Skin* self, int slotIndex, int attachmentIndex);

/** Attach each attachment in this skin if the corresponding attachment in oldSkin is currently attached. */
void sp35Skin_attachAll (const sp35Skin* self, struct sp35Skeleton* skeleton, const sp35Skin* oldspSkin);

#ifdef SPINE_SHORT_NAMES
typedef sp35Skin Skin;
#define Skin_create(...) sp35Skin_create(__VA_ARGS__)
#define Skin_dispose(...) sp35Skin_dispose(__VA_ARGS__)
#define Skin_addAttachment(...) sp35Skin_addAttachment(__VA_ARGS__)
#define Skin_getAttachment(...) sp35Skin_getAttachment(__VA_ARGS__)
#define Skin_getAttachmentName(...) sp35Skin_getAttachmentName(__VA_ARGS__)
#define Skin_attachAll(...) sp35Skin_attachAll(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKIN_H_ */

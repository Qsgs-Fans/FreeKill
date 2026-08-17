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

#ifndef SPINE_SKIN_H_
#define SPINE_SKIN_H_

#include <spine/Attachment.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp21Skeleton;

typedef struct sp21Skin {
	const char* const name;

#ifdef __cplusplus
	sp21Skin() :
		name(0) {
	}
#endif
} sp21Skin;

sp21Skin* sp21Skin_create (const char* name);
void sp21Skin_dispose (sp21Skin* self);

/* The Skin owns the attachment. */
void sp21Skin_addAttachment (sp21Skin* self, int slotIndex, const char* name, sp21Attachment* attachment);
/* Returns 0 if the attachment was not found. */
sp21Attachment* sp21Skin_getAttachment (const sp21Skin* self, int slotIndex, const char* name);

/* Returns 0 if the slot or attachment was not found. */
const char* sp21Skin_getAttachmentName (const sp21Skin* self, int slotIndex, int attachmentIndex);

/** Attach each attachment in this skin if the corresponding attachment in oldSkin is currently attached. */
void sp21Skin_attachAll (const sp21Skin* self, struct sp21Skeleton* skeleton, const sp21Skin* oldspSkin);

#ifdef SPINE_SHORT_NAMES
typedef sp21Skin Skin;
#define Skin_create(...) sp21Skin_create(__VA_ARGS__)
#define Skin_dispose(...) sp21Skin_dispose(__VA_ARGS__)
#define Skin_addAttachment(...) sp21Skin_addAttachment(__VA_ARGS__)
#define Skin_getAttachment(...) sp21Skin_getAttachment(__VA_ARGS__)
#define Skin_getAttachmentName(...) sp21Skin_getAttachmentName(__VA_ARGS__)
#define Skin_attachAll(...) sp21Skin_attachAll(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKIN_H_ */

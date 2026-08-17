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

#ifndef SPINE_ATTACHMENTLOADER_H_
#define SPINE_ATTACHMENTLOADER_H_

#include <spine/dll.h>
#include <spine/Attachment.h>
#include <spine/Skin.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp38AttachmentLoader {
	const char* error1;
	const char* error2;

	const void* const vtable;
#ifdef __cplusplus
	sp38AttachmentLoader () :
		error1(0),
		error2(0),
		vtable(0) {
	}
#endif
} sp38AttachmentLoader;

SP_API void sp38AttachmentLoader_dispose (sp38AttachmentLoader* self);

/* Called to create each attachment. Returns 0 to not load an attachment. If 0 is returned and _sp38AttachmentLoader_setError was
 * called, an error occurred. */
SP_API sp38Attachment* sp38AttachmentLoader_createAttachment (sp38AttachmentLoader* self, sp38Skin* skin, sp38AttachmentType type, const char* name,
		const char* path);
/* Called after the attachment has been fully configured. */
SP_API void sp38AttachmentLoader_configureAttachment (sp38AttachmentLoader* self, sp38Attachment* attachment);
/* Called just before the attachment is disposed. This can release allocations made in sp38AttachmentLoader_configureAttachment. */
SP_API void sp38AttachmentLoader_disposeAttachment (sp38AttachmentLoader* self, sp38Attachment* attachment);

#ifdef SPINE_SHORT_NAMES
typedef sp38AttachmentLoader AttachmentLoader;
#define AttachmentLoader_dispose(...) sp38AttachmentLoader_dispose(__VA_ARGS__)
#define AttachmentLoader_createAttachment(...) sp38AttachmentLoader_createAttachment(__VA_ARGS__)
#define AttachmentLoader_configureAttachment(...) sp38AttachmentLoader_configureAttachment(__VA_ARGS__)
#define AttachmentLoader_disposeAttachment(...) sp38AttachmentLoader_disposeAttachment(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ATTACHMENTLOADER_H_ */

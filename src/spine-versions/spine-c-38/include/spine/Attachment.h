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

#ifndef SPINE_ATTACHMENT_H_
#define SPINE_ATTACHMENT_H_

#include <spine/dll.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp38AttachmentLoader;

typedef enum {
	SP_ATTACHMENT_REGION,
	SP_ATTACHMENT_BOUNDING_BOX,
	SP_ATTACHMENT_MESH,
	SP_ATTACHMENT_LINKED_MESH,
	SP_ATTACHMENT_PATH,
	SP_ATTACHMENT_POINT,
	SP_ATTACHMENT_CLIPPING
} sp38AttachmentType;

typedef struct sp38Attachment {
	const char* const name;
	const sp38AttachmentType type;
	const void* const vtable;
	int refCount;
	struct sp38AttachmentLoader* attachmentLoader;

#ifdef __cplusplus
	sp38Attachment() :
		name(0),
		type(SP_ATTACHMENT_REGION),
		vtable(0),
		refCount(0) {
	}
#endif
} sp38Attachment;

void sp38Attachment_dispose (sp38Attachment* self);

sp38Attachment* sp38Attachment_copy (sp38Attachment* self);

#ifdef SPINE_SHORT_NAMES
typedef sp38AttachmentType AttachmentType;
#define ATTACHMENT_REGION SP_ATTACHMENT_REGION
#define ATTACHMENT_BOUNDING_BOX SP_ATTACHMENT_BOUNDING_BOX
#define ATTACHMENT_MESH SP_ATTACHMENT_MESH
#define ATTACHMENT_LINKED_MESH SP_ATTACHMENT_LINKED_MESH
typedef sp38Attachment Attachment;
#define Attachment_dispose(...) sp38Attachment_dispose(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ATTACHMENT_H_ */

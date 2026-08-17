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

#ifndef SPINE_ATTACHMENT_H_
#define SPINE_ATTACHMENT_H_

#ifdef __cplusplus
extern "C" {
#endif

struct sp34AttachmentLoader;

typedef enum {
	SP_ATTACHMENT_REGION,
	SP_ATTACHMENT_BOUNDING_BOX,
	SP_ATTACHMENT_MESH,
	SP_ATTACHMENT_LINKED_MESH,
	SP_ATTACHMENT_PATH
} sp34AttachmentType;

typedef struct sp34Attachment {
	const char* const name;
	const sp34AttachmentType type;
	const void* const vtable;
	struct sp34AttachmentLoader* attachmentLoader;

#ifdef __cplusplus
	sp34Attachment() :
		name(0),
		type(SP_ATTACHMENT_REGION),
		vtable(0) {
	}
#endif
} sp34Attachment;

void sp34Attachment_dispose (sp34Attachment* self);

#ifdef SPINE_SHORT_NAMES
typedef sp34AttachmentType AttachmentType;
#define ATTACHMENT_REGION SP_ATTACHMENT_REGION
#define ATTACHMENT_BOUNDING_BOX SP_ATTACHMENT_BOUNDING_BOX
#define ATTACHMENT_MESH SP_ATTACHMENT_MESH
#define ATTACHMENT_LINKED_MESH SP_ATTACHMENT_LINKED_MESH
typedef sp34Attachment Attachment;
#define Attachment_dispose(...) sp34Attachment_dispose(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ATTACHMENT_H_ */

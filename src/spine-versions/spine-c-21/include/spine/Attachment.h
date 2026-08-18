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

#ifndef SPINE_ATTACHMENT_H_
#define SPINE_ATTACHMENT_H_

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
	SP_ATTACHMENT_REGION, SP_ATTACHMENT_BOUNDING_BOX, SP_ATTACHMENT_MESH, SP_ATTACHMENT_SKINNED_MESH
} sp21AttachmentType;

typedef struct sp21Attachment {
	const char* const name;
	const sp21AttachmentType type;
	const void* const vtable;

#ifdef __cplusplus
	sp21Attachment() :
		name(0),
		type(SP_ATTACHMENT_REGION),
		vtable(0) {
	}
#endif
} sp21Attachment;

void sp21Attachment_dispose (sp21Attachment* self);

#ifdef SPINE_SHORT_NAMES
typedef sp21AttachmentType AttachmentType;
#define ATTACHMENT_REGION SP_ATTACHMENT_REGION
#define ATTACHMENT_BOUNDING_BOX SP_ATTACHMENT_BOUNDING_BOX
#define ATTACHMENT_MESH SP_ATTACHMENT_MESH
#define ATTACHMENT_SKINNED_MESH SP_ATTACHMENT_SKINNED_MESH
typedef sp21Attachment Attachment;
#define Attachment_dispose(...) sp21Attachment_dispose(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ATTACHMENT_H_ */

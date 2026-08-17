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

#ifndef SPINE_SKELETONBINARY_H_
#define SPINE_SKELETONBINARY_H_

#include <spine/dll.h>
#include <spine/Attachment.h>
#include <spine/AttachmentLoader.h>
#include <spine/SkeletonData.h>
#include <spine/Atlas.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp37AtlasAttachmentLoader;

typedef struct sp37SkeletonBinary {
	float scale;
	sp37AttachmentLoader* attachmentLoader;
	const char* const error;
} sp37SkeletonBinary;

SP_API sp37SkeletonBinary* sp37SkeletonBinary_createWithLoader (sp37AttachmentLoader* attachmentLoader);
SP_API sp37SkeletonBinary* sp37SkeletonBinary_create (sp37Atlas* atlas);
SP_API void sp37SkeletonBinary_dispose (sp37SkeletonBinary* self);

SP_API sp37SkeletonData* sp37SkeletonBinary_readSkeletonData (sp37SkeletonBinary* self, const unsigned char* binary, const int length);
SP_API sp37SkeletonData* sp37SkeletonBinary_readSkeletonDataFile (sp37SkeletonBinary* self, const char* path);

#ifdef SPINE_SHORT_NAMES
typedef sp37SkeletonBinary SkeletonBinary;
#define SkeletonBinary_createWithLoader(...) sp37SkeletonBinary_createWithLoader(__VA_ARGS__)
#define SkeletonBinary_create(...) sp37SkeletonBinary_create(__VA_ARGS__)
#define SkeletonBinary_dispose(...) sp37SkeletonBinary_dispose(__VA_ARGS__)
#define SkeletonBinary_readSkeletonData(...) sp37SkeletonBinary_readSkeletonData(__VA_ARGS__)
#define SkeletonBinary_readSkeletonDataFile(...) sp37SkeletonBinary_readSkeletonDataFile(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONBINARY_H_ */

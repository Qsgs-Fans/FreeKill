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

struct sp36AtlasAttachmentLoader;

typedef struct sp36SkeletonBinary {
	float scale;
	sp36AttachmentLoader* attachmentLoader;
	const char* const error;
} sp36SkeletonBinary;

SP_API sp36SkeletonBinary* sp36SkeletonBinary_createWithLoader (sp36AttachmentLoader* attachmentLoader);
SP_API sp36SkeletonBinary* sp36SkeletonBinary_create (sp36Atlas* atlas);
SP_API void sp36SkeletonBinary_dispose (sp36SkeletonBinary* self);

SP_API sp36SkeletonData* sp36SkeletonBinary_readSkeletonData (sp36SkeletonBinary* self, const unsigned char* binary, const int length);
SP_API sp36SkeletonData* sp36SkeletonBinary_readSkeletonDataFile (sp36SkeletonBinary* self, const char* path);

#ifdef SPINE_SHORT_NAMES
typedef sp36SkeletonBinary SkeletonBinary;
#define SkeletonBinary_createWithLoader(...) sp36SkeletonBinary_createWithLoader(__VA_ARGS__)
#define SkeletonBinary_create(...) sp36SkeletonBinary_create(__VA_ARGS__)
#define SkeletonBinary_dispose(...) sp36SkeletonBinary_dispose(__VA_ARGS__)
#define SkeletonBinary_readSkeletonData(...) sp36SkeletonBinary_readSkeletonData(__VA_ARGS__)
#define SkeletonBinary_readSkeletonDataFile(...) sp36SkeletonBinary_readSkeletonDataFile(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONBINARY_H_ */

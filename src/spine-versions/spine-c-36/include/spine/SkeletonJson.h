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

#ifndef SPINE_SKELETONJSON_H_
#define SPINE_SKELETONJSON_H_

#include <spine/dll.h>
#include <spine/Attachment.h>
#include <spine/AttachmentLoader.h>
#include <spine/SkeletonData.h>
#include <spine/Atlas.h>
#include <spine/Animation.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp36AtlasAttachmentLoader;

typedef struct sp36SkeletonJson {
	float scale;
	sp36AttachmentLoader* attachmentLoader;
	const char* const error;
} sp36SkeletonJson;

SP_API sp36SkeletonJson* sp36SkeletonJson_createWithLoader (sp36AttachmentLoader* attachmentLoader);
SP_API sp36SkeletonJson* sp36SkeletonJson_create (sp36Atlas* atlas);
SP_API void sp36SkeletonJson_dispose (sp36SkeletonJson* self);

SP_API sp36SkeletonData* sp36SkeletonJson_readSkeletonData (sp36SkeletonJson* self, const char* json);
SP_API sp36SkeletonData* sp36SkeletonJson_readSkeletonDataFile (sp36SkeletonJson* self, const char* path);

#ifdef SPINE_SHORT_NAMES
typedef sp36SkeletonJson SkeletonJson;
#define SkeletonJson_createWithLoader(...) sp36SkeletonJson_createWithLoader(__VA_ARGS__)
#define SkeletonJson_create(...) sp36SkeletonJson_create(__VA_ARGS__)
#define SkeletonJson_dispose(...) sp36SkeletonJson_dispose(__VA_ARGS__)
#define SkeletonJson_readSkeletonData(...) sp36SkeletonJson_readSkeletonData(__VA_ARGS__)
#define SkeletonJson_readSkeletonDataFile(...) sp36SkeletonJson_readSkeletonDataFile(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONJSON_H_ */

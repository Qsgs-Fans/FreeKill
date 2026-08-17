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

#include <spine/Attachment.h>
#include <spine/AttachmentLoader.h>
#include <spine/SkeletonData.h>
#include <spine/Atlas.h>
#include <spine/Animation.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp34AtlasAttachmentLoader;

typedef struct sp34SkeletonJson {
	float scale;
	sp34AttachmentLoader* attachmentLoader;
	const char* const error;
} sp34SkeletonJson;

sp34SkeletonJson* sp34SkeletonJson_createWithLoader (sp34AttachmentLoader* attachmentLoader);
sp34SkeletonJson* sp34SkeletonJson_create (sp34Atlas* atlas);
void sp34SkeletonJson_dispose (sp34SkeletonJson* self);

sp34SkeletonData* sp34SkeletonJson_readSkeletonData (sp34SkeletonJson* self, const char* json);
sp34SkeletonData* sp34SkeletonJson_readSkeletonDataFile (sp34SkeletonJson* self, const char* path);

#ifdef SPINE_SHORT_NAMES
typedef sp34SkeletonJson SkeletonJson;
#define SkeletonJson_createWithLoader(...) sp34SkeletonJson_createWithLoader(__VA_ARGS__)
#define SkeletonJson_create(...) sp34SkeletonJson_create(__VA_ARGS__)
#define SkeletonJson_dispose(...) sp34SkeletonJson_dispose(__VA_ARGS__)
#define SkeletonJson_readSkeletonData(...) sp34SkeletonJson_readSkeletonData(__VA_ARGS__)
#define SkeletonJson_readSkeletonDataFile(...) sp34SkeletonJson_readSkeletonDataFile(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONJSON_H_ */

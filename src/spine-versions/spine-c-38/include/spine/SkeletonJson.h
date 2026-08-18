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

struct sp38AtlasAttachmentLoader;

typedef struct sp38SkeletonJson {
	float scale;
	sp38AttachmentLoader* attachmentLoader;
	const char* const error;
} sp38SkeletonJson;

SP_API sp38SkeletonJson* sp38SkeletonJson_createWithLoader (sp38AttachmentLoader* attachmentLoader);
SP_API sp38SkeletonJson* sp38SkeletonJson_create (sp38Atlas* atlas);
SP_API void sp38SkeletonJson_dispose (sp38SkeletonJson* self);

SP_API sp38SkeletonData* sp38SkeletonJson_readSkeletonData (sp38SkeletonJson* self, const char* json);
SP_API sp38SkeletonData* sp38SkeletonJson_readSkeletonDataFile (sp38SkeletonJson* self, const char* path);

#ifdef SPINE_SHORT_NAMES
typedef sp38SkeletonJson SkeletonJson;
#define SkeletonJson_createWithLoader(...) sp38SkeletonJson_createWithLoader(__VA_ARGS__)
#define SkeletonJson_create(...) sp38SkeletonJson_create(__VA_ARGS__)
#define SkeletonJson_dispose(...) sp38SkeletonJson_dispose(__VA_ARGS__)
#define SkeletonJson_readSkeletonData(...) sp38SkeletonJson_readSkeletonData(__VA_ARGS__)
#define SkeletonJson_readSkeletonDataFile(...) sp38SkeletonJson_readSkeletonDataFile(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONJSON_H_ */

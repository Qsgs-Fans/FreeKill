/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated July 28, 2023. Replaces all prior versions.
 *
 * Copyright (c) 2013-2023, Esoteric Software LLC
 *
 * Integration of the Spine Runtimes into software or otherwise creating
 * derivative works of the Spine Runtimes is permitted under the terms and
 * conditions of Section 2 of the Spine Editor License Agreement:
 * http://esotericsoftware.com/spine-editor-license
 *
 * Otherwise, it is permitted to integrate the Spine Runtimes into software or
 * otherwise create derivative works of the Spine Runtimes (collectively,
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
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE
 * SPINE RUNTIMES, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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

struct sp42AtlasAttachmentLoader;

typedef struct sp42SkeletonJson {
	float scale;
	sp42AttachmentLoader *attachmentLoader;
	char *error;
} sp42SkeletonJson;

SP_API sp42SkeletonJson *sp42SkeletonJson_createWithLoader(sp42AttachmentLoader *attachmentLoader);

SP_API sp42SkeletonJson *sp42SkeletonJson_create(sp42Atlas *atlas);

SP_API void sp42SkeletonJson_dispose(sp42SkeletonJson *self);

SP_API sp42SkeletonData *sp42SkeletonJson_readSkeletonData(sp42SkeletonJson *self, const char *json);

SP_API sp42SkeletonData *sp42SkeletonJson_readSkeletonDataFile(sp42SkeletonJson *self, const char *path);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONJSON_H_ */

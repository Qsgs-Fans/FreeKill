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

#ifndef SPINE_ANIMATIONSTATEDATA_H_
#define SPINE_ANIMATIONSTATEDATA_H_

#include <spine/dll.h>
#include <spine/Animation.h>
#include <spine/SkeletonData.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp38AnimationStateData {
	sp38SkeletonData* const skeletonData;
	float defaultMix;
	const void* const entries;

#ifdef __cplusplus
	sp38AnimationStateData() :
		skeletonData(0),
		defaultMix(0),
		entries(0) {
	}
#endif
} sp38AnimationStateData;

SP_API sp38AnimationStateData* sp38AnimationStateData_create (sp38SkeletonData* skeletonData);
SP_API void sp38AnimationStateData_dispose (sp38AnimationStateData* self);

SP_API void sp38AnimationStateData_setMixByName (sp38AnimationStateData* self, const char* fromName, const char* toName, float duration);
SP_API void sp38AnimationStateData_setMix (sp38AnimationStateData* self, sp38Animation* from, sp38Animation* to, float duration);
/* Returns 0 if there is no mixing between the animations. */
SP_API float sp38AnimationStateData_getMix (sp38AnimationStateData* self, sp38Animation* from, sp38Animation* to);

#ifdef SPINE_SHORT_NAMES
typedef sp38AnimationStateData AnimationStateData;
#define AnimationStateData_create(...) sp38AnimationStateData_create(__VA_ARGS__)
#define AnimationStateData_dispose(...) sp38AnimationStateData_dispose(__VA_ARGS__)
#define AnimationStateData_setMixByName(...) sp38AnimationStateData_setMixByName(__VA_ARGS__)
#define AnimationStateData_setMix(...) sp38AnimationStateData_setMix(__VA_ARGS__)
#define AnimationStateData_getMix(...) sp38AnimationStateData_getMix(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATIONSTATEDATA_H_ */

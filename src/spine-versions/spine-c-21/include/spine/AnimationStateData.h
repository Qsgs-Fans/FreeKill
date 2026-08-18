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

#ifndef SPINE_ANIMATIONSTATEDATA_H_
#define SPINE_ANIMATIONSTATEDATA_H_

#include <spine/Animation.h>
#include <spine/SkeletonData.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp21AnimationStateData {
	sp21SkeletonData* const skeletonData;
	float defaultMix;
	const void* const entries;

#ifdef __cplusplus
	sp21AnimationStateData() :
		skeletonData(0),
		defaultMix(0),
		entries(0) {
	}
#endif
} sp21AnimationStateData;

sp21AnimationStateData* sp21AnimationStateData_create (sp21SkeletonData* skeletonData);
void sp21AnimationStateData_dispose (sp21AnimationStateData* self);

void sp21AnimationStateData_setMixByName (sp21AnimationStateData* self, const char* fromName, const char* toName, float duration);
void sp21AnimationStateData_setMix (sp21AnimationStateData* self, sp21Animation* from, sp21Animation* to, float duration);
/* Returns 0 if there is no mixing between the animations. */
float sp21AnimationStateData_getMix (sp21AnimationStateData* self, sp21Animation* from, sp21Animation* to);

#ifdef SPINE_SHORT_NAMES
typedef sp21AnimationStateData AnimationStateData;
#define AnimationStateData_create(...) sp21AnimationStateData_create(__VA_ARGS__)
#define AnimationStateData_dispose(...) sp21AnimationStateData_dispose(__VA_ARGS__)
#define AnimationStateData_setMixByName(...) sp21AnimationStateData_setMixByName(__VA_ARGS__)
#define AnimationStateData_setMix(...) sp21AnimationStateData_setMix(__VA_ARGS__)
#define AnimationStateData_getMix(...) sp21AnimationStateData_getMix(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATIONSTATEDATA_H_ */

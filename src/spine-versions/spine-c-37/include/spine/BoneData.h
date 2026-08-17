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

#ifndef SPINE_BONEDATA_H_
#define SPINE_BONEDATA_H_

#include <spine/dll.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
	SP_TRANSFORMMODE_NORMAL,
	SP_TRANSFORMMODE_ONLYTRANSLATION,
	SP_TRANSFORMMODE_NOROTATIONORREFLECTION,
	SP_TRANSFORMMODE_NOSCALE,
	SP_TRANSFORMMODE_NOSCALEORREFLECTION
} sp37TransformMode;

typedef struct sp37BoneData sp37BoneData;
struct sp37BoneData {
	const int index;
	const char* const name;
	sp37BoneData* const parent;
	float length;
	float x, y, rotation, scaleX, scaleY, shearX, shearY;
	sp37TransformMode transformMode;

#ifdef __cplusplus
	sp37BoneData() :
		index(0),
		name(0),
		parent(0),
		length(0),
		x(0), y(0),
		rotation(0),
		scaleX(0), scaleY(0),
		shearX(0), shearY(0),
		transformMode(SP_TRANSFORMMODE_NORMAL) {
	}
#endif
};

SP_API sp37BoneData* sp37BoneData_create (int index, const char* name, sp37BoneData* parent);
SP_API void sp37BoneData_dispose (sp37BoneData* self);

#ifdef SPINE_SHORT_NAMES
typedef sp37BoneData BoneData;
#define BoneData_create(...) sp37BoneData_create(__VA_ARGS__)
#define BoneData_dispose(...) sp37BoneData_dispose(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_BONEDATA_H_ */

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

#ifndef SPINE_BONEDATA_H_
#define SPINE_BONEDATA_H_

#include <spine/dll.h>
#include <spine/Color.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
	SP_INHERIT_NORMAL,
	SP_INHERIT_ONLYTRANSLATION,
	SP_INHERIT_NOROTATIONORREFLECTION,
	SP_INHERIT_NOSCALE,
	SP_INHERIT_NOSCALEORREFLECTION
} sp42Inherit;

typedef struct sp42BoneData sp42BoneData;
struct sp42BoneData {
	int index;
	char *name;
	sp42BoneData *parent;
	float length;
	float x, y, rotation, scaleX, scaleY, shearX, shearY;
	sp42Inherit inherit;
	int/*bool*/ skinRequired;
	sp42Color color;
    const char *icon;
    int/*bool*/ visible;
};

SP_API sp42BoneData *sp42BoneData_create(int index, const char *name, sp42BoneData *parent);

SP_API void sp42BoneData_dispose(sp42BoneData *self);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_BONEDATA_H_ */

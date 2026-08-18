/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated September 24, 2021. Replaces all prior versions.
 *
 * Copyright (c) 2013-2021, Esoteric Software LLC
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

#ifndef SPINE_PATHCONSTRAINTDATA_H_
#define SPINE_PATHCONSTRAINTDATA_H_

#include <spine/dll.h>
#include <spine/BoneData.h>
#include <spine/SlotData.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
	SP_POSITION_MODE_FIXED, SP_POSITION_MODE_PERCENT
} sp41PositionMode;

typedef enum {
	SP_SPACING_MODE_LENGTH, SP_SPACING_MODE_FIXED, SP_SPACING_MODE_PERCENT, SP_SPACING_MODE_PROPORTIONAL
} sp41SpacingMode;

typedef enum {
	SP_ROTATE_MODE_TANGENT, SP_ROTATE_MODE_CHAIN, SP_ROTATE_MODE_CHAIN_SCALE
} sp41RotateMode;

typedef struct sp41PathConstraintData {
	const char *const name;
	int order;
	int/*bool*/ skinRequired;
	int bonesCount;
	sp41BoneData **const bones;
	sp41SlotData *target;
	sp41PositionMode positionMode;
	sp41SpacingMode spacingMode;
	sp41RotateMode rotateMode;
	float offsetRotation;
	float position, spacing;
	float mixRotate, mixX, mixY;
} sp41PathConstraintData;

SP_API sp41PathConstraintData *sp41PathConstraintData_create(const char *name);

SP_API void sp41PathConstraintData_dispose(sp41PathConstraintData *self);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_PATHCONSTRAINTDATA_H_ */

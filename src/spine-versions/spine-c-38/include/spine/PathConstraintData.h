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
} sp38PositionMode;

typedef enum {
	SP_SPACING_MODE_LENGTH, SP_SPACING_MODE_FIXED, SP_SPACING_MODE_PERCENT
} sp38SpacingMode;

typedef enum {
	SP_ROTATE_MODE_TANGENT, SP_ROTATE_MODE_CHAIN, SP_ROTATE_MODE_CHAIN_SCALE
} sp38RotateMode;

typedef struct sp38PathConstraintData {
	const char* const name;
	int order;
	int/*bool*/ skinRequired;
	int bonesCount;
	sp38BoneData** const bones;
	sp38SlotData* target;
	sp38PositionMode positionMode;
	sp38SpacingMode spacingMode;
	sp38RotateMode rotateMode;
	float offsetRotation;
	float position, spacing, rotateMix, translateMix;

#ifdef __cplusplus
	sp38PathConstraintData() :
		name(0),
		order(0),
		skinRequired(0),
		bonesCount(0),
		bones(0),
		target(0),
		positionMode(SP_POSITION_MODE_FIXED),
		spacingMode(SP_SPACING_MODE_LENGTH),
		rotateMode(SP_ROTATE_MODE_TANGENT),
		offsetRotation(0),
		position(0),
		spacing(0),
		rotateMix(0),
		translateMix(0) {
	}
#endif
} sp38PathConstraintData;

SP_API sp38PathConstraintData* sp38PathConstraintData_create (const char* name);
SP_API void sp38PathConstraintData_dispose (sp38PathConstraintData* self);

#ifdef SPINE_SHORT_NAMES
typedef sp38PathConstraintData PathConstraintData;
#define PathConstraintData_create(...) sp38PathConstraintData_create(__VA_ARGS__)
#define PathConstraintData_dispose(...) sp38PathConstraintData_dispose(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_PATHCONSTRAINTDATA_H_ */

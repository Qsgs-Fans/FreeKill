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

#ifndef SPINE_PATHCONSTRAINT_H_
#define SPINE_PATHCONSTRAINT_H_

#include <spine/dll.h>
#include <spine/PathConstraintData.h>
#include <spine/Bone.h>
#include <spine/Slot.h>
#include "PathAttachment.h"

#ifdef __cplusplus
extern "C" {
#endif

struct sp37Skeleton;

typedef struct sp37PathConstraint {
	sp37PathConstraintData* const data;
	int bonesCount;
	sp37Bone** const bones;
	sp37Slot* target;
	float position, spacing, rotateMix, translateMix;

	int spacesCount;
	float* spaces;

	int positionsCount;
	float* positions;

	int worldCount;
	float* world;

	int curvesCount;
	float* curves;

	int lengthsCount;
	float* lengths;

	float segments[10];

#ifdef __cplusplus
	sp37PathConstraint() :
		data(0),
		bonesCount(0),
		bones(0),
		target(0),
		position(0),
		spacing(0),
		rotateMix(0),
		translateMix(0),
		spacesCount(0),
		spaces(0),
		positionsCount(0),
		positions(0),
		worldCount(0),
		world(0),
		curvesCount(0),
		curves(0),
		lengthsCount(0),
		lengths(0) {
	}
#endif
} sp37PathConstraint;

#define SP_PATHCONSTRAINT_

SP_API sp37PathConstraint* sp37PathConstraint_create (sp37PathConstraintData* data, const struct sp37Skeleton* skeleton);
SP_API void sp37PathConstraint_dispose (sp37PathConstraint* self);

SP_API void sp37PathConstraint_apply (sp37PathConstraint* self);
SP_API float* sp37PathConstraint_computeWorldPositions(sp37PathConstraint* self, sp37PathAttachment* path, int spacesCount, int/*bool*/ tangents, int/*bool*/percentPosition, int/**/percentSpacing);

#ifdef SPINE_SHORT_NAMES
typedef sp37PathConstraint PathConstraint;
#define PathConstraint_create(...) sp37PathConstraint_create(__VA_ARGS__)
#define PathConstraint_dispose(...) sp37PathConstraint_dispose(__VA_ARGS__)
#define PathConstraint_apply(...) sp37PathConstraint_apply(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_PATHCONSTRAINT_H_ */

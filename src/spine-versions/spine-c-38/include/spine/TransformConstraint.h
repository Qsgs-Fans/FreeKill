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

#ifndef SPINE_TRANSFORMCONSTRAINT_H_
#define SPINE_TRANSFORMCONSTRAINT_H_

#include <spine/dll.h>
#include <spine/TransformConstraintData.h>
#include <spine/Bone.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp38Skeleton;

typedef struct sp38TransformConstraint {
	sp38TransformConstraintData* const data;
	int bonesCount;
	sp38Bone** const bones;
	sp38Bone* target;
	float rotateMix, translateMix, scaleMix, shearMix;
	int /*boolean*/ active;

#ifdef __cplusplus
	sp38TransformConstraint() :
		data(0),
		bonesCount(0),
		bones(0),
		target(0),
		rotateMix(0),
		translateMix(0),
		scaleMix(0),
		shearMix(0),
		active(0) {
	}
#endif
} sp38TransformConstraint;

SP_API sp38TransformConstraint* sp38TransformConstraint_create (sp38TransformConstraintData* data, const struct sp38Skeleton* skeleton);
SP_API void sp38TransformConstraint_dispose (sp38TransformConstraint* self);

SP_API void sp38TransformConstraint_apply (sp38TransformConstraint* self);

#ifdef SPINE_SHORT_NAMES
typedef sp38TransformConstraint TransformConstraint;
#define TransformConstraint_create(...) sp38TransformConstraint_create(__VA_ARGS__)
#define TransformConstraint_dispose(...) sp38TransformConstraint_dispose(__VA_ARGS__)
#define TransformConstraint_apply(...) sp38TransformConstraint_apply(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_TRANSFORMCONSTRAINT_H_ */

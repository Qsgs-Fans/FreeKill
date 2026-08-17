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

#ifndef SPINE_TRANSFORMCONSTRAINT_H_
#define SPINE_TRANSFORMCONSTRAINT_H_

#include <spine/dll.h>
#include <spine/TransformConstraintData.h>
#include <spine/Bone.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp37Skeleton;

typedef struct sp37TransformConstraint {
	sp37TransformConstraintData* const data;
	int bonesCount;
	sp37Bone** const bones;
	sp37Bone* target;
	float rotateMix, translateMix, scaleMix, shearMix;

#ifdef __cplusplus
	sp37TransformConstraint() :
		data(0),
		bonesCount(0),
		bones(0),
		target(0),
		rotateMix(0),
		translateMix(0),
		scaleMix(0),
		shearMix(0) {
	}
#endif
} sp37TransformConstraint;

SP_API sp37TransformConstraint* sp37TransformConstraint_create (sp37TransformConstraintData* data, const struct sp37Skeleton* skeleton);
SP_API void sp37TransformConstraint_dispose (sp37TransformConstraint* self);

SP_API void sp37TransformConstraint_apply (sp37TransformConstraint* self);

#ifdef SPINE_SHORT_NAMES
typedef sp37TransformConstraint TransformConstraint;
#define TransformConstraint_create(...) sp37TransformConstraint_create(__VA_ARGS__)
#define TransformConstraint_dispose(...) sp37TransformConstraint_dispose(__VA_ARGS__)
#define TransformConstraint_apply(...) sp37TransformConstraint_apply(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_TRANSFORMCONSTRAINT_H_ */

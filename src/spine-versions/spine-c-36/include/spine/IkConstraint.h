/******************************************************************************
 * Spine Runtimes Software License v2.5
 *
 * Copyright (c) 2013-2016, Esoteric Software
 * All rights reserved.
 *
 * You are granted a perpetual, non-exclusive, non-sublicensable, and
 * non-transferable license to use, install, execute, and perform the Spine
 * Runtimes software and derivative works solely for personal or internal
 * use. Without the written permission of Esoteric Software (see Section 2 of
 * the Spine Software License Agreement), you may not (a) modify, translate,
 * adapt, or develop new applications using the Spine Runtimes or otherwise
 * create derivative works or improvements of the Spine Runtimes or (b) remove,
 * delete, alter, or obscure any trademarks or any copyright, trademark, patent,
 * or other intellectual property or proprietary rights notices on or in the
 * Software, including any copy thereof. Redistributions in binary or source
 * form must include this license and terms.
 *
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, BUSINESS INTERRUPTION, OR LOSS OF
 * USE, DATA, OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 * IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#ifndef SPINE_IKCONSTRAINT_H_
#define SPINE_IKCONSTRAINT_H_

#include <spine/dll.h>
#include <spine/IkConstraintData.h>
#include <spine/Bone.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp36Skeleton;

typedef struct sp36IkConstraint {
	sp36IkConstraintData* const data;

	int bonesCount;
	sp36Bone** bones;

	sp36Bone* target;
	int bendDirection;
	float mix;

#ifdef __cplusplus
	sp36IkConstraint() :
		data(0),
		bonesCount(0),
		bones(0),
		target(0),
		bendDirection(0),
		mix(0) {
	}
#endif
} sp36IkConstraint;

SP_API sp36IkConstraint* sp36IkConstraint_create (sp36IkConstraintData* data, const struct sp36Skeleton* skeleton);
SP_API void sp36IkConstraint_dispose (sp36IkConstraint* self);

SP_API void sp36IkConstraint_apply (sp36IkConstraint* self);

SP_API void sp36IkConstraint_apply1 (sp36Bone* bone, float targetX, float targetY, float alpha);
SP_API void sp36IkConstraint_apply2 (sp36Bone* parent, sp36Bone* child, float targetX, float targetY, int bendDirection, float alpha);

#ifdef SPINE_SHORT_NAMES
typedef sp36IkConstraint IkConstraint;
#define IkConstraint_create(...) sp36IkConstraint_create(__VA_ARGS__)
#define IkConstraint_dispose(...) sp36IkConstraint_dispose(__VA_ARGS__)
#define IkConstraint_apply(...) sp36IkConstraint_apply(__VA_ARGS__)
#define IkConstraint_apply1(...) sp36IkConstraint_apply1(__VA_ARGS__)
#define IkConstraint_apply2(...) sp36IkConstraint_apply2(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_IKCONSTRAINT_H_ */

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

#ifndef SPINE_IKCONSTRAINT_H_
#define SPINE_IKCONSTRAINT_H_

#include <spine/dll.h>
#include <spine/IkConstraintData.h>
#include <spine/Bone.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp37Skeleton;

typedef struct sp37IkConstraint {
	sp37IkConstraintData* const data;

	int bonesCount;
	sp37Bone** bones;

	sp37Bone* target;
	int bendDirection;
	int /*boolean*/ compress;
	int /*boolean*/ stretch;
	float mix;

#ifdef __cplusplus
	sp37IkConstraint() :
		data(0),
		bonesCount(0),
		bones(0),
		target(0),
		bendDirection(0),
		stretch(0),
		mix(0) {
	}
#endif
} sp37IkConstraint;

SP_API sp37IkConstraint* sp37IkConstraint_create (sp37IkConstraintData* data, const struct sp37Skeleton* skeleton);
SP_API void sp37IkConstraint_dispose (sp37IkConstraint* self);

SP_API void sp37IkConstraint_apply (sp37IkConstraint* self);

SP_API void sp37IkConstraint_apply1 (sp37Bone* bone, float targetX, float targetY, int /*boolean*/ compress, int /*boolean*/ stretch, int /*boolean*/ uniform, float alpha);
SP_API void sp37IkConstraint_apply2 (sp37Bone* parent, sp37Bone* child, float targetX, float targetY, int bendDirection, int /*boolean*/ stretch, float alpha);

#ifdef SPINE_SHORT_NAMES
typedef sp37IkConstraint IkConstraint;
#define IkConstraint_create(...) sp37IkConstraint_create(__VA_ARGS__)
#define IkConstraint_dispose(...) sp37IkConstraint_dispose(__VA_ARGS__)
#define IkConstraint_apply(...) sp37IkConstraint_apply(__VA_ARGS__)
#define IkConstraint_apply1(...) sp37IkConstraint_apply1(__VA_ARGS__)
#define IkConstraint_apply2(...) sp37IkConstraint_apply2(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_IKCONSTRAINT_H_ */

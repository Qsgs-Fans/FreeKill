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

#ifndef SPINE_IKCONSTRAINT_H_
#define SPINE_IKCONSTRAINT_H_

#include <spine/IkConstraintData.h>
#include <spine/Bone.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp21Skeleton;

typedef struct sp21IkConstraint {
	sp21IkConstraintData* const data;
	
	int bonesCount;
	sp21Bone** bones;
	
	sp21Bone* target;
	int bendDirection;
	float mix;

#ifdef __cplusplus
	sp21IkConstraint() :
		data(0),
		bonesCount(0),
		bones(0),
		target(0),
		bendDirection(0),
		mix(0) {
	}
#endif
} sp21IkConstraint;

sp21IkConstraint* sp21IkConstraint_create (sp21IkConstraintData* data, const struct sp21Skeleton* skeleton);
void sp21IkConstraint_dispose (sp21IkConstraint* self);

void sp21IkConstraint_apply (sp21IkConstraint* self);

void sp21IkConstraint_apply1 (sp21Bone* bone, float targetX, float targetY, float alpha);
void sp21IkConstraint_apply2 (sp21Bone* parent, sp21Bone* child, float targetX, float targetY, int bendDirection, float alpha);

#ifdef SPINE_SHORT_NAMES
typedef sp21IkConstraint IkConstraint;
#define IkConstraint_create(...) sp21IkConstraint_create(__VA_ARGS__)
#define IkConstraint_dispose(...) sp21IkConstraint_dispose(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_IKCONSTRAINT_H_ */

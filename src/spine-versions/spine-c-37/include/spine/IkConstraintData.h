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

#ifndef SPINE_IKCONSTRAINTDATA_H_
#define SPINE_IKCONSTRAINTDATA_H_

#include <spine/dll.h>
#include <spine/BoneData.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp37IkConstraintData {
	const char* const name;
	int order;
	int bonesCount;
	sp37BoneData** bones;

	sp37BoneData* target;
	int bendDirection;
	int /*boolean*/ compress;
	int /*boolean*/ stretch;
	int /*boolean*/ uniform;
	float mix;

#ifdef __cplusplus
	sp37IkConstraintData() :
		name(0),
		bonesCount(0),
		bones(0),
		target(0),
		bendDirection(0),
		compress(0),
		stretch(0),
		uniform(0),
		mix(0) {
	}
#endif
} sp37IkConstraintData;

SP_API sp37IkConstraintData* sp37IkConstraintData_create (const char* name);
SP_API void sp37IkConstraintData_dispose (sp37IkConstraintData* self);

#ifdef SPINE_SHORT_NAMES
typedef sp37IkConstraintData IkConstraintData;
#define IkConstraintData_create(...) sp37IkConstraintData_create(__VA_ARGS__)
#define IkConstraintData_dispose(...) sp37IkConstraintData_dispose(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_IKCONSTRAINTDATA_H_ */

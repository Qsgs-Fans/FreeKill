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

#ifndef SPINE_BONE_H_
#define SPINE_BONE_H_

#include <spine/dll.h>
#include <spine/BoneData.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp38Skeleton;

typedef struct sp38Bone sp38Bone;
struct sp38Bone {
	sp38BoneData* const data;
	struct sp38Skeleton* const skeleton;
	sp38Bone* const parent;
	int childrenCount;
	sp38Bone** const children;
	float x, y, rotation, scaleX, scaleY, shearX, shearY;
	float ax, ay, arotation, ascaleX, ascaleY, ashearX, ashearY;
	int /*bool*/ appliedValid;

	float const a, b, worldX;
	float const c, d, worldY;

	int/*bool*/ sorted;
	int/*bool*/ active;

#ifdef __cplusplus
	sp38Bone() :
		data(0),
		skeleton(0),
		parent(0),
		childrenCount(0), children(0),
		x(0), y(0), rotation(0), scaleX(0), scaleY(0),
		ax(0), ay(0), arotation(0), ascaleX(0), ascaleY(0), ashearX(0), ashearY(0),
		appliedValid(0),

		a(0), b(0), worldX(0),
		c(0), d(0), worldY(0),

		sorted(0), active(0) {
	}
#endif
};

SP_API void sp38Bone_setYDown (int/*bool*/yDown);
SP_API int/*bool*/sp38Bone_isYDown ();

/* @param parent May be 0. */
SP_API sp38Bone* sp38Bone_create (sp38BoneData* data, struct sp38Skeleton* skeleton, sp38Bone* parent);
SP_API void sp38Bone_dispose (sp38Bone* self);

SP_API void sp38Bone_setToSetupPose (sp38Bone* self);

SP_API void sp38Bone_updateWorldTransform (sp38Bone* self);
SP_API void sp38Bone_updateWorldTransformWith (sp38Bone* self, float x, float y, float rotation, float scaleX, float scaleY, float shearX, float shearY);

SP_API float sp38Bone_getWorldRotationX (sp38Bone* self);
SP_API float sp38Bone_getWorldRotationY (sp38Bone* self);
SP_API float sp38Bone_getWorldScaleX (sp38Bone* self);
SP_API float sp38Bone_getWorldScaleY (sp38Bone* self);

SP_API void sp38Bone_updateAppliedTransform (sp38Bone* self);

SP_API void sp38Bone_worldToLocal (sp38Bone* self, float worldX, float worldY, float* localX, float* localY);
SP_API void sp38Bone_localToWorld (sp38Bone* self, float localX, float localY, float* worldX, float* worldY);
SP_API float sp38Bone_worldToLocalRotation (sp38Bone* self, float worldRotation);
SP_API float sp38Bone_localToWorldRotation (sp38Bone* self, float localRotation);
SP_API void sp38Bone_rotateWorld (sp38Bone* self, float degrees);

#ifdef SPINE_SHORT_NAMES
typedef sp38Bone Bone;
#define Bone_setYDown(...) sp38Bone_setYDown(__VA_ARGS__)
#define Bone_isYDown() sp38Bone_isYDown()
#define Bone_create(...) sp38Bone_create(__VA_ARGS__)
#define Bone_dispose(...) sp38Bone_dispose(__VA_ARGS__)
#define Bone_setToSetupPose(...) sp38Bone_setToSetupPose(__VA_ARGS__)
#define Bone_updateWorldTransform(...) sp38Bone_updateWorldTransform(__VA_ARGS__)
#define Bone_updateWorldTransformWith(...) sp38Bone_updateWorldTransformWith(__VA_ARGS__)
#define Bone_getWorldRotationX(...) sp38Bone_getWorldRotationX(__VA_ARGS__)
#define Bone_getWorldRotationY(...) sp38Bone_getWorldRotationY(__VA_ARGS__)
#define Bone_getWorldScaleX(...) sp38Bone_getWorldScaleX(__VA_ARGS__)
#define Bone_getWorldScaleY(...) sp38Bone_getWorldScaleY(__VA_ARGS__)
#define Bone_updateAppliedTransform(...) sp38Bone_updateAppliedTransform(__VA_ARGS__)
#define Bone_worldToLocal(...) sp38Bone_worldToLocal(__VA_ARGS__)
#define Bone_localToWorld(...) sp38Bone_localToWorld(__VA_ARGS__)
#define Bone_worldToLocalRotation(...) sp38Bone_worldToLocalRotation(__VA_ARGS__)
#define Bone_localToWorldRotation(...) sp38Bone_localToWorldRotation(__VA_ARGS__)
#define Bone_rotateWorld(...) sp38Bone_rotateWorld(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_BONE_H_ */

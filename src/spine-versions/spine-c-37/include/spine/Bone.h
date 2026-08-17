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

#ifndef SPINE_BONE_H_
#define SPINE_BONE_H_

#include <spine/dll.h>
#include <spine/BoneData.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp37Skeleton;

typedef struct sp37Bone sp37Bone;
struct sp37Bone {
	sp37BoneData* const data;
	struct sp37Skeleton* const skeleton;
	sp37Bone* const parent;
	int childrenCount;
	sp37Bone** const children;
	float x, y, rotation, scaleX, scaleY, shearX, shearY;
	float ax, ay, arotation, ascaleX, ascaleY, ashearX, ashearY;
	int /*bool*/ appliedValid;

	float const a, b, worldX;
	float const c, d, worldY;

	int/*bool*/ sorted;

#ifdef __cplusplus
	sp37Bone() :
		data(0),
		skeleton(0),
		parent(0),
		childrenCount(0), children(0),
		x(0), y(0), rotation(0), scaleX(0), scaleY(0),
		ax(0), ay(0), arotation(0), ascaleX(0), ascaleY(0), ashearX(0), ashearY(0),
		appliedValid(0),

		a(0), b(0), worldX(0),
		c(0), d(0), worldY(0),

		sorted(0) {
	}
#endif
};

SP_API void sp37Bone_setYDown (int/*bool*/yDown);
SP_API int/*bool*/sp37Bone_isYDown ();

/* @param parent May be 0. */
SP_API sp37Bone* sp37Bone_create (sp37BoneData* data, struct sp37Skeleton* skeleton, sp37Bone* parent);
SP_API void sp37Bone_dispose (sp37Bone* self);

SP_API void sp37Bone_setToSetupPose (sp37Bone* self);

SP_API void sp37Bone_updateWorldTransform (sp37Bone* self);
SP_API void sp37Bone_updateWorldTransformWith (sp37Bone* self, float x, float y, float rotation, float scaleX, float scaleY, float shearX, float shearY);

SP_API float sp37Bone_getWorldRotationX (sp37Bone* self);
SP_API float sp37Bone_getWorldRotationY (sp37Bone* self);
SP_API float sp37Bone_getWorldScaleX (sp37Bone* self);
SP_API float sp37Bone_getWorldScaleY (sp37Bone* self);

SP_API void sp37Bone_updateAppliedTransform (sp37Bone* self);

SP_API void sp37Bone_worldToLocal (sp37Bone* self, float worldX, float worldY, float* localX, float* localY);
SP_API void sp37Bone_localToWorld (sp37Bone* self, float localX, float localY, float* worldX, float* worldY);
SP_API float sp37Bone_worldToLocalRotation (sp37Bone* self, float worldRotation);
SP_API float sp37Bone_localToWorldRotation (sp37Bone* self, float localRotation);
SP_API void sp37Bone_rotateWorld (sp37Bone* self, float degrees);

#ifdef SPINE_SHORT_NAMES
typedef sp37Bone Bone;
#define Bone_setYDown(...) sp37Bone_setYDown(__VA_ARGS__)
#define Bone_isYDown() sp37Bone_isYDown()
#define Bone_create(...) sp37Bone_create(__VA_ARGS__)
#define Bone_dispose(...) sp37Bone_dispose(__VA_ARGS__)
#define Bone_setToSetupPose(...) sp37Bone_setToSetupPose(__VA_ARGS__)
#define Bone_updateWorldTransform(...) sp37Bone_updateWorldTransform(__VA_ARGS__)
#define Bone_updateWorldTransformWith(...) sp37Bone_updateWorldTransformWith(__VA_ARGS__)
#define Bone_getWorldRotationX(...) sp37Bone_getWorldRotationX(__VA_ARGS__)
#define Bone_getWorldRotationY(...) sp37Bone_getWorldRotationY(__VA_ARGS__)
#define Bone_getWorldScaleX(...) sp37Bone_getWorldScaleX(__VA_ARGS__)
#define Bone_getWorldScaleY(...) sp37Bone_getWorldScaleY(__VA_ARGS__)
#define Bone_updateAppliedTransform(...) sp37Bone_updateAppliedTransform(__VA_ARGS__)
#define Bone_worldToLocal(...) sp37Bone_worldToLocal(__VA_ARGS__)
#define Bone_localToWorld(...) sp37Bone_localToWorld(__VA_ARGS__)
#define Bone_worldToLocalRotation(...) sp37Bone_worldToLocalRotation(__VA_ARGS__)
#define Bone_localToWorldRotation(...) sp37Bone_localToWorldRotation(__VA_ARGS__)
#define Bone_rotateWorld(...) sp37Bone_rotateWorld(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_BONE_H_ */

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

#ifndef SPINE_BONE_H_
#define SPINE_BONE_H_

#include <spine/dll.h>
#include <spine/BoneData.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp36Skeleton;

typedef struct sp36Bone sp36Bone;
struct sp36Bone {
	sp36BoneData* const data;
	struct sp36Skeleton* const skeleton;
	sp36Bone* const parent;
	int childrenCount;
	sp36Bone** const children;
	float x, y, rotation, scaleX, scaleY, shearX, shearY;
	float ax, ay, arotation, ascaleX, ascaleY, ashearX, ashearY;
	int /*bool*/ appliedValid;

	float const a, b, worldX;
	float const c, d, worldY;

	int/*bool*/ sorted;

#ifdef __cplusplus
	sp36Bone() :
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

SP_API void sp36Bone_setYDown (int/*bool*/yDown);
SP_API int/*bool*/sp36Bone_isYDown ();

/* @param parent May be 0. */
SP_API sp36Bone* sp36Bone_create (sp36BoneData* data, struct sp36Skeleton* skeleton, sp36Bone* parent);
SP_API void sp36Bone_dispose (sp36Bone* self);

SP_API void sp36Bone_setToSetupPose (sp36Bone* self);

SP_API void sp36Bone_updateWorldTransform (sp36Bone* self);
SP_API void sp36Bone_updateWorldTransformWith (sp36Bone* self, float x, float y, float rotation, float scaleX, float scaleY, float shearX, float shearY);

SP_API float sp36Bone_getWorldRotationX (sp36Bone* self);
SP_API float sp36Bone_getWorldRotationY (sp36Bone* self);
SP_API float sp36Bone_getWorldScaleX (sp36Bone* self);
SP_API float sp36Bone_getWorldScaleY (sp36Bone* self);

SP_API void sp36Bone_updateAppliedTransform (sp36Bone* self);

SP_API void sp36Bone_worldToLocal (sp36Bone* self, float worldX, float worldY, float* localX, float* localY);
SP_API void sp36Bone_localToWorld (sp36Bone* self, float localX, float localY, float* worldX, float* worldY);
SP_API float sp36Bone_worldToLocalRotation (sp36Bone* self, float worldRotation);
SP_API float sp36Bone_localToWorldRotation (sp36Bone* self, float localRotation);
SP_API void sp36Bone_rotateWorld (sp36Bone* self, float degrees);

#ifdef SPINE_SHORT_NAMES
typedef sp36Bone Bone;
#define Bone_setYDown(...) sp36Bone_setYDown(__VA_ARGS__)
#define Bone_isYDown() sp36Bone_isYDown()
#define Bone_create(...) sp36Bone_create(__VA_ARGS__)
#define Bone_dispose(...) sp36Bone_dispose(__VA_ARGS__)
#define Bone_setToSetupPose(...) sp36Bone_setToSetupPose(__VA_ARGS__)
#define Bone_updateWorldTransform(...) sp36Bone_updateWorldTransform(__VA_ARGS__)
#define Bone_updateWorldTransformWith(...) sp36Bone_updateWorldTransformWith(__VA_ARGS__)
#define Bone_getWorldRotationX(...) sp36Bone_getWorldRotationX(__VA_ARGS__)
#define Bone_getWorldRotationY(...) sp36Bone_getWorldRotationY(__VA_ARGS__)
#define Bone_getWorldScaleX(...) sp36Bone_getWorldScaleX(__VA_ARGS__)
#define Bone_getWorldScaleY(...) sp36Bone_getWorldScaleY(__VA_ARGS__)
#define Bone_updateAppliedTransform(...) sp36Bone_updateAppliedTransform(__VA_ARGS__)
#define Bone_worldToLocal(...) sp36Bone_worldToLocal(__VA_ARGS__)
#define Bone_localToWorld(...) sp36Bone_localToWorld(__VA_ARGS__)
#define Bone_worldToLocalRotation(...) sp36Bone_worldToLocalRotation(__VA_ARGS__)
#define Bone_localToWorldRotation(...) sp36Bone_localToWorldRotation(__VA_ARGS__)
#define Bone_rotateWorld(...) sp36Bone_rotateWorld(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_BONE_H_ */

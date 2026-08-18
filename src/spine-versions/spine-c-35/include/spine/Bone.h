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

#include <spine/BoneData.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp35Skeleton;

typedef struct sp35Bone sp35Bone;
struct sp35Bone {
	sp35BoneData* const data;
	struct sp35Skeleton* const skeleton;
	sp35Bone* const parent;
	int childrenCount;
	sp35Bone** const children;
	float x, y, rotation, scaleX, scaleY, shearX, shearY;
	float ax, ay, arotation, ascaleX, ascaleY, ashearX, ashearY;
	int /*bool*/ appliedValid;

	float const a, b, worldX;
	float const c, d, worldY;

	int/*bool*/ sorted;

#ifdef __cplusplus
	sp35Bone() :
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

void sp35Bone_setYDown (int/*bool*/yDown);
int/*bool*/sp35Bone_isYDown ();

/* @param parent May be 0. */
sp35Bone* sp35Bone_create (sp35BoneData* data, struct sp35Skeleton* skeleton, sp35Bone* parent);
void sp35Bone_dispose (sp35Bone* self);

void sp35Bone_setToSetupPose (sp35Bone* self);

void sp35Bone_updateWorldTransform (sp35Bone* self);
void sp35Bone_updateWorldTransformWith (sp35Bone* self, float x, float y, float rotation, float scaleX, float scaleY, float shearX, float shearY);

float sp35Bone_getWorldRotationX (sp35Bone* self);
float sp35Bone_getWorldRotationY (sp35Bone* self);
float sp35Bone_getWorldScaleX (sp35Bone* self);
float sp35Bone_getWorldScaleY (sp35Bone* self);

float sp35Bone_worldToLocalRotationX (sp35Bone* self);
float sp35Bone_worldToLocalRotationY (sp35Bone* self);
void sp35Bone_rotateWorld (sp35Bone* self, float degrees);
void sp35Bone_updateAppliedTransform (sp35Bone* self);

void sp35Bone_worldToLocal (sp35Bone* self, float worldX, float worldY, float* localX, float* localY);
void sp35Bone_localToWorld (sp35Bone* self, float localX, float localY, float* worldX, float* worldY);

#ifdef SPINE_SHORT_NAMES
typedef sp35Bone Bone;
#define Bone_setYDown(...) sp35Bone_setYDown(__VA_ARGS__)
#define Bone_isYDown() sp35Bone_isYDown()
#define Bone_create(...) sp35Bone_create(__VA_ARGS__)
#define Bone_dispose(...) sp35Bone_dispose(__VA_ARGS__)
#define Bone_setToSetupPose(...) sp35Bone_setToSetupPose(__VA_ARGS__)
#define Bone_updateWorldTransform(...) sp35Bone_updateWorldTransform(__VA_ARGS__)
#define Bone_updateWorldTransformWith(...) sp35Bone_updateWorldTransformWith(__VA_ARGS__)
#define Bone_getWorldRotationX(...) sp35Bone_getWorldRotationX(__VA_ARGS__)
#define Bone_getWorldRotationY(...) sp35Bone_getWorldRotationY(__VA_ARGS__)
#define Bone_getWorldScaleX(...) sp35Bone_getWorldScaleX(__VA_ARGS__)
#define Bone_getWorldScaleY(...) sp35Bone_getWorldScaleY(__VA_ARGS__)
#define Bone_worldToLocalRotationX(...) sp35Bone_worldToLocalRotationX(__VA_ARGS__)
#define Bone_worldToLocalRotationY(...) sp35Bone_worldToLocalRotationY(__VA_ARGS__)
#define Bone_rotateWorld(...) sp35Bone_rotateWorld(__VA_ARGS__)
#define Bone_updateAppliedTransform(...) sp35Bone_updateAppliedTransform(__VA_ARGS__)
#define Bone_worldToLocal(...) sp35Bone_worldToLocal(__VA_ARGS__)
#define Bone_localToWorld(...) sp35Bone_localToWorld(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_BONE_H_ */

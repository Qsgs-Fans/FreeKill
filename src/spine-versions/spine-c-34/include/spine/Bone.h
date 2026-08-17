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

struct sp34Skeleton;

typedef struct sp34Bone sp34Bone;
struct sp34Bone {
	sp34BoneData* const data;
	struct sp34Skeleton* const skeleton;
	sp34Bone* const parent;
	int childrenCount;
	sp34Bone** const children;
	float x, y, rotation, scaleX, scaleY, shearX, shearY;
	float appliedRotation;

	float const a, b, worldX;
	float const c, d, worldY;
	float const worldSignX, worldSignY;

	int/*bool*/ sorted;

#ifdef __cplusplus
	sp34Bone() :
		data(0),
		skeleton(0),
		parent(0),
		childrenCount(0), children(0),
		x(0), y(0), rotation(0), scaleX(0), scaleY(0),
		appliedRotation(0),

		a(0), b(0), worldX(0),
		c(0), d(0), worldY(0),
		worldSignX(0), worldSignY(0),
		
		sorted(0) {
	}
#endif
};

void sp34Bone_setYDown (int/*bool*/yDown);
int/*bool*/sp34Bone_isYDown ();

/* @param parent May be 0. */
sp34Bone* sp34Bone_create (sp34BoneData* data, struct sp34Skeleton* skeleton, sp34Bone* parent);
void sp34Bone_dispose (sp34Bone* self);

void sp34Bone_setToSetupPose (sp34Bone* self);

void sp34Bone_updateWorldTransform (sp34Bone* self);
void sp34Bone_updateWorldTransformWith (sp34Bone* self, float x, float y, float rotation, float scaleX, float scaleY, float shearX, float shearY);

float sp34Bone_getWorldRotationX (sp34Bone* self);
float sp34Bone_getWorldRotationY (sp34Bone* self);
float sp34Bone_getWorldScaleX (sp34Bone* self);
float sp34Bone_getWorldScaleY (sp34Bone* self);

float sp34Bone_worldToLocalRotationX (sp34Bone* self);
float sp34Bone_worldToLocalRotationY (sp34Bone* self);
void sp34Bone_rotateWorld (sp34Bone* self, float degrees);
void sp34Bone_updateLocalTransform (sp34Bone* self);

void sp34Bone_worldToLocal (sp34Bone* self, float worldX, float worldY, float* localX, float* localY);
void sp34Bone_localToWorld (sp34Bone* self, float localX, float localY, float* worldX, float* worldY);

#ifdef SPINE_SHORT_NAMES
typedef sp34Bone Bone;
#define Bone_setYDown(...) sp34Bone_setYDown(__VA_ARGS__)
#define Bone_isYDown() sp34Bone_isYDown()
#define Bone_create(...) sp34Bone_create(__VA_ARGS__)
#define Bone_dispose(...) sp34Bone_dispose(__VA_ARGS__)
#define Bone_setToSetupPose(...) sp34Bone_setToSetupPose(__VA_ARGS__)
#define Bone_updateWorldTransform(...) sp34Bone_updateWorldTransform(__VA_ARGS__)
#define Bone_updateWorldTransformWith(...) sp34Bone_updateWorldTransformWith(__VA_ARGS__)
#define Bone_getWorldRotationX(...) sp34Bone_getWorldRotationX(__VA_ARGS__)
#define Bone_getWorldRotationY(...) sp34Bone_getWorldRotationY(__VA_ARGS__)
#define Bone_getWorldScaleX(...) sp34Bone_getWorldScaleX(__VA_ARGS__)
#define Bone_getWorldScaleY(...) sp34Bone_getWorldScaleY(__VA_ARGS__)
#define Bone_worldToLocalRotationX(...) sp34Bone_worldToLocalRotationX(__VA_ARGS__)
#define Bone_worldToLocalRotationY(...) sp34Bone_worldToLocalRotationY(__VA_ARGS__)
#define Bone_rotateWorld(...) sp34Bone_rotateWorld(__VA_ARGS__)
#define Bone_updateLocalTransform(...) sp34Bone_updateLocalTransform(__VA_ARGS__)
#define Bone_worldToLocal(...) sp34Bone_worldToLocal(__VA_ARGS__)
#define Bone_localToWorld(...) sp34Bone_localToWorld(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_BONE_H_ */

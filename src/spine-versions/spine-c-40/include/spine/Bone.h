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

struct sp40Skeleton;

typedef struct sp40Bone sp40Bone;
struct sp40Bone {
	sp40BoneData *const data;
	struct sp40Skeleton *const skeleton;
	sp40Bone *const parent;
	int childrenCount;
	sp40Bone **const children;
	float x, y, rotation, scaleX, scaleY, shearX, shearY;
	float ax, ay, arotation, ascaleX, ascaleY, ashearX, ashearY;

	float const a, b, worldX;
	float const c, d, worldY;

	int/*bool*/ sorted;
	int/*bool*/ active;
};

SP_API void sp40Bone_setYDown(int/*bool*/yDown);

SP_API int/*bool*/sp40Bone_isYDown();

/* @param parent May be 0. */
SP_API sp40Bone *sp40Bone_create(sp40BoneData *data, struct sp40Skeleton *skeleton, sp40Bone *parent);

SP_API void sp40Bone_dispose(sp40Bone *self);

SP_API void sp40Bone_setToSetupPose(sp40Bone *self);

SP_API void sp40Bone_update(sp40Bone *self);

SP_API void sp40Bone_updateWorldTransform(sp40Bone *self);

SP_API void sp40Bone_updateWorldTransformWith(sp40Bone *self, float x, float y, float rotation, float scaleX, float scaleY,
											float shearX, float shearY);

SP_API float sp40Bone_getWorldRotationX(sp40Bone *self);

SP_API float sp40Bone_getWorldRotationY(sp40Bone *self);

SP_API float sp40Bone_getWorldScaleX(sp40Bone *self);

SP_API float sp40Bone_getWorldScaleY(sp40Bone *self);

SP_API void sp40Bone_updateAppliedTransform(sp40Bone *self);

SP_API void sp40Bone_worldToLocal(sp40Bone *self, float worldX, float worldY, float *localX, float *localY);

SP_API void sp40Bone_localToWorld(sp40Bone *self, float localX, float localY, float *worldX, float *worldY);

SP_API float sp40Bone_worldToLocalRotation(sp40Bone *self, float worldRotation);

SP_API float sp40Bone_localToWorldRotation(sp40Bone *self, float localRotation);

SP_API void sp40Bone_rotateWorld(sp40Bone *self, float degrees);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_BONE_H_ */

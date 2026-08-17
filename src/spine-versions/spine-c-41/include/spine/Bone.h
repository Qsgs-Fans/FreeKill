/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated September 24, 2021. Replaces all prior versions.
 *
 * Copyright (c) 2013-2021, Esoteric Software LLC
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

struct sp41Skeleton;

typedef struct sp41Bone sp41Bone;
struct sp41Bone {
	sp41BoneData *const data;
	struct sp41Skeleton *const skeleton;
	sp41Bone *const parent;
	int childrenCount;
	sp41Bone **const children;
	float x, y, rotation, scaleX, scaleY, shearX, shearY;
	float ax, ay, arotation, ascaleX, ascaleY, ashearX, ashearY;

	float const a, b, worldX;
	float const c, d, worldY;

	int/*bool*/ sorted;
	int/*bool*/ active;
};

SP_API void sp41Bone_setYDown(int/*bool*/yDown);

SP_API int/*bool*/sp41Bone_isYDown();

/* @param parent May be 0. */
SP_API sp41Bone *sp41Bone_create(sp41BoneData *data, struct sp41Skeleton *skeleton, sp41Bone *parent);

SP_API void sp41Bone_dispose(sp41Bone *self);

SP_API void sp41Bone_setToSetupPose(sp41Bone *self);

SP_API void sp41Bone_update(sp41Bone *self);

SP_API void sp41Bone_updateWorldTransform(sp41Bone *self);

SP_API void sp41Bone_updateWorldTransformWith(sp41Bone *self, float x, float y, float rotation, float scaleX, float scaleY,
											float shearX, float shearY);

SP_API float sp41Bone_getWorldRotationX(sp41Bone *self);

SP_API float sp41Bone_getWorldRotationY(sp41Bone *self);

SP_API float sp41Bone_getWorldScaleX(sp41Bone *self);

SP_API float sp41Bone_getWorldScaleY(sp41Bone *self);

SP_API void sp41Bone_updateAppliedTransform(sp41Bone *self);

SP_API void sp41Bone_worldToLocal(sp41Bone *self, float worldX, float worldY, float *localX, float *localY);

SP_API void sp41Bone_localToWorld(sp41Bone *self, float localX, float localY, float *worldX, float *worldY);

SP_API float sp41Bone_worldToLocalRotation(sp41Bone *self, float worldRotation);

SP_API float sp41Bone_localToWorldRotation(sp41Bone *self, float localRotation);

SP_API void sp41Bone_rotateWorld(sp41Bone *self, float degrees);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_BONE_H_ */

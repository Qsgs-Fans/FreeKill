/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated July 28, 2023. Replaces all prior versions.
 *
 * Copyright (c) 2013-2023, Esoteric Software LLC
 *
 * Integration of the Spine Runtimes into software or otherwise creating
 * derivative works of the Spine Runtimes is permitted under the terms and
 * conditions of Section 2 of the Spine Editor License Agreement:
 * http://esotericsoftware.com/spine-editor-license
 *
 * Otherwise, it is permitted to integrate the Spine Runtimes into software or
 * otherwise create derivative works of the Spine Runtimes (collectively,
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
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE
 * SPINE RUNTIMES, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#ifndef SPINE_BONE_H_
#define SPINE_BONE_H_

#include <spine/dll.h>
#include <spine/BoneData.h>
#include <spine/Physics.h>

#ifdef __cplusplus
extern "C" {
#endif

struct sp42Skeleton;

typedef struct sp42Bone sp42Bone;
struct sp42Bone {
	sp42BoneData *data;
	struct sp42Skeleton *skeleton;
	sp42Bone *parent;
	int childrenCount;
	sp42Bone **children;
	float x, y, rotation, scaleX, scaleY, shearX, shearY;
	float ax, ay, arotation, ascaleX, ascaleY, ashearX, ashearY;

	float a, b, worldX;
	float c, d, worldY;

	int/*bool*/ sorted;
	int/*bool*/ active;

    sp42Inherit inherit;
};

SP_API void sp42Bone_setYDown(int/*bool*/yDown);

SP_API int/*bool*/sp42Bone_isYDown(void);

/* @param parent May be 0. */
SP_API sp42Bone *sp42Bone_create(sp42BoneData *data, struct sp42Skeleton *skeleton, sp42Bone *parent);

SP_API void sp42Bone_dispose(sp42Bone *self);

SP_API void sp42Bone_setToSetupPose(sp42Bone *self);

SP_API void sp42Bone_update(sp42Bone *self);

SP_API void sp42Bone_updateWorldTransform(sp42Bone *self);

SP_API void sp42Bone_updateWorldTransformWith(sp42Bone *self, float x, float y, float rotation, float scaleX, float scaleY,
											float shearX, float shearY);

SP_API float sp42Bone_getWorldRotationX(sp42Bone *self);

SP_API float sp42Bone_getWorldRotationY(sp42Bone *self);

SP_API float sp42Bone_getWorldScaleX(sp42Bone *self);

SP_API float sp42Bone_getWorldScaleY(sp42Bone *self);

SP_API void sp42Bone_updateAppliedTransform(sp42Bone *self);

SP_API void sp42Bone_worldToLocal(sp42Bone *self, float worldX, float worldY, float *localX, float *localY);

SP_API void sp42Bone_worldToParent(sp42Bone *self, float worldX, float worldY, float *parentX, float *parentY);

SP_API void sp42Bone_localToWorld(sp42Bone *self, float localX, float localY, float *worldX, float *worldY);

SP_API void sp42Bone_localToParent(sp42Bone *self, float localX, float localY, float *parentX, float *parentY);

SP_API float sp42Bone_worldToLocalRotation(sp42Bone *self, float worldRotation);

SP_API float sp42Bone_localToWorldRotation(sp42Bone *self, float localRotation);

SP_API void sp42Bone_rotateWorld(sp42Bone *self, float degrees);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_BONE_H_ */

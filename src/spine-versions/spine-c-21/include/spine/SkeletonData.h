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

#ifndef SPINE_SKELETONDATA_H_
#define SPINE_SKELETONDATA_H_

#include <spine/BoneData.h>
#include <spine/SlotData.h>
#include <spine/Skin.h>
#include <spine/EventData.h>
#include <spine/Animation.h>
#include <spine/IkConstraintData.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp21SkeletonData {
	const char* version;
	const char* hash;
	float width, height;

	int bonesCount;
	sp21BoneData** bones;

	int slotsCount;
	sp21SlotData** slots;

	int skinsCount;
	sp21Skin** skins;
	sp21Skin* defaultSkin;

	int eventsCount;
	sp21EventData** events;

	int animationsCount;
	sp21Animation** animations;

	int ikConstraintsCount;
	sp21IkConstraintData** ikConstraints;
} sp21SkeletonData;

sp21SkeletonData* sp21SkeletonData_create ();
void sp21SkeletonData_dispose (sp21SkeletonData* self);

sp21BoneData* sp21SkeletonData_findBone (const sp21SkeletonData* self, const char* boneName);
int sp21SkeletonData_findBoneIndex (const sp21SkeletonData* self, const char* boneName);

sp21SlotData* sp21SkeletonData_findSlot (const sp21SkeletonData* self, const char* slotName);
int sp21SkeletonData_findSlotIndex (const sp21SkeletonData* self, const char* slotName);

sp21Skin* sp21SkeletonData_findSkin (const sp21SkeletonData* self, const char* skinName);

sp21EventData* sp21SkeletonData_findEvent (const sp21SkeletonData* self, const char* eventName);

sp21Animation* sp21SkeletonData_findAnimation (const sp21SkeletonData* self, const char* animationName);

sp21IkConstraintData* sp21SkeletonData_findIkConstraint (const sp21SkeletonData* self, const char* ikConstraintName);

#ifdef SPINE_SHORT_NAMES
typedef sp21SkeletonData SkeletonData;
#define SkeletonData_create(...) sp21SkeletonData_create(__VA_ARGS__)
#define SkeletonData_dispose(...) sp21SkeletonData_dispose(__VA_ARGS__)
#define SkeletonData_findBone(...) sp21SkeletonData_findBone(__VA_ARGS__)
#define SkeletonData_findBoneIndex(...) sp21SkeletonData_findBoneIndex(__VA_ARGS__)
#define SkeletonData_findSlot(...) sp21SkeletonData_findSlot(__VA_ARGS__)
#define SkeletonData_findSlotIndex(...) sp21SkeletonData_findSlotIndex(__VA_ARGS__)
#define SkeletonData_findSkin(...) sp21SkeletonData_findSkin(__VA_ARGS__)
#define SkeletonData_findEvent(...) sp21SkeletonData_findEvent(__VA_ARGS__)
#define SkeletonData_findAnimation(...) sp21SkeletonData_findAnimation(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKELETONDATA_H_ */

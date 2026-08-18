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

#include <spine/SkeletonData.h>
#include <string.h>
#include <spine/extension.h>

sp35SkeletonData* sp35SkeletonData_create () {
	return NEW(sp35SkeletonData);
}

void sp35SkeletonData_dispose (sp35SkeletonData* self) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		sp35BoneData_dispose(self->bones[i]);
	FREE(self->bones);

	for (i = 0; i < self->slotsCount; ++i)
		sp35SlotData_dispose(self->slots[i]);
	FREE(self->slots);

	for (i = 0; i < self->skinsCount; ++i)
		sp35Skin_dispose(self->skins[i]);
	FREE(self->skins);

	for (i = 0; i < self->eventsCount; ++i)
		sp35EventData_dispose(self->events[i]);
	FREE(self->events);

	for (i = 0; i < self->animationsCount; ++i)
		sp35Animation_dispose(self->animations[i]);
	FREE(self->animations);

	for (i = 0; i < self->ikConstraintsCount; ++i)
		sp35IkConstraintData_dispose(self->ikConstraints[i]);
	FREE(self->ikConstraints);

	for (i = 0; i < self->transformConstraintsCount; ++i)
		sp35TransformConstraintData_dispose(self->transformConstraints[i]);
	FREE(self->transformConstraints);

	for (i = 0; i < self->pathConstraintsCount; i++)
		sp35PathConstraintData_dispose(self->pathConstraints[i]);
	FREE(self->pathConstraints);

	FREE(self->hash);
	FREE(self->version);

	FREE(self);
}

sp35BoneData* sp35SkeletonData_findBone (const sp35SkeletonData* self, const char* boneName) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		if (strcmp(self->bones[i]->name, boneName) == 0) return self->bones[i];
	return 0;
}

int sp35SkeletonData_findBoneIndex (const sp35SkeletonData* self, const char* boneName) {
	int i;
	for (i = 0; i < self->bonesCount; ++i)
		if (strcmp(self->bones[i]->name, boneName) == 0) return i;
	return -1;
}

sp35SlotData* sp35SkeletonData_findSlot (const sp35SkeletonData* self, const char* slotName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i)
		if (strcmp(self->slots[i]->name, slotName) == 0) return self->slots[i];
	return 0;
}

int sp35SkeletonData_findSlotIndex (const sp35SkeletonData* self, const char* slotName) {
	int i;
	for (i = 0; i < self->slotsCount; ++i)
		if (strcmp(self->slots[i]->name, slotName) == 0) return i;
	return -1;
}

sp35Skin* sp35SkeletonData_findSkin (const sp35SkeletonData* self, const char* skinName) {
	int i;
	for (i = 0; i < self->skinsCount; ++i)
		if (strcmp(self->skins[i]->name, skinName) == 0) return self->skins[i];
	return 0;
}

sp35EventData* sp35SkeletonData_findEvent (const sp35SkeletonData* self, const char* eventName) {
	int i;
	for (i = 0; i < self->eventsCount; ++i)
		if (strcmp(self->events[i]->name, eventName) == 0) return self->events[i];
	return 0;
}

sp35Animation* sp35SkeletonData_findAnimation (const sp35SkeletonData* self, const char* animationName) {
	int i;
	for (i = 0; i < self->animationsCount; ++i)
		if (strcmp(self->animations[i]->name, animationName) == 0) return self->animations[i];
	return 0;
}

sp35IkConstraintData* sp35SkeletonData_findIkConstraint (const sp35SkeletonData* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->ikConstraintsCount; ++i)
		if (strcmp(self->ikConstraints[i]->name, constraintName) == 0) return self->ikConstraints[i];
	return 0;
}

sp35TransformConstraintData* sp35SkeletonData_findTransformConstraint (const sp35SkeletonData* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->transformConstraintsCount; ++i)
		if (strcmp(self->transformConstraints[i]->name, constraintName) == 0) return self->transformConstraints[i];
	return 0;
}

sp35PathConstraintData* sp35SkeletonData_findPathConstraint (const sp35SkeletonData* self, const char* constraintName) {
	int i;
	for (i = 0; i < self->pathConstraintsCount; ++i)
		if (strcmp(self->pathConstraints[i]->name, constraintName) == 0) return self->pathConstraints[i];
	return 0;
}

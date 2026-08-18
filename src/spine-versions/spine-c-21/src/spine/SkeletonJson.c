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

#include <spine/SkeletonJson.h>
#include <stdio.h>
#include "Json.h"
#include <spine/extension.h>
#include <spine/AtlasAttachmentLoader.h>

typedef struct {
	sp21SkeletonJson super;
	int ownsLoader;
} _sp21SkeletonJson;

sp21SkeletonJson* sp21SkeletonJson_createWithLoader (sp21AttachmentLoader* attachmentLoader) {
	sp21SkeletonJson* self = SUPER(NEW(_sp21SkeletonJson));
	self->scale = 1;
	self->attachmentLoader = attachmentLoader;
	return self;
}

sp21SkeletonJson* sp21SkeletonJson_create (sp21Atlas* atlas) {
	sp21AtlasAttachmentLoader* attachmentLoader = sp21AtlasAttachmentLoader_create(atlas);
	sp21SkeletonJson* self = sp21SkeletonJson_createWithLoader(SUPER(attachmentLoader));
	SUB_CAST(_sp21SkeletonJson, self)->ownsLoader = 1;
	return self;
}

void sp21SkeletonJson_dispose (sp21SkeletonJson* self) {
	if (SUB_CAST(_sp21SkeletonJson, self)->ownsLoader) sp21AttachmentLoader_dispose(self->attachmentLoader);
	FREE(self->error);
	FREE(self);
}

void _sp21SkeletonJson_setError (sp21SkeletonJson* self, Json21* root, const char* value1, const char* value2) {
	char message[256];
	int length;
	FREE(self->error);
	strcpy(message, value1);
	length = (int)strlen(value1);
	if (value2) strncat(message + length, value2, 255 - length);
	MALLOC_STR(self->error, message);
	if (root) Json21_dispose(root);
}

static float toColor (const char* value, int index) {
	char digits[3];
	char *error;
	int color;

	if (strlen(value) != 8) return -1;
	value += index * 2;

	digits[0] = *value;
	digits[1] = *(value + 1);
	digits[2] = '\0';
	color = (int)strtoul(digits, &error, 16);
	if (*error != 0) return -1;
	return color / (float)255;
}

static void readCurve (sp21CurveTimeline* timeline, int frameIndex, Json21* frame) {
	Json21* curve = Json21_getItem(frame, "curve");
	if (!curve) return;
	if (curve->type == Json21_String && strcmp(curve->valueString, "stepped") == 0)
		sp21CurveTimeline_setStepped(timeline, frameIndex);
	else if (curve->type == Json21_Array) {
		Json21* child0 = curve->child;
		Json21* child1 = child0->next;
		Json21* child2 = child1->next;
		Json21* child3 = child2->next;
		sp21CurveTimeline_setCurve(timeline, frameIndex, child0->valueFloat, child1->valueFloat, child2->valueFloat,
				child3->valueFloat);
	}
}

static sp21Animation* _sp21SkeletonJson_readAnimation (sp21SkeletonJson* self, Json21* root, sp21SkeletonData *skeletonData) {
	int i;
	sp21Animation* animation;
	Json21* frame;
	float duration;
	int timelinesCount = 0;

	Json21* bones = Json21_getItem(root, "bones");
	Json21* slots = Json21_getItem(root, "slots");
	Json21* ik = Json21_getItem(root, "ik");
	Json21* ffd = Json21_getItem(root, "ffd");
	Json21* drawOrder = Json21_getItem(root, "drawOrder");
	Json21* events = Json21_getItem(root, "events");
	Json21* flipX = Json21_getItem(root, "flipx");
	Json21* flipY = Json21_getItem(root, "flipy");
	Json21 *boneMap, *slotMap, *ikMap, *ffdMap;
	if (!drawOrder) drawOrder = Json21_getItem(root, "draworder");

	for (boneMap = bones ? bones->child : 0; boneMap; boneMap = boneMap->next)
		timelinesCount += boneMap->size;
	for (slotMap = slots ? slots->child : 0; slotMap; slotMap = slotMap->next)
		timelinesCount += slotMap->size;
	timelinesCount += ik ? ik->size : 0;
	for (ffdMap = ffd ? ffd->child : 0; ffdMap; ffdMap = ffdMap->next)
		for (slotMap = ffdMap->child; slotMap; slotMap = slotMap->next)
			timelinesCount += slotMap->size;
	if (drawOrder) ++timelinesCount;
	if (events) ++timelinesCount;
	if (flipX) ++timelinesCount;
	if (flipY) ++timelinesCount;

	animation = sp21Animation_create(root->name, timelinesCount);
	animation->timelinesCount = 0;
	skeletonData->animations[skeletonData->animationsCount++] = animation;

	/* Slot timelines. */
	for (slotMap = slots ? slots->child : 0; slotMap; slotMap = slotMap->next) {
		Json21 *timelineArray;

		int slotIndex = sp21SkeletonData_findSlotIndex(skeletonData, slotMap->name);
		if (slotIndex == -1) {
			sp21Animation_dispose(animation);
			_sp21SkeletonJson_setError(self, root, "Slot not found: ", slotMap->name);
			return 0;
		}

		for (timelineArray = slotMap->child; timelineArray; timelineArray = timelineArray->next) {
			if (strcmp(timelineArray->name, "color") == 0) {
				sp21ColorTimeline *timeline = sp21ColorTimeline_create(timelineArray->size);
				timeline->slotIndex = slotIndex;
				for (frame = timelineArray->child, i = 0; frame; frame = frame->next, ++i) {
					const char* s = Json21_getString(frame, "color", 0);
					sp21ColorTimeline_setFrame(timeline, i, Json21_getFloat(frame, "time", 0), toColor(s, 0), toColor(s, 1), toColor(s, 2),
							toColor(s, 3));
					readCurve(SUPER(timeline), i, frame);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp21Timeline, timeline);
				duration = timeline->frames[timelineArray->size * 5 - 5];
				if (duration > animation->duration) animation->duration = duration;

			} else if (strcmp(timelineArray->name, "attachment") == 0) {
				sp21AttachmentTimeline *timeline = sp21AttachmentTimeline_create(timelineArray->size);
				timeline->slotIndex = slotIndex;
				for (frame = timelineArray->child, i = 0; frame; frame = frame->next, ++i) {
					Json21* name = Json21_getItem(frame, "name");
					sp21AttachmentTimeline_setFrame(timeline, i, Json21_getFloat(frame, "time", 0),
							name->type == Json21_NULL ? 0 : name->valueString);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp21Timeline, timeline);
				duration = timeline->frames[timelineArray->size - 1];
				if (duration > animation->duration) animation->duration = duration;

			} else {
				sp21Animation_dispose(animation);
				_sp21SkeletonJson_setError(self, 0, "Invalid timeline type for a slot: ", timelineArray->name);
				return 0;
			}
		}
	}

	/* Bone timelines. */
	for (boneMap = bones ? bones->child : 0; boneMap; boneMap = boneMap->next) {
		Json21 *timelineArray;

		int boneIndex = sp21SkeletonData_findBoneIndex(skeletonData, boneMap->name);
		if (boneIndex == -1) {
			sp21Animation_dispose(animation);
			_sp21SkeletonJson_setError(self, root, "Bone not found: ", boneMap->name);
			return 0;
		}

		for (timelineArray = boneMap->child; timelineArray; timelineArray = timelineArray->next) {
			if (strcmp(timelineArray->name, "rotate") == 0) {
				sp21RotateTimeline *timeline = sp21RotateTimeline_create(timelineArray->size);
				timeline->boneIndex = boneIndex;
				for (frame = timelineArray->child, i = 0; frame; frame = frame->next, ++i) {
					sp21RotateTimeline_setFrame(timeline, i, Json21_getFloat(frame, "time", 0), Json21_getFloat(frame, "angle", 0));
					readCurve(SUPER(timeline), i, frame);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp21Timeline, timeline);
				duration = timeline->frames[timelineArray->size * 2 - 2];
				if (duration > animation->duration) animation->duration = duration;

			} else {
				int isScale = strcmp(timelineArray->name, "scale") == 0;
				if (isScale || strcmp(timelineArray->name, "translate") == 0) {
					float scale = isScale ? 1 : self->scale;
					sp21TranslateTimeline *timeline =
							isScale ? sp21ScaleTimeline_create(timelineArray->size) : sp21TranslateTimeline_create(timelineArray->size);
					timeline->boneIndex = boneIndex;
					for (frame = timelineArray->child, i = 0; frame; frame = frame->next, ++i) {
						sp21TranslateTimeline_setFrame(timeline, i, Json21_getFloat(frame, "time", 0), Json21_getFloat(frame, "x", 0) * scale,
								Json21_getFloat(frame, "y", 0) * scale);
						readCurve(SUPER(timeline), i, frame);
					}
					animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp21Timeline, timeline);
					duration = timeline->frames[timelineArray->size * 3 - 3];
					if (duration > animation->duration) animation->duration = duration;
				} else if (strcmp(timelineArray->name, "flipX") == 0 || strcmp(timelineArray->name, "flipY") == 0) {
					int x = strcmp(timelineArray->name, "flipX") == 0;
					const char* field = x ? "x" : "y";
					sp21FlipTimeline *timeline = sp21FlipTimeline_create(timelineArray->size, x);
					timeline->boneIndex = boneIndex;
					for (frame = timelineArray->child, i = 0; frame; frame = frame->next, ++i)
						sp21FlipTimeline_setFrame(timeline, i, Json21_getFloat(frame, "time", 0), Json21_getInt(frame, field, 0));
					animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp21Timeline, timeline);
					duration = timeline->frames[timelineArray->size * 2 - 2];
					if (duration > animation->duration) animation->duration = duration;

				} else {
					sp21Animation_dispose(animation);
					_sp21SkeletonJson_setError(self, 0, "Invalid timeline type for a bone: ", timelineArray->name);
					return 0;
				}
			}
		}
	}

	/* IK timelines. */
	for (ikMap = ik ? ik->child : 0; ikMap; ikMap = ikMap->next) {
		sp21IkConstraintData* ikConstraint = sp21SkeletonData_findIkConstraint(skeletonData, ikMap->name);
		sp21IkConstraintTimeline* timeline = sp21IkConstraintTimeline_create(ikMap->size);
		for (i = 0; i < skeletonData->ikConstraintsCount; ++i) {
			if (ikConstraint == skeletonData->ikConstraints[i]) {
				timeline->ikConstraintIndex = i;
				break;
			}
		}
		for (frame = ikMap->child, i = 0; frame; frame = frame->next, ++i) {
			sp21IkConstraintTimeline_setFrame(timeline, i, Json21_getFloat(frame, "time", 0), Json21_getFloat(frame, "mix", 0),
					Json21_getInt(frame, "bendPositive", 1) ? 1 : -1);
			readCurve(SUPER(timeline), i, frame);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp21Timeline, timeline);
		duration = timeline->frames[ikMap->size * 3 - 3];
		if (duration > animation->duration) animation->duration = duration;
	}

	/* FFD timelines. */
	for (ffdMap = ffd ? ffd->child : 0; ffdMap; ffdMap = ffdMap->next) {
		sp21Skin* skin = sp21SkeletonData_findSkin(skeletonData, ffdMap->name);
		for (slotMap = ffdMap->child; slotMap; slotMap = slotMap->next) {
			int slotIndex = sp21SkeletonData_findSlotIndex(skeletonData, slotMap->name);
			Json21* timelineArray;
			for (timelineArray = slotMap->child; timelineArray; timelineArray = timelineArray->next) {
				Json21* frame;
				int verticesCount = 0;
				float* tempVertices;
				sp21FFDTimeline *timeline;

				sp21Attachment* attachment = sp21Skin_getAttachment(skin, slotIndex, timelineArray->name);
				if (!attachment) {
					sp21Animation_dispose(animation);
					_sp21SkeletonJson_setError(self, 0, "Attachment not found: ", timelineArray->name);
					return 0;
				}
				if (attachment->type == SP_ATTACHMENT_MESH)
					verticesCount = SUB_CAST(sp21MeshAttachment, attachment)->verticesCount;
				else if (attachment->type == SP_ATTACHMENT_SKINNED_MESH)
					verticesCount = SUB_CAST(sp21SkinnedMeshAttachment, attachment)->weightsCount / 3 * 2;

				timeline = sp21FFDTimeline_create(timelineArray->size, verticesCount);
				timeline->slotIndex = slotIndex;
				timeline->attachment = attachment;

				tempVertices = MALLOC(float, verticesCount);
				for (frame = timelineArray->child, i = 0; frame; frame = frame->next, ++i) {
					Json21* vertices = Json21_getItem(frame, "vertices");
					float* frameVertices;
					if (!vertices) {
						if (attachment->type == SP_ATTACHMENT_MESH)
							frameVertices = SUB_CAST(sp21MeshAttachment, attachment)->vertices;
						else {
							frameVertices = tempVertices;
							memset(frameVertices, 0, sizeof(float) * verticesCount);
						}
					} else {
						int v, start = Json21_getInt(frame, "offset", 0);
						Json21* vertex;
						frameVertices = tempVertices;
						memset(frameVertices, 0, sizeof(float) * start);
						if (self->scale == 1) {
							for (vertex = vertices->child, v = start; vertex; vertex = vertex->next, ++v)
								frameVertices[v] = vertex->valueFloat;
						} else {
							for (vertex = vertices->child, v = start; vertex; vertex = vertex->next, ++v)
								frameVertices[v] = vertex->valueFloat * self->scale;
						}
						memset(frameVertices + v, 0, sizeof(float) * (verticesCount - v));
						if (attachment->type == SP_ATTACHMENT_MESH) {
							float* meshVertices = SUB_CAST(sp21MeshAttachment, attachment)->vertices;
							for (v = 0; v < verticesCount; ++v)
								frameVertices[v] += meshVertices[v];
						}
					}
					sp21FFDTimeline_setFrame(timeline, i, Json21_getFloat(frame, "time", 0), frameVertices);
					readCurve(SUPER(timeline), i, frame);
				}
				FREE(tempVertices);

				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp21Timeline, timeline);
				duration = timeline->frames[timelineArray->size - 1];
				if (duration > animation->duration) animation->duration = duration;
			}
		}
	}

	/* Draw order timeline. */
	if (drawOrder) {
		sp21DrawOrderTimeline* timeline = sp21DrawOrderTimeline_create(drawOrder->size, skeletonData->slotsCount);
		for (frame = drawOrder->child, i = 0; frame; frame = frame->next, ++i) {
			int ii;
			int* drawOrder = 0;
			Json21* offsets = Json21_getItem(frame, "offsets");
			if (offsets) {
				Json21* offsetMap;
				int* unchanged = MALLOC(int, skeletonData->slotsCount - offsets->size);
				int originalIndex = 0, unchangedIndex = 0;

				drawOrder = MALLOC(int, skeletonData->slotsCount);
				for (ii = skeletonData->slotsCount - 1; ii >= 0; --ii)
					drawOrder[ii] = -1;

				for (offsetMap = offsets->child; offsetMap; offsetMap = offsetMap->next) {
					int slotIndex = sp21SkeletonData_findSlotIndex(skeletonData, Json21_getString(offsetMap, "slot", 0));
					if (slotIndex == -1) {
						sp21Animation_dispose(animation);
						_sp21SkeletonJson_setError(self, 0, "Slot not found: ", Json21_getString(offsetMap, "slot", 0));
						return 0;
					}
					/* Collect unchanged items. */
					while (originalIndex != slotIndex)
						unchanged[unchangedIndex++] = originalIndex++;
					/* Set changed items. */
					drawOrder[originalIndex + Json21_getInt(offsetMap, "offset", 0)] = originalIndex;
					originalIndex++;
				}
				/* Collect remaining unchanged items. */
				while (originalIndex < skeletonData->slotsCount)
					unchanged[unchangedIndex++] = originalIndex++;
				/* Fill in unchanged items. */
				for (ii = skeletonData->slotsCount - 1; ii >= 0; ii--)
					if (drawOrder[ii] == -1) drawOrder[ii] = unchanged[--unchangedIndex];
				FREE(unchanged);
			}
			sp21DrawOrderTimeline_setFrame(timeline, i, Json21_getFloat(frame, "time", 0), drawOrder);
			FREE(drawOrder);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp21Timeline, timeline);
		duration = timeline->frames[drawOrder->size - 1];
		if (duration > animation->duration) animation->duration = duration;
	}

	/* Event timeline. */
	if (events) {
		Json21* frame;

		sp21EventTimeline* timeline = sp21EventTimeline_create(events->size);
		for (frame = events->child, i = 0; frame; frame = frame->next, ++i) {
			sp21Event* event;
			const char* stringValue;
			sp21EventData* eventData = sp21SkeletonData_findEvent(skeletonData, Json21_getString(frame, "name", 0));
			if (!eventData) {
				sp21Animation_dispose(animation);
				_sp21SkeletonJson_setError(self, 0, "Event not found: ", Json21_getString(frame, "name", 0));
				return 0;
			}
			event = sp21Event_create(eventData);
			event->intValue = Json21_getInt(frame, "int", eventData->intValue);
			event->floatValue = Json21_getFloat(frame, "float", eventData->floatValue);
			stringValue = Json21_getString(frame, "string", eventData->stringValue);
			if (stringValue) MALLOC_STR(event->stringValue, stringValue);
			sp21EventTimeline_setFrame(timeline, i, Json21_getFloat(frame, "time", 0), event);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp21Timeline, timeline);
		duration = timeline->frames[events->size - 1];
		if (duration > animation->duration) animation->duration = duration;
	}

	return animation;
}

sp21SkeletonData* sp21SkeletonJson_readSkeletonDataFile (sp21SkeletonJson* self, const char* path) {
	int length;
	sp21SkeletonData* skeletonData;
	const char* json = _sp21Util_readFile(path, &length);
	if (!json) {
		_sp21SkeletonJson_setError(self, 0, "Unable to read skeleton file: ", path);
		return 0;
	}
	skeletonData = sp21SkeletonJson_readSkeletonData(self, json);
	FREE(json);
	return skeletonData;
}

sp21SkeletonData* sp21SkeletonJson_readSkeletonData (sp21SkeletonJson* self, const char* json) {
	int i, ii;
	sp21SkeletonData* skeletonData;
	Json21 *root, *skeleton, *bones, *boneMap, *ik, *slots, *skins, *animations, *events;

	FREE(self->error);
	CONST_CAST(char*, self->error) = 0;

	root = Json21_create(json);
	if (!root) {
		_sp21SkeletonJson_setError(self, 0, "Invalid skeleton JSON: ", Json21_getError());
		return 0;
	}

	skeletonData = sp21SkeletonData_create();

	skeleton = Json21_getItem(root, "skeleton");
	if (skeleton) {
		MALLOC_STR(skeletonData->hash, Json21_getString(skeleton, "hash", 0));
		MALLOC_STR(skeletonData->version,  Json21_getString(skeleton, "spine", 0));
		skeletonData->width = Json21_getFloat(skeleton, "width", 0);
		skeletonData->height = Json21_getFloat(skeleton, "height", 0);
	}

	/* Bones. */
	bones = Json21_getItem(root, "bones");
	skeletonData->bones = MALLOC(sp21BoneData*, bones->size);
	for (boneMap = bones->child, i = 0; boneMap; boneMap = boneMap->next, ++i) {
		sp21BoneData* boneData;

		sp21BoneData* parent = 0;
		const char* parentName = Json21_getString(boneMap, "parent", 0);
		if (parentName) {
			parent = sp21SkeletonData_findBone(skeletonData, parentName);
			if (!parent) {
				sp21SkeletonData_dispose(skeletonData);
				_sp21SkeletonJson_setError(self, root, "Parent bone not found: ", parentName);
				return 0;
			}
		}

		boneData = sp21BoneData_create(Json21_getString(boneMap, "name", 0), parent);
		boneData->length = Json21_getFloat(boneMap, "length", 0) * self->scale;
		boneData->x = Json21_getFloat(boneMap, "x", 0) * self->scale;
		boneData->y = Json21_getFloat(boneMap, "y", 0) * self->scale;
		boneData->rotation = Json21_getFloat(boneMap, "rotation", 0);
		boneData->scaleX = Json21_getFloat(boneMap, "scaleX", 1);
		boneData->scaleY = Json21_getFloat(boneMap, "scaleY", 1);
		boneData->inheritScale = Json21_getInt(boneMap, "inheritScale", 1);
		boneData->inheritRotation = Json21_getInt(boneMap, "inheritRotation", 1);
		boneData->flipX = Json21_getInt(boneMap, "flipX", 0);
		boneData->flipY = Json21_getInt(boneMap, "flipY", 0);

		skeletonData->bones[i] = boneData;
		skeletonData->bonesCount++;
	}

	/* IK constraints. */
	ik = Json21_getItem(root, "ik");
	if (ik) {
		Json21 *ikMap;
		skeletonData->ikConstraintsCount = ik->size;
		skeletonData->ikConstraints = MALLOC(sp21IkConstraintData*, ik->size);
		for (ikMap = ik->child, i = 0; ikMap; ikMap = ikMap->next, ++i) {
			const char* targetName;

			sp21IkConstraintData* ikConstraintData = sp21IkConstraintData_create(Json21_getString(ikMap, "name", 0));
			boneMap = Json21_getItem(ikMap, "bones");
			ikConstraintData->bonesCount = boneMap->size;
			ikConstraintData->bones = MALLOC(sp21BoneData*, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				ikConstraintData->bones[ii] = sp21SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!ikConstraintData->bones[ii]) {
					sp21SkeletonData_dispose(skeletonData);
					_sp21SkeletonJson_setError(self, root, "IK bone not found: ", boneMap->valueString);
					return 0;
				}
			}

			targetName = Json21_getString(ikMap, "target", 0);
			ikConstraintData->target = sp21SkeletonData_findBone(skeletonData, targetName);
			if (!ikConstraintData->target) {
				sp21SkeletonData_dispose(skeletonData);
				_sp21SkeletonJson_setError(self, root, "Target bone not found: ", boneMap->name);
				return 0;
			}

			ikConstraintData->bendDirection = Json21_getInt(ikMap, "bendPositive", 1) ? 1 : -1;
			ikConstraintData->mix = Json21_getFloat(ikMap, "mix", 1);

			skeletonData->ikConstraints[i] = ikConstraintData;
		}
	}

	/* Slots. */
	slots = Json21_getItem(root, "slots");
	if (slots) {
		Json21 *slotMap;
		skeletonData->slotsCount = slots->size;
		skeletonData->slots = MALLOC(sp21SlotData*, slots->size);
		for (slotMap = slots->child, i = 0; slotMap; slotMap = slotMap->next, ++i) {
			sp21SlotData* slotData;
			const char* color;
			Json21 *attachmentItem;

			const char* boneName = Json21_getString(slotMap, "bone", 0);
			sp21BoneData* boneData = sp21SkeletonData_findBone(skeletonData, boneName);
			if (!boneData) {
				sp21SkeletonData_dispose(skeletonData);
				_sp21SkeletonJson_setError(self, root, "Slot bone not found: ", boneName);
				return 0;
			}

			slotData = sp21SlotData_create(Json21_getString(slotMap, "name", 0), boneData);

			color = Json21_getString(slotMap, "color", 0);
			if (color) {
				slotData->r = toColor(color, 0);
				slotData->g = toColor(color, 1);
				slotData->b = toColor(color, 2);
				slotData->a = toColor(color, 3);
			}

			attachmentItem = Json21_getItem(slotMap, "attachment");
			if (attachmentItem) sp21SlotData_setAttachmentName(slotData, attachmentItem->valueString);

			slotData->additiveBlending = Json21_getInt(slotMap, "additive", 0);

			skeletonData->slots[i] = slotData;
		}
	}

	/* Skins. */
	skins = Json21_getItem(root, "skins");
	if (skins) {
		Json21 *slotMap;
		skeletonData->skinsCount = skins->size;
		skeletonData->skins = MALLOC(sp21Skin*, skins->size);
		for (slotMap = skins->child, i = 0; slotMap; slotMap = slotMap->next, ++i) {
			Json21 *attachmentsMap;
			sp21Skin *skin = sp21Skin_create(slotMap->name);

			skeletonData->skins[i] = skin;
			if (strcmp(slotMap->name, "default") == 0) skeletonData->defaultSkin = skin;

			for (attachmentsMap = slotMap->child; attachmentsMap; attachmentsMap = attachmentsMap->next) {
				int slotIndex = sp21SkeletonData_findSlotIndex(skeletonData, attachmentsMap->name);
				Json21 *attachmentMap;

				for (attachmentMap = attachmentsMap->child; attachmentMap; attachmentMap = attachmentMap->next) {
					sp21Attachment* attachment;
					const char* skinAttachmentName = attachmentMap->name;
					const char* attachmentName = Json21_getString(attachmentMap, "name", skinAttachmentName);
					const char* path = Json21_getString(attachmentMap, "path", attachmentName);
					const char* color;
					int i;
					Json21* entry;

					const char* typeString = Json21_getString(attachmentMap, "type", "region");
					sp21AttachmentType type;
					if (strcmp(typeString, "region") == 0)
						type = SP_ATTACHMENT_REGION;
					else if (strcmp(typeString, "mesh") == 0)
						type = SP_ATTACHMENT_MESH;
					else if (strcmp(typeString, "skinnedmesh") == 0)
						type = SP_ATTACHMENT_SKINNED_MESH;
					else if (strcmp(typeString, "boundingbox") == 0)
						type = SP_ATTACHMENT_BOUNDING_BOX;
					else {
						sp21SkeletonData_dispose(skeletonData);
						_sp21SkeletonJson_setError(self, root, "Unknown attachment type: ", typeString);
						return 0;
					}

					attachment = sp21AttachmentLoader_newAttachment(self->attachmentLoader, skin, type, attachmentName, path);
					if (!attachment) {
						if (self->attachmentLoader->error1) {
							sp21SkeletonData_dispose(skeletonData);
							_sp21SkeletonJson_setError(self, root, self->attachmentLoader->error1, self->attachmentLoader->error2);
							return 0;
						}
						continue;
					}

					switch (attachment->type) {
					case SP_ATTACHMENT_REGION: {
						sp21RegionAttachment* region = SUB_CAST(sp21RegionAttachment, attachment);
						if (path) MALLOC_STR(region->path, path);
						region->x = Json21_getFloat(attachmentMap, "x", 0) * self->scale;
						region->y = Json21_getFloat(attachmentMap, "y", 0) * self->scale;
						region->scaleX = Json21_getFloat(attachmentMap, "scaleX", 1);
						region->scaleY = Json21_getFloat(attachmentMap, "scaleY", 1);
						region->rotation = Json21_getFloat(attachmentMap, "rotation", 0);
						region->width = Json21_getFloat(attachmentMap, "width", 32) * self->scale;
						region->height = Json21_getFloat(attachmentMap, "height", 32) * self->scale;

						color = Json21_getString(attachmentMap, "color", 0);
						if (color) {
							region->r = toColor(color, 0);
							region->g = toColor(color, 1);
							region->b = toColor(color, 2);
							region->a = toColor(color, 3);
						}

						sp21RegionAttachment_updateOffset(region);
						break;
					}
					case SP_ATTACHMENT_MESH: {
						sp21MeshAttachment* mesh = SUB_CAST(sp21MeshAttachment, attachment);

						MALLOC_STR(mesh->path, path);

						entry = Json21_getItem(attachmentMap, "vertices");
						mesh->verticesCount = entry->size;
						mesh->vertices = MALLOC(float, entry->size);
						for (entry = entry->child, i = 0; entry; entry = entry->next, ++i)
							mesh->vertices[i] = entry->valueFloat * self->scale;

						entry = Json21_getItem(attachmentMap, "triangles");
						mesh->trianglesCount = entry->size;
						mesh->triangles = MALLOC(int, entry->size);
						for (entry = entry->child, i = 0; entry; entry = entry->next, ++i)
							mesh->triangles[i] = entry->valueInt;

						entry = Json21_getItem(attachmentMap, "uvs");
						mesh->regionUVs = MALLOC(float, entry->size);
						for (entry = entry->child, i = 0; entry; entry = entry->next, ++i)
							mesh->regionUVs[i] = entry->valueFloat;

						sp21MeshAttachment_updateUVs(mesh);

						color = Json21_getString(attachmentMap, "color", 0);
						if (color) {
							mesh->r = toColor(color, 0);
							mesh->g = toColor(color, 1);
							mesh->b = toColor(color, 2);
							mesh->a = toColor(color, 3);
						}

						mesh->hullLength = Json21_getInt(attachmentMap, "hull", 0);

						entry = Json21_getItem(attachmentMap, "edges");
						if (entry) {
							mesh->edgesCount = entry->size;
							mesh->edges = MALLOC(int, entry->size);
							for (entry = entry->child, i = 0; entry; entry = entry->next, ++i)
								mesh->edges[i] = entry->valueInt;
						}

						mesh->width = Json21_getFloat(attachmentMap, "width", 32) * self->scale;
						mesh->height = Json21_getFloat(attachmentMap, "height", 32) * self->scale;
						break;
					}
					case SP_ATTACHMENT_SKINNED_MESH: {
						sp21SkinnedMeshAttachment* mesh = SUB_CAST(sp21SkinnedMeshAttachment, attachment);
						int verticesCount, b, w, nn;
						float* vertices;

						MALLOC_STR(mesh->path, path);

						entry = Json21_getItem(attachmentMap, "uvs");
						mesh->uvsCount = entry->size;
						mesh->regionUVs = MALLOC(float, entry->size);
						for (entry = entry->child, i = 0; entry; entry = entry->next, ++i)
							mesh->regionUVs[i] = entry->valueFloat;

						entry = Json21_getItem(attachmentMap, "vertices");
						verticesCount = entry->size;
						vertices = MALLOC(float, entry->size);
						for (entry = entry->child, i = 0; entry; entry = entry->next, ++i)
							vertices[i] = entry->valueFloat;

						for (i = 0; i < verticesCount;) {
							int bonesCount = (int)vertices[i];
							mesh->bonesCount += bonesCount + 1;
							mesh->weightsCount += bonesCount * 3;
							i += 1 + bonesCount * 4;
						}
						mesh->bones = MALLOC(int, mesh->bonesCount);
						mesh->weights = MALLOC(float, mesh->weightsCount);

						for (i = 0, b = 0, w = 0; i < verticesCount;) {
							int bonesCount = (int)vertices[i++];
							mesh->bones[b++] = bonesCount;
							for (nn = i + bonesCount * 4; i < nn; i += 4, ++b, w += 3) {
								mesh->bones[b] = (int)vertices[i];
								mesh->weights[w] = vertices[i + 1] * self->scale;
								mesh->weights[w + 1] = vertices[i + 2] * self->scale;
								mesh->weights[w + 2] = vertices[i + 3];
							}
						}

						FREE(vertices);

						entry = Json21_getItem(attachmentMap, "triangles");
						mesh->trianglesCount = entry->size;
						mesh->triangles = MALLOC(int, entry->size);
						for (entry = entry->child, i = 0; entry; entry = entry->next, ++i)
							mesh->triangles[i] = entry->valueInt;

						sp21SkinnedMeshAttachment_updateUVs(mesh);

						color = Json21_getString(attachmentMap, "color", 0);
						if (color) {
							mesh->r = toColor(color, 0);
							mesh->g = toColor(color, 1);
							mesh->b = toColor(color, 2);
							mesh->a = toColor(color, 3);
						}

						mesh->hullLength = Json21_getInt(attachmentMap, "hull", 0);

						entry = Json21_getItem(attachmentMap, "edges");
						if (entry) {
							mesh->edgesCount = entry->size;
							mesh->edges = MALLOC(int, entry->size);
							for (entry = entry->child, i = 0; entry; entry = entry->next, ++i)
								mesh->edges[i] = entry->valueInt;
						}

						mesh->width = Json21_getFloat(attachmentMap, "width", 32) * self->scale;
						mesh->height = Json21_getFloat(attachmentMap, "height", 32) * self->scale;
						break;
					}
					case SP_ATTACHMENT_BOUNDING_BOX: {
						sp21BoundingBoxAttachment* box = SUB_CAST(sp21BoundingBoxAttachment, attachment);
						entry = Json21_getItem(attachmentMap, "vertices");
						box->verticesCount = entry->size;
						box->vertices = MALLOC(float, entry->size);
						for (entry = entry->child, i = 0; entry; entry = entry->next, ++i)
							box->vertices[i] = entry->valueFloat * self->scale;
						break;
					}
					}

					sp21Skin_addAttachment(skin, slotIndex, skinAttachmentName, attachment);
				}
			}
		}
	}

	/* Events. */
	events = Json21_getItem(root, "events");
	if (events) {
		Json21 *eventMap;
		const char* stringValue;
		skeletonData->eventsCount = events->size;
		skeletonData->events = MALLOC(sp21EventData*, events->size);
		for (eventMap = events->child, i = 0; eventMap; eventMap = eventMap->next, ++i) {
			sp21EventData* eventData = sp21EventData_create(eventMap->name);
			eventData->intValue = Json21_getInt(eventMap, "int", 0);
			eventData->floatValue = Json21_getFloat(eventMap, "float", 0);
			stringValue = Json21_getString(eventMap, "string", 0);
			if (stringValue) MALLOC_STR(eventData->stringValue, stringValue);
			skeletonData->events[i] = eventData;
		}
	}

	/* Animations. */
	animations = Json21_getItem(root, "animations");
	if (animations) {
		Json21 *animationMap;
		skeletonData->animations = MALLOC(sp21Animation*, animations->size);
		for (animationMap = animations->child; animationMap; animationMap = animationMap->next)
			_sp21SkeletonJson_readAnimation(self, animationMap, skeletonData);
	}

	Json21_dispose(root);
	return skeletonData;
}

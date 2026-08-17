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

#include <spine/SkeletonJson.h>
#include <stdio.h>
#include "Json.h"
#include <spine/extension.h>
#include <spine/AtlasAttachmentLoader.h>
#include <spine/Array.h>

#if defined(WIN32) || defined(_WIN32) || defined(__WIN32) && !defined(__CYGWIN__)
#define strdup _strdup
#endif

typedef struct {
	const char* parent;
	const char* skin;
	int slotIndex;
	sp36MeshAttachment* mesh;
} _sp36LinkedMesh;

typedef struct {
	sp36SkeletonJson super;
	int ownsLoader;

	int linkedMeshCount;
	int linkedMeshCapacity;
	_sp36LinkedMesh* linkedMeshes;
} _sp36SkeletonJson;

sp36SkeletonJson* sp36SkeletonJson_createWithLoader (sp36AttachmentLoader* attachmentLoader) {
	sp36SkeletonJson* self = SUPER(NEW(_sp36SkeletonJson));
	self->scale = 1;
	self->attachmentLoader = attachmentLoader;
	return self;
}

sp36SkeletonJson* sp36SkeletonJson_create (sp36Atlas* atlas) {
	sp36AtlasAttachmentLoader* attachmentLoader = sp36AtlasAttachmentLoader_create(atlas);
	sp36SkeletonJson* self = sp36SkeletonJson_createWithLoader(SUPER(attachmentLoader));
	SUB_CAST(_sp36SkeletonJson, self)->ownsLoader = 1;
	return self;
}

void sp36SkeletonJson_dispose (sp36SkeletonJson* self) {
	_sp36SkeletonJson* internal = SUB_CAST(_sp36SkeletonJson, self);
	if (internal->ownsLoader) sp36AttachmentLoader_dispose(self->attachmentLoader);
	FREE(internal->linkedMeshes);
	FREE(self->error);
	FREE(self);
}

void _sp36SkeletonJson_setError (sp36SkeletonJson* self, Json36* root, const char* value1, const char* value2) {
	char message[256];
	int length;
	FREE(self->error);
	strcpy(message, value1);
	length = (int)strlen(value1);
	if (value2) strncat(message + length, value2, 255 - length);
	MALLOC_STR(self->error, message);
	if (root) Json36_dispose(root);
}

static float toColor (const char* value, int index) {
	char digits[3];
	char *error;
	int color;

	if (index >= strlen(value) / 2)
		return -1;
	value += index * 2;

	digits[0] = *value;
	digits[1] = *(value + 1);
	digits[2] = '\0';
	color = (int)strtoul(digits, &error, 16);
	if (*error != 0) return -1;
	return color / (float)255;
}

static void readCurve (Json36* frame, sp36CurveTimeline* timeline, int frameIndex) {
	Json36* curve = Json36_getItem(frame, "curve");
	if (!curve) return;
	if (curve->type == Json36_String && strcmp(curve->valueString, "stepped") == 0)
		sp36CurveTimeline_setStepped(timeline, frameIndex);
	else if (curve->type == Json36_Array) {
		Json36* child0 = curve->child;
		Json36* child1 = child0->next;
		Json36* child2 = child1->next;
		Json36* child3 = child2->next;
		sp36CurveTimeline_setCurve(timeline, frameIndex, child0->valueFloat, child1->valueFloat, child2->valueFloat,
				child3->valueFloat);
	}
}

static void _sp36SkeletonJson_addLinkedMesh (sp36SkeletonJson* self, sp36MeshAttachment* mesh, const char* skin, int slotIndex,
		const char* parent) {
	_sp36LinkedMesh* linkedMesh;
	_sp36SkeletonJson* internal = SUB_CAST(_sp36SkeletonJson, self);

	if (internal->linkedMeshCount == internal->linkedMeshCapacity) {
		_sp36LinkedMesh* linkedMeshes;
		internal->linkedMeshCapacity *= 2;
		if (internal->linkedMeshCapacity < 8) internal->linkedMeshCapacity = 8;
		linkedMeshes = MALLOC(_sp36LinkedMesh, internal->linkedMeshCapacity);
		memcpy(linkedMeshes, internal->linkedMeshes, sizeof(_sp36LinkedMesh) * internal->linkedMeshCount);
		FREE(internal->linkedMeshes);
		internal->linkedMeshes = linkedMeshes;
	}

	linkedMesh = internal->linkedMeshes + internal->linkedMeshCount++;
	linkedMesh->mesh = mesh;
	linkedMesh->skin = skin;
	linkedMesh->slotIndex = slotIndex;
	linkedMesh->parent = parent;
}

static sp36Animation* _sp36SkeletonJson_readAnimation (sp36SkeletonJson* self, Json36* root, sp36SkeletonData *skeletonData) {
	int frameIndex;
	sp36Animation* animation;
	Json36* valueMap;
	int timelinesCount = 0;

	Json36* bones = Json36_getItem(root, "bones");
	Json36* slots = Json36_getItem(root, "slots");
	Json36* ik = Json36_getItem(root, "ik");
	Json36* transform = Json36_getItem(root, "transform");
	Json36* paths = Json36_getItem(root, "paths");
	Json36* deform = Json36_getItem(root, "deform");
	Json36* drawOrder = Json36_getItem(root, "drawOrder");
	Json36* events = Json36_getItem(root, "events");
	Json36 *boneMap, *slotMap, *constraintMap;
	if (!drawOrder) drawOrder = Json36_getItem(root, "draworder");

	for (boneMap = bones ? bones->child : 0; boneMap; boneMap = boneMap->next)
		timelinesCount += boneMap->size;
	for (slotMap = slots ? slots->child : 0; slotMap; slotMap = slotMap->next)
		timelinesCount += slotMap->size;
	timelinesCount += ik ? ik->size : 0;
	timelinesCount += transform ? transform->size : 0;
	for (constraintMap = paths ? paths->child : 0; constraintMap; constraintMap = constraintMap->next)
		timelinesCount += constraintMap->size;
	for (constraintMap = deform ? deform->child : 0; constraintMap; constraintMap = constraintMap->next)
		for (slotMap = constraintMap->child; slotMap; slotMap = slotMap->next)
			timelinesCount += slotMap->size;
	if (drawOrder) ++timelinesCount;
	if (events) ++timelinesCount;

	animation = sp36Animation_create(root->name, timelinesCount);
	animation->timelinesCount = 0;

	/* Slot timelines. */
	for (slotMap = slots ? slots->child : 0; slotMap; slotMap = slotMap->next) {
		Json36 *timelineMap;

		int slotIndex = sp36SkeletonData_findSlotIndex(skeletonData, slotMap->name);
		if (slotIndex == -1) {
			sp36Animation_dispose(animation);
			_sp36SkeletonJson_setError(self, root, "Slot not found: ", slotMap->name);
			return 0;
		}

		for (timelineMap = slotMap->child; timelineMap; timelineMap = timelineMap->next) {
			if (strcmp(timelineMap->name, "attachment") == 0) {
				sp36AttachmentTimeline *timeline = sp36AttachmentTimeline_create(timelineMap->size);
				timeline->slotIndex = slotIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					Json36* name = Json36_getItem(valueMap, "name");
					sp36AttachmentTimeline_setFrame(timeline, frameIndex, Json36_getFloat(valueMap, "time", 0),
												  name->type == Json36_NULL ? 0 : name->valueString);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp36Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[timelineMap->size - 1]);

			} else if (strcmp(timelineMap->name, "color") == 0) {
				sp36ColorTimeline *timeline = sp36ColorTimeline_create(timelineMap->size);
				timeline->slotIndex = slotIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					const char* s = Json36_getString(valueMap, "color", 0);
					sp36ColorTimeline_setFrame(timeline, frameIndex, Json36_getFloat(valueMap, "time", 0), toColor(s, 0), toColor(s, 1), toColor(s, 2),
							toColor(s, 3));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp36Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * COLOR_ENTRIES]);

			} else if (strcmp(timelineMap->name, "twoColor") == 0) {
				sp36TwoColorTimeline *timeline = sp36TwoColorTimeline_create(timelineMap->size);
				timeline->slotIndex = slotIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					const char* s = Json36_getString(valueMap, "light", 0);
					const char* ds = Json36_getString(valueMap, "dark", 0);
					sp36TwoColorTimeline_setFrame(timeline, frameIndex, Json36_getFloat(valueMap, "time", 0), toColor(s, 0), toColor(s, 1), toColor(s, 2),
											 toColor(s, 3), toColor(ds, 0), toColor(ds, 1), toColor(ds, 2));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp36Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * TWOCOLOR_ENTRIES]);

			} else {
				sp36Animation_dispose(animation);
				_sp36SkeletonJson_setError(self, 0, "Invalid timeline type for a slot: ", timelineMap->name);
				return 0;
			}
		}
	}

	/* Bone timelines. */
	for (boneMap = bones ? bones->child : 0; boneMap; boneMap = boneMap->next) {
		Json36 *timelineMap;

		int boneIndex = sp36SkeletonData_findBoneIndex(skeletonData, boneMap->name);
		if (boneIndex == -1) {
			sp36Animation_dispose(animation);
			_sp36SkeletonJson_setError(self, root, "Bone not found: ", boneMap->name);
			return 0;
		}

		for (timelineMap = boneMap->child; timelineMap; timelineMap = timelineMap->next) {
			if (strcmp(timelineMap->name, "rotate") == 0) {
				sp36RotateTimeline *timeline = sp36RotateTimeline_create(timelineMap->size);
				timeline->boneIndex = boneIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					sp36RotateTimeline_setFrame(timeline, frameIndex, Json36_getFloat(valueMap, "time", 0), Json36_getFloat(valueMap, "angle", 0));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp36Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * ROTATE_ENTRIES]);

			} else {
				int isScale = strcmp(timelineMap->name, "scale") == 0;
				int isTranslate = strcmp(timelineMap->name, "translate") == 0;
				int isShear = strcmp(timelineMap->name, "shear") == 0;
				if (isScale || isTranslate || isShear) {
					float timelineScale = isTranslate ? self->scale: 1;
					sp36TranslateTimeline *timeline = 0;
					if (isScale) timeline = sp36ScaleTimeline_create(timelineMap->size);
					else if (isTranslate) timeline = sp36TranslateTimeline_create(timelineMap->size);
					else if (isShear) timeline = sp36ShearTimeline_create(timelineMap->size);
					timeline->boneIndex = boneIndex;

					for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
						sp36TranslateTimeline_setFrame(timeline, frameIndex, Json36_getFloat(valueMap, "time", 0), Json36_getFloat(valueMap, "x", 0) * timelineScale,
								Json36_getFloat(valueMap, "y", 0) * timelineScale);
						readCurve(valueMap, SUPER(timeline), frameIndex);
					}
					animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp36Timeline, timeline);
					animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * TRANSLATE_ENTRIES]);

				} else {
					sp36Animation_dispose(animation);
					_sp36SkeletonJson_setError(self, 0, "Invalid timeline type for a bone: ", timelineMap->name);
					return 0;
				}
			}
		}
	}

	/* IK constraint timelines. */
	for (constraintMap = ik ? ik->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp36IkConstraintData* constraint = sp36SkeletonData_findIkConstraint(skeletonData, constraintMap->name);
		sp36IkConstraintTimeline* timeline = sp36IkConstraintTimeline_create(constraintMap->size);
		for (frameIndex = 0; frameIndex < skeletonData->ikConstraintsCount; ++frameIndex) {
			if (constraint == skeletonData->ikConstraints[frameIndex]) {
				timeline->ikConstraintIndex = frameIndex;
				break;
			}
		}
		for (valueMap = constraintMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			sp36IkConstraintTimeline_setFrame(timeline, frameIndex, Json36_getFloat(valueMap, "time", 0), Json36_getFloat(valueMap, "mix", 1),
					Json36_getInt(valueMap, "bendPositive", 1) ? 1 : -1);
			readCurve(valueMap, SUPER(timeline), frameIndex);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp36Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[(constraintMap->size - 1) * IKCONSTRAINT_ENTRIES]);
	}

	/* Transform constraint timelines. */
	for (constraintMap = transform ? transform->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp36TransformConstraintData* constraint = sp36SkeletonData_findTransformConstraint(skeletonData, constraintMap->name);
		sp36TransformConstraintTimeline* timeline = sp36TransformConstraintTimeline_create(constraintMap->size);
		for (frameIndex = 0; frameIndex < skeletonData->transformConstraintsCount; ++frameIndex) {
			if (constraint == skeletonData->transformConstraints[frameIndex]) {
				timeline->transformConstraintIndex = frameIndex;
				break;
			}
		}
		for (valueMap = constraintMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			sp36TransformConstraintTimeline_setFrame(timeline, frameIndex, Json36_getFloat(valueMap, "time", 0), Json36_getFloat(valueMap, "rotateMix", 1),
					Json36_getFloat(valueMap, "translateMix", 1), Json36_getFloat(valueMap, "scaleMix", 1), Json36_getFloat(valueMap, "shearMix", 1));
			readCurve(valueMap, SUPER(timeline), frameIndex);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp36Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[(constraintMap->size - 1) * TRANSFORMCONSTRAINT_ENTRIES]);
	}

	/** Path constraint timelines. */
	for(constraintMap = paths ? paths->child : 0; constraintMap; constraintMap = constraintMap->next ) {
		int constraintIndex, i;
		Json36* timelineMap;

		sp36PathConstraintData* data = sp36SkeletonData_findPathConstraint(skeletonData, constraintMap->name);
		if (!data) {
			sp36Animation_dispose(animation);
			_sp36SkeletonJson_setError(self, root, "Path constraint not found: ", constraintMap->name);
			return 0;
		}
		for (i = 0; i < skeletonData->pathConstraintsCount; i++) {
			if (skeletonData->pathConstraints[i] == data) {
				constraintIndex = i;
				break;
			}
		}

		for (timelineMap = constraintMap->child; timelineMap; timelineMap = timelineMap->next) {
			const char* timelineName = timelineMap->name;
			if (strcmp(timelineName, "position") == 0 || strcmp(timelineName, "spacing") == 0) {
				sp36PathConstraintPositionTimeline* timeline;
				float timelineScale = 1;
				if (strcmp(timelineName, "spacing") == 0) {
					timeline = (sp36PathConstraintPositionTimeline*)sp36PathConstraintSpacingTimeline_create(timelineMap->size);
					if (data->spacingMode == SP_SPACING_MODE_LENGTH || data->spacingMode == SP_SPACING_MODE_FIXED) timelineScale = self->scale;
				} else {
					timeline = sp36PathConstraintPositionTimeline_create(timelineMap->size);
					if (data->positionMode == SP_POSITION_MODE_FIXED) timelineScale = self->scale;
				}
				timeline->pathConstraintIndex = constraintIndex;
				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					sp36PathConstraintPositionTimeline_setFrame(timeline, frameIndex, Json36_getFloat(valueMap, "time", 0), Json36_getFloat(valueMap, timelineName, 0) * timelineScale);
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp36Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * PATHCONSTRAINTPOSITION_ENTRIES]);
			} else if (strcmp(timelineName, "mix") == 0) {
				sp36PathConstraintMixTimeline* timeline = sp36PathConstraintMixTimeline_create(timelineMap->size);
				timeline->pathConstraintIndex = constraintIndex;
				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					sp36PathConstraintMixTimeline_setFrame(timeline, frameIndex, Json36_getFloat(valueMap, "time", 0),
						Json36_getFloat(valueMap, "rotateMix", 1), Json36_getFloat(valueMap, "translateMix", 1));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp36Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * PATHCONSTRAINTMIX_ENTRIES]);
			}
		}
	}

	/* Deform timelines. */
	for (constraintMap = deform ? deform->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp36Skin* skin = sp36SkeletonData_findSkin(skeletonData, constraintMap->name);
		for (slotMap = constraintMap->child; slotMap; slotMap = slotMap->next) {
			int slotIndex = sp36SkeletonData_findSlotIndex(skeletonData, slotMap->name);
			Json36* timelineMap;
			for (timelineMap = slotMap->child; timelineMap; timelineMap = timelineMap->next) {
				float* tempDeform;
				sp36DeformTimeline *timeline;
				int weighted, deformLength;

				sp36VertexAttachment* attachment = SUB_CAST(sp36VertexAttachment, sp36Skin_getAttachment(skin, slotIndex, timelineMap->name));
				if (!attachment) {
					sp36Animation_dispose(animation);
					_sp36SkeletonJson_setError(self, 0, "Attachment not found: ", timelineMap->name);
					return 0;
				}
				weighted = attachment->bones != 0;
				deformLength = weighted ? attachment->verticesCount / 3 * 2 : attachment->verticesCount;
				tempDeform = MALLOC(float, deformLength);

				timeline = sp36DeformTimeline_create(timelineMap->size, deformLength);
				timeline->slotIndex = slotIndex;
				timeline->attachment = SUPER(attachment);

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					Json36* vertices = Json36_getItem(valueMap, "vertices");
					float* deform;
					if (!vertices) {
						if (weighted) {
							deform = tempDeform;
							memset(deform, 0, sizeof(float) * deformLength);
						} else
							deform = attachment->vertices;
					} else {
						int v, start = Json36_getInt(valueMap, "offset", 0);
						Json36* vertex;
						deform = tempDeform;
						memset(deform, 0, sizeof(float) * start);
						if (self->scale == 1) {
							for (vertex = vertices->child, v = start; vertex; vertex = vertex->next, ++v)
								deform[v] = vertex->valueFloat;
						} else {
							for (vertex = vertices->child, v = start; vertex; vertex = vertex->next, ++v)
								deform[v] = vertex->valueFloat * self->scale;
						}
						memset(deform + v, 0, sizeof(float) * (deformLength - v));
						if (!weighted) {
							float* vertices = attachment->vertices;
							for (v = 0; v < deformLength; ++v)
								deform[v] += vertices[v];
						}
					}
					sp36DeformTimeline_setFrame(timeline, frameIndex, Json36_getFloat(valueMap, "time", 0), deform);
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				FREE(tempDeform);

				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp36Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[timelineMap->size - 1]);
			}
		}
	}

	/* Draw order timeline. */
	if (drawOrder) {
		sp36DrawOrderTimeline* timeline = sp36DrawOrderTimeline_create(drawOrder->size, skeletonData->slotsCount);
		for (valueMap = drawOrder->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			int ii;
			int* drawOrder = 0;
			Json36* offsets = Json36_getItem(valueMap, "offsets");
			if (offsets) {
				Json36* offsetMap;
				int* unchanged = MALLOC(int, skeletonData->slotsCount - offsets->size);
				int originalIndex = 0, unchangedIndex = 0;

				drawOrder = MALLOC(int, skeletonData->slotsCount);
				for (ii = skeletonData->slotsCount - 1; ii >= 0; --ii)
					drawOrder[ii] = -1;

				for (offsetMap = offsets->child; offsetMap; offsetMap = offsetMap->next) {
					int slotIndex = sp36SkeletonData_findSlotIndex(skeletonData, Json36_getString(offsetMap, "slot", 0));
					if (slotIndex == -1) {
						sp36Animation_dispose(animation);
						_sp36SkeletonJson_setError(self, 0, "Slot not found: ", Json36_getString(offsetMap, "slot", 0));
						return 0;
					}
					/* Collect unchanged items. */
					while (originalIndex != slotIndex)
						unchanged[unchangedIndex++] = originalIndex++;
					/* Set changed items. */
					drawOrder[originalIndex + Json36_getInt(offsetMap, "offset", 0)] = originalIndex;
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
			sp36DrawOrderTimeline_setFrame(timeline, frameIndex, Json36_getFloat(valueMap, "time", 0), drawOrder);
			FREE(drawOrder);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp36Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[drawOrder->size - 1]);
	}

	/* Event timeline. */
	if (events) {
		sp36EventTimeline* timeline = sp36EventTimeline_create(events->size);
		for (valueMap = events->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			sp36Event* event;
			const char* stringValue;
			sp36EventData* eventData = sp36SkeletonData_findEvent(skeletonData, Json36_getString(valueMap, "name", 0));
			if (!eventData) {
				sp36Animation_dispose(animation);
				_sp36SkeletonJson_setError(self, 0, "Event not found: ", Json36_getString(valueMap, "name", 0));
				return 0;
			}
			event = sp36Event_create(Json36_getFloat(valueMap, "time", 0), eventData);
			event->intValue = Json36_getInt(valueMap, "int", eventData->intValue);
			event->floatValue = Json36_getFloat(valueMap, "float", eventData->floatValue);
			stringValue = Json36_getString(valueMap, "string", eventData->stringValue);
			if (stringValue) MALLOC_STR(event->stringValue, stringValue);
			sp36EventTimeline_setFrame(timeline, frameIndex, event);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp36Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[events->size - 1]);
	}

	return animation;
}

static void _readVertices (sp36SkeletonJson* self, Json36* attachmentMap, sp36VertexAttachment* attachment, int verticesLength) {
	Json36* entry;
	float* vertices;
	int i, n, nn, entrySize;
	sp36FloatArray* weights;
	sp36IntArray* bones;

	attachment->worldVerticesLength = verticesLength;

	entry = Json36_getItem(attachmentMap, "vertices");
	entrySize = entry->size;
	vertices = MALLOC(float, entrySize);
	for (entry = entry->child, i = 0; entry; entry = entry->next, ++i)
		vertices[i] = entry->valueFloat;

	if (verticesLength == entrySize) {
		if (self->scale != 1)
			for (i = 0; i < entrySize; ++i)
				vertices[i] *= self->scale;
		attachment->verticesCount = verticesLength;
		attachment->vertices = vertices;

		attachment->bonesCount = 0;
		attachment->bones = 0;
		return;
	}

	weights = sp36FloatArray_create(verticesLength * 3 * 3);
	bones = sp36IntArray_create(verticesLength * 3);

	for (i = 0, n = entrySize; i < n;) {
		int boneCount = (int)vertices[i++];
		sp36IntArray_add(bones, boneCount);
		for (nn = i + boneCount * 4; i < nn; i += 4) {
			sp36IntArray_add(bones, (int)vertices[i]);
			sp36FloatArray_add(weights, vertices[i + 1] * self->scale);
			sp36FloatArray_add(weights, vertices[i + 2] * self->scale);
			sp36FloatArray_add(weights, vertices[i + 3]);
		}
	}

	attachment->verticesCount = weights->size;
	attachment->vertices = weights->items;
	FREE(weights);
	attachment->bonesCount = bones->size;
	attachment->bones = bones->items;
	FREE(bones);

	FREE(vertices);
}

sp36SkeletonData* sp36SkeletonJson_readSkeletonDataFile (sp36SkeletonJson* self, const char* path) {
	int length;
	sp36SkeletonData* skeletonData;
	const char* json = _sp36Util_readFile(path, &length);
	if (length == 0 || !json) {
		_sp36SkeletonJson_setError(self, 0, "Unable to read skeleton file: ", path);
		return 0;
	}
	skeletonData = sp36SkeletonJson_readSkeletonData(self, json);
	FREE(json);
	return skeletonData;
}

sp36SkeletonData* sp36SkeletonJson_readSkeletonData (sp36SkeletonJson* self, const char* json) {
	int i, ii;
	sp36SkeletonData* skeletonData;
	Json36 *root, *skeleton, *bones, *boneMap, *ik, *transform, *path, *slots, *skins, *animations, *events;
	_sp36SkeletonJson* internal = SUB_CAST(_sp36SkeletonJson, self);

	FREE(self->error);
	CONST_CAST(char*, self->error) = 0;
	internal->linkedMeshCount = 0;

	root = Json36_create(json);

	if (!root) {
		_sp36SkeletonJson_setError(self, 0, "Invalid skeleton JSON: ", Json36_getError());
		return 0;
	}

	skeletonData = sp36SkeletonData_create();

	skeleton = Json36_getItem(root, "skeleton");
	if (skeleton) {
		MALLOC_STR(skeletonData->hash, Json36_getString(skeleton, "hash", 0));
		MALLOC_STR(skeletonData->version, Json36_getString(skeleton, "spine", 0));
		skeletonData->width = Json36_getFloat(skeleton, "width", 0);
		skeletonData->height = Json36_getFloat(skeleton, "height", 0);
	}

	/* Bones. */
	bones = Json36_getItem(root, "bones");
	skeletonData->bones = MALLOC(sp36BoneData*, bones->size);
	for (boneMap = bones->child, i = 0; boneMap; boneMap = boneMap->next, ++i) {
		sp36BoneData* data;
		const char* transformMode;

		sp36BoneData* parent = 0;
		const char* parentName = Json36_getString(boneMap, "parent", 0);
		if (parentName) {
			parent = sp36SkeletonData_findBone(skeletonData, parentName);
			if (!parent) {
				sp36SkeletonData_dispose(skeletonData);
				_sp36SkeletonJson_setError(self, root, "Parent bone not found: ", parentName);
				return 0;
			}
		}

		data = sp36BoneData_create(skeletonData->bonesCount, Json36_getString(boneMap, "name", 0), parent);
		data->length = Json36_getFloat(boneMap, "length", 0) * self->scale;
		data->x = Json36_getFloat(boneMap, "x", 0) * self->scale;
		data->y = Json36_getFloat(boneMap, "y", 0) * self->scale;
		data->rotation = Json36_getFloat(boneMap, "rotation", 0);
		data->scaleX = Json36_getFloat(boneMap, "scaleX", 1);
		data->scaleY = Json36_getFloat(boneMap, "scaleY", 1);
		data->shearX = Json36_getFloat(boneMap, "shearX", 0);
		data->shearY = Json36_getFloat(boneMap, "shearY", 0);
		transformMode = Json36_getString(boneMap, "transform", "normal");
		data->transformMode = SP_TRANSFORMMODE_NORMAL;
		if (strcmp(transformMode, "normal") == 0)
			data->transformMode = SP_TRANSFORMMODE_NORMAL;
		if (strcmp(transformMode, "onlyTranslation") == 0)
			data->transformMode = SP_TRANSFORMMODE_ONLYTRANSLATION;
		if (strcmp(transformMode, "noRotationOrReflection") == 0)
			data->transformMode = SP_TRANSFORMMODE_NOROTATIONORREFLECTION;
		if (strcmp(transformMode, "noScale") == 0)
			data->transformMode = SP_TRANSFORMMODE_NOSCALE;
		if (strcmp(transformMode, "noScaleOrReflection") == 0)
			data->transformMode = SP_TRANSFORMMODE_NOSCALEORREFLECTION;

		skeletonData->bones[i] = data;
		skeletonData->bonesCount++;
	}

	/* Slots. */
	slots = Json36_getItem(root, "slots");
	if (slots) {
		Json36 *slotMap;
		skeletonData->slotsCount = slots->size;
		skeletonData->slots = MALLOC(sp36SlotData*, slots->size);
		for (slotMap = slots->child, i = 0; slotMap; slotMap = slotMap->next, ++i) {
			sp36SlotData* data;
			const char* color;
			const char* dark;
			Json36 *item;

			const char* boneName = Json36_getString(slotMap, "bone", 0);
			sp36BoneData* boneData = sp36SkeletonData_findBone(skeletonData, boneName);
			if (!boneData) {
				sp36SkeletonData_dispose(skeletonData);
				_sp36SkeletonJson_setError(self, root, "Slot bone not found: ", boneName);
				return 0;
			}

			data = sp36SlotData_create(i, Json36_getString(slotMap, "name", 0), boneData);

			color = Json36_getString(slotMap, "color", 0);
			if (color) {
				sp36Color_setFromFloats(&data->color,
									  toColor(color, 0),
									  toColor(color, 1),
									  toColor(color, 2),
									  toColor(color, 3));
			}

			dark = Json36_getString(slotMap, "dark", 0);
			if (dark) {
				data->darkColor = sp36Color_create();
				sp36Color_setFromFloats(data->darkColor,
									  toColor(dark, 0),
									  toColor(dark, 1),
									  toColor(dark, 2),
									  toColor(dark, 3));
			}

			item = Json36_getItem(slotMap, "attachment");
			if (item) sp36SlotData_setAttachmentName(data, item->valueString);

			item = Json36_getItem(slotMap, "blend");
			if (item) {
				if (strcmp(item->valueString, "additive") == 0)
					data->blendMode = SP_BLEND_MODE_ADDITIVE;
				else if (strcmp(item->valueString, "multiply") == 0)
					data->blendMode = SP_BLEND_MODE_MULTIPLY;
				else if (strcmp(item->valueString, "screen") == 0)
					data->blendMode = SP_BLEND_MODE_SCREEN;
			}

			skeletonData->slots[i] = data;
		}
	}

	/* IK constraints. */
	ik = Json36_getItem(root, "ik");
	if (ik) {
		Json36 *constraintMap;
		skeletonData->ikConstraintsCount = ik->size;
		skeletonData->ikConstraints = MALLOC(sp36IkConstraintData*, ik->size);
		for (constraintMap = ik->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char* targetName;

			sp36IkConstraintData* data = sp36IkConstraintData_create(Json36_getString(constraintMap, "name", 0));
			data->order = Json36_getInt(constraintMap, "order", 0);

			boneMap = Json36_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			data->bones = MALLOC(sp36BoneData*, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp36SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp36SkeletonData_dispose(skeletonData);
					_sp36SkeletonJson_setError(self, root, "IK bone not found: ", boneMap->valueString);
					return 0;
				}
			}

			targetName = Json36_getString(constraintMap, "target", 0);
			data->target = sp36SkeletonData_findBone(skeletonData, targetName);
			if (!data->target) {
				sp36SkeletonData_dispose(skeletonData);
				_sp36SkeletonJson_setError(self, root, "Target bone not found: ", targetName);
				return 0;
			}

			data->bendDirection = Json36_getInt(constraintMap, "bendPositive", 1) ? 1 : -1;
			data->mix = Json36_getFloat(constraintMap, "mix", 1);

			skeletonData->ikConstraints[i] = data;
		}
	}

	/* Transform constraints. */
	transform = Json36_getItem(root, "transform");
	if (transform) {
		Json36 *constraintMap;
		skeletonData->transformConstraintsCount = transform->size;
		skeletonData->transformConstraints = MALLOC(sp36TransformConstraintData*, transform->size);
		for (constraintMap = transform->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char* name;

			sp36TransformConstraintData* data = sp36TransformConstraintData_create(Json36_getString(constraintMap, "name", 0));
			data->order = Json36_getInt(constraintMap, "order", 0);

			boneMap = Json36_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			CONST_CAST(sp36BoneData**, data->bones) = MALLOC(sp36BoneData*, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp36SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp36SkeletonData_dispose(skeletonData);
					_sp36SkeletonJson_setError(self, root, "Transform bone not found: ", boneMap->valueString);
					return 0;
				}
			}

			name = Json36_getString(constraintMap, "target", 0);
			data->target = sp36SkeletonData_findBone(skeletonData, name);
			if (!data->target) {
				sp36SkeletonData_dispose(skeletonData);
				_sp36SkeletonJson_setError(self, root, "Target bone not found: ", name);
				return 0;
			}

			data->local = Json36_getInt(constraintMap, "local", 0);
			data->relative = Json36_getInt(constraintMap, "relative", 0);
			data->offsetRotation = Json36_getFloat(constraintMap, "rotation", 0);
			data->offsetX = Json36_getFloat(constraintMap, "x", 0) * self->scale;
			data->offsetY = Json36_getFloat(constraintMap, "y", 0) * self->scale;
			data->offsetScaleX = Json36_getFloat(constraintMap, "scaleX", 0);
			data->offsetScaleY = Json36_getFloat(constraintMap, "scaleY", 0);
			data->offsetShearY = Json36_getFloat(constraintMap, "shearY", 0);

			data->rotateMix = Json36_getFloat(constraintMap, "rotateMix", 1);
			data->translateMix = Json36_getFloat(constraintMap, "translateMix", 1);
			data->scaleMix = Json36_getFloat(constraintMap, "scaleMix", 1);
			data->shearMix = Json36_getFloat(constraintMap, "shearMix", 1);

			skeletonData->transformConstraints[i] = data;
		}
	}

	/* Path constraints */
	path = Json36_getItem(root, "path");
	if (path) {
		Json36 *constraintMap;
		skeletonData->pathConstraintsCount = path->size;
		skeletonData->pathConstraints = MALLOC(sp36PathConstraintData*, path->size);
		for (constraintMap = path->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char* name;
			const char* item;

			sp36PathConstraintData* data = sp36PathConstraintData_create(Json36_getString(constraintMap, "name", 0));
			data->order = Json36_getInt(constraintMap, "order", 0);

			boneMap = Json36_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			CONST_CAST(sp36BoneData**, data->bones) = MALLOC(sp36BoneData*, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp36SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp36SkeletonData_dispose(skeletonData);
					_sp36SkeletonJson_setError(self, root, "Path bone not found: ", boneMap->valueString);
					return 0;
				}
			}

			name = Json36_getString(constraintMap, "target", 0);
			data->target = sp36SkeletonData_findSlot(skeletonData, name);
			if (!data->target) {
				sp36SkeletonData_dispose(skeletonData);
				_sp36SkeletonJson_setError(self, root, "Target slot not found: ", name);
				return 0;
			}

			item = Json36_getString(constraintMap, "positionMode", "percent");
			if (strcmp(item, "fixed") == 0) data->positionMode = SP_POSITION_MODE_FIXED;
			else if (strcmp(item, "percent") == 0) data->positionMode = SP_POSITION_MODE_PERCENT;

			item = Json36_getString(constraintMap, "spacingMode", "length");
			if (strcmp(item, "length") == 0) data->spacingMode = SP_SPACING_MODE_LENGTH;
			else if (strcmp(item, "fixed") == 0) data->spacingMode = SP_SPACING_MODE_FIXED;
			else if (strcmp(item, "percent") == 0) data->spacingMode = SP_SPACING_MODE_PERCENT;

			item = Json36_getString(constraintMap, "rotateMode", "tangent");
			if (strcmp(item, "tangent") == 0) data->rotateMode = SP_ROTATE_MODE_TANGENT;
			else if (strcmp(item, "chain") == 0) data->rotateMode = SP_ROTATE_MODE_CHAIN;
			else if (strcmp(item, "chainScale") == 0) data->rotateMode = SP_ROTATE_MODE_CHAIN_SCALE;

			data->offsetRotation = Json36_getFloat(constraintMap, "rotation", 0);
			data->position = Json36_getFloat(constraintMap, "position", 0);
			if (data->positionMode == SP_POSITION_MODE_FIXED) data->position *= self->scale;
			data->spacing = Json36_getFloat(constraintMap, "spacing", 0);
			if (data->spacingMode == SP_SPACING_MODE_LENGTH || data->spacingMode == SP_SPACING_MODE_FIXED) data->spacing *= self->scale;
			data->rotateMix = Json36_getFloat(constraintMap, "rotateMix", 1);
			data->translateMix = Json36_getFloat(constraintMap, "translateMix", 1);

			skeletonData->pathConstraints[i] = data;
		}
	}

	/* Skins. */
	skins = Json36_getItem(root, "skins");
	if (skins) {
		Json36 *skinMap;
		skeletonData->skins = MALLOC(sp36Skin*, skins->size);
		for (skinMap = skins->child, i = 0; skinMap; skinMap = skinMap->next, ++i) {
			Json36 *attachmentsMap;
			Json36 *curves;
			sp36Skin *skin = sp36Skin_create(skinMap->name);

			skeletonData->skins[skeletonData->skinsCount++] = skin;
			if (strcmp(skinMap->name, "default") == 0) skeletonData->defaultSkin = skin;

			for (attachmentsMap = skinMap->child; attachmentsMap; attachmentsMap = attachmentsMap->next) {
				int slotIndex = sp36SkeletonData_findSlotIndex(skeletonData, attachmentsMap->name);
				Json36 *attachmentMap;

				for (attachmentMap = attachmentsMap->child; attachmentMap; attachmentMap = attachmentMap->next) {
					sp36Attachment* attachment;
					const char* skinAttachmentName = attachmentMap->name;
					const char* attachmentName = Json36_getString(attachmentMap, "name", skinAttachmentName);
					const char* path = Json36_getString(attachmentMap, "path", attachmentName);
					const char* color;
					Json36* entry;

					const char* typeString = Json36_getString(attachmentMap, "type", "region");
					sp36AttachmentType type;
					if (strcmp(typeString, "region") == 0)
						type = SP_ATTACHMENT_REGION;
					else if (strcmp(typeString, "mesh") == 0)
						type = SP_ATTACHMENT_MESH;
					else if (strcmp(typeString, "linkedmesh") == 0)
						type = SP_ATTACHMENT_LINKED_MESH;
					else if (strcmp(typeString, "boundingbox") == 0)
						type = SP_ATTACHMENT_BOUNDING_BOX;
					else if (strcmp(typeString, "path") == 0)
						type = SP_ATTACHMENT_PATH;
					else if	(strcmp(typeString, "clipping") == 0)
						type = SP_ATTACHMENT_CLIPPING;
					else if	(strcmp(typeString, "point") == 0)
						type = SP_ATTACHMENT_POINT;
					else {
						sp36SkeletonData_dispose(skeletonData);
						_sp36SkeletonJson_setError(self, root, "Unknown attachment type: ", typeString);
						return 0;
					}

					attachment = sp36AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, attachmentName, path);
					if (!attachment) {
						if (self->attachmentLoader->error1) {
							sp36SkeletonData_dispose(skeletonData);
							_sp36SkeletonJson_setError(self, root, self->attachmentLoader->error1, self->attachmentLoader->error2);
							return 0;
						}
						continue;
					}

					switch (attachment->type) {
					case SP_ATTACHMENT_REGION: {
						sp36RegionAttachment* region = SUB_CAST(sp36RegionAttachment, attachment);
						if (path) MALLOC_STR(region->path, path);
						region->x = Json36_getFloat(attachmentMap, "x", 0) * self->scale;
						region->y = Json36_getFloat(attachmentMap, "y", 0) * self->scale;
						region->scaleX = Json36_getFloat(attachmentMap, "scaleX", 1);
						region->scaleY = Json36_getFloat(attachmentMap, "scaleY", 1);
						region->rotation = Json36_getFloat(attachmentMap, "rotation", 0);
						region->width = Json36_getFloat(attachmentMap, "width", 32) * self->scale;
						region->height = Json36_getFloat(attachmentMap, "height", 32) * self->scale;

						color = Json36_getString(attachmentMap, "color", 0);
						if (color) {
							sp36Color_setFromFloats(&region->color,
												  toColor(color, 0),
												  toColor(color, 1),
												  toColor(color, 2),
												  toColor(color, 3));
						}

						sp36RegionAttachment_updateOffset(region);

						sp36AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						break;
					}
					case SP_ATTACHMENT_MESH:
					case SP_ATTACHMENT_LINKED_MESH: {
						sp36MeshAttachment* mesh = SUB_CAST(sp36MeshAttachment, attachment);

						MALLOC_STR(mesh->path, path);

						color = Json36_getString(attachmentMap, "color", 0);
						if (color) {
							sp36Color_setFromFloats(&mesh->color,
												  toColor(color, 0),
												  toColor(color, 1),
												  toColor(color, 2),
												  toColor(color, 3));
						}

						mesh->width = Json36_getFloat(attachmentMap, "width", 32) * self->scale;
						mesh->height = Json36_getFloat(attachmentMap, "height", 32) * self->scale;

						entry = Json36_getItem(attachmentMap, "parent");
						if (!entry) {
							int verticesLength;
							entry = Json36_getItem(attachmentMap, "triangles");
							mesh->trianglesCount = entry->size;
							mesh->triangles = MALLOC(unsigned short, entry->size);
							for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
								mesh->triangles[ii] = (unsigned short)entry->valueInt;

							entry = Json36_getItem(attachmentMap, "uvs");
							verticesLength = entry->size;
							mesh->regionUVs = MALLOC(float, verticesLength);
							for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
								mesh->regionUVs[ii] = entry->valueFloat;

							_readVertices(self, attachmentMap, SUPER(mesh), verticesLength);

							sp36MeshAttachment_updateUVs(mesh);

							mesh->hullLength = Json36_getInt(attachmentMap, "hull", 0);

							entry = Json36_getItem(attachmentMap, "edges");
							if (entry) {
								mesh->edgesCount = entry->size;
								mesh->edges = MALLOC(int, entry->size);
								for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
									mesh->edges[ii] = entry->valueInt;
							}

							sp36AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						} else {
							mesh->inheritDeform = Json36_getInt(attachmentMap, "deform", 1);
							_sp36SkeletonJson_addLinkedMesh(self, SUB_CAST(sp36MeshAttachment, attachment), Json36_getString(attachmentMap, "skin", 0), slotIndex,
									entry->valueString);
						}
						break;
					}
					case SP_ATTACHMENT_BOUNDING_BOX: {
						sp36BoundingBoxAttachment* box = SUB_CAST(sp36BoundingBoxAttachment, attachment);
						int vertexCount = Json36_getInt(attachmentMap, "vertexCount", 0) << 1;
						_readVertices(self, attachmentMap, SUPER(box), vertexCount);
						box->super.verticesCount = vertexCount;
						sp36AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						break;
					}
					case SP_ATTACHMENT_PATH: {
						sp36PathAttachment* path = SUB_CAST(sp36PathAttachment, attachment);
						int vertexCount = 0;
						path->closed = Json36_getInt(attachmentMap, "closed", 0);
						path->constantSpeed = Json36_getInt(attachmentMap, "constantSpeed", 1);
						vertexCount = Json36_getInt(attachmentMap, "vertexCount", 0);
						_readVertices(self, attachmentMap, SUPER(path), vertexCount << 1);

						path->lengthsLength = vertexCount / 3;
						path->lengths = MALLOC(float, path->lengthsLength);

						curves = Json36_getItem(attachmentMap, "lengths");
						for (curves = curves->child, ii = 0; curves; curves = curves->next, ++ii) {
							path->lengths[ii] = curves->valueFloat * self->scale;
						}
						break;
					}
					case SP_ATTACHMENT_POINT: {
						sp36PointAttachment* point = SUB_CAST(sp36PointAttachment, attachment);
						point->x = Json36_getFloat(attachmentMap, "x", 0) * self->scale;
						point->y = Json36_getFloat(attachmentMap, "y", 0) * self->scale;
						point->rotation = Json36_getFloat(attachmentMap, "rotation", 0);

						color = Json36_getString(attachmentMap, "color", 0);
						if (color) {
							sp36Color_setFromFloats(&point->color,
												  toColor(color, 0),
												  toColor(color, 1),
												  toColor(color, 2),
												  toColor(color, 3));
						}
						break;
					}
					case SP_ATTACHMENT_CLIPPING: {
						sp36ClippingAttachment* clip = SUB_CAST(sp36ClippingAttachment, attachment);
						int vertexCount = 0;
						const char* end = Json36_getString(attachmentMap, "end", 0);
						if (end) {
							sp36SlotData* slot = sp36SkeletonData_findSlot(skeletonData, end);
							clip->endSlot = slot;
						}
						vertexCount = Json36_getInt(attachmentMap, "vertexCount", 0) << 1;
						_readVertices(self, attachmentMap, SUPER(clip), vertexCount);
						sp36AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						break;
					}
					}

					sp36Skin_addAttachment(skin, slotIndex, skinAttachmentName, attachment);
				}
			}
		}
	}

	/* Linked meshes. */
	for (i = 0; i < internal->linkedMeshCount; i++) {
		sp36Attachment* parent;
		_sp36LinkedMesh* linkedMesh = internal->linkedMeshes + i;
		sp36Skin* skin = !linkedMesh->skin ? skeletonData->defaultSkin : sp36SkeletonData_findSkin(skeletonData, linkedMesh->skin);
		if (!skin) {
			sp36SkeletonData_dispose(skeletonData);
			_sp36SkeletonJson_setError(self, 0, "Skin not found: ", linkedMesh->skin);
			return 0;
		}
		parent = sp36Skin_getAttachment(skin, linkedMesh->slotIndex, linkedMesh->parent);
		if (!parent) {
			sp36SkeletonData_dispose(skeletonData);
			_sp36SkeletonJson_setError(self, 0, "Parent mesh not found: ", linkedMesh->parent);
			return 0;
		}
		sp36MeshAttachment_setParentMesh(linkedMesh->mesh, SUB_CAST(sp36MeshAttachment, parent));
		sp36MeshAttachment_updateUVs(linkedMesh->mesh);
		sp36AttachmentLoader_configureAttachment(self->attachmentLoader, SUPER(SUPER(linkedMesh->mesh)));
	}

	/* Events. */
	events = Json36_getItem(root, "events");
	if (events) {
		Json36 *eventMap;
		const char* stringValue;
		skeletonData->eventsCount = events->size;
		skeletonData->events = MALLOC(sp36EventData*, events->size);
		for (eventMap = events->child, i = 0; eventMap; eventMap = eventMap->next, ++i) {
			sp36EventData* eventData = sp36EventData_create(eventMap->name);
			eventData->intValue = Json36_getInt(eventMap, "int", 0);
			eventData->floatValue = Json36_getFloat(eventMap, "float", 0);
			stringValue = Json36_getString(eventMap, "string", 0);
			if (stringValue) MALLOC_STR(eventData->stringValue, stringValue);
			skeletonData->events[i] = eventData;
		}
	}

	/* Animations. */
	animations = Json36_getItem(root, "animations");
	if (animations) {
		Json36 *animationMap;
		skeletonData->animations = MALLOC(sp36Animation*, animations->size);
		for (animationMap = animations->child; animationMap; animationMap = animationMap->next) {
			sp36Animation* animation = _sp36SkeletonJson_readAnimation(self, animationMap, skeletonData);
			if (!animation) {
				sp36SkeletonData_dispose(skeletonData);
				return 0;
			}
			skeletonData->animations[skeletonData->animationsCount++] = animation;
		}
	}

	Json36_dispose(root);
	return skeletonData;
}

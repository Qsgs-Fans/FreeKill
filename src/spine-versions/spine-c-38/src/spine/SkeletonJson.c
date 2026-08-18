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
	sp38MeshAttachment* mesh;
	int inheritDeform;
} _sp38LinkedMesh;

typedef struct {
	sp38SkeletonJson super;
	int ownsLoader;

	int linkedMeshCount;
	int linkedMeshCapacity;
	_sp38LinkedMesh* linkedMeshes;
} _sp38SkeletonJson;

sp38SkeletonJson* sp38SkeletonJson_createWithLoader (sp38AttachmentLoader* attachmentLoader) {
	sp38SkeletonJson* self = SUPER(NEW(_sp38SkeletonJson));
	self->scale = 1;
	self->attachmentLoader = attachmentLoader;
	return self;
}

sp38SkeletonJson* sp38SkeletonJson_create (sp38Atlas* atlas) {
	sp38AtlasAttachmentLoader* attachmentLoader = sp38AtlasAttachmentLoader_create(atlas);
	sp38SkeletonJson* self = sp38SkeletonJson_createWithLoader(SUPER(attachmentLoader));
	SUB_CAST(_sp38SkeletonJson, self)->ownsLoader = 1;
	return self;
}

void sp38SkeletonJson_dispose (sp38SkeletonJson* self) {
	_sp38SkeletonJson* internal = SUB_CAST(_sp38SkeletonJson, self);
	if (internal->ownsLoader) sp38AttachmentLoader_dispose(self->attachmentLoader);
	FREE(internal->linkedMeshes);
	FREE(self->error);
	FREE(self);
}

void _sp38SkeletonJson_setError (sp38SkeletonJson* self, Json38* root, const char* value1, const char* value2) {
	char message[256];
	int length;
	FREE(self->error);
	strcpy(message, value1);
	length = (int)strlen(value1);
	if (value2) strncat(message + length, value2, 255 - length);
	MALLOC_STR(self->error, message);
	if (root) Json38_dispose(root);
}

static float toColor (const char* value, int index) {
	char digits[3];
	char *error;
	int color;

	if ((size_t)index >= strlen(value) / 2) return -1;
	value += index * 2;

	digits[0] = *value;
	digits[1] = *(value + 1);
	digits[2] = '\0';
	color = (int)strtoul(digits, &error, 16);
	if (*error != 0) return -1;
	return color / (float)255;
}

static void readCurve (Json38* frame, sp38CurveTimeline* timeline, int frameIndex) {
	Json38* curve = Json38_getItem(frame, "curve");
	if (!curve) return;
	if (curve->type == Json38_String && strcmp(curve->valueString, "stepped") == 0)
		sp38CurveTimeline_setStepped(timeline, frameIndex);
	else {
		float c1 = Json38_getFloat(frame, "curve", 0);
		float c2 = Json38_getFloat(frame, "c2", 0);
		float c3 = Json38_getFloat(frame, "c3", 1);
		float c4 = Json38_getFloat(frame, "c4", 1);
		sp38CurveTimeline_setCurve(timeline, frameIndex, c1, c2, c3, c4);
	}
}

static void _sp38SkeletonJson_addLinkedMesh (sp38SkeletonJson* self, sp38MeshAttachment* mesh, const char* skin, int slotIndex,
	const char* parent, int inheritDeform
) {
	_sp38LinkedMesh* linkedMesh;
	_sp38SkeletonJson* internal = SUB_CAST(_sp38SkeletonJson, self);

	if (internal->linkedMeshCount == internal->linkedMeshCapacity) {
		_sp38LinkedMesh* linkedMeshes;
		internal->linkedMeshCapacity *= 2;
		if (internal->linkedMeshCapacity < 8) internal->linkedMeshCapacity = 8;
		linkedMeshes = MALLOC(_sp38LinkedMesh, internal->linkedMeshCapacity);
		memcpy(linkedMeshes, internal->linkedMeshes, sizeof(_sp38LinkedMesh) * internal->linkedMeshCount);
		FREE(internal->linkedMeshes);
		internal->linkedMeshes = linkedMeshes;
	}

	linkedMesh = internal->linkedMeshes + internal->linkedMeshCount++;
	linkedMesh->mesh = mesh;
	linkedMesh->skin = skin;
	linkedMesh->slotIndex = slotIndex;
	linkedMesh->parent = parent;
	linkedMesh->inheritDeform = inheritDeform;
}

static sp38Animation* _sp38SkeletonJson_readAnimation (sp38SkeletonJson* self, Json38* root, sp38SkeletonData *skeletonData) {
	int frameIndex;
	sp38Animation* animation;
	Json38* valueMap;
	int timelinesCount = 0;

	Json38* bones = Json38_getItem(root, "bones");
	Json38* slots = Json38_getItem(root, "slots");
	Json38* ik = Json38_getItem(root, "ik");
	Json38* transform = Json38_getItem(root, "transform");
	Json38* paths = Json38_getItem(root, "paths");
	Json38* deformJson = Json38_getItem(root, "deform");
	Json38* drawOrderJson = Json38_getItem(root, "drawOrder");
	Json38* events = Json38_getItem(root, "events");
	Json38 *boneMap, *slotMap, *constraintMap;
	if (!drawOrderJson) drawOrderJson = Json38_getItem(root, "draworder");

	for (boneMap = bones ? bones->child : 0; boneMap; boneMap = boneMap->next)
		timelinesCount += boneMap->size;
	for (slotMap = slots ? slots->child : 0; slotMap; slotMap = slotMap->next)
		timelinesCount += slotMap->size;
	timelinesCount += ik ? ik->size : 0;
	timelinesCount += transform ? transform->size : 0;
	for (constraintMap = paths ? paths->child : 0; constraintMap; constraintMap = constraintMap->next)
		timelinesCount += constraintMap->size;
	for (constraintMap = deformJson ? deformJson->child : 0; constraintMap; constraintMap = constraintMap->next)
		for (slotMap = constraintMap->child; slotMap; slotMap = slotMap->next)
			timelinesCount += slotMap->size;
	if (drawOrderJson) ++timelinesCount;
	if (events) ++timelinesCount;

	animation = sp38Animation_create(root->name, timelinesCount);
	animation->timelinesCount = 0;

	/* Slot timelines. */
	for (slotMap = slots ? slots->child : 0; slotMap; slotMap = slotMap->next) {
		Json38 *timelineMap;

		int slotIndex = sp38SkeletonData_findSlotIndex(skeletonData, slotMap->name);
		if (slotIndex == -1) {
			sp38Animation_dispose(animation);
			_sp38SkeletonJson_setError(self, root, "Slot not found: ", slotMap->name);
			return 0;
		}

		for (timelineMap = slotMap->child; timelineMap; timelineMap = timelineMap->next) {
			if (strcmp(timelineMap->name, "attachment") == 0) {
				sp38AttachmentTimeline *timeline = sp38AttachmentTimeline_create(timelineMap->size);
				timeline->slotIndex = slotIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					Json38* name = Json38_getItem(valueMap, "name");
					sp38AttachmentTimeline_setFrame(timeline, frameIndex, Json38_getFloat(valueMap, "time", 0),
						name->type == Json38_NULL ? 0 : name->valueString);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp38Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[timelineMap->size - 1]);

			} else if (strcmp(timelineMap->name, "color") == 0) {
				sp38ColorTimeline *timeline = sp38ColorTimeline_create(timelineMap->size);
				timeline->slotIndex = slotIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					const char* s = Json38_getString(valueMap, "color", 0);
					sp38ColorTimeline_setFrame(timeline, frameIndex, Json38_getFloat(valueMap, "time", 0), toColor(s, 0), toColor(s, 1),
						toColor(s, 2), toColor(s, 3));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp38Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * COLOR_ENTRIES]);

			} else if (strcmp(timelineMap->name, "twoColor") == 0) {
				sp38TwoColorTimeline *timeline = sp38TwoColorTimeline_create(timelineMap->size);
				timeline->slotIndex = slotIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					const char* s = Json38_getString(valueMap, "light", 0);
					const char* ds = Json38_getString(valueMap, "dark", 0);
					sp38TwoColorTimeline_setFrame(timeline, frameIndex, Json38_getFloat(valueMap, "time", 0), toColor(s, 0), toColor(s, 1), toColor(s, 2),
						toColor(s, 3), toColor(ds, 0), toColor(ds, 1), toColor(ds, 2));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp38Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * TWOCOLOR_ENTRIES]);

			} else {
				sp38Animation_dispose(animation);
				_sp38SkeletonJson_setError(self, 0, "Invalid timeline type for a slot: ", timelineMap->name);
				return 0;
			}
		}
	}

	/* Bone timelines. */
	for (boneMap = bones ? bones->child : 0; boneMap; boneMap = boneMap->next) {
		Json38 *timelineMap;

		int boneIndex = sp38SkeletonData_findBoneIndex(skeletonData, boneMap->name);
		if (boneIndex == -1) {
			sp38Animation_dispose(animation);
			_sp38SkeletonJson_setError(self, root, "Bone not found: ", boneMap->name);
			return 0;
		}

		for (timelineMap = boneMap->child; timelineMap; timelineMap = timelineMap->next) {
			if (strcmp(timelineMap->name, "rotate") == 0) {
				sp38RotateTimeline *timeline = sp38RotateTimeline_create(timelineMap->size);
				timeline->boneIndex = boneIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					sp38RotateTimeline_setFrame(timeline, frameIndex, Json38_getFloat(valueMap, "time", 0), Json38_getFloat(valueMap, "angle", 0));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp38Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * ROTATE_ENTRIES]);

			} else {
				int isScale = strcmp(timelineMap->name, "scale") == 0;
				int isTranslate = strcmp(timelineMap->name, "translate") == 0;
				int isShear = strcmp(timelineMap->name, "shear") == 0;
				if (isScale || isTranslate || isShear) {
					float defaultValue = 0;
					float timelineScale = isTranslate ? self->scale: 1;
					sp38TranslateTimeline *timeline = 0;
					if (isScale) {
						timeline = sp38ScaleTimeline_create(timelineMap->size);
						defaultValue = 1;
					}
					else if (isTranslate) timeline = sp38TranslateTimeline_create(timelineMap->size);
					else if (isShear) timeline = sp38ShearTimeline_create(timelineMap->size);
					timeline->boneIndex = boneIndex;

					for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
						sp38TranslateTimeline_setFrame(timeline, frameIndex, Json38_getFloat(valueMap, "time", 0),
							Json38_getFloat(valueMap, "x", defaultValue) * timelineScale,
							Json38_getFloat(valueMap, "y", defaultValue) * timelineScale);
						readCurve(valueMap, SUPER(timeline), frameIndex);
					}
					animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp38Timeline, timeline);
					animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * TRANSLATE_ENTRIES]);

				} else {
					sp38Animation_dispose(animation);
					_sp38SkeletonJson_setError(self, 0, "Invalid timeline type for a bone: ", timelineMap->name);
					return 0;
				}
			}
		}
	}

	/* IK constraint timelines. */
	for (constraintMap = ik ? ik->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp38IkConstraintData* constraint = sp38SkeletonData_findIkConstraint(skeletonData, constraintMap->name);
		sp38IkConstraintTimeline* timeline = sp38IkConstraintTimeline_create(constraintMap->size);
		for (frameIndex = 0; frameIndex < skeletonData->ikConstraintsCount; ++frameIndex) {
			if (constraint == skeletonData->ikConstraints[frameIndex]) {
				timeline->ikConstraintIndex = frameIndex;
				break;
			}
		}
		for (valueMap = constraintMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			sp38IkConstraintTimeline_setFrame(timeline, frameIndex, Json38_getFloat(valueMap, "time", 0), Json38_getFloat(valueMap, "mix", 1), Json38_getFloat(valueMap, "softness", 0) * self->scale,
					Json38_getInt(valueMap, "bendPositive", 1) ? 1 : -1, Json38_getInt(valueMap, "compress", 0) ? 1 : 0, Json38_getInt(valueMap, "stretch", 0) ? 1 : 0);
			readCurve(valueMap, SUPER(timeline), frameIndex);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp38Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[(constraintMap->size - 1) * IKCONSTRAINT_ENTRIES]);
	}

	/* Transform constraint timelines. */
	for (constraintMap = transform ? transform->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp38TransformConstraintData* constraint = sp38SkeletonData_findTransformConstraint(skeletonData, constraintMap->name);
		sp38TransformConstraintTimeline* timeline = sp38TransformConstraintTimeline_create(constraintMap->size);
		for (frameIndex = 0; frameIndex < skeletonData->transformConstraintsCount; ++frameIndex) {
			if (constraint == skeletonData->transformConstraints[frameIndex]) {
				timeline->transformConstraintIndex = frameIndex;
				break;
			}
		}
		for (valueMap = constraintMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			sp38TransformConstraintTimeline_setFrame(timeline, frameIndex, Json38_getFloat(valueMap, "time", 0), Json38_getFloat(valueMap, "rotateMix", 1),
					Json38_getFloat(valueMap, "translateMix", 1), Json38_getFloat(valueMap, "scaleMix", 1), Json38_getFloat(valueMap, "shearMix", 1));
			readCurve(valueMap, SUPER(timeline), frameIndex);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp38Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[(constraintMap->size - 1) * TRANSFORMCONSTRAINT_ENTRIES]);
	}

	/** Path constraint timelines. */
	for(constraintMap = paths ? paths->child : 0; constraintMap; constraintMap = constraintMap->next ) {
		int constraintIndex, i;
		Json38* timelineMap;

		sp38PathConstraintData* data = sp38SkeletonData_findPathConstraint(skeletonData, constraintMap->name);
		if (!data) {
			sp38Animation_dispose(animation);
			_sp38SkeletonJson_setError(self, root, "Path constraint not found: ", constraintMap->name);
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
				sp38PathConstraintPositionTimeline* timeline;
				float timelineScale = 1;
				if (strcmp(timelineName, "spacing") == 0) {
					timeline = (sp38PathConstraintPositionTimeline*)sp38PathConstraintSpacingTimeline_create(timelineMap->size);
					if (data->spacingMode == SP_SPACING_MODE_LENGTH || data->spacingMode == SP_SPACING_MODE_FIXED) timelineScale = self->scale;
				} else {
					timeline = sp38PathConstraintPositionTimeline_create(timelineMap->size);
					if (data->positionMode == SP_POSITION_MODE_FIXED) timelineScale = self->scale;
				}
				timeline->pathConstraintIndex = constraintIndex;
				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					sp38PathConstraintPositionTimeline_setFrame(timeline, frameIndex, Json38_getFloat(valueMap, "time", 0), Json38_getFloat(valueMap, timelineName, 0) * timelineScale);
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp38Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * PATHCONSTRAINTPOSITION_ENTRIES]);
			} else if (strcmp(timelineName, "mix") == 0) {
				sp38PathConstraintMixTimeline* timeline = sp38PathConstraintMixTimeline_create(timelineMap->size);
				timeline->pathConstraintIndex = constraintIndex;
				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					sp38PathConstraintMixTimeline_setFrame(timeline, frameIndex, Json38_getFloat(valueMap, "time", 0),
						Json38_getFloat(valueMap, "rotateMix", 1), Json38_getFloat(valueMap, "translateMix", 1));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp38Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * PATHCONSTRAINTMIX_ENTRIES]);
			}
		}
	}

	/* Deform timelines. */
	for (constraintMap = deformJson ? deformJson->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp38Skin* skin = sp38SkeletonData_findSkin(skeletonData, constraintMap->name);
		for (slotMap = constraintMap->child; slotMap; slotMap = slotMap->next) {
			int slotIndex = sp38SkeletonData_findSlotIndex(skeletonData, slotMap->name);
			Json38* timelineMap;
			for (timelineMap = slotMap->child; timelineMap; timelineMap = timelineMap->next) {
				float* tempDeform;
				sp38DeformTimeline *timeline;
				int weighted, deformLength;

				sp38VertexAttachment* attachment = SUB_CAST(sp38VertexAttachment, sp38Skin_getAttachment(skin, slotIndex, timelineMap->name));
				if (!attachment) {
					sp38Animation_dispose(animation);
					_sp38SkeletonJson_setError(self, 0, "Attachment not found: ", timelineMap->name);
					return 0;
				}
				weighted = attachment->bones != 0;
				deformLength = weighted ? attachment->verticesCount / 3 * 2 : attachment->verticesCount;
				tempDeform = MALLOC(float, deformLength);

				timeline = sp38DeformTimeline_create(timelineMap->size, deformLength);
				timeline->slotIndex = slotIndex;
				timeline->attachment = SUPER(attachment);

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					float* deform;
					Json38* vertices = Json38_getItem(valueMap, "vertices");
					if (!vertices) {
						if (weighted) {
							deform = tempDeform;
							memset(deform, 0, sizeof(float) * deformLength);
						} else
							deform = attachment->vertices;
					} else {
						int v, start = Json38_getInt(valueMap, "offset", 0);
						Json38* vertex;
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
							float* verticesValues = attachment->vertices;
							for (v = 0; v < deformLength; ++v)
								deform[v] += verticesValues[v];
						}
					}
					sp38DeformTimeline_setFrame(timeline, frameIndex, Json38_getFloat(valueMap, "time", 0), deform);
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				FREE(tempDeform);

				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp38Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[timelineMap->size - 1]);
			}
		}
	}

	/* Draw order timeline. */
	if (drawOrderJson) {
		sp38DrawOrderTimeline* timeline = sp38DrawOrderTimeline_create(drawOrderJson->size, skeletonData->slotsCount);
		for (valueMap = drawOrderJson->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			int ii;
			int* drawOrder = 0;
			Json38* offsets = Json38_getItem(valueMap, "offsets");
			if (offsets) {
				Json38* offsetMap;
				int* unchanged = MALLOC(int, skeletonData->slotsCount - offsets->size);
				int originalIndex = 0, unchangedIndex = 0;

				drawOrder = MALLOC(int, skeletonData->slotsCount);
				for (ii = skeletonData->slotsCount - 1; ii >= 0; --ii)
					drawOrder[ii] = -1;

				for (offsetMap = offsets->child; offsetMap; offsetMap = offsetMap->next) {
					int slotIndex = sp38SkeletonData_findSlotIndex(skeletonData, Json38_getString(offsetMap, "slot", 0));
					if (slotIndex == -1) {
						sp38Animation_dispose(animation);
						_sp38SkeletonJson_setError(self, 0, "Slot not found: ", Json38_getString(offsetMap, "slot", 0));
						return 0;
					}
					/* Collect unchanged items. */
					while (originalIndex != slotIndex)
						unchanged[unchangedIndex++] = originalIndex++;
					/* Set changed items. */
					drawOrder[originalIndex + Json38_getInt(offsetMap, "offset", 0)] = originalIndex;
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
			sp38DrawOrderTimeline_setFrame(timeline, frameIndex, Json38_getFloat(valueMap, "time", 0), drawOrder);
			FREE(drawOrder);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp38Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[drawOrderJson->size - 1]);
	}

	/* Event timeline. */
	if (events) {
		sp38EventTimeline* timeline = sp38EventTimeline_create(events->size);
		for (valueMap = events->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			sp38Event* event;
			const char* stringValue;
			sp38EventData* eventData = sp38SkeletonData_findEvent(skeletonData, Json38_getString(valueMap, "name", 0));
			if (!eventData) {
				sp38Animation_dispose(animation);
				_sp38SkeletonJson_setError(self, 0, "Event not found: ", Json38_getString(valueMap, "name", 0));
				return 0;
			}
			event = sp38Event_create(Json38_getFloat(valueMap, "time", 0), eventData);
			event->intValue = Json38_getInt(valueMap, "int", eventData->intValue);
			event->floatValue = Json38_getFloat(valueMap, "float", eventData->floatValue);
			stringValue = Json38_getString(valueMap, "string", eventData->stringValue);
			if (stringValue) MALLOC_STR(event->stringValue, stringValue);
			if (eventData->audioPath) {
				event->volume = Json38_getFloat(valueMap, "volume", 1);
				event->balance = Json38_getFloat(valueMap, "volume", 0);
			}
			sp38EventTimeline_setFrame(timeline, frameIndex, event);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp38Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[events->size - 1]);
	}

	return animation;
}

static void _readVertices (sp38SkeletonJson* self, Json38* attachmentMap, sp38VertexAttachment* attachment, int verticesLength) {
	Json38* entry;
	float* vertices;
	int i, n, nn, entrySize;
	sp38FloatArray* weights;
	sp38IntArray* bones;

	attachment->worldVerticesLength = verticesLength;

	entry = Json38_getItem(attachmentMap, "vertices");
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

	weights = sp38FloatArray_create(verticesLength * 3 * 3);
	bones = sp38IntArray_create(verticesLength * 3);

	for (i = 0, n = entrySize; i < n;) {
		int boneCount = (int)vertices[i++];
		sp38IntArray_add(bones, boneCount);
		for (nn = i + boneCount * 4; i < nn; i += 4) {
			sp38IntArray_add(bones, (int)vertices[i]);
			sp38FloatArray_add(weights, vertices[i + 1] * self->scale);
			sp38FloatArray_add(weights, vertices[i + 2] * self->scale);
			sp38FloatArray_add(weights, vertices[i + 3]);
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

sp38SkeletonData* sp38SkeletonJson_readSkeletonDataFile (sp38SkeletonJson* self, const char* path) {
	int length;
	sp38SkeletonData* skeletonData;
	const char* json = _sp38Util_readFile(path, &length);
	if (length == 0 || !json) {
		_sp38SkeletonJson_setError(self, 0, "Unable to read skeleton file: ", path);
		return 0;
	}
	skeletonData = sp38SkeletonJson_readSkeletonData(self, json);
	FREE(json);
	return skeletonData;
}

sp38SkeletonData* sp38SkeletonJson_readSkeletonData (sp38SkeletonJson* self, const char* json) {
	int i, ii;
	sp38SkeletonData* skeletonData;
	Json38 *root, *skeleton, *bones, *boneMap, *ik, *transform, *pathJson, *slots, *skins, *animations, *events;
	_sp38SkeletonJson* internal = SUB_CAST(_sp38SkeletonJson, self);

	FREE(self->error);
	CONST_CAST(char*, self->error) = 0;
	internal->linkedMeshCount = 0;

	root = Json38_create(json);

	if (!root) {
		_sp38SkeletonJson_setError(self, 0, "Invalid skeleton JSON: ", Json38_getError());
		return 0;
	}

	skeletonData = sp38SkeletonData_create();

	skeleton = Json38_getItem(root, "skeleton");
	if (skeleton) {
		MALLOC_STR(skeletonData->hash, Json38_getString(skeleton, "hash", 0));
		MALLOC_STR(skeletonData->version, Json38_getString(skeleton, "spine", 0));
        if (strcmp(skeletonData->version, "3.8.75") == 0) {
            sp38SkeletonData_dispose(skeletonData);
            _sp38SkeletonJson_setError(self, root, "Unsupported skeleton data, please export with a newer version of Spine.", "");
            return 0;
        }
		skeletonData->x = Json38_getFloat(skeleton, "x", 0);
		skeletonData->y = Json38_getFloat(skeleton, "y", 0);
		skeletonData->width = Json38_getFloat(skeleton, "width", 0);
		skeletonData->height = Json38_getFloat(skeleton, "height", 0);
	}

	/* Bones. */
	bones = Json38_getItem(root, "bones");
	skeletonData->bones = MALLOC(sp38BoneData*, bones->size);
	for (boneMap = bones->child, i = 0; boneMap; boneMap = boneMap->next, ++i) {
		sp38BoneData* data;
		const char* transformMode;

		sp38BoneData* parent = 0;
		const char* parentName = Json38_getString(boneMap, "parent", 0);
		if (parentName) {
			parent = sp38SkeletonData_findBone(skeletonData, parentName);
			if (!parent) {
				sp38SkeletonData_dispose(skeletonData);
				_sp38SkeletonJson_setError(self, root, "Parent bone not found: ", parentName);
				return 0;
			}
		}

		data = sp38BoneData_create(skeletonData->bonesCount, Json38_getString(boneMap, "name", 0), parent);
		data->length = Json38_getFloat(boneMap, "length", 0) * self->scale;
		data->x = Json38_getFloat(boneMap, "x", 0) * self->scale;
		data->y = Json38_getFloat(boneMap, "y", 0) * self->scale;
		data->rotation = Json38_getFloat(boneMap, "rotation", 0);
		data->scaleX = Json38_getFloat(boneMap, "scaleX", 1);
		data->scaleY = Json38_getFloat(boneMap, "scaleY", 1);
		data->shearX = Json38_getFloat(boneMap, "shearX", 0);
		data->shearY = Json38_getFloat(boneMap, "shearY", 0);
		transformMode = Json38_getString(boneMap, "transform", "normal");
		data->transformMode = SP_TRANSFORMMODE_NORMAL;
		if (strcmp(transformMode, "normal") == 0) data->transformMode = SP_TRANSFORMMODE_NORMAL;
		else if (strcmp(transformMode, "onlyTranslation") == 0) data->transformMode = SP_TRANSFORMMODE_ONLYTRANSLATION;
		else if (strcmp(transformMode, "noRotationOrReflection") == 0) data->transformMode = SP_TRANSFORMMODE_NOROTATIONORREFLECTION;
		else if (strcmp(transformMode, "noScale") == 0) data->transformMode = SP_TRANSFORMMODE_NOSCALE;
		else if (strcmp(transformMode, "noScaleOrReflection") == 0) data->transformMode = SP_TRANSFORMMODE_NOSCALEORREFLECTION;
		data->skinRequired = Json38_getInt(boneMap, "skin", 0) ? 1 : 0;

		skeletonData->bones[i] = data;
		skeletonData->bonesCount++;
	}

	/* Slots. */
	slots = Json38_getItem(root, "slots");
	if (slots) {
		Json38 *slotMap;
		skeletonData->slotsCount = slots->size;
		skeletonData->slots = MALLOC(sp38SlotData*, slots->size);
		for (slotMap = slots->child, i = 0; slotMap; slotMap = slotMap->next, ++i) {
			sp38SlotData* data;
			const char* color;
			const char* dark;
			Json38 *item;

			const char* boneName = Json38_getString(slotMap, "bone", 0);
			sp38BoneData* boneData = sp38SkeletonData_findBone(skeletonData, boneName);
			if (!boneData) {
				sp38SkeletonData_dispose(skeletonData);
				_sp38SkeletonJson_setError(self, root, "Slot bone not found: ", boneName);
				return 0;
			}

			data = sp38SlotData_create(i, Json38_getString(slotMap, "name", 0), boneData);

			color = Json38_getString(slotMap, "color", 0);
			if (color) {
				sp38Color_setFromFloats(&data->color,
					toColor(color, 0),
					toColor(color, 1),
					toColor(color, 2),
					toColor(color, 3));
			}

			dark = Json38_getString(slotMap, "dark", 0);
			if (dark) {
				data->darkColor = sp38Color_create();
				sp38Color_setFromFloats(data->darkColor,
					toColor(dark, 0),
					toColor(dark, 1),
					toColor(dark, 2),
					toColor(dark, 3));
			}

			item = Json38_getItem(slotMap, "attachment");
			if (item) sp38SlotData_setAttachmentName(data, item->valueString);

			item = Json38_getItem(slotMap, "blend");
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
	ik = Json38_getItem(root, "ik");
	if (ik) {
		Json38 *constraintMap;
		skeletonData->ikConstraintsCount = ik->size;
		skeletonData->ikConstraints = MALLOC(sp38IkConstraintData*, ik->size);
		for (constraintMap = ik->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char* targetName;

			sp38IkConstraintData* data = sp38IkConstraintData_create(Json38_getString(constraintMap, "name", 0));
			data->order = Json38_getInt(constraintMap, "order", 0);
			data->skinRequired = Json38_getInt(constraintMap, "skin", 0) ? 1 : 0;

			boneMap = Json38_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			data->bones = MALLOC(sp38BoneData*, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp38SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp38SkeletonData_dispose(skeletonData);
					_sp38SkeletonJson_setError(self, root, "IK bone not found: ", boneMap->valueString);
					return 0;
				}
			}

			targetName = Json38_getString(constraintMap, "target", 0);
			data->target = sp38SkeletonData_findBone(skeletonData, targetName);
			if (!data->target) {
				sp38SkeletonData_dispose(skeletonData);
				_sp38SkeletonJson_setError(self, root, "Target bone not found: ", targetName);
				return 0;
			}

			data->bendDirection = Json38_getInt(constraintMap, "bendPositive", 1) ? 1 : -1;
			data->compress = Json38_getInt(constraintMap, "compress", 0) ? 1 : 0;
			data->stretch = Json38_getInt(constraintMap, "stretch", 0) ? 1 : 0;
			data->uniform = Json38_getInt(constraintMap, "uniform", 0) ? 1 : 0;
			data->mix = Json38_getFloat(constraintMap, "mix", 1);
			data->softness = Json38_getFloat(constraintMap, "softness", 0) * self->scale;

			skeletonData->ikConstraints[i] = data;
		}
	}

	/* Transform constraints. */
	transform = Json38_getItem(root, "transform");
	if (transform) {
		Json38 *constraintMap;
		skeletonData->transformConstraintsCount = transform->size;
		skeletonData->transformConstraints = MALLOC(sp38TransformConstraintData*, transform->size);
		for (constraintMap = transform->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char* name;

			sp38TransformConstraintData* data = sp38TransformConstraintData_create(Json38_getString(constraintMap, "name", 0));
			data->order = Json38_getInt(constraintMap, "order", 0);
			data->skinRequired = Json38_getInt(constraintMap, "skin", 0) ? 1 : 0;

			boneMap = Json38_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			CONST_CAST(sp38BoneData**, data->bones) = MALLOC(sp38BoneData*, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp38SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp38SkeletonData_dispose(skeletonData);
					_sp38SkeletonJson_setError(self, root, "Transform bone not found: ", boneMap->valueString);
					return 0;
				}
			}

			name = Json38_getString(constraintMap, "target", 0);
			data->target = sp38SkeletonData_findBone(skeletonData, name);
			if (!data->target) {
				sp38SkeletonData_dispose(skeletonData);
				_sp38SkeletonJson_setError(self, root, "Target bone not found: ", name);
				return 0;
			}

			data->local = Json38_getInt(constraintMap, "local", 0);
			data->relative = Json38_getInt(constraintMap, "relative", 0);
			data->offsetRotation = Json38_getFloat(constraintMap, "rotation", 0);
			data->offsetX = Json38_getFloat(constraintMap, "x", 0) * self->scale;
			data->offsetY = Json38_getFloat(constraintMap, "y", 0) * self->scale;
			data->offsetScaleX = Json38_getFloat(constraintMap, "scaleX", 0);
			data->offsetScaleY = Json38_getFloat(constraintMap, "scaleY", 0);
			data->offsetShearY = Json38_getFloat(constraintMap, "shearY", 0);

			data->rotateMix = Json38_getFloat(constraintMap, "rotateMix", 1);
			data->translateMix = Json38_getFloat(constraintMap, "translateMix", 1);
			data->scaleMix = Json38_getFloat(constraintMap, "scaleMix", 1);
			data->shearMix = Json38_getFloat(constraintMap, "shearMix", 1);

			skeletonData->transformConstraints[i] = data;
		}
	}

	/* Path constraints */
	pathJson = Json38_getItem(root, "path");
	if (pathJson) {
		Json38 *constraintMap;
		skeletonData->pathConstraintsCount = pathJson->size;
		skeletonData->pathConstraints = MALLOC(sp38PathConstraintData*, pathJson->size);
		for (constraintMap = pathJson->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char* name;
			const char* item;

			sp38PathConstraintData* data = sp38PathConstraintData_create(Json38_getString(constraintMap, "name", 0));
			data->order = Json38_getInt(constraintMap, "order", 0);
			data->skinRequired = Json38_getInt(constraintMap, "skin", 0) ? 1 : 0;

			boneMap = Json38_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			CONST_CAST(sp38BoneData**, data->bones) = MALLOC(sp38BoneData*, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp38SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp38SkeletonData_dispose(skeletonData);
					_sp38SkeletonJson_setError(self, root, "Path bone not found: ", boneMap->valueString);
					return 0;
				}
			}

			name = Json38_getString(constraintMap, "target", 0);
			data->target = sp38SkeletonData_findSlot(skeletonData, name);
			if (!data->target) {
				sp38SkeletonData_dispose(skeletonData);
				_sp38SkeletonJson_setError(self, root, "Target slot not found: ", name);
				return 0;
			}

			item = Json38_getString(constraintMap, "positionMode", "percent");
			if (strcmp(item, "fixed") == 0) data->positionMode = SP_POSITION_MODE_FIXED;
			else if (strcmp(item, "percent") == 0) data->positionMode = SP_POSITION_MODE_PERCENT;

			item = Json38_getString(constraintMap, "spacingMode", "length");
			if (strcmp(item, "length") == 0) data->spacingMode = SP_SPACING_MODE_LENGTH;
			else if (strcmp(item, "fixed") == 0) data->spacingMode = SP_SPACING_MODE_FIXED;
			else if (strcmp(item, "percent") == 0) data->spacingMode = SP_SPACING_MODE_PERCENT;

			item = Json38_getString(constraintMap, "rotateMode", "tangent");
			if (strcmp(item, "tangent") == 0) data->rotateMode = SP_ROTATE_MODE_TANGENT;
			else if (strcmp(item, "chain") == 0) data->rotateMode = SP_ROTATE_MODE_CHAIN;
			else if (strcmp(item, "chainScale") == 0) data->rotateMode = SP_ROTATE_MODE_CHAIN_SCALE;

			data->offsetRotation = Json38_getFloat(constraintMap, "rotation", 0);
			data->position = Json38_getFloat(constraintMap, "position", 0);
			if (data->positionMode == SP_POSITION_MODE_FIXED) data->position *= self->scale;
			data->spacing = Json38_getFloat(constraintMap, "spacing", 0);
			if (data->spacingMode == SP_SPACING_MODE_LENGTH || data->spacingMode == SP_SPACING_MODE_FIXED) data->spacing *= self->scale;
			data->rotateMix = Json38_getFloat(constraintMap, "rotateMix", 1);
			data->translateMix = Json38_getFloat(constraintMap, "translateMix", 1);

			skeletonData->pathConstraints[i] = data;
		}
	}

	/* Skins. */
	skins = Json38_getItem(root, "skins");
	if (skins) {
		Json38 *skinMap;
		skeletonData->skins = MALLOC(sp38Skin*, skins->size);
		for (skinMap = skins->child, i = 0; skinMap; skinMap = skinMap->next, ++i) {
			Json38 *attachmentsMap;
			Json38 *curves;
			Json38 *skinPart;
			sp38Skin *skin = sp38Skin_create(Json38_getString(skinMap, "name", ""));

			skinPart = Json38_getItem(skinMap, "bones");
			if (skinPart) {
				for(skinPart = skinPart->child; skinPart; skinPart = skinPart->next) {
					sp38BoneData* bone = sp38SkeletonData_findBone(skeletonData, skinPart->valueString);
					if (!bone) {
						sp38SkeletonData_dispose(skeletonData);
						_sp38SkeletonJson_setError(self, root, "Skin bone constraint not found: ", skinPart->valueString);
						return 0;
					}
					sp38BoneDataArray_add(skin->bones, bone);
				}
			}

			skinPart = Json38_getItem(skinMap, "ik");
			if (skinPart) {
				for(skinPart = skinPart->child; skinPart; skinPart = skinPart->next) {
					sp38IkConstraintData* constraint = sp38SkeletonData_findIkConstraint(skeletonData, skinPart->valueString);
					if (!constraint) {
						sp38SkeletonData_dispose(skeletonData);
						_sp38SkeletonJson_setError(self, root, "Skin IK constraint not found: ", skinPart->valueString);
						return 0;
					}
					sp38IkConstraintDataArray_add(skin->ikConstraints, constraint);
				}
			}

			skinPart = Json38_getItem(skinMap, "path");
			if (skinPart) {
				for(skinPart = skinPart->child; skinPart; skinPart = skinPart->next) {
					sp38PathConstraintData* constraint = sp38SkeletonData_findPathConstraint(skeletonData, skinPart->valueString);
					if (!constraint) {
						sp38SkeletonData_dispose(skeletonData);
						_sp38SkeletonJson_setError(self, root, "Skin path constraint not found: ", skinPart->valueString);
						return 0;
					}
					sp38PathConstraintDataArray_add(skin->pathConstraints, constraint);
				}
			}

			skinPart = Json38_getItem(skinMap, "transform");
			if (skinPart) {
				for(skinPart = skinPart->child; skinPart; skinPart = skinPart->next) {
					sp38TransformConstraintData* constraint = sp38SkeletonData_findTransformConstraint(skeletonData, skinPart->valueString);
					if (!constraint) {
						sp38SkeletonData_dispose(skeletonData);
						_sp38SkeletonJson_setError(self, root, "Skin transform constraint not found: ", skinPart->valueString);
						return 0;
					}
					sp38TransformConstraintDataArray_add(skin->transformConstraints, constraint);
				}
			}

			skeletonData->skins[skeletonData->skinsCount++] = skin;
			if (strcmp(skin->name, "default") == 0) skeletonData->defaultSkin = skin;

			for (attachmentsMap = Json38_getItem(skinMap, "attachments")->child; attachmentsMap; attachmentsMap = attachmentsMap->next) {
				sp38SlotData* slot = sp38SkeletonData_findSlot(skeletonData, attachmentsMap->name);
				Json38 *attachmentMap;

				for (attachmentMap = attachmentsMap->child; attachmentMap; attachmentMap = attachmentMap->next) {
					sp38Attachment* attachment;
					const char* skinAttachmentName = attachmentMap->name;
					const char* attachmentName = Json38_getString(attachmentMap, "name", skinAttachmentName);
					const char* path = Json38_getString(attachmentMap, "path", attachmentName);
					const char* color;
					Json38* entry;

					const char* typeString = Json38_getString(attachmentMap, "type", "region");
					sp38AttachmentType type;
					if (strcmp(typeString, "region") == 0) type = SP_ATTACHMENT_REGION;
					else if (strcmp(typeString, "mesh") == 0) type = SP_ATTACHMENT_MESH;
					else if (strcmp(typeString, "linkedmesh") == 0) type = SP_ATTACHMENT_LINKED_MESH;
					else if (strcmp(typeString, "boundingbox") == 0) type = SP_ATTACHMENT_BOUNDING_BOX;
					else if (strcmp(typeString, "path") == 0) type = SP_ATTACHMENT_PATH;
					else if	(strcmp(typeString, "clipping") == 0) type = SP_ATTACHMENT_CLIPPING;
					else if	(strcmp(typeString, "point") == 0) type = SP_ATTACHMENT_POINT;
					else {
						sp38SkeletonData_dispose(skeletonData);
						_sp38SkeletonJson_setError(self, root, "Unknown attachment type: ", typeString);
						return 0;
					}

					attachment = sp38AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, attachmentName, path);
					if (!attachment) {
						if (self->attachmentLoader->error1) {
							sp38SkeletonData_dispose(skeletonData);
							_sp38SkeletonJson_setError(self, root, self->attachmentLoader->error1, self->attachmentLoader->error2);
							return 0;
						}
						continue;
					}

					switch (attachment->type) {
					case SP_ATTACHMENT_REGION: {
						sp38RegionAttachment* region = SUB_CAST(sp38RegionAttachment, attachment);
						if (path) MALLOC_STR(region->path, path);
						region->x = Json38_getFloat(attachmentMap, "x", 0) * self->scale;
						region->y = Json38_getFloat(attachmentMap, "y", 0) * self->scale;
						region->scaleX = Json38_getFloat(attachmentMap, "scaleX", 1);
						region->scaleY = Json38_getFloat(attachmentMap, "scaleY", 1);
						region->rotation = Json38_getFloat(attachmentMap, "rotation", 0);
						region->width = Json38_getFloat(attachmentMap, "width", 32) * self->scale;
						region->height = Json38_getFloat(attachmentMap, "height", 32) * self->scale;

						color = Json38_getString(attachmentMap, "color", 0);
						if (color) {
							sp38Color_setFromFloats(&region->color,
								toColor(color, 0),
								toColor(color, 1),
								toColor(color, 2),
								toColor(color, 3));
						}

						sp38RegionAttachment_updateOffset(region);

						sp38AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						break;
					}
					case SP_ATTACHMENT_MESH:
					case SP_ATTACHMENT_LINKED_MESH: {
						sp38MeshAttachment* mesh = SUB_CAST(sp38MeshAttachment, attachment);

						MALLOC_STR(mesh->path, path);

						color = Json38_getString(attachmentMap, "color", 0);
						if (color) {
							sp38Color_setFromFloats(&mesh->color,
								toColor(color, 0),
								toColor(color, 1),
								toColor(color, 2),
								toColor(color, 3));
						}

						mesh->width = Json38_getFloat(attachmentMap, "width", 32) * self->scale;
						mesh->height = Json38_getFloat(attachmentMap, "height", 32) * self->scale;

						entry = Json38_getItem(attachmentMap, "parent");
						if (!entry) {
							int verticesLength;
							entry = Json38_getItem(attachmentMap, "triangles");
							mesh->trianglesCount = entry->size;
							mesh->triangles = MALLOC(unsigned short, entry->size);
							for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
								mesh->triangles[ii] = (unsigned short)entry->valueInt;

							entry = Json38_getItem(attachmentMap, "uvs");
							verticesLength = entry->size;
							mesh->regionUVs = MALLOC(float, verticesLength);
							for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
								mesh->regionUVs[ii] = entry->valueFloat;

							_readVertices(self, attachmentMap, SUPER(mesh), verticesLength);

							sp38MeshAttachment_updateUVs(mesh);

							mesh->hullLength = Json38_getInt(attachmentMap, "hull", 0);

							entry = Json38_getItem(attachmentMap, "edges");
							if (entry) {
								mesh->edgesCount = entry->size;
								mesh->edges = MALLOC(int, entry->size);
								for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
									mesh->edges[ii] = entry->valueInt;
							}

							sp38AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						} else {
							int inheritDeform = Json38_getInt(attachmentMap, "deform", 1);
							_sp38SkeletonJson_addLinkedMesh(self, SUB_CAST(sp38MeshAttachment, attachment),
								Json38_getString(attachmentMap, "skin", 0), slot->index, entry->valueString, inheritDeform);
						}
						break;
					}
					case SP_ATTACHMENT_BOUNDING_BOX: {
						sp38BoundingBoxAttachment* box = SUB_CAST(sp38BoundingBoxAttachment, attachment);
						int vertexCount = Json38_getInt(attachmentMap, "vertexCount", 0) << 1;
						_readVertices(self, attachmentMap, SUPER(box), vertexCount);
						box->super.verticesCount = vertexCount;
						sp38AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						break;
					}
					case SP_ATTACHMENT_PATH: {
						sp38PathAttachment* pathAttachment = SUB_CAST(sp38PathAttachment, attachment);
						int vertexCount = 0;
						pathAttachment->closed = Json38_getInt(attachmentMap, "closed", 0);
						pathAttachment->constantSpeed = Json38_getInt(attachmentMap, "constantSpeed", 1);
						vertexCount = Json38_getInt(attachmentMap, "vertexCount", 0);
						_readVertices(self, attachmentMap, SUPER(pathAttachment), vertexCount << 1);

						pathAttachment->lengthsLength = vertexCount / 3;
						pathAttachment->lengths = MALLOC(float, pathAttachment->lengthsLength);

						curves = Json38_getItem(attachmentMap, "lengths");
						for (curves = curves->child, ii = 0; curves; curves = curves->next, ++ii)
							pathAttachment->lengths[ii] = curves->valueFloat * self->scale;
						break;
					}
					case SP_ATTACHMENT_POINT: {
						sp38PointAttachment* point = SUB_CAST(sp38PointAttachment, attachment);
						point->x = Json38_getFloat(attachmentMap, "x", 0) * self->scale;
						point->y = Json38_getFloat(attachmentMap, "y", 0) * self->scale;
						point->rotation = Json38_getFloat(attachmentMap, "rotation", 0);

						color = Json38_getString(attachmentMap, "color", 0);
						if (color) {
							sp38Color_setFromFloats(&point->color,
								toColor(color, 0),
								toColor(color, 1),
								toColor(color, 2),
								toColor(color, 3));
						}
						break;
					}
					case SP_ATTACHMENT_CLIPPING: {
						sp38ClippingAttachment* clip = SUB_CAST(sp38ClippingAttachment, attachment);
						int vertexCount = 0;
						const char* end = Json38_getString(attachmentMap, "end", 0);
						if (end) {
							sp38SlotData* endSlot = sp38SkeletonData_findSlot(skeletonData, end);
							clip->endSlot = endSlot;
						}
						vertexCount = Json38_getInt(attachmentMap, "vertexCount", 0) << 1;
						_readVertices(self, attachmentMap, SUPER(clip), vertexCount);
						sp38AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						break;
					}
					}

					sp38Skin_setAttachment(skin, slot->index, skinAttachmentName, attachment);
				}
			}
		}
	}

	/* Linked meshes. */
	for (i = 0; i < internal->linkedMeshCount; i++) {
		sp38Attachment* parent;
		_sp38LinkedMesh* linkedMesh = internal->linkedMeshes + i;
		sp38Skin* skin = !linkedMesh->skin ? skeletonData->defaultSkin : sp38SkeletonData_findSkin(skeletonData, linkedMesh->skin);
		if (!skin) {
			sp38SkeletonData_dispose(skeletonData);
			_sp38SkeletonJson_setError(self, 0, "Skin not found: ", linkedMesh->skin);
			return 0;
		}
		parent = sp38Skin_getAttachment(skin, linkedMesh->slotIndex, linkedMesh->parent);
		if (!parent) {
			sp38SkeletonData_dispose(skeletonData);
			_sp38SkeletonJson_setError(self, 0, "Parent mesh not found: ", linkedMesh->parent);
			return 0;
		}
		linkedMesh->mesh->super.deformAttachment = linkedMesh->inheritDeform ? SUB_CAST(sp38VertexAttachment, parent) : SUB_CAST(sp38VertexAttachment, linkedMesh->mesh);
		sp38MeshAttachment_setParentMesh(linkedMesh->mesh, SUB_CAST(sp38MeshAttachment, parent));
		sp38MeshAttachment_updateUVs(linkedMesh->mesh);
		sp38AttachmentLoader_configureAttachment(self->attachmentLoader, SUPER(SUPER(linkedMesh->mesh)));
	}

	/* Events. */
	events = Json38_getItem(root, "events");
	if (events) {
		Json38 *eventMap;
		const char* stringValue;
		const char* audioPath;
		skeletonData->eventsCount = events->size;
		skeletonData->events = MALLOC(sp38EventData*, events->size);
		for (eventMap = events->child, i = 0; eventMap; eventMap = eventMap->next, ++i) {
			sp38EventData* eventData = sp38EventData_create(eventMap->name);
			eventData->intValue = Json38_getInt(eventMap, "int", 0);
			eventData->floatValue = Json38_getFloat(eventMap, "float", 0);
			stringValue = Json38_getString(eventMap, "string", 0);
			if (stringValue) MALLOC_STR(eventData->stringValue, stringValue);
			audioPath = Json38_getString(eventMap, "audio", 0);
			if (audioPath) {
				MALLOC_STR(eventData->audioPath, audioPath);
				eventData->volume = Json38_getFloat(eventMap, "volume", 1);
				eventData->balance = Json38_getFloat(eventMap, "balance", 0);
			}
			skeletonData->events[i] = eventData;
		}
	}

	/* Animations. */
	animations = Json38_getItem(root, "animations");
	if (animations) {
		Json38 *animationMap;
		skeletonData->animations = MALLOC(sp38Animation*, animations->size);
		for (animationMap = animations->child; animationMap; animationMap = animationMap->next) {
			sp38Animation* animation = _sp38SkeletonJson_readAnimation(self, animationMap, skeletonData);
			if (!animation) {
				sp38SkeletonData_dispose(skeletonData);
				return 0;
			}
			skeletonData->animations[skeletonData->animationsCount++] = animation;
		}
	}

	Json38_dispose(root);
	return skeletonData;
}

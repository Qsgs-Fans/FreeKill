/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated May 1, 2019. Replaces all prior versions.
 *
 * Copyright (c) 2013-2019, Esoteric Software LLC
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
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE LLC "AS IS" AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
 * NO EVENT SHALL ESOTERIC SOFTWARE LLC BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, BUSINESS
 * INTERRUPTION, OR LOSS OF USE, DATA, OR PROFITS) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
	sp37MeshAttachment* mesh;
} _sp37LinkedMesh;

typedef struct {
	sp37SkeletonJson super;
	int ownsLoader;

	int linkedMeshCount;
	int linkedMeshCapacity;
	_sp37LinkedMesh* linkedMeshes;
} _sp37SkeletonJson;

sp37SkeletonJson* sp37SkeletonJson_createWithLoader (sp37AttachmentLoader* attachmentLoader) {
	sp37SkeletonJson* self = SUPER(NEW(_sp37SkeletonJson));
	self->scale = 1;
	self->attachmentLoader = attachmentLoader;
	return self;
}

sp37SkeletonJson* sp37SkeletonJson_create (sp37Atlas* atlas) {
	sp37AtlasAttachmentLoader* attachmentLoader = sp37AtlasAttachmentLoader_create(atlas);
	sp37SkeletonJson* self = sp37SkeletonJson_createWithLoader(SUPER(attachmentLoader));
	SUB_CAST(_sp37SkeletonJson, self)->ownsLoader = 1;
	return self;
}

void sp37SkeletonJson_dispose (sp37SkeletonJson* self) {
	_sp37SkeletonJson* internal = SUB_CAST(_sp37SkeletonJson, self);
	if (internal->ownsLoader) sp37AttachmentLoader_dispose(self->attachmentLoader);
	FREE(internal->linkedMeshes);
	FREE(self->error);
	FREE(self);
}

void _sp37SkeletonJson_setError (sp37SkeletonJson* self, Json37* root, const char* value1, const char* value2) {
	char message[256];
	int length;
	FREE(self->error);
	strcpy(message, value1);
	length = (int)strlen(value1);
	if (value2) strncat(message + length, value2, 255 - length);
	MALLOC_STR(self->error, message);
	if (root) Json37_dispose(root);
}

static float toColor (const char* value, int index) {
	char digits[3];
	char *error;
	int color;

	if ((size_t)index >= strlen(value) / 2)
		return -1;
	value += index * 2;

	digits[0] = *value;
	digits[1] = *(value + 1);
	digits[2] = '\0';
	color = (int)strtoul(digits, &error, 16);
	if (*error != 0) return -1;
	return color / (float)255;
}

static void readCurve (Json37* frame, sp37CurveTimeline* timeline, int frameIndex) {
	Json37* curve = Json37_getItem(frame, "curve");
	if (!curve) return;
	if (curve->type == Json37_String && strcmp(curve->valueString, "stepped") == 0)
		sp37CurveTimeline_setStepped(timeline, frameIndex);
	else if (curve->type == Json37_Array) {
		Json37* child0 = curve->child;
		Json37* child1 = child0->next;
		Json37* child2 = child1->next;
		Json37* child3 = child2->next;
		sp37CurveTimeline_setCurve(timeline, frameIndex, child0->valueFloat, child1->valueFloat, child2->valueFloat,
				child3->valueFloat);
	}
}

static void _sp37SkeletonJson_addLinkedMesh (sp37SkeletonJson* self, sp37MeshAttachment* mesh, const char* skin, int slotIndex,
		const char* parent) {
	_sp37LinkedMesh* linkedMesh;
	_sp37SkeletonJson* internal = SUB_CAST(_sp37SkeletonJson, self);

	if (internal->linkedMeshCount == internal->linkedMeshCapacity) {
		_sp37LinkedMesh* linkedMeshes;
		internal->linkedMeshCapacity *= 2;
		if (internal->linkedMeshCapacity < 8) internal->linkedMeshCapacity = 8;
		linkedMeshes = MALLOC(_sp37LinkedMesh, internal->linkedMeshCapacity);
		memcpy(linkedMeshes, internal->linkedMeshes, sizeof(_sp37LinkedMesh) * internal->linkedMeshCount);
		FREE(internal->linkedMeshes);
		internal->linkedMeshes = linkedMeshes;
	}

	linkedMesh = internal->linkedMeshes + internal->linkedMeshCount++;
	linkedMesh->mesh = mesh;
	linkedMesh->skin = skin;
	linkedMesh->slotIndex = slotIndex;
	linkedMesh->parent = parent;
}

static sp37Animation* _sp37SkeletonJson_readAnimation (sp37SkeletonJson* self, Json37* root, sp37SkeletonData *skeletonData) {
	int frameIndex;
	sp37Animation* animation;
	Json37* valueMap;
	int timelinesCount = 0;

	Json37* bones = Json37_getItem(root, "bones");
	Json37* slots = Json37_getItem(root, "slots");
	Json37* ik = Json37_getItem(root, "ik");
	Json37* transform = Json37_getItem(root, "transform");
	Json37* paths = Json37_getItem(root, "paths");
	Json37* deform = Json37_getItem(root, "deform");
	Json37* drawOrder = Json37_getItem(root, "drawOrder");
	Json37* events = Json37_getItem(root, "events");
	Json37 *boneMap, *slotMap, *constraintMap;
	if (!drawOrder) drawOrder = Json37_getItem(root, "draworder");

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

	animation = sp37Animation_create(root->name, timelinesCount);
	animation->timelinesCount = 0;

	/* Slot timelines. */
	for (slotMap = slots ? slots->child : 0; slotMap; slotMap = slotMap->next) {
		Json37 *timelineMap;

		int slotIndex = sp37SkeletonData_findSlotIndex(skeletonData, slotMap->name);
		if (slotIndex == -1) {
			sp37Animation_dispose(animation);
			_sp37SkeletonJson_setError(self, root, "Slot not found: ", slotMap->name);
			return 0;
		}

		for (timelineMap = slotMap->child; timelineMap; timelineMap = timelineMap->next) {
			if (strcmp(timelineMap->name, "attachment") == 0) {
				sp37AttachmentTimeline *timeline = sp37AttachmentTimeline_create(timelineMap->size);
				timeline->slotIndex = slotIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					Json37* name = Json37_getItem(valueMap, "name");
					sp37AttachmentTimeline_setFrame(timeline, frameIndex, Json37_getFloat(valueMap, "time", 0),
												  name->type == Json37_NULL ? 0 : name->valueString);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp37Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[timelineMap->size - 1]);

			} else if (strcmp(timelineMap->name, "color") == 0) {
				sp37ColorTimeline *timeline = sp37ColorTimeline_create(timelineMap->size);
				timeline->slotIndex = slotIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					const char* s = Json37_getString(valueMap, "color", 0);
					sp37ColorTimeline_setFrame(timeline, frameIndex, Json37_getFloat(valueMap, "time", 0), toColor(s, 0), toColor(s, 1), toColor(s, 2),
							toColor(s, 3));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp37Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * COLOR_ENTRIES]);

			} else if (strcmp(timelineMap->name, "twoColor") == 0) {
				sp37TwoColorTimeline *timeline = sp37TwoColorTimeline_create(timelineMap->size);
				timeline->slotIndex = slotIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					const char* s = Json37_getString(valueMap, "light", 0);
					const char* ds = Json37_getString(valueMap, "dark", 0);
					sp37TwoColorTimeline_setFrame(timeline, frameIndex, Json37_getFloat(valueMap, "time", 0), toColor(s, 0), toColor(s, 1), toColor(s, 2),
											 toColor(s, 3), toColor(ds, 0), toColor(ds, 1), toColor(ds, 2));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp37Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * TWOCOLOR_ENTRIES]);

			} else {
				sp37Animation_dispose(animation);
				_sp37SkeletonJson_setError(self, 0, "Invalid timeline type for a slot: ", timelineMap->name);
				return 0;
			}
		}
	}

	/* Bone timelines. */
	for (boneMap = bones ? bones->child : 0; boneMap; boneMap = boneMap->next) {
		Json37 *timelineMap;

		int boneIndex = sp37SkeletonData_findBoneIndex(skeletonData, boneMap->name);
		if (boneIndex == -1) {
			sp37Animation_dispose(animation);
			_sp37SkeletonJson_setError(self, root, "Bone not found: ", boneMap->name);
			return 0;
		}

		for (timelineMap = boneMap->child; timelineMap; timelineMap = timelineMap->next) {
			if (strcmp(timelineMap->name, "rotate") == 0) {
				sp37RotateTimeline *timeline = sp37RotateTimeline_create(timelineMap->size);
				timeline->boneIndex = boneIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					sp37RotateTimeline_setFrame(timeline, frameIndex, Json37_getFloat(valueMap, "time", 0), Json37_getFloat(valueMap, "angle", 0));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp37Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * ROTATE_ENTRIES]);

			} else {
				int isScale = strcmp(timelineMap->name, "scale") == 0;
				int isTranslate = strcmp(timelineMap->name, "translate") == 0;
				int isShear = strcmp(timelineMap->name, "shear") == 0;
				if (isScale || isTranslate || isShear) {
					float timelineScale = isTranslate ? self->scale: 1;
					sp37TranslateTimeline *timeline = 0;
					if (isScale) timeline = sp37ScaleTimeline_create(timelineMap->size);
					else if (isTranslate) timeline = sp37TranslateTimeline_create(timelineMap->size);
					else if (isShear) timeline = sp37ShearTimeline_create(timelineMap->size);
					timeline->boneIndex = boneIndex;

					for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
						sp37TranslateTimeline_setFrame(timeline, frameIndex, Json37_getFloat(valueMap, "time", 0), Json37_getFloat(valueMap, "x", 0) * timelineScale,
								Json37_getFloat(valueMap, "y", 0) * timelineScale);
						readCurve(valueMap, SUPER(timeline), frameIndex);
					}
					animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp37Timeline, timeline);
					animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * TRANSLATE_ENTRIES]);

				} else {
					sp37Animation_dispose(animation);
					_sp37SkeletonJson_setError(self, 0, "Invalid timeline type for a bone: ", timelineMap->name);
					return 0;
				}
			}
		}
	}

	/* IK constraint timelines. */
	for (constraintMap = ik ? ik->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp37IkConstraintData* constraint = sp37SkeletonData_findIkConstraint(skeletonData, constraintMap->name);
		sp37IkConstraintTimeline* timeline = sp37IkConstraintTimeline_create(constraintMap->size);
		for (frameIndex = 0; frameIndex < skeletonData->ikConstraintsCount; ++frameIndex) {
			if (constraint == skeletonData->ikConstraints[frameIndex]) {
				timeline->ikConstraintIndex = frameIndex;
				break;
			}
		}
		for (valueMap = constraintMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			sp37IkConstraintTimeline_setFrame(timeline, frameIndex, Json37_getFloat(valueMap, "time", 0), Json37_getFloat(valueMap, "mix", 1),
					Json37_getInt(valueMap, "bendPositive", 1) ? 1 : -1, Json37_getInt(valueMap, "compress", 0) ? 1 : 0, Json37_getInt(valueMap, "stretch", 0) ? 1 : 0);
			readCurve(valueMap, SUPER(timeline), frameIndex);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp37Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[(constraintMap->size - 1) * IKCONSTRAINT_ENTRIES]);
	}

	/* Transform constraint timelines. */
	for (constraintMap = transform ? transform->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp37TransformConstraintData* constraint = sp37SkeletonData_findTransformConstraint(skeletonData, constraintMap->name);
		sp37TransformConstraintTimeline* timeline = sp37TransformConstraintTimeline_create(constraintMap->size);
		for (frameIndex = 0; frameIndex < skeletonData->transformConstraintsCount; ++frameIndex) {
			if (constraint == skeletonData->transformConstraints[frameIndex]) {
				timeline->transformConstraintIndex = frameIndex;
				break;
			}
		}
		for (valueMap = constraintMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			sp37TransformConstraintTimeline_setFrame(timeline, frameIndex, Json37_getFloat(valueMap, "time", 0), Json37_getFloat(valueMap, "rotateMix", 1),
					Json37_getFloat(valueMap, "translateMix", 1), Json37_getFloat(valueMap, "scaleMix", 1), Json37_getFloat(valueMap, "shearMix", 1));
			readCurve(valueMap, SUPER(timeline), frameIndex);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp37Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[(constraintMap->size - 1) * TRANSFORMCONSTRAINT_ENTRIES]);
	}

	/** Path constraint timelines. */
	for(constraintMap = paths ? paths->child : 0; constraintMap; constraintMap = constraintMap->next ) {
		int constraintIndex, i;
		Json37* timelineMap;

		sp37PathConstraintData* data = sp37SkeletonData_findPathConstraint(skeletonData, constraintMap->name);
		if (!data) {
			sp37Animation_dispose(animation);
			_sp37SkeletonJson_setError(self, root, "Path constraint not found: ", constraintMap->name);
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
				sp37PathConstraintPositionTimeline* timeline;
				float timelineScale = 1;
				if (strcmp(timelineName, "spacing") == 0) {
					timeline = (sp37PathConstraintPositionTimeline*)sp37PathConstraintSpacingTimeline_create(timelineMap->size);
					if (data->spacingMode == SP_SPACING_MODE_LENGTH || data->spacingMode == SP_SPACING_MODE_FIXED) timelineScale = self->scale;
				} else {
					timeline = sp37PathConstraintPositionTimeline_create(timelineMap->size);
					if (data->positionMode == SP_POSITION_MODE_FIXED) timelineScale = self->scale;
				}
				timeline->pathConstraintIndex = constraintIndex;
				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					sp37PathConstraintPositionTimeline_setFrame(timeline, frameIndex, Json37_getFloat(valueMap, "time", 0), Json37_getFloat(valueMap, timelineName, 0) * timelineScale);
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp37Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * PATHCONSTRAINTPOSITION_ENTRIES]);
			} else if (strcmp(timelineName, "mix") == 0) {
				sp37PathConstraintMixTimeline* timeline = sp37PathConstraintMixTimeline_create(timelineMap->size);
				timeline->pathConstraintIndex = constraintIndex;
				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					sp37PathConstraintMixTimeline_setFrame(timeline, frameIndex, Json37_getFloat(valueMap, "time", 0),
						Json37_getFloat(valueMap, "rotateMix", 1), Json37_getFloat(valueMap, "translateMix", 1));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp37Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * PATHCONSTRAINTMIX_ENTRIES]);
			}
		}
	}

	/* Deform timelines. */
	for (constraintMap = deform ? deform->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp37Skin* skin = sp37SkeletonData_findSkin(skeletonData, constraintMap->name);
		for (slotMap = constraintMap->child; slotMap; slotMap = slotMap->next) {
			int slotIndex = sp37SkeletonData_findSlotIndex(skeletonData, slotMap->name);
			Json37* timelineMap;
			for (timelineMap = slotMap->child; timelineMap; timelineMap = timelineMap->next) {
				float* tempDeform;
				sp37DeformTimeline *timeline;
				int weighted, deformLength;

				sp37VertexAttachment* attachment = SUB_CAST(sp37VertexAttachment, sp37Skin_getAttachment(skin, slotIndex, timelineMap->name));
				if (!attachment) {
					sp37Animation_dispose(animation);
					_sp37SkeletonJson_setError(self, 0, "Attachment not found: ", timelineMap->name);
					return 0;
				}
				weighted = attachment->bones != 0;
				deformLength = weighted ? attachment->verticesCount / 3 * 2 : attachment->verticesCount;
				tempDeform = MALLOC(float, deformLength);

				timeline = sp37DeformTimeline_create(timelineMap->size, deformLength);
				timeline->slotIndex = slotIndex;
				timeline->attachment = SUPER(attachment);

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					Json37* vertices = Json37_getItem(valueMap, "vertices");
					float* deform;
					if (!vertices) {
						if (weighted) {
							deform = tempDeform;
							memset(deform, 0, sizeof(float) * deformLength);
						} else
							deform = attachment->vertices;
					} else {
						int v, start = Json37_getInt(valueMap, "offset", 0);
						Json37* vertex;
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
					sp37DeformTimeline_setFrame(timeline, frameIndex, Json37_getFloat(valueMap, "time", 0), deform);
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				FREE(tempDeform);

				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp37Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[timelineMap->size - 1]);
			}
		}
	}

	/* Draw order timeline. */
	if (drawOrder) {
		sp37DrawOrderTimeline* timeline = sp37DrawOrderTimeline_create(drawOrder->size, skeletonData->slotsCount);
		for (valueMap = drawOrder->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			int ii;
			int* drawOrder = 0;
			Json37* offsets = Json37_getItem(valueMap, "offsets");
			if (offsets) {
				Json37* offsetMap;
				int* unchanged = MALLOC(int, skeletonData->slotsCount - offsets->size);
				int originalIndex = 0, unchangedIndex = 0;

				drawOrder = MALLOC(int, skeletonData->slotsCount);
				for (ii = skeletonData->slotsCount - 1; ii >= 0; --ii)
					drawOrder[ii] = -1;

				for (offsetMap = offsets->child; offsetMap; offsetMap = offsetMap->next) {
					int slotIndex = sp37SkeletonData_findSlotIndex(skeletonData, Json37_getString(offsetMap, "slot", 0));
					if (slotIndex == -1) {
						sp37Animation_dispose(animation);
						_sp37SkeletonJson_setError(self, 0, "Slot not found: ", Json37_getString(offsetMap, "slot", 0));
						return 0;
					}
					/* Collect unchanged items. */
					while (originalIndex != slotIndex)
						unchanged[unchangedIndex++] = originalIndex++;
					/* Set changed items. */
					drawOrder[originalIndex + Json37_getInt(offsetMap, "offset", 0)] = originalIndex;
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
			sp37DrawOrderTimeline_setFrame(timeline, frameIndex, Json37_getFloat(valueMap, "time", 0), drawOrder);
			FREE(drawOrder);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp37Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[drawOrder->size - 1]);
	}

	/* Event timeline. */
	if (events) {
		sp37EventTimeline* timeline = sp37EventTimeline_create(events->size);
		for (valueMap = events->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			sp37Event* event;
			const char* stringValue;
			sp37EventData* eventData = sp37SkeletonData_findEvent(skeletonData, Json37_getString(valueMap, "name", 0));
			if (!eventData) {
				sp37Animation_dispose(animation);
				_sp37SkeletonJson_setError(self, 0, "Event not found: ", Json37_getString(valueMap, "name", 0));
				return 0;
			}
			event = sp37Event_create(Json37_getFloat(valueMap, "time", 0), eventData);
			event->intValue = Json37_getInt(valueMap, "int", eventData->intValue);
			event->floatValue = Json37_getFloat(valueMap, "float", eventData->floatValue);
			stringValue = Json37_getString(valueMap, "string", eventData->stringValue);
			if (stringValue) MALLOC_STR(event->stringValue, stringValue);
			if (eventData->audioPath) {
				event->volume = Json37_getFloat(valueMap, "volume", 1);
				event->balance = Json37_getFloat(valueMap, "volume", 0);
			}
			sp37EventTimeline_setFrame(timeline, frameIndex, event);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp37Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[events->size - 1]);
	}

	return animation;
}

static void _readVertices (sp37SkeletonJson* self, Json37* attachmentMap, sp37VertexAttachment* attachment, int verticesLength) {
	Json37* entry;
	float* vertices;
	int i, n, nn, entrySize;
	sp37FloatArray* weights;
	sp37IntArray* bones;

	attachment->worldVerticesLength = verticesLength;

	entry = Json37_getItem(attachmentMap, "vertices");
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

	weights = sp37FloatArray_create(verticesLength * 3 * 3);
	bones = sp37IntArray_create(verticesLength * 3);

	for (i = 0, n = entrySize; i < n;) {
		int boneCount = (int)vertices[i++];
		sp37IntArray_add(bones, boneCount);
		for (nn = i + boneCount * 4; i < nn; i += 4) {
			sp37IntArray_add(bones, (int)vertices[i]);
			sp37FloatArray_add(weights, vertices[i + 1] * self->scale);
			sp37FloatArray_add(weights, vertices[i + 2] * self->scale);
			sp37FloatArray_add(weights, vertices[i + 3]);
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

sp37SkeletonData* sp37SkeletonJson_readSkeletonDataFile (sp37SkeletonJson* self, const char* path) {
	int length;
	sp37SkeletonData* skeletonData;
	const char* json = _sp37Util_readFile(path, &length);
	if (length == 0 || !json) {
		_sp37SkeletonJson_setError(self, 0, "Unable to read skeleton file: ", path);
		return 0;
	}
	skeletonData = sp37SkeletonJson_readSkeletonData(self, json);
	FREE(json);
	return skeletonData;
}

sp37SkeletonData* sp37SkeletonJson_readSkeletonData (sp37SkeletonJson* self, const char* json) {
	int i, ii;
	sp37SkeletonData* skeletonData;
	Json37 *root, *skeleton, *bones, *boneMap, *ik, *transform, *path, *slots, *skins, *animations, *events;
	_sp37SkeletonJson* internal = SUB_CAST(_sp37SkeletonJson, self);

	FREE(self->error);
	CONST_CAST(char*, self->error) = 0;
	internal->linkedMeshCount = 0;

	root = Json37_create(json);

	if (!root) {
		_sp37SkeletonJson_setError(self, 0, "Invalid skeleton JSON: ", Json37_getError());
		return 0;
	}

	skeletonData = sp37SkeletonData_create();

	skeleton = Json37_getItem(root, "skeleton");
	if (skeleton) {
		MALLOC_STR(skeletonData->hash, Json37_getString(skeleton, "hash", 0));
		MALLOC_STR(skeletonData->version, Json37_getString(skeleton, "spine", 0));
		skeletonData->width = Json37_getFloat(skeleton, "width", 0);
		skeletonData->height = Json37_getFloat(skeleton, "height", 0);
	}

	/* Bones. */
	bones = Json37_getItem(root, "bones");
	skeletonData->bones = MALLOC(sp37BoneData*, bones->size);
	for (boneMap = bones->child, i = 0; boneMap; boneMap = boneMap->next, ++i) {
		sp37BoneData* data;
		const char* transformMode;

		sp37BoneData* parent = 0;
		const char* parentName = Json37_getString(boneMap, "parent", 0);
		if (parentName) {
			parent = sp37SkeletonData_findBone(skeletonData, parentName);
			if (!parent) {
				sp37SkeletonData_dispose(skeletonData);
				_sp37SkeletonJson_setError(self, root, "Parent bone not found: ", parentName);
				return 0;
			}
		}

		data = sp37BoneData_create(skeletonData->bonesCount, Json37_getString(boneMap, "name", 0), parent);
		data->length = Json37_getFloat(boneMap, "length", 0) * self->scale;
		data->x = Json37_getFloat(boneMap, "x", 0) * self->scale;
		data->y = Json37_getFloat(boneMap, "y", 0) * self->scale;
		data->rotation = Json37_getFloat(boneMap, "rotation", 0);
		data->scaleX = Json37_getFloat(boneMap, "scaleX", 1);
		data->scaleY = Json37_getFloat(boneMap, "scaleY", 1);
		data->shearX = Json37_getFloat(boneMap, "shearX", 0);
		data->shearY = Json37_getFloat(boneMap, "shearY", 0);
		transformMode = Json37_getString(boneMap, "transform", "normal");
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
	slots = Json37_getItem(root, "slots");
	if (slots) {
		Json37 *slotMap;
		skeletonData->slotsCount = slots->size;
		skeletonData->slots = MALLOC(sp37SlotData*, slots->size);
		for (slotMap = slots->child, i = 0; slotMap; slotMap = slotMap->next, ++i) {
			sp37SlotData* data;
			const char* color;
			const char* dark;
			Json37 *item;

			const char* boneName = Json37_getString(slotMap, "bone", 0);
			sp37BoneData* boneData = sp37SkeletonData_findBone(skeletonData, boneName);
			if (!boneData) {
				sp37SkeletonData_dispose(skeletonData);
				_sp37SkeletonJson_setError(self, root, "Slot bone not found: ", boneName);
				return 0;
			}

			data = sp37SlotData_create(i, Json37_getString(slotMap, "name", 0), boneData);

			color = Json37_getString(slotMap, "color", 0);
			if (color) {
				sp37Color_setFromFloats(&data->color,
									  toColor(color, 0),
									  toColor(color, 1),
									  toColor(color, 2),
									  toColor(color, 3));
			}

			dark = Json37_getString(slotMap, "dark", 0);
			if (dark) {
				data->darkColor = sp37Color_create();
				sp37Color_setFromFloats(data->darkColor,
									  toColor(dark, 0),
									  toColor(dark, 1),
									  toColor(dark, 2),
									  toColor(dark, 3));
			}

			item = Json37_getItem(slotMap, "attachment");
			if (item) sp37SlotData_setAttachmentName(data, item->valueString);

			item = Json37_getItem(slotMap, "blend");
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
	ik = Json37_getItem(root, "ik");
	if (ik) {
		Json37 *constraintMap;
		skeletonData->ikConstraintsCount = ik->size;
		skeletonData->ikConstraints = MALLOC(sp37IkConstraintData*, ik->size);
		for (constraintMap = ik->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char* targetName;

			sp37IkConstraintData* data = sp37IkConstraintData_create(Json37_getString(constraintMap, "name", 0));
			data->order = Json37_getInt(constraintMap, "order", 0);

			boneMap = Json37_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			data->bones = MALLOC(sp37BoneData*, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp37SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp37SkeletonData_dispose(skeletonData);
					_sp37SkeletonJson_setError(self, root, "IK bone not found: ", boneMap->valueString);
					return 0;
				}
			}

			targetName = Json37_getString(constraintMap, "target", 0);
			data->target = sp37SkeletonData_findBone(skeletonData, targetName);
			if (!data->target) {
				sp37SkeletonData_dispose(skeletonData);
				_sp37SkeletonJson_setError(self, root, "Target bone not found: ", targetName);
				return 0;
			}

			data->bendDirection = Json37_getInt(constraintMap, "bendPositive", 1) ? 1 : -1;
			data->compress = Json37_getInt(constraintMap, "compress", 0) ? 1 : 0;
			data->stretch = Json37_getInt(constraintMap, "stretch", 0) ? 1 : 0;
			data->uniform = Json37_getInt(constraintMap, "uniform", 0) ? 1 : 0;
			data->mix = Json37_getFloat(constraintMap, "mix", 1);

			skeletonData->ikConstraints[i] = data;
		}
	}

	/* Transform constraints. */
	transform = Json37_getItem(root, "transform");
	if (transform) {
		Json37 *constraintMap;
		skeletonData->transformConstraintsCount = transform->size;
		skeletonData->transformConstraints = MALLOC(sp37TransformConstraintData*, transform->size);
		for (constraintMap = transform->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char* name;

			sp37TransformConstraintData* data = sp37TransformConstraintData_create(Json37_getString(constraintMap, "name", 0));
			data->order = Json37_getInt(constraintMap, "order", 0);

			boneMap = Json37_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			CONST_CAST(sp37BoneData**, data->bones) = MALLOC(sp37BoneData*, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp37SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp37SkeletonData_dispose(skeletonData);
					_sp37SkeletonJson_setError(self, root, "Transform bone not found: ", boneMap->valueString);
					return 0;
				}
			}

			name = Json37_getString(constraintMap, "target", 0);
			data->target = sp37SkeletonData_findBone(skeletonData, name);
			if (!data->target) {
				sp37SkeletonData_dispose(skeletonData);
				_sp37SkeletonJson_setError(self, root, "Target bone not found: ", name);
				return 0;
			}

			data->local = Json37_getInt(constraintMap, "local", 0);
			data->relative = Json37_getInt(constraintMap, "relative", 0);
			data->offsetRotation = Json37_getFloat(constraintMap, "rotation", 0);
			data->offsetX = Json37_getFloat(constraintMap, "x", 0) * self->scale;
			data->offsetY = Json37_getFloat(constraintMap, "y", 0) * self->scale;
			data->offsetScaleX = Json37_getFloat(constraintMap, "scaleX", 0);
			data->offsetScaleY = Json37_getFloat(constraintMap, "scaleY", 0);
			data->offsetShearY = Json37_getFloat(constraintMap, "shearY", 0);

			data->rotateMix = Json37_getFloat(constraintMap, "rotateMix", 1);
			data->translateMix = Json37_getFloat(constraintMap, "translateMix", 1);
			data->scaleMix = Json37_getFloat(constraintMap, "scaleMix", 1);
			data->shearMix = Json37_getFloat(constraintMap, "shearMix", 1);

			skeletonData->transformConstraints[i] = data;
		}
	}

	/* Path constraints */
	path = Json37_getItem(root, "path");
	if (path) {
		Json37 *constraintMap;
		skeletonData->pathConstraintsCount = path->size;
		skeletonData->pathConstraints = MALLOC(sp37PathConstraintData*, path->size);
		for (constraintMap = path->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char* name;
			const char* item;

			sp37PathConstraintData* data = sp37PathConstraintData_create(Json37_getString(constraintMap, "name", 0));
			data->order = Json37_getInt(constraintMap, "order", 0);

			boneMap = Json37_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			CONST_CAST(sp37BoneData**, data->bones) = MALLOC(sp37BoneData*, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp37SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp37SkeletonData_dispose(skeletonData);
					_sp37SkeletonJson_setError(self, root, "Path bone not found: ", boneMap->valueString);
					return 0;
				}
			}

			name = Json37_getString(constraintMap, "target", 0);
			data->target = sp37SkeletonData_findSlot(skeletonData, name);
			if (!data->target) {
				sp37SkeletonData_dispose(skeletonData);
				_sp37SkeletonJson_setError(self, root, "Target slot not found: ", name);
				return 0;
			}

			item = Json37_getString(constraintMap, "positionMode", "percent");
			if (strcmp(item, "fixed") == 0) data->positionMode = SP_POSITION_MODE_FIXED;
			else if (strcmp(item, "percent") == 0) data->positionMode = SP_POSITION_MODE_PERCENT;

			item = Json37_getString(constraintMap, "spacingMode", "length");
			if (strcmp(item, "length") == 0) data->spacingMode = SP_SPACING_MODE_LENGTH;
			else if (strcmp(item, "fixed") == 0) data->spacingMode = SP_SPACING_MODE_FIXED;
			else if (strcmp(item, "percent") == 0) data->spacingMode = SP_SPACING_MODE_PERCENT;

			item = Json37_getString(constraintMap, "rotateMode", "tangent");
			if (strcmp(item, "tangent") == 0) data->rotateMode = SP_ROTATE_MODE_TANGENT;
			else if (strcmp(item, "chain") == 0) data->rotateMode = SP_ROTATE_MODE_CHAIN;
			else if (strcmp(item, "chainScale") == 0) data->rotateMode = SP_ROTATE_MODE_CHAIN_SCALE;

			data->offsetRotation = Json37_getFloat(constraintMap, "rotation", 0);
			data->position = Json37_getFloat(constraintMap, "position", 0);
			if (data->positionMode == SP_POSITION_MODE_FIXED) data->position *= self->scale;
			data->spacing = Json37_getFloat(constraintMap, "spacing", 0);
			if (data->spacingMode == SP_SPACING_MODE_LENGTH || data->spacingMode == SP_SPACING_MODE_FIXED) data->spacing *= self->scale;
			data->rotateMix = Json37_getFloat(constraintMap, "rotateMix", 1);
			data->translateMix = Json37_getFloat(constraintMap, "translateMix", 1);

			skeletonData->pathConstraints[i] = data;
		}
	}

	/* Skins. */
	skins = Json37_getItem(root, "skins");
	if (skins) {
		Json37 *skinMap;
		skeletonData->skins = MALLOC(sp37Skin*, skins->size);
		for (skinMap = skins->child, i = 0; skinMap; skinMap = skinMap->next, ++i) {
			Json37 *attachmentsMap;
			Json37 *curves;
			sp37Skin *skin = sp37Skin_create(skinMap->name);

			skeletonData->skins[skeletonData->skinsCount++] = skin;
			if (strcmp(skinMap->name, "default") == 0) skeletonData->defaultSkin = skin;

			for (attachmentsMap = skinMap->child; attachmentsMap; attachmentsMap = attachmentsMap->next) {
				int slotIndex = sp37SkeletonData_findSlotIndex(skeletonData, attachmentsMap->name);
				Json37 *attachmentMap;

				for (attachmentMap = attachmentsMap->child; attachmentMap; attachmentMap = attachmentMap->next) {
					sp37Attachment* attachment;
					const char* skinAttachmentName = attachmentMap->name;
					const char* attachmentName = Json37_getString(attachmentMap, "name", skinAttachmentName);
					const char* path = Json37_getString(attachmentMap, "path", attachmentName);
					const char* color;
					Json37* entry;

					const char* typeString = Json37_getString(attachmentMap, "type", "region");
					sp37AttachmentType type;
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
						sp37SkeletonData_dispose(skeletonData);
						_sp37SkeletonJson_setError(self, root, "Unknown attachment type: ", typeString);
						return 0;
					}

					attachment = sp37AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, attachmentName, path);
					if (!attachment) {
						if (self->attachmentLoader->error1) {
							sp37SkeletonData_dispose(skeletonData);
							_sp37SkeletonJson_setError(self, root, self->attachmentLoader->error1, self->attachmentLoader->error2);
							return 0;
						}
						continue;
					}

					switch (attachment->type) {
					case SP_ATTACHMENT_REGION: {
						sp37RegionAttachment* region = SUB_CAST(sp37RegionAttachment, attachment);
						if (path) MALLOC_STR(region->path, path);
						region->x = Json37_getFloat(attachmentMap, "x", 0) * self->scale;
						region->y = Json37_getFloat(attachmentMap, "y", 0) * self->scale;
						region->scaleX = Json37_getFloat(attachmentMap, "scaleX", 1);
						region->scaleY = Json37_getFloat(attachmentMap, "scaleY", 1);
						region->rotation = Json37_getFloat(attachmentMap, "rotation", 0);
						region->width = Json37_getFloat(attachmentMap, "width", 32) * self->scale;
						region->height = Json37_getFloat(attachmentMap, "height", 32) * self->scale;

						color = Json37_getString(attachmentMap, "color", 0);
						if (color) {
							sp37Color_setFromFloats(&region->color,
												  toColor(color, 0),
												  toColor(color, 1),
												  toColor(color, 2),
												  toColor(color, 3));
						}

						sp37RegionAttachment_updateOffset(region);

						sp37AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						break;
					}
					case SP_ATTACHMENT_MESH:
					case SP_ATTACHMENT_LINKED_MESH: {
						sp37MeshAttachment* mesh = SUB_CAST(sp37MeshAttachment, attachment);

						MALLOC_STR(mesh->path, path);

						color = Json37_getString(attachmentMap, "color", 0);
						if (color) {
							sp37Color_setFromFloats(&mesh->color,
												  toColor(color, 0),
												  toColor(color, 1),
												  toColor(color, 2),
												  toColor(color, 3));
						}

						mesh->width = Json37_getFloat(attachmentMap, "width", 32) * self->scale;
						mesh->height = Json37_getFloat(attachmentMap, "height", 32) * self->scale;

						entry = Json37_getItem(attachmentMap, "parent");
						if (!entry) {
							int verticesLength;
							entry = Json37_getItem(attachmentMap, "triangles");
							mesh->trianglesCount = entry->size;
							mesh->triangles = MALLOC(unsigned short, entry->size);
							for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
								mesh->triangles[ii] = (unsigned short)entry->valueInt;

							entry = Json37_getItem(attachmentMap, "uvs");
							verticesLength = entry->size;
							mesh->regionUVs = MALLOC(float, verticesLength);
							for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
								mesh->regionUVs[ii] = entry->valueFloat;

							_readVertices(self, attachmentMap, SUPER(mesh), verticesLength);

							sp37MeshAttachment_updateUVs(mesh);

							mesh->hullLength = Json37_getInt(attachmentMap, "hull", 0);

							entry = Json37_getItem(attachmentMap, "edges");
							if (entry) {
								mesh->edgesCount = entry->size;
								mesh->edges = MALLOC(int, entry->size);
								for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
									mesh->edges[ii] = entry->valueInt;
							}

							sp37AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						} else {
							mesh->inheritDeform = Json37_getInt(attachmentMap, "deform", 1);
							_sp37SkeletonJson_addLinkedMesh(self, SUB_CAST(sp37MeshAttachment, attachment), Json37_getString(attachmentMap, "skin", 0), slotIndex,
									entry->valueString);
						}
						break;
					}
					case SP_ATTACHMENT_BOUNDING_BOX: {
						sp37BoundingBoxAttachment* box = SUB_CAST(sp37BoundingBoxAttachment, attachment);
						int vertexCount = Json37_getInt(attachmentMap, "vertexCount", 0) << 1;
						_readVertices(self, attachmentMap, SUPER(box), vertexCount);
						box->super.verticesCount = vertexCount;
						sp37AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						break;
					}
					case SP_ATTACHMENT_PATH: {
						sp37PathAttachment* path = SUB_CAST(sp37PathAttachment, attachment);
						int vertexCount = 0;
						path->closed = Json37_getInt(attachmentMap, "closed", 0);
						path->constantSpeed = Json37_getInt(attachmentMap, "constantSpeed", 1);
						vertexCount = Json37_getInt(attachmentMap, "vertexCount", 0);
						_readVertices(self, attachmentMap, SUPER(path), vertexCount << 1);

						path->lengthsLength = vertexCount / 3;
						path->lengths = MALLOC(float, path->lengthsLength);

						curves = Json37_getItem(attachmentMap, "lengths");
						for (curves = curves->child, ii = 0; curves; curves = curves->next, ++ii) {
							path->lengths[ii] = curves->valueFloat * self->scale;
						}
						break;
					}
					case SP_ATTACHMENT_POINT: {
						sp37PointAttachment* point = SUB_CAST(sp37PointAttachment, attachment);
						point->x = Json37_getFloat(attachmentMap, "x", 0) * self->scale;
						point->y = Json37_getFloat(attachmentMap, "y", 0) * self->scale;
						point->rotation = Json37_getFloat(attachmentMap, "rotation", 0);

						color = Json37_getString(attachmentMap, "color", 0);
						if (color) {
							sp37Color_setFromFloats(&point->color,
												  toColor(color, 0),
												  toColor(color, 1),
												  toColor(color, 2),
												  toColor(color, 3));
						}
						break;
					}
					case SP_ATTACHMENT_CLIPPING: {
						sp37ClippingAttachment* clip = SUB_CAST(sp37ClippingAttachment, attachment);
						int vertexCount = 0;
						const char* end = Json37_getString(attachmentMap, "end", 0);
						if (end) {
							sp37SlotData* slot = sp37SkeletonData_findSlot(skeletonData, end);
							clip->endSlot = slot;
						}
						vertexCount = Json37_getInt(attachmentMap, "vertexCount", 0) << 1;
						_readVertices(self, attachmentMap, SUPER(clip), vertexCount);
						sp37AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						break;
					}
					}

					sp37Skin_addAttachment(skin, slotIndex, skinAttachmentName, attachment);
				}
			}
		}
	}

	/* Linked meshes. */
	for (i = 0; i < internal->linkedMeshCount; i++) {
		sp37Attachment* parent;
		_sp37LinkedMesh* linkedMesh = internal->linkedMeshes + i;
		sp37Skin* skin = !linkedMesh->skin ? skeletonData->defaultSkin : sp37SkeletonData_findSkin(skeletonData, linkedMesh->skin);
		if (!skin) {
			sp37SkeletonData_dispose(skeletonData);
			_sp37SkeletonJson_setError(self, 0, "Skin not found: ", linkedMesh->skin);
			return 0;
		}
		parent = sp37Skin_getAttachment(skin, linkedMesh->slotIndex, linkedMesh->parent);
		if (!parent) {
			sp37SkeletonData_dispose(skeletonData);
			_sp37SkeletonJson_setError(self, 0, "Parent mesh not found: ", linkedMesh->parent);
			return 0;
		}
		sp37MeshAttachment_setParentMesh(linkedMesh->mesh, SUB_CAST(sp37MeshAttachment, parent));
		sp37MeshAttachment_updateUVs(linkedMesh->mesh);
		sp37AttachmentLoader_configureAttachment(self->attachmentLoader, SUPER(SUPER(linkedMesh->mesh)));
	}

	/* Events. */
	events = Json37_getItem(root, "events");
	if (events) {
		Json37 *eventMap;
		const char* stringValue;
		const char* audioPath;
		skeletonData->eventsCount = events->size;
		skeletonData->events = MALLOC(sp37EventData*, events->size);
		for (eventMap = events->child, i = 0; eventMap; eventMap = eventMap->next, ++i) {
			sp37EventData* eventData = sp37EventData_create(eventMap->name);
			eventData->intValue = Json37_getInt(eventMap, "int", 0);
			eventData->floatValue = Json37_getFloat(eventMap, "float", 0);
			stringValue = Json37_getString(eventMap, "string", 0);
			if (stringValue) MALLOC_STR(eventData->stringValue, stringValue);
			audioPath = Json37_getString(eventMap, "audio", 0);
			if (audioPath) {
				MALLOC_STR(eventData->audioPath, audioPath);
				eventData->volume = Json37_getFloat(eventMap, "volume", 1);
				eventData->balance = Json37_getFloat(eventMap, "balance", 0);
			}
			skeletonData->events[i] = eventData;
		}
	}

	/* Animations. */
	animations = Json37_getItem(root, "animations");
	if (animations) {
		Json37 *animationMap;
		skeletonData->animations = MALLOC(sp37Animation*, animations->size);
		for (animationMap = animations->child; animationMap; animationMap = animationMap->next) {
			sp37Animation* animation = _sp37SkeletonJson_readAnimation(self, animationMap, skeletonData);
			if (!animation) {
				sp37SkeletonData_dispose(skeletonData);
				return 0;
			}
			skeletonData->animations[skeletonData->animationsCount++] = animation;
		}
	}

	Json37_dispose(root);
	return skeletonData;
}

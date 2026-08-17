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
#include <locale.h>
#include "Json.h"
#include <spine/extension.h>
#include <spine/AtlasAttachmentLoader.h>
#include <spine/Animation.h>

#if defined(WIN32) || defined(_WIN32) || defined(__WIN32) && !defined(__CYGWIN__)
#define strdup _strdup
#endif

typedef struct {
	const char* parent;
	const char* skin;
	int slotIndex;
	sp35MeshAttachment* mesh;
} _sp35LinkedMesh;

typedef struct {
	sp35SkeletonJson super;
	int ownsLoader;

	int linkedMeshCount;
	int linkedMeshCapacity;
	_sp35LinkedMesh* linkedMeshes;
} _sp35SkeletonJson;

sp35SkeletonJson* sp35SkeletonJson_createWithLoader (sp35AttachmentLoader* attachmentLoader) {
	sp35SkeletonJson* self = SUPER(NEW(_sp35SkeletonJson));
	self->scale = 1;
	self->attachmentLoader = attachmentLoader;
	return self;
}

sp35SkeletonJson* sp35SkeletonJson_create (sp35Atlas* atlas) {
	sp35AtlasAttachmentLoader* attachmentLoader = sp35AtlasAttachmentLoader_create(atlas);
	sp35SkeletonJson* self = sp35SkeletonJson_createWithLoader(SUPER(attachmentLoader));
	SUB_CAST(_sp35SkeletonJson, self)->ownsLoader = 1;
	return self;
}

void sp35SkeletonJson_dispose (sp35SkeletonJson* self) {
	_sp35SkeletonJson* internal = SUB_CAST(_sp35SkeletonJson, self);
	if (internal->ownsLoader) sp35AttachmentLoader_dispose(self->attachmentLoader);
	FREE(internal->linkedMeshes);
	FREE(self->error);
	FREE(self);
}

void _sp35SkeletonJson_setError (sp35SkeletonJson* self, Json35* root, const char* value1, const char* value2) {
	char message[256];
	int length;
	FREE(self->error);
	strcpy(message, value1);
	length = (int)strlen(value1);
	if (value2) strncat(message + length, value2, 255 - length);
	MALLOC_STR(self->error, message);
	if (root) Json35_dispose(root);
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

static void readCurve (Json35* frame, sp35CurveTimeline* timeline, int frameIndex) {
	Json35* curve = Json35_getItem(frame, "curve");
	if (!curve) return;
	if (curve->type == Json35_String && strcmp(curve->valueString, "stepped") == 0)
		sp35CurveTimeline_setStepped(timeline, frameIndex);
	else if (curve->type == Json35_Array) {
		Json35* child0 = curve->child;
		Json35* child1 = child0->next;
		Json35* child2 = child1->next;
		Json35* child3 = child2->next;
		sp35CurveTimeline_setCurve(timeline, frameIndex, child0->valueFloat, child1->valueFloat, child2->valueFloat,
				child3->valueFloat);
	}
}

static void _sp35SkeletonJson_addLinkedMesh (sp35SkeletonJson* self, sp35MeshAttachment* mesh, const char* skin, int slotIndex,
		const char* parent) {
	_sp35LinkedMesh* linkedMesh;
	_sp35SkeletonJson* internal = SUB_CAST(_sp35SkeletonJson, self);

	if (internal->linkedMeshCount == internal->linkedMeshCapacity) {
		_sp35LinkedMesh* linkedMeshes;
		internal->linkedMeshCapacity *= 2;
		if (internal->linkedMeshCapacity < 8) internal->linkedMeshCapacity = 8;
		linkedMeshes = MALLOC(_sp35LinkedMesh, internal->linkedMeshCapacity);
		memcpy(linkedMeshes, internal->linkedMeshes, sizeof(_sp35LinkedMesh) * internal->linkedMeshCount);
		FREE(internal->linkedMeshes);
		internal->linkedMeshes = linkedMeshes;
	}

	linkedMesh = internal->linkedMeshes + internal->linkedMeshCount++;
	linkedMesh->mesh = mesh;
	linkedMesh->skin = skin;
	linkedMesh->slotIndex = slotIndex;
	linkedMesh->parent = parent;
}

static sp35Animation* _sp35SkeletonJson_readAnimation (sp35SkeletonJson* self, Json35* root, sp35SkeletonData *skeletonData) {
	int frameIndex;
	sp35Animation* animation;
	Json35* valueMap;
	int timelinesCount = 0;

	Json35* bones = Json35_getItem(root, "bones");
	Json35* slots = Json35_getItem(root, "slots");
	Json35* ik = Json35_getItem(root, "ik");
	Json35* transform = Json35_getItem(root, "transform");
	Json35* paths = Json35_getItem(root, "paths");
	Json35* deform = Json35_getItem(root, "deform");
	Json35* drawOrder = Json35_getItem(root, "drawOrder");
	Json35* events = Json35_getItem(root, "events");
	Json35 *boneMap, *slotMap, *constraintMap;
	if (!drawOrder) drawOrder = Json35_getItem(root, "draworder");

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

	animation = sp35Animation_create(root->name, timelinesCount);
	animation->timelinesCount = 0;

	/* Slot timelines. */
	for (slotMap = slots ? slots->child : 0; slotMap; slotMap = slotMap->next) {
		Json35 *timelineMap;

		int slotIndex = sp35SkeletonData_findSlotIndex(skeletonData, slotMap->name);
		if (slotIndex == -1) {
			sp35Animation_dispose(animation);
			_sp35SkeletonJson_setError(self, root, "Slot not found: ", slotMap->name);
			return 0;
		}

		for (timelineMap = slotMap->child; timelineMap; timelineMap = timelineMap->next) {
			if (strcmp(timelineMap->name, "color") == 0) {
				sp35ColorTimeline *timeline = sp35ColorTimeline_create(timelineMap->size);
				timeline->slotIndex = slotIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					const char* s = Json35_getString(valueMap, "color", 0);
					sp35ColorTimeline_setFrame(timeline, frameIndex, Json35_getFloat(valueMap, "time", 0), toColor(s, 0), toColor(s, 1), toColor(s, 2),
							toColor(s, 3));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp35Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * COLOR_ENTRIES]);

			} else if (strcmp(timelineMap->name, "attachment") == 0) {
				sp35AttachmentTimeline *timeline = sp35AttachmentTimeline_create(timelineMap->size);
				timeline->slotIndex = slotIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					Json35* name = Json35_getItem(valueMap, "name");
					sp35AttachmentTimeline_setFrame(timeline, frameIndex, Json35_getFloat(valueMap, "time", 0),
							name->type == Json35_NULL ? 0 : name->valueString);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp35Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[timelineMap->size - 1]);

			} else {
				sp35Animation_dispose(animation);
				_sp35SkeletonJson_setError(self, 0, "Invalid timeline type for a slot: ", timelineMap->name);
				return 0;
			}
		}
	}

	/* Bone timelines. */
	for (boneMap = bones ? bones->child : 0; boneMap; boneMap = boneMap->next) {
		Json35 *timelineMap;

		int boneIndex = sp35SkeletonData_findBoneIndex(skeletonData, boneMap->name);
		if (boneIndex == -1) {
			sp35Animation_dispose(animation);
			_sp35SkeletonJson_setError(self, root, "Bone not found: ", boneMap->name);
			return 0;
		}

		for (timelineMap = boneMap->child; timelineMap; timelineMap = timelineMap->next) {
			if (strcmp(timelineMap->name, "rotate") == 0) {
				sp35RotateTimeline *timeline = sp35RotateTimeline_create(timelineMap->size);
				timeline->boneIndex = boneIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					sp35RotateTimeline_setFrame(timeline, frameIndex, Json35_getFloat(valueMap, "time", 0), Json35_getFloat(valueMap, "angle", 0));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp35Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * ROTATE_ENTRIES]);

			} else {
				int isScale = strcmp(timelineMap->name, "scale") == 0;
				int isTranslate = strcmp(timelineMap->name, "translate") == 0;
				int isShear = strcmp(timelineMap->name, "shear") == 0;
				if (isScale || isTranslate || isShear) {
					float timelineScale = isTranslate ? self->scale: 1;
					sp35TranslateTimeline *timeline = 0;
					if (isScale) timeline = sp35ScaleTimeline_create(timelineMap->size);
					else if (isTranslate) timeline = sp35TranslateTimeline_create(timelineMap->size);
					else if (isShear) timeline = sp35ShearTimeline_create(timelineMap->size);
					timeline->boneIndex = boneIndex;

					for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
						sp35TranslateTimeline_setFrame(timeline, frameIndex, Json35_getFloat(valueMap, "time", 0), Json35_getFloat(valueMap, "x", 0) * timelineScale,
								Json35_getFloat(valueMap, "y", 0) * timelineScale);
						readCurve(valueMap, SUPER(timeline), frameIndex);
					}
					animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp35Timeline, timeline);
					animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * TRANSLATE_ENTRIES]);

				} else {
					sp35Animation_dispose(animation);
					_sp35SkeletonJson_setError(self, 0, "Invalid timeline type for a bone: ", timelineMap->name);
					return 0;
				}
			}
		}
	}

	/* IK constraint timelines. */
	for (constraintMap = ik ? ik->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp35IkConstraintData* constraint = sp35SkeletonData_findIkConstraint(skeletonData, constraintMap->name);
		sp35IkConstraintTimeline* timeline = sp35IkConstraintTimeline_create(constraintMap->size);
		for (frameIndex = 0; frameIndex < skeletonData->ikConstraintsCount; ++frameIndex) {
			if (constraint == skeletonData->ikConstraints[frameIndex]) {
				timeline->ikConstraintIndex = frameIndex;
				break;
			}
		}
		for (valueMap = constraintMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			sp35IkConstraintTimeline_setFrame(timeline, frameIndex, Json35_getFloat(valueMap, "time", 0), Json35_getFloat(valueMap, "mix", 1),
					Json35_getInt(valueMap, "bendPositive", 1) ? 1 : -1);
			readCurve(valueMap, SUPER(timeline), frameIndex);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp35Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[(constraintMap->size - 1) * IKCONSTRAINT_ENTRIES]);
	}

	/* Transform constraint timelines. */
	for (constraintMap = transform ? transform->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp35TransformConstraintData* constraint = sp35SkeletonData_findTransformConstraint(skeletonData, constraintMap->name);
		sp35TransformConstraintTimeline* timeline = sp35TransformConstraintTimeline_create(constraintMap->size);
		for (frameIndex = 0; frameIndex < skeletonData->transformConstraintsCount; ++frameIndex) {
			if (constraint == skeletonData->transformConstraints[frameIndex]) {
				timeline->transformConstraintIndex = frameIndex;
				break;
			}
		}
		for (valueMap = constraintMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			sp35TransformConstraintTimeline_setFrame(timeline, frameIndex, Json35_getFloat(valueMap, "time", 0), Json35_getFloat(valueMap, "rotateMix", 1),
					Json35_getFloat(valueMap, "translateMix", 1), Json35_getFloat(valueMap, "scaleMix", 1), Json35_getFloat(valueMap, "shearMix", 1));
			readCurve(valueMap, SUPER(timeline), frameIndex);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp35Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[(constraintMap->size - 1) * TRANSFORMCONSTRAINT_ENTRIES]);
	}

	/** Path constraint timelines. */
	for(constraintMap = paths ? paths->child : 0; constraintMap; constraintMap = constraintMap->next ) {
		int constraintIndex, i;
		Json35* timelineMap;

		sp35PathConstraintData* data = sp35SkeletonData_findPathConstraint(skeletonData, constraintMap->name);
		if (!data) {
			sp35Animation_dispose(animation);
			_sp35SkeletonJson_setError(self, root, "Path constraint not found: ", constraintMap->name);
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
				sp35PathConstraintPositionTimeline* timeline;
				float timelineScale = 1;
				if (strcmp(timelineName, "spacing") == 0) {
					timeline = (sp35PathConstraintPositionTimeline*)sp35PathConstraintSpacingTimeline_create(timelineMap->size);
					if (data->spacingMode == SP_SPACING_MODE_LENGTH || data->spacingMode == SP_SPACING_MODE_FIXED) timelineScale = self->scale;
				} else {
					timeline = sp35PathConstraintPositionTimeline_create(timelineMap->size);
					if (data->positionMode == SP_POSITION_MODE_FIXED) timelineScale = self->scale;
				}
				timeline->pathConstraintIndex = constraintIndex;
				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					sp35PathConstraintPositionTimeline_setFrame(timeline, frameIndex, Json35_getFloat(valueMap, "time", 0), Json35_getFloat(valueMap, timelineName, 0) * timelineScale);
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp35Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * PATHCONSTRAINTPOSITION_ENTRIES]);
			} else if (strcmp(timelineName, "mix")) {
				sp35PathConstraintMixTimeline* timeline = sp35PathConstraintMixTimeline_create(timelineMap->size);
				timeline->pathConstraintIndex = constraintIndex;
				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					sp35PathConstraintMixTimeline_setFrame(timeline, frameIndex, Json35_getFloat(valueMap, "time", 0),
						Json35_getFloat(valueMap, "rotateMix", 1), Json35_getFloat(valueMap, "translateMix", 1));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp35Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * PATHCONSTRAINTMIX_ENTRIES]);
			}
		}
	}

	/* Deform timelines. */
	for (constraintMap = deform ? deform->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp35Skin* skin = sp35SkeletonData_findSkin(skeletonData, constraintMap->name);
		for (slotMap = constraintMap->child; slotMap; slotMap = slotMap->next) {
			int slotIndex = sp35SkeletonData_findSlotIndex(skeletonData, slotMap->name);
			Json35* timelineMap;
			for (timelineMap = slotMap->child; timelineMap; timelineMap = timelineMap->next) {
				float* tempDeform;
				sp35DeformTimeline *timeline;
				int weighted, deformLength;

				sp35VertexAttachment* attachment = SUB_CAST(sp35VertexAttachment, sp35Skin_getAttachment(skin, slotIndex, timelineMap->name));
				if (!attachment) {
					sp35Animation_dispose(animation);
					_sp35SkeletonJson_setError(self, 0, "Attachment not found: ", timelineMap->name);
					return 0;
				}
				weighted = attachment->bones != 0;
				deformLength = weighted ? attachment->verticesCount / 3 * 2 : attachment->verticesCount;
				tempDeform = MALLOC(float, deformLength);

				timeline = sp35DeformTimeline_create(timelineMap->size, deformLength);
				timeline->slotIndex = slotIndex;
				timeline->attachment = SUPER(attachment);

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					Json35* vertices = Json35_getItem(valueMap, "vertices");
					float* deform;
					if (!vertices) {
						if (weighted) {
							deform = tempDeform;
							memset(deform, 0, sizeof(float) * deformLength);
						} else
							deform = attachment->vertices;
					} else {
						int v, start = Json35_getInt(valueMap, "offset", 0);
						Json35* vertex;
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
					sp35DeformTimeline_setFrame(timeline, frameIndex, Json35_getFloat(valueMap, "time", 0), deform);
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				FREE(tempDeform);

				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp35Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[timelineMap->size - 1]);
			}
		}
	}

	/* Draw order timeline. */
	if (drawOrder) {
		sp35DrawOrderTimeline* timeline = sp35DrawOrderTimeline_create(drawOrder->size, skeletonData->slotsCount);
		for (valueMap = drawOrder->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			int ii;
			int* drawOrder = 0;
			Json35* offsets = Json35_getItem(valueMap, "offsets");
			if (offsets) {
				Json35* offsetMap;
				int* unchanged = MALLOC(int, skeletonData->slotsCount - offsets->size);
				int originalIndex = 0, unchangedIndex = 0;

				drawOrder = MALLOC(int, skeletonData->slotsCount);
				for (ii = skeletonData->slotsCount - 1; ii >= 0; --ii)
					drawOrder[ii] = -1;

				for (offsetMap = offsets->child; offsetMap; offsetMap = offsetMap->next) {
					int slotIndex = sp35SkeletonData_findSlotIndex(skeletonData, Json35_getString(offsetMap, "slot", 0));
					if (slotIndex == -1) {
						sp35Animation_dispose(animation);
						_sp35SkeletonJson_setError(self, 0, "Slot not found: ", Json35_getString(offsetMap, "slot", 0));
						return 0;
					}
					/* Collect unchanged items. */
					while (originalIndex != slotIndex)
						unchanged[unchangedIndex++] = originalIndex++;
					/* Set changed items. */
					drawOrder[originalIndex + Json35_getInt(offsetMap, "offset", 0)] = originalIndex;
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
			sp35DrawOrderTimeline_setFrame(timeline, frameIndex, Json35_getFloat(valueMap, "time", 0), drawOrder);
			FREE(drawOrder);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp35Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[drawOrder->size - 1]);
	}

	/* Event timeline. */
	if (events) {
		sp35EventTimeline* timeline = sp35EventTimeline_create(events->size);
		for (valueMap = events->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			sp35Event* event;
			const char* stringValue;
			sp35EventData* eventData = sp35SkeletonData_findEvent(skeletonData, Json35_getString(valueMap, "name", 0));
			if (!eventData) {
				sp35Animation_dispose(animation);
				_sp35SkeletonJson_setError(self, 0, "Event not found: ", Json35_getString(valueMap, "name", 0));
				return 0;
			}
			event = sp35Event_create(Json35_getFloat(valueMap, "time", 0), eventData);
			event->intValue = Json35_getInt(valueMap, "int", eventData->intValue);
			event->floatValue = Json35_getFloat(valueMap, "float", eventData->floatValue);
			stringValue = Json35_getString(valueMap, "string", eventData->stringValue);
			if (stringValue) MALLOC_STR(event->stringValue, stringValue);
			sp35EventTimeline_setFrame(timeline, frameIndex, event);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp35Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[events->size - 1]);
	}

	return animation;
}

static void _readVertices (sp35SkeletonJson* self, Json35* attachmentMap, sp35VertexAttachment* attachment, int verticesLength) {
	Json35* entry;
	float* vertices;
	int i, b, w, nn, entrySize;

	attachment->worldVerticesLength = verticesLength;

	entry = Json35_getItem(attachmentMap, "vertices");
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
	} else {
		attachment->verticesCount = 0;
		attachment->bonesCount = 0;

		for (i = 0; i < entrySize;) {
			int bonesCount = (int)vertices[i];
			attachment->bonesCount += 1 + bonesCount;
			attachment->verticesCount += 3 * bonesCount;
			i += 1 + bonesCount * 4;
		}

		attachment->vertices = MALLOC(float, attachment->verticesCount);
		attachment->bones = MALLOC(int, attachment->bonesCount);

		for (i = 0, b = 0, w = 0; i < entrySize;) {
			int bonesCount = (int)vertices[i++];
			attachment->bones[b++] = bonesCount;
			for (nn = i + bonesCount * 4; i < nn;) {
				attachment->bones[b++] = (int)vertices[i++];
				attachment->vertices[w++] = vertices[i++] * self->scale;
				attachment->vertices[w++] = vertices[i++] * self->scale;
				attachment->vertices[w++] = vertices[i++];
			}
		}

		FREE(vertices);
	}
}

sp35SkeletonData* sp35SkeletonJson_readSkeletonDataFile (sp35SkeletonJson* self, const char* path) {
	int length;
	sp35SkeletonData* skeletonData;
	const char* json = _sp35Util_readFile(path, &length);
	if (length == 0 || !json) {
		_sp35SkeletonJson_setError(self, 0, "Unable to read skeleton file: ", path);
		return 0;
	}
	skeletonData = sp35SkeletonJson_readSkeletonData(self, json);
	FREE(json);
	return skeletonData;
}

sp35SkeletonData* sp35SkeletonJson_readSkeletonData (sp35SkeletonJson* self, const char* json) {
	int i, ii;
	sp35SkeletonData* skeletonData;
	Json35 *root, *skeleton, *bones, *boneMap, *ik, *transform, *path, *slots, *skins, *animations, *events;
	char* oldLocale;
	_sp35SkeletonJson* internal = SUB_CAST(_sp35SkeletonJson, self);

	FREE(self->error);
	CONST_CAST(char*, self->error) = 0;
	internal->linkedMeshCount = 0;

#ifndef __ANDROID__
	oldLocale = strdup(setlocale(LC_NUMERIC, NULL));
	setlocale(LC_NUMERIC, "C");
#endif

	root = Json35_create(json);

#ifndef __ANDROID__
	setlocale(LC_NUMERIC, oldLocale);
	free(oldLocale);
#endif

	if (!root) {
		_sp35SkeletonJson_setError(self, 0, "Invalid skeleton JSON: ", Json35_getError());
		return 0;
	}

	skeletonData = sp35SkeletonData_create();

	skeleton = Json35_getItem(root, "skeleton");
	if (skeleton) {
		MALLOC_STR(skeletonData->hash, Json35_getString(skeleton, "hash", 0));
		MALLOC_STR(skeletonData->version, Json35_getString(skeleton, "spine", 0));
		skeletonData->width = Json35_getFloat(skeleton, "width", 0);
		skeletonData->height = Json35_getFloat(skeleton, "height", 0);
	}

	/* Bones. */
	bones = Json35_getItem(root, "bones");
	skeletonData->bones = MALLOC(sp35BoneData*, bones->size);
	for (boneMap = bones->child, i = 0; boneMap; boneMap = boneMap->next, ++i) {
		sp35BoneData* data;
		const char* transformMode;

		sp35BoneData* parent = 0;
		const char* parentName = Json35_getString(boneMap, "parent", 0);
		if (parentName) {
			parent = sp35SkeletonData_findBone(skeletonData, parentName);
			if (!parent) {
				sp35SkeletonData_dispose(skeletonData);
				_sp35SkeletonJson_setError(self, root, "Parent bone not found: ", parentName);
				return 0;
			}
		}

		data = sp35BoneData_create(skeletonData->bonesCount, Json35_getString(boneMap, "name", 0), parent);
		data->length = Json35_getFloat(boneMap, "length", 0) * self->scale;
		data->x = Json35_getFloat(boneMap, "x", 0) * self->scale;
		data->y = Json35_getFloat(boneMap, "y", 0) * self->scale;
		data->rotation = Json35_getFloat(boneMap, "rotation", 0);
		data->scaleX = Json35_getFloat(boneMap, "scaleX", 1);
		data->scaleY = Json35_getFloat(boneMap, "scaleY", 1);
		data->shearX = Json35_getFloat(boneMap, "shearX", 0);
		data->shearY = Json35_getFloat(boneMap, "shearY", 0);
		transformMode = Json35_getString(boneMap, "transform", "normal");
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
	slots = Json35_getItem(root, "slots");
	if (slots) {
		Json35 *slotMap;
		skeletonData->slotsCount = slots->size;
		skeletonData->slots = MALLOC(sp35SlotData*, slots->size);
		for (slotMap = slots->child, i = 0; slotMap; slotMap = slotMap->next, ++i) {
			sp35SlotData* data;
			const char* color;
			Json35 *item;

			const char* boneName = Json35_getString(slotMap, "bone", 0);
			sp35BoneData* boneData = sp35SkeletonData_findBone(skeletonData, boneName);
			if (!boneData) {
				sp35SkeletonData_dispose(skeletonData);
				_sp35SkeletonJson_setError(self, root, "Slot bone not found: ", boneName);
				return 0;
			}

			data = sp35SlotData_create(i, Json35_getString(slotMap, "name", 0), boneData);

			color = Json35_getString(slotMap, "color", 0);
			if (color) {
				data->r = toColor(color, 0);
				data->g = toColor(color, 1);
				data->b = toColor(color, 2);
				data->a = toColor(color, 3);
			}

			item = Json35_getItem(slotMap, "attachment");
			if (item) sp35SlotData_setAttachmentName(data, item->valueString);

			item = Json35_getItem(slotMap, "blend");
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
	ik = Json35_getItem(root, "ik");
	if (ik) {
		Json35 *constraintMap;
		skeletonData->ikConstraintsCount = ik->size;
		skeletonData->ikConstraints = MALLOC(sp35IkConstraintData*, ik->size);
		for (constraintMap = ik->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char* targetName;

			sp35IkConstraintData* data = sp35IkConstraintData_create(Json35_getString(constraintMap, "name", 0));
			data->order = Json35_getInt(constraintMap, "order", 0);

			boneMap = Json35_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			data->bones = MALLOC(sp35BoneData*, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp35SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp35SkeletonData_dispose(skeletonData);
					_sp35SkeletonJson_setError(self, root, "IK bone not found: ", boneMap->valueString);
					return 0;
				}
			}

			targetName = Json35_getString(constraintMap, "target", 0);
			data->target = sp35SkeletonData_findBone(skeletonData, targetName);
			if (!data->target) {
				sp35SkeletonData_dispose(skeletonData);
				_sp35SkeletonJson_setError(self, root, "Target bone not found: ", boneMap->name);
				return 0;
			}

			data->bendDirection = Json35_getInt(constraintMap, "bendPositive", 1) ? 1 : -1;
			data->mix = Json35_getFloat(constraintMap, "mix", 1);

			skeletonData->ikConstraints[i] = data;
		}
	}

	/* Transform constraints. */
	transform = Json35_getItem(root, "transform");
	if (transform) {
		Json35 *constraintMap;
		skeletonData->transformConstraintsCount = transform->size;
		skeletonData->transformConstraints = MALLOC(sp35TransformConstraintData*, transform->size);
		for (constraintMap = transform->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char* name;

			sp35TransformConstraintData* data = sp35TransformConstraintData_create(Json35_getString(constraintMap, "name", 0));
			data->order = Json35_getInt(constraintMap, "order", 0);

			boneMap = Json35_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			CONST_CAST(sp35BoneData**, data->bones) = MALLOC(sp35BoneData*, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp35SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp35SkeletonData_dispose(skeletonData);
					_sp35SkeletonJson_setError(self, root, "Transform bone not found: ", boneMap->valueString);
					return 0;
				}
			}

			name = Json35_getString(constraintMap, "target", 0);
			data->target = sp35SkeletonData_findBone(skeletonData, name);
			if (!data->target) {
				sp35SkeletonData_dispose(skeletonData);
				_sp35SkeletonJson_setError(self, root, "Target bone not found: ", boneMap->name);
				return 0;
			}

			data->offsetRotation = Json35_getFloat(constraintMap, "rotation", 0);
			data->offsetX = Json35_getFloat(constraintMap, "x", 0) * self->scale;
			data->offsetY = Json35_getFloat(constraintMap, "y", 0) * self->scale;
			data->offsetScaleX = Json35_getFloat(constraintMap, "scaleX", 0);
			data->offsetScaleY = Json35_getFloat(constraintMap, "scaleY", 0);
			data->offsetShearY = Json35_getFloat(constraintMap, "shearY", 0);

			data->rotateMix = Json35_getFloat(constraintMap, "rotateMix", 1);
			data->translateMix = Json35_getFloat(constraintMap, "translateMix", 1);
			data->scaleMix = Json35_getFloat(constraintMap, "scaleMix", 1);
			data->shearMix = Json35_getFloat(constraintMap, "shearMix", 1);

			skeletonData->transformConstraints[i] = data;
		}
	}

	/* Path constraints */
	path = Json35_getItem(root, "path");
	if (path) {
		Json35 *constraintMap;
		skeletonData->pathConstraintsCount = path->size;
		skeletonData->pathConstraints = MALLOC(sp35PathConstraintData*, path->size);
		for (constraintMap = path->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char* name;
			const char* item;

			sp35PathConstraintData* data = sp35PathConstraintData_create(Json35_getString(constraintMap, "name", 0));
			data->order = Json35_getInt(constraintMap, "order", 0);

			boneMap = Json35_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			CONST_CAST(sp35BoneData**, data->bones) = MALLOC(sp35BoneData*, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp35SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp35SkeletonData_dispose(skeletonData);
					_sp35SkeletonJson_setError(self, root, "Path bone not found: ", boneMap->valueString);
					return 0;
				}
			}

			name = Json35_getString(constraintMap, "target", 0);
			data->target = sp35SkeletonData_findSlot(skeletonData, name);
			if (!data->target) {
				sp35SkeletonData_dispose(skeletonData);
				_sp35SkeletonJson_setError(self, root, "Target slot not found: ", boneMap->name);
				return 0;
			}

			item = Json35_getString(constraintMap, "positionMode", "percent");
			if (strcmp(item, "fixed") == 0) data->positionMode = SP_POSITION_MODE_FIXED;
			else if (strcmp(item, "percent") == 0) data->positionMode = SP_POSITION_MODE_PERCENT;

			item = Json35_getString(constraintMap, "spacingMode", "length");
			if (strcmp(item, "length") == 0) data->spacingMode = SP_SPACING_MODE_LENGTH;
			else if (strcmp(item, "fixed") == 0) data->spacingMode = SP_SPACING_MODE_FIXED;
			else if (strcmp(item, "percent") == 0) data->spacingMode = SP_SPACING_MODE_PERCENT;

			item = Json35_getString(constraintMap, "rotateMode", "tangent");
			if (strcmp(item, "tangent") == 0) data->rotateMode = SP_ROTATE_MODE_TANGENT;
			else if (strcmp(item, "chain") == 0) data->rotateMode = SP_ROTATE_MODE_CHAIN;
			else if (strcmp(item, "chainScale") == 0) data->rotateMode = SP_ROTATE_MODE_CHAIN_SCALE;

			data->offsetRotation = Json35_getFloat(constraintMap, "rotation", 0);
			data->position = Json35_getFloat(constraintMap, "position", 0);
			if (data->positionMode == SP_POSITION_MODE_FIXED) data->position *= self->scale;
			data->spacing = Json35_getFloat(constraintMap, "spacing", 0);
			if (data->spacingMode == SP_SPACING_MODE_LENGTH || data->spacingMode == SP_SPACING_MODE_FIXED) data->spacing *= self->scale;
			data->rotateMix = Json35_getFloat(constraintMap, "rotateMix", 1);
			data->translateMix = Json35_getFloat(constraintMap, "translateMix", 1);

			skeletonData->pathConstraints[i] = data;
		}
	}

	/* Skins. */
	skins = Json35_getItem(root, "skins");
	if (skins) {
		Json35 *skinMap;
		skeletonData->skins = MALLOC(sp35Skin*, skins->size);
		for (skinMap = skins->child, i = 0; skinMap; skinMap = skinMap->next, ++i) {
			Json35 *attachmentsMap;
			Json35 *curves;
			sp35Skin *skin = sp35Skin_create(skinMap->name);

			skeletonData->skins[skeletonData->skinsCount++] = skin;
			if (strcmp(skinMap->name, "default") == 0) skeletonData->defaultSkin = skin;

			for (attachmentsMap = skinMap->child; attachmentsMap; attachmentsMap = attachmentsMap->next) {
				int slotIndex = sp35SkeletonData_findSlotIndex(skeletonData, attachmentsMap->name);
				Json35 *attachmentMap;

				for (attachmentMap = attachmentsMap->child; attachmentMap; attachmentMap = attachmentMap->next) {
					sp35Attachment* attachment;
					const char* skinAttachmentName = attachmentMap->name;
					const char* attachmentName = Json35_getString(attachmentMap, "name", skinAttachmentName);
					const char* path = Json35_getString(attachmentMap, "path", attachmentName);
					const char* color;
					Json35* entry;

					const char* typeString = Json35_getString(attachmentMap, "type", "region");
					sp35AttachmentType type;
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
					else {
						sp35SkeletonData_dispose(skeletonData);
						_sp35SkeletonJson_setError(self, root, "Unknown attachment type: ", typeString);
						return 0;
					}

					attachment = sp35AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, attachmentName, path);
					if (!attachment) {
						if (self->attachmentLoader->error1) {
							sp35SkeletonData_dispose(skeletonData);
							_sp35SkeletonJson_setError(self, root, self->attachmentLoader->error1, self->attachmentLoader->error2);
							return 0;
						}
						continue;
					}

					switch (attachment->type) {
					case SP_ATTACHMENT_REGION: {
						sp35RegionAttachment* region = SUB_CAST(sp35RegionAttachment, attachment);
						if (path) MALLOC_STR(region->path, path);
						region->x = Json35_getFloat(attachmentMap, "x", 0) * self->scale;
						region->y = Json35_getFloat(attachmentMap, "y", 0) * self->scale;
						region->scaleX = Json35_getFloat(attachmentMap, "scaleX", 1);
						region->scaleY = Json35_getFloat(attachmentMap, "scaleY", 1);
						region->rotation = Json35_getFloat(attachmentMap, "rotation", 0);
						region->width = Json35_getFloat(attachmentMap, "width", 32) * self->scale;
						region->height = Json35_getFloat(attachmentMap, "height", 32) * self->scale;

						color = Json35_getString(attachmentMap, "color", 0);
						if (color) {
							region->r = toColor(color, 0);
							region->g = toColor(color, 1);
							region->b = toColor(color, 2);
							region->a = toColor(color, 3);
						}

						sp35RegionAttachment_updateOffset(region);

						sp35AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						break;
					}
					case SP_ATTACHMENT_MESH:
					case SP_ATTACHMENT_LINKED_MESH: {
						sp35MeshAttachment* mesh = SUB_CAST(sp35MeshAttachment, attachment);

						MALLOC_STR(mesh->path, path);

						color = Json35_getString(attachmentMap, "color", 0);
						if (color) {
							mesh->r = toColor(color, 0);
							mesh->g = toColor(color, 1);
							mesh->b = toColor(color, 2);
							mesh->a = toColor(color, 3);
						}

						mesh->width = Json35_getFloat(attachmentMap, "width", 32) * self->scale;
						mesh->height = Json35_getFloat(attachmentMap, "height", 32) * self->scale;

						entry = Json35_getItem(attachmentMap, "parent");
						if (!entry) {
							int verticesLength;
							entry = Json35_getItem(attachmentMap, "triangles");
							mesh->trianglesCount = entry->size;
							mesh->triangles = MALLOC(unsigned short, entry->size);
							for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
								mesh->triangles[ii] = (unsigned short)entry->valueInt;

							entry = Json35_getItem(attachmentMap, "uvs");
							verticesLength = entry->size;
							mesh->regionUVs = MALLOC(float, verticesLength);
							for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
								mesh->regionUVs[ii] = entry->valueFloat;

							_readVertices(self, attachmentMap, SUPER(mesh), verticesLength);

							sp35MeshAttachment_updateUVs(mesh);

							mesh->hullLength = Json35_getInt(attachmentMap, "hull", 0);

							entry = Json35_getItem(attachmentMap, "edges");
							if (entry) {
								mesh->edgesCount = entry->size;
								mesh->edges = MALLOC(int, entry->size);
								for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
									mesh->edges[ii] = entry->valueInt;
							}

							sp35AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						} else {
							mesh->inheritDeform = Json35_getInt(attachmentMap, "deform", 1);
							_sp35SkeletonJson_addLinkedMesh(self, SUB_CAST(sp35MeshAttachment, attachment), Json35_getString(attachmentMap, "skin", 0), slotIndex,
									entry->valueString);
						}
						break;
					}
					case SP_ATTACHMENT_BOUNDING_BOX: {
						sp35BoundingBoxAttachment* box = SUB_CAST(sp35BoundingBoxAttachment, attachment);
						int vertexCount = Json35_getInt(attachmentMap, "vertexCount", 0) << 1;
						_readVertices(self, attachmentMap, SUPER(box), vertexCount);
						box->super.verticesCount = vertexCount;
						sp35AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						break;
					}
					case SP_ATTACHMENT_PATH: {
						sp35PathAttachment* path = SUB_CAST(sp35PathAttachment, attachment);
						int vertexCount = 0;
						path->closed = Json35_getInt(attachmentMap, "closed", 0);
						path->constantSpeed = Json35_getInt(attachmentMap, "constantSpeed", 1);
						vertexCount = Json35_getInt(attachmentMap, "vertexCount", 0);
						_readVertices(self, attachmentMap, SUPER(path), vertexCount << 1);

						path->lengthsLength = vertexCount / 3;
						path->lengths = MALLOC(float, path->lengthsLength);

						curves = Json35_getItem(attachmentMap, "lengths");
						for (curves = curves->child, ii = 0; curves; curves = curves->next, ++ii) {
							path->lengths[ii] = curves->valueFloat * self->scale;
						}
						break;
					}
					}

					sp35Skin_addAttachment(skin, slotIndex, skinAttachmentName, attachment);
				}
			}
		}
	}

	/* Linked meshes. */
	for (i = 0; i < internal->linkedMeshCount; i++) {
		sp35Attachment* parent;
		_sp35LinkedMesh* linkedMesh = internal->linkedMeshes + i;
		sp35Skin* skin = !linkedMesh->skin ? skeletonData->defaultSkin : sp35SkeletonData_findSkin(skeletonData, linkedMesh->skin);
		if (!skin) {
			sp35SkeletonData_dispose(skeletonData);
			_sp35SkeletonJson_setError(self, 0, "Skin not found: ", linkedMesh->skin);
			return 0;
		}
		parent = sp35Skin_getAttachment(skin, linkedMesh->slotIndex, linkedMesh->parent);
		if (!parent) {
			sp35SkeletonData_dispose(skeletonData);
			_sp35SkeletonJson_setError(self, 0, "Parent mesh not found: ", linkedMesh->parent);
			return 0;
		}
		sp35MeshAttachment_setParentMesh(linkedMesh->mesh, SUB_CAST(sp35MeshAttachment, parent));
		sp35MeshAttachment_updateUVs(linkedMesh->mesh);
		sp35AttachmentLoader_configureAttachment(self->attachmentLoader, SUPER(SUPER(linkedMesh->mesh)));
	}

	/* Events. */
	events = Json35_getItem(root, "events");
	if (events) {
		Json35 *eventMap;
		const char* stringValue;
		skeletonData->eventsCount = events->size;
		skeletonData->events = MALLOC(sp35EventData*, events->size);
		for (eventMap = events->child, i = 0; eventMap; eventMap = eventMap->next, ++i) {
			sp35EventData* eventData = sp35EventData_create(eventMap->name);
			eventData->intValue = Json35_getInt(eventMap, "int", 0);
			eventData->floatValue = Json35_getFloat(eventMap, "float", 0);
			stringValue = Json35_getString(eventMap, "string", 0);
			if (stringValue) MALLOC_STR(eventData->stringValue, stringValue);
			skeletonData->events[i] = eventData;
		}
	}

	/* Animations. */
	animations = Json35_getItem(root, "animations");
	if (animations) {
		Json35 *animationMap;
		skeletonData->animations = MALLOC(sp35Animation*, animations->size);
		for (animationMap = animations->child; animationMap; animationMap = animationMap->next) {
			sp35Animation* animation = _sp35SkeletonJson_readAnimation(self, animationMap, skeletonData);
			if (!animation) {
				sp35SkeletonData_dispose(skeletonData);
				return 0;
			}
			skeletonData->animations[skeletonData->animationsCount++] = animation;
		}
	}

	Json35_dispose(root);
	return skeletonData;
}

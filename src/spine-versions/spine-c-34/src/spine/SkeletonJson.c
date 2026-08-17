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
	sp34MeshAttachment* mesh;
} _sp34LinkedMesh;

typedef struct {
	sp34SkeletonJson super;
	int ownsLoader;

	int linkedMeshCount;
	int linkedMeshCapacity;
	_sp34LinkedMesh* linkedMeshes;
} _sp34SkeletonJson;

sp34SkeletonJson* sp34SkeletonJson_createWithLoader (sp34AttachmentLoader* attachmentLoader) {
	sp34SkeletonJson* self = SUPER(NEW(_sp34SkeletonJson));
	self->scale = 1;
	self->attachmentLoader = attachmentLoader;
	return self;
}

sp34SkeletonJson* sp34SkeletonJson_create (sp34Atlas* atlas) {
	sp34AtlasAttachmentLoader* attachmentLoader = sp34AtlasAttachmentLoader_create(atlas);
	sp34SkeletonJson* self = sp34SkeletonJson_createWithLoader(SUPER(attachmentLoader));
	SUB_CAST(_sp34SkeletonJson, self)->ownsLoader = 1;
	return self;
}

void sp34SkeletonJson_dispose (sp34SkeletonJson* self) {
	_sp34SkeletonJson* internal = SUB_CAST(_sp34SkeletonJson, self);
	if (internal->ownsLoader) sp34AttachmentLoader_dispose(self->attachmentLoader);
	FREE(internal->linkedMeshes);
	FREE(self->error);
	FREE(self);
}

void _sp34SkeletonJson_setError (sp34SkeletonJson* self, Json34* root, const char* value1, const char* value2) {
	char message[256];
	int length;
	FREE(self->error);
	strcpy(message, value1);
	length = (int)strlen(value1);
	if (value2) strncat(message + length, value2, 255 - length);
	MALLOC_STR(self->error, message);
	if (root) Json34_dispose(root);
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

static void readCurve (Json34* frame, sp34CurveTimeline* timeline, int frameIndex) {
	Json34* curve = Json34_getItem(frame, "curve");
	if (!curve) return;
	if (curve->type == Json34_String && strcmp(curve->valueString, "stepped") == 0)
		sp34CurveTimeline_setStepped(timeline, frameIndex);
	else if (curve->type == Json34_Array) {
		Json34* child0 = curve->child;
		Json34* child1 = child0->next;
		Json34* child2 = child1->next;
		Json34* child3 = child2->next;
		sp34CurveTimeline_setCurve(timeline, frameIndex, child0->valueFloat, child1->valueFloat, child2->valueFloat,
				child3->valueFloat);
	}
}

static void _sp34SkeletonJson_addLinkedMesh (sp34SkeletonJson* self, sp34MeshAttachment* mesh, const char* skin, int slotIndex,
		const char* parent) {
	_sp34LinkedMesh* linkedMesh;
	_sp34SkeletonJson* internal = SUB_CAST(_sp34SkeletonJson, self);

	if (internal->linkedMeshCount == internal->linkedMeshCapacity) {
		_sp34LinkedMesh* linkedMeshes;
		internal->linkedMeshCapacity *= 2;
		if (internal->linkedMeshCapacity < 8) internal->linkedMeshCapacity = 8;
		linkedMeshes = MALLOC(_sp34LinkedMesh, internal->linkedMeshCapacity);
		memcpy(linkedMeshes, internal->linkedMeshes, sizeof(_sp34LinkedMesh) * internal->linkedMeshCount);
		FREE(internal->linkedMeshes);
		internal->linkedMeshes = linkedMeshes;
	}

	linkedMesh = internal->linkedMeshes + internal->linkedMeshCount++;
	linkedMesh->mesh = mesh;
	linkedMesh->skin = skin;
	linkedMesh->slotIndex = slotIndex;
	linkedMesh->parent = parent;
}

static sp34Animation* _sp34SkeletonJson_readAnimation (sp34SkeletonJson* self, Json34* root, sp34SkeletonData *skeletonData) {
	int frameIndex;
	sp34Animation* animation;
	Json34* valueMap;
	int timelinesCount = 0;

	Json34* bones = Json34_getItem(root, "bones");
	Json34* slots = Json34_getItem(root, "slots");
	Json34* ik = Json34_getItem(root, "ik");
	Json34* transform = Json34_getItem(root, "transform");
	Json34* paths = Json34_getItem(root, "paths");
	Json34* deform = Json34_getItem(root, "deform");
	Json34* drawOrder = Json34_getItem(root, "drawOrder");
	Json34* events = Json34_getItem(root, "events");
	Json34 *boneMap, *slotMap, *constraintMap;
	if (!drawOrder) drawOrder = Json34_getItem(root, "draworder");

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

	animation = sp34Animation_create(root->name, timelinesCount);
	animation->timelinesCount = 0;

	/* Slot timelines. */
	for (slotMap = slots ? slots->child : 0; slotMap; slotMap = slotMap->next) {
		Json34 *timelineMap;

		int slotIndex = sp34SkeletonData_findSlotIndex(skeletonData, slotMap->name);
		if (slotIndex == -1) {
			sp34Animation_dispose(animation);
			_sp34SkeletonJson_setError(self, root, "Slot not found: ", slotMap->name);
			return 0;
		}

		for (timelineMap = slotMap->child; timelineMap; timelineMap = timelineMap->next) {
			if (strcmp(timelineMap->name, "color") == 0) {
				sp34ColorTimeline *timeline = sp34ColorTimeline_create(timelineMap->size);
				timeline->slotIndex = slotIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					const char* s = Json34_getString(valueMap, "color", 0);
					sp34ColorTimeline_setFrame(timeline, frameIndex, Json34_getFloat(valueMap, "time", 0), toColor(s, 0), toColor(s, 1), toColor(s, 2),
							toColor(s, 3));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp34Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * COLOR_ENTRIES]);

			} else if (strcmp(timelineMap->name, "attachment") == 0) {
				sp34AttachmentTimeline *timeline = sp34AttachmentTimeline_create(timelineMap->size);
				timeline->slotIndex = slotIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					Json34* name = Json34_getItem(valueMap, "name");
					sp34AttachmentTimeline_setFrame(timeline, frameIndex, Json34_getFloat(valueMap, "time", 0),
							name->type == Json34_NULL ? 0 : name->valueString);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp34Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[timelineMap->size - 1]);

			} else {
				sp34Animation_dispose(animation);
				_sp34SkeletonJson_setError(self, 0, "Invalid timeline type for a slot: ", timelineMap->name);
				return 0;
			}
		}
	}

	/* Bone timelines. */
	for (boneMap = bones ? bones->child : 0; boneMap; boneMap = boneMap->next) {
		Json34 *timelineMap;

		int boneIndex = sp34SkeletonData_findBoneIndex(skeletonData, boneMap->name);
		if (boneIndex == -1) {
			sp34Animation_dispose(animation);
			_sp34SkeletonJson_setError(self, root, "Bone not found: ", boneMap->name);
			return 0;
		}

		for (timelineMap = boneMap->child; timelineMap; timelineMap = timelineMap->next) {
			if (strcmp(timelineMap->name, "rotate") == 0) {
				sp34RotateTimeline *timeline = sp34RotateTimeline_create(timelineMap->size);
				timeline->boneIndex = boneIndex;

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					sp34RotateTimeline_setFrame(timeline, frameIndex, Json34_getFloat(valueMap, "time", 0), Json34_getFloat(valueMap, "angle", 0));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp34Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * ROTATE_ENTRIES]);

			} else {
				int isScale = strcmp(timelineMap->name, "scale") == 0;
				int isTranslate = strcmp(timelineMap->name, "translate") == 0;
				int isShear = strcmp(timelineMap->name, "shear") == 0;
				if (isScale || isTranslate || isShear) {
					float timelineScale = isTranslate ? self->scale: 1;
					sp34TranslateTimeline *timeline = 0;
					if (isScale) timeline = sp34ScaleTimeline_create(timelineMap->size);
					else if (isTranslate) timeline = sp34TranslateTimeline_create(timelineMap->size);
					else if (isShear) timeline = sp34ShearTimeline_create(timelineMap->size);
					timeline->boneIndex = boneIndex;

					for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
						sp34TranslateTimeline_setFrame(timeline, frameIndex, Json34_getFloat(valueMap, "time", 0), Json34_getFloat(valueMap, "x", 0) * timelineScale,
								Json34_getFloat(valueMap, "y", 0) * timelineScale);
						readCurve(valueMap, SUPER(timeline), frameIndex);
					}
					animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp34Timeline, timeline);
					animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * TRANSLATE_ENTRIES]);

				} else {
					sp34Animation_dispose(animation);
					_sp34SkeletonJson_setError(self, 0, "Invalid timeline type for a bone: ", timelineMap->name);
					return 0;
				}
			}
		}
	}

	/* IK constraint timelines. */
	for (constraintMap = ik ? ik->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp34IkConstraintData* constraint = sp34SkeletonData_findIkConstraint(skeletonData, constraintMap->name);
		sp34IkConstraintTimeline* timeline = sp34IkConstraintTimeline_create(constraintMap->size);
		for (frameIndex = 0; frameIndex < skeletonData->ikConstraintsCount; ++frameIndex) {
			if (constraint == skeletonData->ikConstraints[frameIndex]) {
				timeline->ikConstraintIndex = frameIndex;
				break;
			}
		}
		for (valueMap = constraintMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			sp34IkConstraintTimeline_setFrame(timeline, frameIndex, Json34_getFloat(valueMap, "time", 0), Json34_getFloat(valueMap, "mix", 1),
					Json34_getInt(valueMap, "bendPositive", 1) ? 1 : -1);
			readCurve(valueMap, SUPER(timeline), frameIndex);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp34Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[(constraintMap->size - 1) * IKCONSTRAINT_ENTRIES]);
	}

	/* Transform constraint timelines. */
	for (constraintMap = transform ? transform->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp34TransformConstraintData* constraint = sp34SkeletonData_findTransformConstraint(skeletonData, constraintMap->name);
		sp34TransformConstraintTimeline* timeline = sp34TransformConstraintTimeline_create(constraintMap->size);
		for (frameIndex = 0; frameIndex < skeletonData->transformConstraintsCount; ++frameIndex) {
			if (constraint == skeletonData->transformConstraints[frameIndex]) {
				timeline->transformConstraintIndex = frameIndex;
				break;
			}
		}
		for (valueMap = constraintMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			sp34TransformConstraintTimeline_setFrame(timeline, frameIndex, Json34_getFloat(valueMap, "time", 0), Json34_getFloat(valueMap, "rotateMix", 1),
					Json34_getFloat(valueMap, "translateMix", 1), Json34_getFloat(valueMap, "scaleMix", 1), Json34_getFloat(valueMap, "shearMix", 1));
			readCurve(valueMap, SUPER(timeline), frameIndex);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp34Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[(constraintMap->size - 1) * TRANSFORMCONSTRAINT_ENTRIES]);
	}

	/** Path constraint timelines. */
	for(constraintMap = paths ? paths->child : 0; constraintMap; constraintMap = constraintMap->next ) {
		int constraintIndex, i;
		Json34* timelineMap;

		sp34PathConstraintData* data = sp34SkeletonData_findPathConstraint(skeletonData, constraintMap->name);
		if (!data) {
			sp34Animation_dispose(animation);
			_sp34SkeletonJson_setError(self, root, "Path constraint not found: ", constraintMap->name);
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
				sp34PathConstraintPositionTimeline* timeline;
				float timelineScale = 1;
				if (strcmp(timelineName, "spacing") == 0) {
					timeline = (sp34PathConstraintPositionTimeline*)sp34PathConstraintSpacingTimeline_create(timelineMap->size);
					if (data->spacingMode == SP_SPACING_MODE_LENGTH || data->spacingMode == SP_SPACING_MODE_FIXED) timelineScale = self->scale;
				} else {
					timeline = sp34PathConstraintPositionTimeline_create(timelineMap->size);
					if (data->positionMode == SP_POSITION_MODE_FIXED) timelineScale = self->scale;
				}
				timeline->pathConstraintIndex = constraintIndex;
				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					sp34PathConstraintPositionTimeline_setFrame(timeline, frameIndex, Json34_getFloat(valueMap, "time", 0), Json34_getFloat(valueMap, timelineName, 0) * timelineScale);
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp34Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * PATHCONSTRAINTPOSITION_ENTRIES]);
			} else if (strcmp(timelineName, "mix")) {
				sp34PathConstraintMixTimeline* timeline = sp34PathConstraintMixTimeline_create(timelineMap->size);
				timeline->pathConstraintIndex = constraintIndex;
				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					sp34PathConstraintMixTimeline_setFrame(timeline, frameIndex, Json34_getFloat(valueMap, "time", 0),
														 Json34_getFloat(valueMap, "rotateMix", 1), Json34_getFloat(valueMap, "translateMix", 1));
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp34Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[(timelineMap->size - 1) * PATHCONSTRAINTMIX_ENTRIES]);
			}
		}
	}

	/* Deform timelines. */
	for (constraintMap = deform ? deform->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp34Skin* skin = sp34SkeletonData_findSkin(skeletonData, constraintMap->name);
		for (slotMap = constraintMap->child; slotMap; slotMap = slotMap->next) {
			int slotIndex = sp34SkeletonData_findSlotIndex(skeletonData, slotMap->name);
			Json34* timelineMap;
			for (timelineMap = slotMap->child; timelineMap; timelineMap = timelineMap->next) {
				float* tempDeform;
				sp34DeformTimeline *timeline;
				int weighted, deformLength;

				sp34VertexAttachment* attachment = SUB_CAST(sp34VertexAttachment, sp34Skin_getAttachment(skin, slotIndex, timelineMap->name));
				if (!attachment) {
					sp34Animation_dispose(animation);
					_sp34SkeletonJson_setError(self, 0, "Attachment not found: ", timelineMap->name);
					return 0;
				}
				weighted = attachment->bones != 0;
				deformLength = weighted ? attachment->verticesCount / 3 * 2 : attachment->verticesCount;
				tempDeform = MALLOC(float, deformLength);

				timeline = sp34DeformTimeline_create(timelineMap->size, deformLength);
				timeline->slotIndex = slotIndex;
				timeline->attachment = SUPER(attachment);

				for (valueMap = timelineMap->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
					Json34* vertices = Json34_getItem(valueMap, "vertices");
					float* deform;
					if (!vertices) {
						if (weighted) {
							deform = tempDeform;
							memset(deform, 0, sizeof(float) * deformLength);
						} else
							deform = attachment->vertices;
					} else {
						int v, start = Json34_getInt(valueMap, "offset", 0);
						Json34* vertex;
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
					sp34DeformTimeline_setFrame(timeline, frameIndex, Json34_getFloat(valueMap, "time", 0), deform);
					readCurve(valueMap, SUPER(timeline), frameIndex);
				}
				FREE(tempDeform);

				animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp34Timeline, timeline);
				animation->duration = MAX(animation->duration, timeline->frames[timelineMap->size - 1]);
			}
		}
	}

	/* Draw order timeline. */
	if (drawOrder) {
		sp34DrawOrderTimeline* timeline = sp34DrawOrderTimeline_create(drawOrder->size, skeletonData->slotsCount);
		for (valueMap = drawOrder->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			int ii;
			int* drawOrder = 0;
			Json34* offsets = Json34_getItem(valueMap, "offsets");
			if (offsets) {
				Json34* offsetMap;
				int* unchanged = MALLOC(int, skeletonData->slotsCount - offsets->size);
				int originalIndex = 0, unchangedIndex = 0;

				drawOrder = MALLOC(int, skeletonData->slotsCount);
				for (ii = skeletonData->slotsCount - 1; ii >= 0; --ii)
					drawOrder[ii] = -1;

				for (offsetMap = offsets->child; offsetMap; offsetMap = offsetMap->next) {
					int slotIndex = sp34SkeletonData_findSlotIndex(skeletonData, Json34_getString(offsetMap, "slot", 0));
					if (slotIndex == -1) {
						sp34Animation_dispose(animation);
						_sp34SkeletonJson_setError(self, 0, "Slot not found: ", Json34_getString(offsetMap, "slot", 0));
						return 0;
					}
					/* Collect unchanged items. */
					while (originalIndex != slotIndex)
						unchanged[unchangedIndex++] = originalIndex++;
					/* Set changed items. */
					drawOrder[originalIndex + Json34_getInt(offsetMap, "offset", 0)] = originalIndex;
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
			sp34DrawOrderTimeline_setFrame(timeline, frameIndex, Json34_getFloat(valueMap, "time", 0), drawOrder);
			FREE(drawOrder);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp34Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[drawOrder->size - 1]);
	}

	/* Event timeline. */
	if (events) {
		sp34EventTimeline* timeline = sp34EventTimeline_create(events->size);
		for (valueMap = events->child, frameIndex = 0; valueMap; valueMap = valueMap->next, ++frameIndex) {
			sp34Event* event;
			const char* stringValue;
			sp34EventData* eventData = sp34SkeletonData_findEvent(skeletonData, Json34_getString(valueMap, "name", 0));
			if (!eventData) {
				sp34Animation_dispose(animation);
				_sp34SkeletonJson_setError(self, 0, "Event not found: ", Json34_getString(valueMap, "name", 0));
				return 0;
			}
			event = sp34Event_create(Json34_getFloat(valueMap, "time", 0), eventData);
			event->intValue = Json34_getInt(valueMap, "int", eventData->intValue);
			event->floatValue = Json34_getFloat(valueMap, "float", eventData->floatValue);
			stringValue = Json34_getString(valueMap, "string", eventData->stringValue);
			if (stringValue) MALLOC_STR(event->stringValue, stringValue);
			sp34EventTimeline_setFrame(timeline, frameIndex, event);
		}
		animation->timelines[animation->timelinesCount++] = SUPER_CAST(sp34Timeline, timeline);
		animation->duration = MAX(animation->duration, timeline->frames[events->size - 1]);
	}

	return animation;
}

static void _readVertices (sp34SkeletonJson* self, Json34* attachmentMap, sp34VertexAttachment* attachment, int verticesLength) {
	Json34* entry;
	float* vertices;
	int i, b, w, nn, entrySize;

	attachment->worldVerticesLength = verticesLength;

	entry = Json34_getItem(attachmentMap, "vertices");
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

sp34SkeletonData* sp34SkeletonJson_readSkeletonDataFile (sp34SkeletonJson* self, const char* path) {
	int length;
	sp34SkeletonData* skeletonData;
	const char* json = _sp34Util_readFile(path, &length);
	if (length == 0 || !json) {
		_sp34SkeletonJson_setError(self, 0, "Unable to read skeleton file: ", path);
		return 0;
	}
	skeletonData = sp34SkeletonJson_readSkeletonData(self, json);
	FREE(json);
	return skeletonData;
}

sp34SkeletonData* sp34SkeletonJson_readSkeletonData (sp34SkeletonJson* self, const char* json) {
	int i, ii;
	sp34SkeletonData* skeletonData;
	Json34 *root, *skeleton, *bones, *boneMap, *ik, *transform, *path, *slots, *skins, *animations, *events;
	char* oldLocale;
	_sp34SkeletonJson* internal = SUB_CAST(_sp34SkeletonJson, self);

	FREE(self->error);
	CONST_CAST(char*, self->error) = 0;
	internal->linkedMeshCount = 0;

#ifndef __ANDROID__
	oldLocale = strdup(setlocale(LC_NUMERIC, NULL));
	setlocale(LC_NUMERIC, "C");
#endif
    
	root = Json34_create(json);
    
#ifndef __ANDROID__
	setlocale(LC_NUMERIC, oldLocale);
	free(oldLocale);
#endif
    
	if (!root) {
		_sp34SkeletonJson_setError(self, 0, "Invalid skeleton JSON: ", Json34_getError());
		return 0;
	}

	skeletonData = sp34SkeletonData_create();

	skeleton = Json34_getItem(root, "skeleton");
	if (skeleton) {
		MALLOC_STR(skeletonData->hash, Json34_getString(skeleton, "hash", 0));
		MALLOC_STR(skeletonData->version,  Json34_getString(skeleton, "spine", 0));
		skeletonData->width = Json34_getFloat(skeleton, "width", 0);
		skeletonData->height = Json34_getFloat(skeleton, "height", 0);
	}

	/* Bones. */
	bones = Json34_getItem(root, "bones");
	skeletonData->bones = MALLOC(sp34BoneData*, bones->size);
	for (boneMap = bones->child, i = 0; boneMap; boneMap = boneMap->next, ++i) {
		sp34BoneData* data;

		sp34BoneData* parent = 0;
		const char* parentName = Json34_getString(boneMap, "parent", 0);
		if (parentName) {
			parent = sp34SkeletonData_findBone(skeletonData, parentName);
			if (!parent) {
				sp34SkeletonData_dispose(skeletonData);
				_sp34SkeletonJson_setError(self, root, "Parent bone not found: ", parentName);
				return 0;
			}
		}

		data = sp34BoneData_create(skeletonData->bonesCount, Json34_getString(boneMap, "name", 0), parent);
		data->length = Json34_getFloat(boneMap, "length", 0) * self->scale;
		data->x = Json34_getFloat(boneMap, "x", 0) * self->scale;
		data->y = Json34_getFloat(boneMap, "y", 0) * self->scale;
		data->rotation = Json34_getFloat(boneMap, "rotation", 0);
		data->scaleX = Json34_getFloat(boneMap, "scaleX", 1);
		data->scaleY = Json34_getFloat(boneMap, "scaleY", 1);
		data->shearX = Json34_getFloat(boneMap, "shearX", 0);
		data->shearY = Json34_getFloat(boneMap, "shearY", 0);
		data->inheritRotation = Json34_getInt(boneMap, "inheritRotation", 1);
		data->inheritScale = Json34_getInt(boneMap, "inheritScale", 1);

		skeletonData->bones[i] = data;
		skeletonData->bonesCount++;
	}

	/* Slots. */
	slots = Json34_getItem(root, "slots");
	if (slots) {
		Json34 *slotMap;
		skeletonData->slotsCount = slots->size;
		skeletonData->slots = MALLOC(sp34SlotData*, slots->size);
		for (slotMap = slots->child, i = 0; slotMap; slotMap = slotMap->next, ++i) {
			sp34SlotData* data;
			const char* color;
			Json34 *item;

			const char* boneName = Json34_getString(slotMap, "bone", 0);
			sp34BoneData* boneData = sp34SkeletonData_findBone(skeletonData, boneName);
			if (!boneData) {
				sp34SkeletonData_dispose(skeletonData);
				_sp34SkeletonJson_setError(self, root, "Slot bone not found: ", boneName);
				return 0;
			}

			data = sp34SlotData_create(i, Json34_getString(slotMap, "name", 0), boneData);

			color = Json34_getString(slotMap, "color", 0);
			if (color) {
				data->r = toColor(color, 0);
				data->g = toColor(color, 1);
				data->b = toColor(color, 2);
				data->a = toColor(color, 3);
			}

			item = Json34_getItem(slotMap, "attachment");
			if (item) sp34SlotData_setAttachmentName(data, item->valueString);

			item = Json34_getItem(slotMap, "blend");
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
	ik = Json34_getItem(root, "ik");
	if (ik) {
		Json34 *constraintMap;
		skeletonData->ikConstraintsCount = ik->size;
		skeletonData->ikConstraints = MALLOC(sp34IkConstraintData*, ik->size);
		for (constraintMap = ik->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char* targetName;

			sp34IkConstraintData* data = sp34IkConstraintData_create(Json34_getString(constraintMap, "name", 0));

			boneMap = Json34_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			data->bones = MALLOC(sp34BoneData*, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp34SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp34SkeletonData_dispose(skeletonData);
					_sp34SkeletonJson_setError(self, root, "IK bone not found: ", boneMap->valueString);
					return 0;
				}
			}

			targetName = Json34_getString(constraintMap, "target", 0);
			data->target = sp34SkeletonData_findBone(skeletonData, targetName);
			if (!data->target) {
				sp34SkeletonData_dispose(skeletonData);
				_sp34SkeletonJson_setError(self, root, "Target bone not found: ", boneMap->name);
				return 0;
			}

			data->bendDirection = Json34_getInt(constraintMap, "bendPositive", 1) ? 1 : -1;
			data->mix = Json34_getFloat(constraintMap, "mix", 1);

			skeletonData->ikConstraints[i] = data;
		}
	}

	/* Transform constraints. */
	transform = Json34_getItem(root, "transform");
	if (transform) {
		Json34 *constraintMap;
		skeletonData->transformConstraintsCount = transform->size;
		skeletonData->transformConstraints = MALLOC(sp34TransformConstraintData*, transform->size);
		for (constraintMap = transform->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char* name;

			sp34TransformConstraintData* data = sp34TransformConstraintData_create(Json34_getString(constraintMap, "name", 0));

			boneMap = Json34_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			CONST_CAST(sp34BoneData**, data->bones) = MALLOC(sp34BoneData*, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp34SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp34SkeletonData_dispose(skeletonData);
					_sp34SkeletonJson_setError(self, root, "Transform bone not found: ", boneMap->valueString);
					return 0;
				}
			}

			name = Json34_getString(constraintMap, "target", 0);
			data->target = sp34SkeletonData_findBone(skeletonData, name);
			if (!data->target) {
				sp34SkeletonData_dispose(skeletonData);
				_sp34SkeletonJson_setError(self, root, "Target bone not found: ", boneMap->name);
				return 0;
			}

			data->offsetRotation = Json34_getFloat(constraintMap, "rotation", 0);
			data->offsetX = Json34_getFloat(constraintMap, "x", 0) * self->scale;
			data->offsetY = Json34_getFloat(constraintMap, "y", 0) * self->scale;
			data->offsetScaleX = Json34_getFloat(constraintMap, "scaleX", 0);
			data->offsetScaleY = Json34_getFloat(constraintMap, "scaleY", 0);
			data->offsetShearY = Json34_getFloat(constraintMap, "shearY", 0);

			data->rotateMix = Json34_getFloat(constraintMap, "rotateMix", 1);
			data->translateMix = Json34_getFloat(constraintMap, "translateMix", 1);
			data->scaleMix = Json34_getFloat(constraintMap, "scaleMix", 1);
			data->shearMix = Json34_getFloat(constraintMap, "shearMix", 1);

			skeletonData->transformConstraints[i] = data;
		}
	}

	/* Path constraints */
	path = Json34_getItem(root, "path");
	if (path) {
		Json34 *constraintMap;
		skeletonData->pathConstraintsCount = path->size;
		skeletonData->pathConstraints = MALLOC(sp34PathConstraintData*, path->size);
		for (constraintMap = path->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char* name;
			const char* item;

			sp34PathConstraintData* data = sp34PathConstraintData_create(Json34_getString(constraintMap, "name", 0));

			boneMap = Json34_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			CONST_CAST(sp34BoneData**, data->bones) = MALLOC(sp34BoneData*, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp34SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp34SkeletonData_dispose(skeletonData);
					_sp34SkeletonJson_setError(self, root, "Path bone not found: ", boneMap->valueString);
					return 0;
				}
			}

			name = Json34_getString(constraintMap, "target", 0);
			data->target = sp34SkeletonData_findSlot(skeletonData, name);
			if (!data->target) {
				sp34SkeletonData_dispose(skeletonData);
				_sp34SkeletonJson_setError(self, root, "Target slot not found: ", boneMap->name);
				return 0;
			}

			item = Json34_getString(constraintMap, "positionMode", "percent");
			if (strcmp(item, "fixed") == 0) data->positionMode = SP_POSITION_MODE_FIXED;
			else if (strcmp(item, "percent") == 0) data->positionMode = SP_POSITION_MODE_PERCENT;

			item = Json34_getString(constraintMap, "spacingMode", "length");
			if (strcmp(item, "length") == 0) data->spacingMode = SP_SPACING_MODE_LENGTH;
			else if (strcmp(item, "fixed") == 0) data->spacingMode = SP_SPACING_MODE_FIXED;
			else if (strcmp(item, "percent") == 0) data->spacingMode = SP_SPACING_MODE_PERCENT;

			item = Json34_getString(constraintMap, "rotateMode", "tangent");
			if (strcmp(item, "tangent") == 0) data->rotateMode = SP_ROTATE_MODE_TANGENT;
			else if (strcmp(item, "chain") == 0) data->rotateMode = SP_ROTATE_MODE_CHAIN;
			else if (strcmp(item, "chainScale") == 0) data->rotateMode = SP_ROTATE_MODE_CHAIN_SCALE;

			data->offsetRotation = Json34_getFloat(constraintMap, "rotation", 0);
			data->position = Json34_getFloat(constraintMap, "position", 0);
			if (data->positionMode == SP_POSITION_MODE_FIXED) data->position *= self->scale;
			data->spacing = Json34_getFloat(constraintMap, "spacing", 0);
			if (data->spacingMode == SP_SPACING_MODE_LENGTH || data->spacingMode == SP_SPACING_MODE_FIXED) data->spacing *= self->scale;
			data->rotateMix = Json34_getFloat(constraintMap, "rotateMix", 1);
			data->translateMix = Json34_getFloat(constraintMap, "translateMix", 1);

			skeletonData->pathConstraints[i] = data;
		}
	}

	/* Skins. */
	skins = Json34_getItem(root, "skins");
	if (skins) {
		Json34 *skinMap;
		skeletonData->skins = MALLOC(sp34Skin*, skins->size);
		for (skinMap = skins->child, i = 0; skinMap; skinMap = skinMap->next, ++i) {
			Json34 *attachmentsMap;
			Json34 *curves;
			sp34Skin *skin = sp34Skin_create(skinMap->name);

			skeletonData->skins[skeletonData->skinsCount++] = skin;
			if (strcmp(skinMap->name, "default") == 0) skeletonData->defaultSkin = skin;

			for (attachmentsMap = skinMap->child; attachmentsMap; attachmentsMap = attachmentsMap->next) {
				int slotIndex = sp34SkeletonData_findSlotIndex(skeletonData, attachmentsMap->name);
				Json34 *attachmentMap;

				for (attachmentMap = attachmentsMap->child; attachmentMap; attachmentMap = attachmentMap->next) {
					sp34Attachment* attachment;
					const char* skinAttachmentName = attachmentMap->name;
					const char* attachmentName = Json34_getString(attachmentMap, "name", skinAttachmentName);
					const char* path = Json34_getString(attachmentMap, "path", attachmentName);
					const char* color;
					Json34* entry;

					const char* typeString = Json34_getString(attachmentMap, "type", "region");
					sp34AttachmentType type;
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
						sp34SkeletonData_dispose(skeletonData);
						_sp34SkeletonJson_setError(self, root, "Unknown attachment type: ", typeString);
						return 0;
					}

					attachment = sp34AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, attachmentName, path);
					if (!attachment) {
						if (self->attachmentLoader->error1) {
							sp34SkeletonData_dispose(skeletonData);
							_sp34SkeletonJson_setError(self, root, self->attachmentLoader->error1, self->attachmentLoader->error2);
							return 0;
						}
						continue;
					}

					switch (attachment->type) {
					case SP_ATTACHMENT_REGION: {
						sp34RegionAttachment* region = SUB_CAST(sp34RegionAttachment, attachment);
						if (path) MALLOC_STR(region->path, path);
						region->x = Json34_getFloat(attachmentMap, "x", 0) * self->scale;
						region->y = Json34_getFloat(attachmentMap, "y", 0) * self->scale;
						region->scaleX = Json34_getFloat(attachmentMap, "scaleX", 1);
						region->scaleY = Json34_getFloat(attachmentMap, "scaleY", 1);
						region->rotation = Json34_getFloat(attachmentMap, "rotation", 0);
						region->width = Json34_getFloat(attachmentMap, "width", 32) * self->scale;
						region->height = Json34_getFloat(attachmentMap, "height", 32) * self->scale;

						color = Json34_getString(attachmentMap, "color", 0);
						if (color) {
							region->r = toColor(color, 0);
							region->g = toColor(color, 1);
							region->b = toColor(color, 2);
							region->a = toColor(color, 3);
						}

						sp34RegionAttachment_updateOffset(region);

						sp34AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						break;
					}
					case SP_ATTACHMENT_MESH:
					case SP_ATTACHMENT_LINKED_MESH: {
						sp34MeshAttachment* mesh = SUB_CAST(sp34MeshAttachment, attachment);

						MALLOC_STR(mesh->path, path);

						color = Json34_getString(attachmentMap, "color", 0);
						if (color) {
							mesh->r = toColor(color, 0);
							mesh->g = toColor(color, 1);
							mesh->b = toColor(color, 2);
							mesh->a = toColor(color, 3);
						}

						mesh->width = Json34_getFloat(attachmentMap, "width", 32) * self->scale;
						mesh->height = Json34_getFloat(attachmentMap, "height", 32) * self->scale;

						entry = Json34_getItem(attachmentMap, "parent");
						if (!entry) {
							int verticesLength;
							entry = Json34_getItem(attachmentMap, "triangles");
							mesh->trianglesCount = entry->size;
							mesh->triangles = MALLOC(unsigned short, entry->size);
							for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
								mesh->triangles[ii] = (unsigned short)entry->valueInt;

							entry = Json34_getItem(attachmentMap, "uvs");
							verticesLength = entry->size;
							mesh->regionUVs = MALLOC(float, verticesLength);
							for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
								mesh->regionUVs[ii] = entry->valueFloat;

							_readVertices(self, attachmentMap, SUPER(mesh), verticesLength);

							sp34MeshAttachment_updateUVs(mesh);

							mesh->hullLength = Json34_getInt(attachmentMap, "hull", 0);

							entry = Json34_getItem(attachmentMap, "edges");
							if (entry) {
								mesh->edgesCount = entry->size;
								mesh->edges = MALLOC(int, entry->size);
								for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
									mesh->edges[ii] = entry->valueInt;
							}

							sp34AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						} else {
							mesh->inheritDeform = Json34_getInt(attachmentMap, "deform", 1);
							_sp34SkeletonJson_addLinkedMesh(self, SUB_CAST(sp34MeshAttachment, attachment), Json34_getString(attachmentMap, "skin", 0), slotIndex,
									entry->valueString);
						}
						break;
					}
					case SP_ATTACHMENT_BOUNDING_BOX: {
						sp34BoundingBoxAttachment* box = SUB_CAST(sp34BoundingBoxAttachment, attachment);
						int vertexCount = Json34_getInt(attachmentMap, "vertexCount", 0) << 1;
						_readVertices(self, attachmentMap, SUPER(box), vertexCount);
						box->super.verticesCount = vertexCount;
						sp34AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
						break;
					}
					case SP_ATTACHMENT_PATH: {
						sp34PathAttachment* path = SUB_CAST(sp34PathAttachment, attachment);
						int vertexCount = 0;
						path->closed = Json34_getInt(attachmentMap, "closed", 0);
						path->constantSpeed = Json34_getInt(attachmentMap, "constantSpeed", 1);
						vertexCount = Json34_getInt(attachmentMap, "vertexCount", 0);
						_readVertices(self, attachmentMap, SUPER(path), vertexCount << 1);

						path->lengthsLength = vertexCount / 3;
						path->lengths = MALLOC(float, path->lengthsLength);

						curves = Json34_getItem(attachmentMap, "lengths");
						for (curves = curves->child, ii = 0; curves; curves = curves->next, ++ii) {
							path->lengths[ii] = curves->valueFloat * self->scale;
						}
						break;
					}
					}

					sp34Skin_addAttachment(skin, slotIndex, skinAttachmentName, attachment);
				}
			}
		}
	}

	/* Linked meshes. */
	for (i = 0; i < internal->linkedMeshCount; i++) {
		sp34Attachment* parent;
		_sp34LinkedMesh* linkedMesh = internal->linkedMeshes + i;
		sp34Skin* skin = !linkedMesh->skin ? skeletonData->defaultSkin : sp34SkeletonData_findSkin(skeletonData, linkedMesh->skin);
		if (!skin) {
			sp34SkeletonData_dispose(skeletonData);
			_sp34SkeletonJson_setError(self, 0, "Skin not found: ", linkedMesh->skin);
			return 0;
		}
		parent = sp34Skin_getAttachment(skin, linkedMesh->slotIndex, linkedMesh->parent);
		if (!parent) {
			sp34SkeletonData_dispose(skeletonData);
			_sp34SkeletonJson_setError(self, 0, "Parent mesh not found: ", linkedMesh->parent);
			return 0;
		}
		sp34MeshAttachment_setParentMesh(linkedMesh->mesh, SUB_CAST(sp34MeshAttachment, parent));
		sp34MeshAttachment_updateUVs(linkedMesh->mesh);
		sp34AttachmentLoader_configureAttachment(self->attachmentLoader, SUPER(SUPER(linkedMesh->mesh)));
	}

	/* Events. */
	events = Json34_getItem(root, "events");
	if (events) {
		Json34 *eventMap;
		const char* stringValue;
		skeletonData->eventsCount = events->size;
		skeletonData->events = MALLOC(sp34EventData*, events->size);
		for (eventMap = events->child, i = 0; eventMap; eventMap = eventMap->next, ++i) {
			sp34EventData* eventData = sp34EventData_create(eventMap->name);
			eventData->intValue = Json34_getInt(eventMap, "int", 0);
			eventData->floatValue = Json34_getFloat(eventMap, "float", 0);
			stringValue = Json34_getString(eventMap, "string", 0);
			if (stringValue) MALLOC_STR(eventData->stringValue, stringValue);
			skeletonData->events[i] = eventData;
		}
	}

	/* Animations. */
	animations = Json34_getItem(root, "animations");
	if (animations) {
		Json34 *animationMap;
		skeletonData->animations = MALLOC(sp34Animation*, animations->size);
		for (animationMap = animations->child; animationMap; animationMap = animationMap->next) {
			sp34Animation* animation = _sp34SkeletonJson_readAnimation(self, animationMap, skeletonData);
			if (!animation) {
				sp34SkeletonData_dispose(skeletonData);
				return 0;
			}
			skeletonData->animations[skeletonData->animationsCount++] = animation;
		}
	}

	Json34_dispose(root);
	return skeletonData;
}

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

#include "Json.h"
#include <spine/Version.h>
#include <spine/Array.h>
#include <spine/AtlasAttachmentLoader.h>
#include <spine/SkeletonJson.h>
#include <spine/extension.h>
#include <stdio.h>

typedef struct {
	const char *parent;
	const char *skin;
	int slotIndex;
	sp41MeshAttachment *mesh;
	int inheritTimeline;
} _sp41LinkedMesh;

typedef struct {
	sp41SkeletonJson super;
	int ownsLoader;

	int linkedMeshCount;
	int linkedMeshCapacity;
	_sp41LinkedMesh *linkedMeshes;
} _sp41SkeletonJson;

sp41SkeletonJson *sp41SkeletonJson_createWithLoader(sp41AttachmentLoader *attachmentLoader) {
	sp41SkeletonJson *self = SUPER(NEW(_sp41SkeletonJson));
	self->scale = 1;
	self->attachmentLoader = attachmentLoader;
	return self;
}

sp41SkeletonJson *sp41SkeletonJson_create(sp41Atlas *atlas) {
	sp41AtlasAttachmentLoader *attachmentLoader = sp41AtlasAttachmentLoader_create(atlas);
	sp41SkeletonJson *self = sp41SkeletonJson_createWithLoader(SUPER(attachmentLoader));
	SUB_CAST(_sp41SkeletonJson, self)->ownsLoader = 1;
	return self;
}

void sp41SkeletonJson_dispose(sp41SkeletonJson *self) {
	_sp41SkeletonJson *internal = SUB_CAST(_sp41SkeletonJson, self);
	if (internal->ownsLoader) sp41AttachmentLoader_dispose(self->attachmentLoader);
	FREE(internal->linkedMeshes);
	FREE(self->error);
	FREE(self);
}

void _sp41SkeletonJson_setError(sp41SkeletonJson *self, Json41 *root, const char *value1, const char *value2) {
	char message[256];
	int length;
	FREE(self->error);
	strcpy(message, value1);
	length = (int) strlen(value1);
	if (value2) strncat(message + length, value2, 255 - length);
	MALLOC_STR(self->error, message);
	if (root) Json41_dispose(root);
}

static float toColor(const char *value, int index) {
	char digits[3];
	char *error;
	int color;

	if ((size_t) index >= strlen(value) / 2) return -1;
	value += index * 2;

	digits[0] = *value;
	digits[1] = *(value + 1);
	digits[2] = '\0';
	color = (int) strtoul(digits, &error, 16);
	if (*error != 0) return -1;
	return color / (float) 255;
}

static void toColor2(sp41Color *color, const char *value, int /*bool*/ hasAlpha) {
	color->r = toColor(value, 0);
	color->g = toColor(value, 1);
	color->b = toColor(value, 2);
	if (hasAlpha) color->a = toColor(value, 3);
}

static void
setBezier(sp41CurveTimeline *timeline, int frame, int value, int bezier, float time1, float value1, float cx1, float cy1,
		  float cx2, float cy2, float time2, float value2) {
	sp41Timeline_setBezier(SUPER(timeline), bezier, frame, value, time1, value1, cx1, cy1, cx2, cy2, time2, value2);
}

static int readCurve(Json41 *curve, sp41CurveTimeline *timeline, int bezier, int frame, int value, float time1, float time2,
					 float value1, float value2, float scale) {
	float cx1, cy1, cx2, cy2;
	if (curve->type == Json41_String && strcmp(curve->valueString, "stepped") == 0) {
		if (value != 0) sp41CurveTimeline_setStepped(timeline, frame);
		return bezier;
	}
	curve = Json41_getItemAtIndex(curve, value << 2);
	cx1 = curve->valueFloat;
	curve = curve->next;
	cy1 = curve->valueFloat * scale;
	curve = curve->next;
	cx2 = curve->valueFloat;
	curve = curve->next;
	cy2 = curve->valueFloat * scale;
	setBezier(timeline, frame, value, bezier, time1, value1, cx1, cy1, cx2, cy2, time2, value2);
	return bezier + 1;
}

static sp41Timeline *readTimeline(Json41 *keyMap, sp41CurveTimeline1 *timeline, float defaultValue, float scale) {
	float time = Json41_getFloat(keyMap, "time", 0);
	float value = Json41_getFloat(keyMap, "value", defaultValue) * scale;
	int frame, bezier = 0;
	for (frame = 0;; ++frame) {
		Json41 *nextMap, *curve;
		float time2, value2;
		sp41CurveTimeline1_setFrame(timeline, frame, time, value);
		nextMap = keyMap->next;
		if (nextMap == NULL) break;
		time2 = Json41_getFloat(nextMap, "time", 0);
		value2 = Json41_getFloat(nextMap, "value", defaultValue) * scale;
		curve = Json41_getItem(keyMap, "curve");
		if (curve != NULL) bezier = readCurve(curve, timeline, bezier, frame, 0, time, time2, value, value2, scale);
		time = time2;
		value = value2;
		keyMap = nextMap;
	}
	/* timeline.shrink(); // BOZO */
	return SUPER(timeline);
}

static sp41Timeline *
readTimeline2(Json41 *keyMap, sp41CurveTimeline2 *timeline, const char *name1, const char *name2, float defaultValue,
			  float scale) {
	float time = Json41_getFloat(keyMap, "time", 0);
	float value1 = Json41_getFloat(keyMap, name1, defaultValue) * scale;
	float value2 = Json41_getFloat(keyMap, name2, defaultValue) * scale;
	int frame, bezier = 0;
	for (frame = 0;; ++frame) {
		Json41 *nextMap, *curve;
		float time2, nvalue1, nvalue2;
		sp41CurveTimeline2_setFrame(timeline, frame, time, value1, value2);
		nextMap = keyMap->next;
		if (nextMap == NULL) break;
		time2 = Json41_getFloat(nextMap, "time", 0);
		nvalue1 = Json41_getFloat(nextMap, name1, defaultValue) * scale;
		nvalue2 = Json41_getFloat(nextMap, name2, defaultValue) * scale;
		curve = Json41_getItem(keyMap, "curve");
		if (curve != NULL) {
			bezier = readCurve(curve, timeline, bezier, frame, 0, time, time2, value1, nvalue1, scale);
			bezier = readCurve(curve, timeline, bezier, frame, 1, time, time2, value2, nvalue2, scale);
		}
		time = time2;
		value1 = nvalue1;
		value2 = nvalue2;
		keyMap = nextMap;
	}
	/* timeline.shrink(); // BOZO */
	return SUPER(timeline);
}

static sp41Sequence *readSequence(Json41 *item) {
	sp41Sequence *sequence;
	if (item == NULL) return NULL;
	sequence = sp41Sequence_create(Json41_getInt(item, "count", 0));
	sequence->start = Json41_getInt(item, "start", 1);
	sequence->digits = Json41_getInt(item, "digits", 0);
	sequence->setupIndex = Json41_getInt(item, "setupIndex", 0);
	return sequence;
}

static void _sp41SkeletonJson_addLinkedMesh(sp41SkeletonJson *self, sp41MeshAttachment *mesh, const char *skin, int slotIndex,
										  const char *parent, int inheritDeform) {
	_sp41LinkedMesh *linkedMesh;
	_sp41SkeletonJson *internal = SUB_CAST(_sp41SkeletonJson, self);

	if (internal->linkedMeshCount == internal->linkedMeshCapacity) {
		_sp41LinkedMesh *linkedMeshes;
		internal->linkedMeshCapacity *= 2;
		if (internal->linkedMeshCapacity < 8) internal->linkedMeshCapacity = 8;
		linkedMeshes = MALLOC(_sp41LinkedMesh, internal->linkedMeshCapacity);
		memcpy(linkedMeshes, internal->linkedMeshes, sizeof(_sp41LinkedMesh) * internal->linkedMeshCount);
		FREE(internal->linkedMeshes);
		internal->linkedMeshes = linkedMeshes;
	}

	linkedMesh = internal->linkedMeshes + internal->linkedMeshCount++;
	linkedMesh->mesh = mesh;
	linkedMesh->skin = skin;
	linkedMesh->slotIndex = slotIndex;
	linkedMesh->parent = parent;
	linkedMesh->inheritTimeline = inheritDeform;
}

static void cleanUpTimelines(sp41TimelineArray *timelines) {
	int i, n;
	for (i = 0, n = timelines->size; i < n; ++i)
		sp41Timeline_dispose(timelines->items[i]);
	sp41TimelineArray_dispose(timelines);
}

static int findSlotIndex(sp41SkeletonJson *json, const sp41SkeletonData *skeletonData, const char *slotName, sp41TimelineArray *timelines) {
	sp41SlotData *slot = sp41SkeletonData_findSlot(skeletonData, slotName);
	if (slot) return slot->index;
	cleanUpTimelines(timelines);
	_sp41SkeletonJson_setError(json, NULL, "Slot not found: ", slotName);
	return -1;
}

static int findIkConstraintIndex(sp41SkeletonJson *json, const sp41SkeletonData *skeletonData, const sp41IkConstraintData *constraint, sp41TimelineArray *timelines) {
	if (constraint) {
		int i;
		for (i = 0; i < skeletonData->ikConstraintsCount; ++i)
			if (skeletonData->ikConstraints[i] == constraint) return i;
	}
	cleanUpTimelines(timelines);
	_sp41SkeletonJson_setError(json, NULL, "IK constraint not found: ", constraint->name);
	return -1;
}

static int findTransformConstraintIndex(sp41SkeletonJson *json, const sp41SkeletonData *skeletonData, const sp41TransformConstraintData *constraint, sp41TimelineArray *timelines) {
	if (constraint) {
		int i;
		for (i = 0; i < skeletonData->transformConstraintsCount; ++i)
			if (skeletonData->transformConstraints[i] == constraint) return i;
	}
	cleanUpTimelines(timelines);
	_sp41SkeletonJson_setError(json, NULL, "Transform constraint not found: ", constraint->name);
	return -1;
}

static int findPathConstraintIndex(sp41SkeletonJson *json, const sp41SkeletonData *skeletonData, const sp41PathConstraintData *constraint, sp41TimelineArray *timelines) {
	if (constraint) {
		int i;
		for (i = 0; i < skeletonData->pathConstraintsCount; ++i)
			if (skeletonData->pathConstraints[i] == constraint) return i;
	}
	cleanUpTimelines(timelines);
	_sp41SkeletonJson_setError(json, NULL, "Path constraint not found: ", constraint->name);
	return -1;
}

static sp41Animation *_sp41SkeletonJson_readAnimation(sp41SkeletonJson *self, Json41 *root, sp41SkeletonData *skeletonData) {
	sp41TimelineArray *timelines = sp41TimelineArray_create(8);

	float scale = self->scale, duration;
	Json41 *bones = Json41_getItem(root, "bones");
	Json41 *slots = Json41_getItem(root, "slots");
	Json41 *ik = Json41_getItem(root, "ik");
	Json41 *transform = Json41_getItem(root, "transform");
	Json41 *paths = Json41_getItem(root, "path");
	Json41 *attachmentsJson = Json41_getItem(root, "attachments");
	Json41 *drawOrderJson = Json41_getItem(root, "drawOrder");
	Json41 *events = Json41_getItem(root, "events");
	Json41 *boneMap, *slotMap, *keyMap, *nextMap, *curve, *timelineMap;
	Json41 *attachmentsMap, *constraintMap;
	int frame, bezier, i, n;
	sp41Color color, color2, newColor, newColor2;

	/* Slot timelines. */
	for (slotMap = slots ? slots->child : 0; slotMap; slotMap = slotMap->next) {
		int slotIndex = findSlotIndex(self, skeletonData, slotMap->name, timelines);
		if (slotIndex == -1) return NULL;

		for (timelineMap = slotMap->child; timelineMap; timelineMap = timelineMap->next) {
			int frames = timelineMap->size;
			if (strcmp(timelineMap->name, "attachment") == 0) {
				sp41AttachmentTimeline *timeline = sp41AttachmentTimeline_create(frames, slotIndex);
				for (keyMap = timelineMap->child, frame = 0; keyMap; keyMap = keyMap->next, ++frame) {
					sp41AttachmentTimeline_setFrame(timeline, frame, Json41_getFloat(keyMap, "time", 0),
												  Json41_getItem(keyMap, "name") ? Json41_getItem(keyMap, "name")->valueString : NULL);
				}
				sp41TimelineArray_add(timelines, SUPER(timeline));

			} else if (strcmp(timelineMap->name, "rgba") == 0) {
				float time;
				sp41RGBATimeline *timeline = sp41RGBATimeline_create(frames, frames << 2, slotIndex);
				keyMap = timelineMap->child;
				time = Json41_getFloat(keyMap, "time", 0);
				toColor2(&color, Json41_getString(keyMap, "color", 0), 1);

				for (frame = 0, bezier = 0;; ++frame) {
					float time2;
					sp41RGBATimeline_setFrame(timeline, frame, time, color.r, color.g, color.b, color.a);
					nextMap = keyMap->next;
					if (!nextMap) {
						/* timeline.shrink(); // BOZO */
						break;
					}
					time2 = Json41_getFloat(nextMap, "time", 0);
					toColor2(&newColor, Json41_getString(nextMap, "color", 0), 1);
					curve = Json41_getItem(keyMap, "curve");
					if (curve) {
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 0, time, time2, color.r, newColor.r,
										   1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 1, time, time2, color.g, newColor.g,
										   1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 2, time, time2, color.b, newColor.b,
										   1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 3, time, time2, color.a, newColor.a,
										   1);
					}
					time = time2;
					color = newColor;
					keyMap = nextMap;
				}
				sp41TimelineArray_add(timelines, SUPER(SUPER(timeline)));
			} else if (strcmp(timelineMap->name, "rgb") == 0) {
				float time;
				sp41RGBTimeline *timeline = sp41RGBTimeline_create(frames, frames * 3, slotIndex);
				keyMap = timelineMap->child;
				time = Json41_getFloat(keyMap, "time", 0);
				toColor2(&color, Json41_getString(keyMap, "color", 0), 1);

				for (frame = 0, bezier = 0;; ++frame) {
					float time2;
					sp41RGBTimeline_setFrame(timeline, frame, time, color.r, color.g, color.b);
					nextMap = keyMap->next;
					if (!nextMap) {
						/* timeline.shrink(); // BOZO */
						break;
					}
					time2 = Json41_getFloat(nextMap, "time", 0);
					toColor2(&newColor, Json41_getString(nextMap, "color", 0), 1);
					curve = Json41_getItem(keyMap, "curve");
					if (curve) {
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 0, time, time2, color.r, newColor.r,
										   1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 1, time, time2, color.g, newColor.g,
										   1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 2, time, time2, color.b, newColor.b,
										   1);
					}
					time = time2;
					color = newColor;
					keyMap = nextMap;
				}
				sp41TimelineArray_add(timelines, SUPER(SUPER(timeline)));
			} else if (strcmp(timelineMap->name, "alpha") == 0) {
				sp41TimelineArray_add(timelines, readTimeline(timelineMap->child,
															SUPER(sp41AlphaTimeline_create(frames,
																						 frames, slotIndex)),
															0, 1));
			} else if (strcmp(timelineMap->name, "rgba2") == 0) {
				float time;
				sp41RGBA2Timeline *timeline = sp41RGBA2Timeline_create(frames, frames * 7, slotIndex);
				keyMap = timelineMap->child;
				time = Json41_getFloat(keyMap, "time", 0);
				toColor2(&color, Json41_getString(keyMap, "light", 0), 1);
				toColor2(&color2, Json41_getString(keyMap, "dark", 0), 0);

				for (frame = 0, bezier = 0;; ++frame) {
					float time2;
					sp41RGBA2Timeline_setFrame(timeline, frame, time, color.r, color.g, color.b, color.a, color2.g,
											 color2.g, color2.b);
					nextMap = keyMap->next;
					if (!nextMap) {
						/* timeline.shrink(); // BOZO */
						break;
					}
					time2 = Json41_getFloat(nextMap, "time", 0);
					toColor2(&newColor, Json41_getString(nextMap, "light", 0), 1);
					toColor2(&newColor2, Json41_getString(nextMap, "dark", 0), 0);
					curve = Json41_getItem(keyMap, "curve");
					if (curve) {
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 0, time, time2, color.r, newColor.r,
										   1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 1, time, time2, color.g, newColor.g,
										   1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 2, time, time2, color.b, newColor.b,
										   1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 3, time, time2, color.a, newColor.a,
										   1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 4, time, time2, color2.r, newColor2.r,
										   1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 5, time, time2, color2.g, newColor2.g,
										   1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 6, time, time2, color2.b, newColor2.b,
										   1);
					}
					time = time2;
					color = newColor;
					color2 = newColor2;
					keyMap = nextMap;
				}
				sp41TimelineArray_add(timelines, SUPER(SUPER(timeline)));
			} else if (strcmp(timelineMap->name, "rgb2") == 0) {
				float time;
				sp41RGBA2Timeline *timeline = sp41RGBA2Timeline_create(frames, frames * 6, slotIndex);
				keyMap = timelineMap->child;
				time = Json41_getFloat(keyMap, "time", 0);
				toColor2(&color, Json41_getString(keyMap, "light", 0), 0);
				toColor2(&color2, Json41_getString(keyMap, "dark", 0), 0);

				for (frame = 0, bezier = 0;; ++frame) {
					float time2;
					sp41RGBA2Timeline_setFrame(timeline, frame, time, color.r, color.g, color.b, color.a, color2.r,
											 color2.g, color2.b);
					nextMap = keyMap->next;
					if (!nextMap) {
						/* timeline.shrink(); // BOZO */
						break;
					}
					time2 = Json41_getFloat(nextMap, "time", 0);
					toColor2(&newColor, Json41_getString(nextMap, "light", 0), 0);
					toColor2(&newColor2, Json41_getString(nextMap, "dark", 0), 0);
					curve = Json41_getItem(keyMap, "curve");
					if (curve) {
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 0, time, time2, color.r, newColor.r,
										   1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 1, time, time2, color.g, newColor.g,
										   1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 2, time, time2, color.b, newColor.b,
										   1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 3, time, time2, color2.r, newColor2.r,
										   1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 4, time, time2, color2.g, newColor2.g,
										   1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 5, time, time2, color2.b, newColor2.b,
										   1);
					}
					time = time2;
					color = newColor;
					color2 = newColor2;
					keyMap = nextMap;
				}
				sp41TimelineArray_add(timelines, SUPER(SUPER(timeline)));
			} else {
				cleanUpTimelines(timelines);
				_sp41SkeletonJson_setError(self, NULL, "Invalid timeline type for a slot: ", timelineMap->name);
				return NULL;
			}
		}
	}

	/* Bone timelines. */
	for (boneMap = bones ? bones->child : 0; boneMap; boneMap = boneMap->next) {
		int boneIndex = -1;
		for (i = 0; i < skeletonData->bonesCount; ++i) {
			if (strcmp(skeletonData->bones[i]->name, boneMap->name) == 0) {
				boneIndex = i;
				break;
			}
		}
		if (boneIndex == -1) {
			cleanUpTimelines(timelines);
			_sp41SkeletonJson_setError(self, NULL, "Bone not found: ", boneMap->name);
			return NULL;
		}

		for (timelineMap = boneMap->child; timelineMap; timelineMap = timelineMap->next) {
			int frames = timelineMap->size;
			if (frames == 0) continue;

			if (strcmp(timelineMap->name, "rotate") == 0) {
				sp41TimelineArray_add(timelines, readTimeline(timelineMap->child,
															SUPER(sp41RotateTimeline_create(frames,
																						  frames,
																						  boneIndex)),
															0, 1));
			} else if (strcmp(timelineMap->name, "translate") == 0) {
				sp41TranslateTimeline *timeline = sp41TranslateTimeline_create(frames, frames << 1,
																		   boneIndex);
				sp41TimelineArray_add(timelines, readTimeline2(timelineMap->child, SUPER(timeline), "x", "y", 0, scale));
			} else if (strcmp(timelineMap->name, "translatex") == 0) {
				sp41TranslateXTimeline *timeline = sp41TranslateXTimeline_create(frames, frames,
																			 boneIndex);
				sp41TimelineArray_add(timelines, readTimeline(timelineMap->child, SUPER(timeline), 0, scale));
			} else if (strcmp(timelineMap->name, "translatey") == 0) {
				sp41TranslateYTimeline *timeline = sp41TranslateYTimeline_create(frames, frames,
																			 boneIndex);
				sp41TimelineArray_add(timelines, readTimeline(timelineMap->child, SUPER(timeline), 0, scale));
			} else if (strcmp(timelineMap->name, "scale") == 0) {
				sp41ScaleTimeline *timeline = sp41ScaleTimeline_create(frames, frames << 1,
																   boneIndex);
				sp41TimelineArray_add(timelines, readTimeline2(timelineMap->child, SUPER(timeline), "x", "y", 1, 1));
			} else if (strcmp(timelineMap->name, "scalex") == 0) {
				sp41ScaleXTimeline *timeline = sp41ScaleXTimeline_create(frames, frames, boneIndex);
				sp41TimelineArray_add(timelines, readTimeline(timelineMap->child, SUPER(timeline), 1, 1));
			} else if (strcmp(timelineMap->name, "scaley") == 0) {
				sp41ScaleYTimeline *timeline = sp41ScaleYTimeline_create(frames, frames, boneIndex);
				sp41TimelineArray_add(timelines, readTimeline(timelineMap->child, SUPER(timeline), 1, 1));
			} else if (strcmp(timelineMap->name, "shear") == 0) {
				sp41ShearTimeline *timeline = sp41ShearTimeline_create(frames, frames << 1,
																   boneIndex);
				sp41TimelineArray_add(timelines, readTimeline2(timelineMap->child, SUPER(timeline), "x", "y", 0, 1));
			} else if (strcmp(timelineMap->name, "shearx") == 0) {
				sp41ShearXTimeline *timeline = sp41ShearXTimeline_create(frames, frames, boneIndex);
				sp41TimelineArray_add(timelines, readTimeline(timelineMap->child, SUPER(timeline), 0, 1));
			} else if (strcmp(timelineMap->name, "sheary") == 0) {
				sp41ShearYTimeline *timeline = sp41ShearYTimeline_create(frames, frames, boneIndex);
				sp41TimelineArray_add(timelines, readTimeline(timelineMap->child, SUPER(timeline), 0, 1));
			} else {
				cleanUpTimelines(timelines);
				_sp41SkeletonJson_setError(self, NULL, "Invalid timeline type for a bone: ", timelineMap->name);
				return NULL;
			}
		}
	}

	/* IK constraint timelines. */
	for (constraintMap = ik ? ik->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp41IkConstraintData *constraint;
		sp41IkConstraintTimeline *timeline;
		int constraintIndex;
		float time, mix, softness;
		keyMap = constraintMap->child;
		if (keyMap == NULL) continue;

		constraint = sp41SkeletonData_findIkConstraint(skeletonData, constraintMap->name);
		constraintIndex = findIkConstraintIndex(self, skeletonData, constraint, timelines);
		if (constraintIndex == -1) return NULL;
		timeline = sp41IkConstraintTimeline_create(constraintMap->size, constraintMap->size << 1, constraintIndex);

		time = Json41_getFloat(keyMap, "time", 0);
		mix = Json41_getFloat(keyMap, "mix", 1);
		softness = Json41_getFloat(keyMap, "softness", 0) * scale;

		for (frame = 0, bezier = 0;; ++frame) {
			float time2, mix2, softness2;
			int bendDirection = Json41_getInt(keyMap, "bendPositive", 1) ? 1 : -1;
			sp41IkConstraintTimeline_setFrame(timeline, frame, time, mix, softness, bendDirection,
											Json41_getInt(keyMap, "compress", 0) ? 1 : 0,
											Json41_getInt(keyMap, "stretch", 0) ? 1 : 0);
			nextMap = keyMap->next;
			if (!nextMap) {
				/* timeline.shrink(); // BOZO */
				break;
			}

			time2 = Json41_getFloat(nextMap, "time", 0);
			mix2 = Json41_getFloat(nextMap, "mix", 1);
			softness2 = Json41_getFloat(nextMap, "softness", 0) * scale;
			curve = Json41_getItem(keyMap, "curve");
			if (curve) {
				bezier = readCurve(curve, SUPER(timeline), bezier, frame, 0, time, time2, mix, mix2, 1);
				bezier = readCurve(curve, SUPER(timeline), bezier, frame, 1, time, time2, softness, softness2, scale);
			}

			time = time2;
			mix = mix2;
			softness = softness2;
			keyMap = nextMap;
		}

		sp41TimelineArray_add(timelines, SUPER(SUPER(timeline)));
	}

	/* Transform constraint timelines. */
	for (constraintMap = transform ? transform->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp41TransformConstraintData *constraint;
		sp41TransformConstraintTimeline *timeline;
		int constraintIndex;
		float time, mixRotate, mixShearY, mixX, mixY, mixScaleX, mixScaleY;
		keyMap = constraintMap->child;
		if (keyMap == NULL) continue;

		constraint = sp41SkeletonData_findTransformConstraint(skeletonData, constraintMap->name);
		constraintIndex = findTransformConstraintIndex(self, skeletonData, constraint, timelines);
		if (constraintIndex == -1) return NULL;
		timeline = sp41TransformConstraintTimeline_create(constraintMap->size, constraintMap->size * 6, constraintIndex);

		time = Json41_getFloat(keyMap, "time", 0);
		mixRotate = Json41_getFloat(keyMap, "mixRotate", 1);
		mixShearY = Json41_getFloat(keyMap, "mixShearY", 1);
		mixX = Json41_getFloat(keyMap, "mixX", 1);
		mixY = Json41_getFloat(keyMap, "mixY", mixX);
		mixScaleX = Json41_getFloat(keyMap, "mixScaleX", 1);
		mixScaleY = Json41_getFloat(keyMap, "mixScaleY", mixScaleX);

		for (frame = 0, bezier = 0;; ++frame) {
			float time2, mixRotate2, mixShearY2, mixX2, mixY2, mixScaleX2, mixScaleY2;
			sp41TransformConstraintTimeline_setFrame(timeline, frame, time, mixRotate, mixX, mixY, mixScaleX, mixScaleY,
												   mixShearY);
			nextMap = keyMap->next;
			if (!nextMap) {
				/* timeline.shrink(); // BOZO */
				break;
			}

			time2 = Json41_getFloat(nextMap, "time", 0);
			mixRotate2 = Json41_getFloat(nextMap, "mixRotate", 1);
			mixShearY2 = Json41_getFloat(nextMap, "mixShearY", 1);
			mixX2 = Json41_getFloat(nextMap, "mixX", 1);
			mixY2 = Json41_getFloat(nextMap, "mixY", mixX2);
			mixScaleX2 = Json41_getFloat(nextMap, "mixScaleX", 1);
			mixScaleY2 = Json41_getFloat(nextMap, "mixScaleY", mixScaleX2);
			curve = Json41_getItem(keyMap, "curve");
			if (curve) {
				bezier = readCurve(curve, SUPER(timeline), bezier, frame, 0, time, time2, mixRotate, mixRotate2, 1);
				bezier = readCurve(curve, SUPER(timeline), bezier, frame, 1, time, time2, mixX, mixX2, 1);
				bezier = readCurve(curve, SUPER(timeline), bezier, frame, 2, time, time2, mixY, mixY2, 1);
				bezier = readCurve(curve, SUPER(timeline), bezier, frame, 3, time, time2, mixScaleX, mixScaleX2, 1);
				bezier = readCurve(curve, SUPER(timeline), bezier, frame, 4, time, time2, mixScaleY, mixScaleY2, 1);
				bezier = readCurve(curve, SUPER(timeline), bezier, frame, 5, time, time2, mixShearY, mixShearY2, 1);
			}

			time = time2;
			mixRotate = mixRotate2;
			mixX = mixX2;
			mixY = mixY2;
			mixScaleX = mixScaleX2;
			mixScaleY = mixScaleY2;
			mixScaleX = mixScaleX2;
			keyMap = nextMap;
		}

		sp41TimelineArray_add(timelines, SUPER(SUPER(timeline)));
	}

	/** Path constraint timelines. */
	for (constraintMap = paths ? paths->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp41PathConstraintData *constraint = sp41SkeletonData_findPathConstraint(skeletonData, constraintMap->name);
		int constraintIndex = findPathConstraintIndex(self, skeletonData, constraint, timelines);
		if (constraintIndex == -1) return NULL;
		for (timelineMap = constraintMap->child; timelineMap; timelineMap = timelineMap->next) {
			const char *timelineName;
			int frames;
			keyMap = timelineMap->child;
			if (keyMap == NULL) continue;
			frames = timelineMap->size;
			timelineName = timelineMap->name;
			if (strcmp(timelineName, "position") == 0) {
				sp41PathConstraintPositionTimeline *timeline = sp41PathConstraintPositionTimeline_create(frames,
																									 frames,
																									 constraintIndex);
				sp41TimelineArray_add(timelines, readTimeline(keyMap, SUPER(timeline), 0,
															constraint->positionMode == SP_POSITION_MODE_FIXED ? scale : 1));
			} else if (strcmp(timelineName, "spacing") == 0) {
				sp41CurveTimeline1 *timeline = SUPER(
						sp41PathConstraintSpacingTimeline_create(frames, frames, constraintIndex));
				sp41TimelineArray_add(timelines, readTimeline(keyMap, timeline, 0,
															constraint->spacingMode == SP_SPACING_MODE_LENGTH ||
																			constraint->spacingMode == SP_SPACING_MODE_FIXED
																	? scale
																	: 1));
			} else if (strcmp(timelineName, "mix") == 0) {
				sp41PathConstraintMixTimeline *timeline = sp41PathConstraintMixTimeline_create(frames,
																						   frames * 3,
																						   constraintIndex);
				float time = Json41_getFloat(keyMap, "time", 0);
				float mixRotate = Json41_getFloat(keyMap, "mixRotate", 1);
				float mixX = Json41_getFloat(keyMap, "mixX", 1);
				float mixY = Json41_getFloat(keyMap, "mixY", mixX);
				for (frame = 0, bezier = 0;; ++frame) {
					float time2, mixRotate2, mixX2, mixY2;
					sp41PathConstraintMixTimeline_setFrame(timeline, frame, time, mixRotate, mixX, mixY);
					nextMap = keyMap->next;
					if (!nextMap) {
						/* timeline.shrink(); // BOZO */
						break;
					}

					time2 = Json41_getFloat(nextMap, "time", 0);
					mixRotate2 = Json41_getFloat(nextMap, "mixRotate", 1);
					mixX2 = Json41_getFloat(nextMap, "mixX", 1);
					mixY2 = Json41_getFloat(nextMap, "mixY", mixX2);
					curve = Json41_getItem(keyMap, "curve");
					if (curve != NULL) {
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 0, time, time2, mixRotate, mixRotate2,
										   1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 1, time, time2, mixX, mixX2, 1);
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 2, time, time2, mixY, mixY2, 1);
					}
					time = time2;
					mixRotate = mixRotate2;
					mixX = mixX2;
					mixY = mixY2;
					keyMap = nextMap;
				}
				sp41TimelineArray_add(timelines, SUPER(SUPER(timeline)));
			}
		}
	}

	/* Attachment timelines. */
	for (attachmentsMap = attachmentsJson ? attachmentsJson->child : 0; attachmentsMap; attachmentsMap = attachmentsMap->next) {
		sp41Skin *skin = sp41SkeletonData_findSkin(skeletonData, attachmentsMap->name);
		for (slotMap = attachmentsMap->child; slotMap; slotMap = slotMap->next) {
			Json41 *attachmentMap;
			int slotIndex = findSlotIndex(self, skeletonData, slotMap->name, timelines);
			if (slotIndex == -1) return NULL;

			for (attachmentMap = slotMap->child; attachmentMap; attachmentMap = attachmentMap->next) {
				sp41Attachment *baseAttachment = sp41Skin_getAttachment(skin, slotIndex, attachmentMap->name);
				if (!baseAttachment) {
					cleanUpTimelines(timelines);
					_sp41SkeletonJson_setError(self, 0, "Attachment not found: ", attachmentMap->name);
					return NULL;
				}

				for (timelineMap = attachmentMap->child; timelineMap; timelineMap = timelineMap->next) {
					int frames;
					const char *timelineName;
					keyMap = timelineMap->child;
					if (keyMap == NULL) continue;
					frames = timelineMap->size;
					timelineName = timelineMap->name;
					if (!strcmp("deform", timelineName)) {
						float *tempDeform;
						sp41VertexAttachment *vertexAttachment;
						int weighted, deformLength;
						sp41DeformTimeline *timeline;
						float time;

						vertexAttachment = SUB_CAST(sp41VertexAttachment, baseAttachment);
						weighted = vertexAttachment->bones != 0;
						deformLength = weighted ? vertexAttachment->verticesCount / 3 * 2 : vertexAttachment->verticesCount;
						tempDeform = MALLOC(float, deformLength);

						timeline = sp41DeformTimeline_create(timelineMap->size, deformLength, timelineMap->size,
														   slotIndex,
														   vertexAttachment);

						time = Json41_getFloat(keyMap, "time", 0);
						for (frame = 0, bezier = 0;; ++frame) {
							Json41 *vertices = Json41_getItem(keyMap, "vertices");
							float *deform;
							float time2;

							if (!vertices) {
								if (weighted) {
									deform = tempDeform;
									memset(deform, 0, sizeof(float) * deformLength);
								} else
									deform = vertexAttachment->vertices;
							} else {
								int v, start = Json41_getInt(keyMap, "offset", 0);
								Json41 *vertex;
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
									float *verticesValues = vertexAttachment->vertices;
									for (v = 0; v < deformLength; ++v)
										deform[v] += verticesValues[v];
								}
							}
							sp41DeformTimeline_setFrame(timeline, frame, time, deform);
							nextMap = keyMap->next;
							if (!nextMap) {
								/* timeline.shrink(); // BOZO */
								break;
							}
							time2 = Json41_getFloat(nextMap, "time", 0);
							curve = Json41_getItem(keyMap, "curve");
							if (curve) {
								bezier = readCurve(curve, SUPER(timeline), bezier, frame, 0, time, time2, 0, 1, 1);
							}
							time = time2;
							keyMap = nextMap;
						}
						FREE(tempDeform);

						sp41TimelineArray_add(timelines, SUPER(SUPER(timeline)));
					} else if (!strcmp(timelineName, "sequence")) {
						sp41SequenceTimeline *timeline = sp41SequenceTimeline_create(frames, slotIndex, baseAttachment);
						float lastDelay = 0;
						for (frame = 0; keyMap != NULL; keyMap = keyMap->next, frame++) {
							float delay = Json41_getFloat(keyMap, "delay", lastDelay);
							float time = Json41_getFloat(keyMap, "time", 0);
							const char *modeString = Json41_getString(keyMap, "mode", "hold");
							int index = Json41_getInt(keyMap, "index", 0);
							int mode = SP_SEQUENCE_MODE_HOLD;
							if (!strcmp(modeString, "once")) mode = SP_SEQUENCE_MODE_ONCE;
							if (!strcmp(modeString, "loop")) mode = SP_SEQUENCE_MODE_LOOP;
							if (!strcmp(modeString, "pingpong")) mode = SP_SEQUENCE_MODE_PINGPONG;
							if (!strcmp(modeString, "onceReverse")) mode = SP_SEQUENCE_MODE_ONCEREVERSE;
							if (!strcmp(modeString, "loopReverse")) mode = SP_SEQUENCE_MODE_LOOPREVERSE;
							if (!strcmp(modeString, "pingpongReverse")) mode = SP_SEQUENCE_MODE_PINGPONGREVERSE;
							sp41SequenceTimeline_setFrame(timeline, frame, time, mode, index, delay);
							lastDelay = delay;
						}
						sp41TimelineArray_add(timelines, SUPER(timeline));
					}
				}
			}
		}
	}

	/* Draw order timeline. */
	if (drawOrderJson) {
		sp41DrawOrderTimeline *timeline = sp41DrawOrderTimeline_create(drawOrderJson->size, skeletonData->slotsCount);
		for (keyMap = drawOrderJson->child, frame = 0; keyMap; keyMap = keyMap->next, ++frame) {
			int ii;
			int *drawOrder = 0;
			Json41 *offsets = Json41_getItem(keyMap, "offsets");
			if (offsets) {
				Json41 *offsetMap;
				int *unchanged = MALLOC(int, skeletonData->slotsCount - offsets->size);
				int originalIndex = 0, unchangedIndex = 0;

				drawOrder = MALLOC(int, skeletonData->slotsCount);
				for (ii = skeletonData->slotsCount - 1; ii >= 0; --ii)
					drawOrder[ii] = -1;

				for (offsetMap = offsets->child; offsetMap; offsetMap = offsetMap->next) {
					int slotIndex = findSlotIndex(self, skeletonData, Json41_getString(offsetMap, "slot", 0), timelines);
					if (slotIndex == -1) return NULL;

					/* Collect unchanged items. */
					while (originalIndex != slotIndex)
						unchanged[unchangedIndex++] = originalIndex++;
					/* Set changed items. */
					drawOrder[originalIndex + Json41_getInt(offsetMap, "offset", 0)] = originalIndex;
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
			sp41DrawOrderTimeline_setFrame(timeline, frame, Json41_getFloat(keyMap, "time", 0), drawOrder);
			FREE(drawOrder);
		}

		sp41TimelineArray_add(timelines, SUPER(timeline));
	}

	/* Event timeline. */
	if (events) {
		sp41EventTimeline *timeline = sp41EventTimeline_create(events->size);
		for (keyMap = events->child, frame = 0; keyMap; keyMap = keyMap->next, ++frame) {
			sp41Event *event;
			const char *stringValue;
			sp41EventData *eventData = sp41SkeletonData_findEvent(skeletonData, Json41_getString(keyMap, "name", 0));
			if (!eventData) {
				cleanUpTimelines(timelines);
				_sp41SkeletonJson_setError(self, 0, "Event not found: ", Json41_getString(keyMap, "name", 0));
				return NULL;
			}
			event = sp41Event_create(Json41_getFloat(keyMap, "time", 0), eventData);
			event->intValue = Json41_getInt(keyMap, "int", eventData->intValue);
			event->floatValue = Json41_getFloat(keyMap, "float", eventData->floatValue);
			stringValue = Json41_getString(keyMap, "string", eventData->stringValue);
			if (stringValue) MALLOC_STR(event->stringValue, stringValue);
			if (eventData->audioPath) {
				event->volume = Json41_getFloat(keyMap, "volume", 1);
				event->balance = Json41_getFloat(keyMap, "volume", 0);
			}
			sp41EventTimeline_setFrame(timeline, frame, event);
		}
		sp41TimelineArray_add(timelines, SUPER(timeline));
	}

	duration = 0;
	for (i = 0, n = timelines->size; i < n; ++i)
		duration = MAX(duration, sp41Timeline_getDuration(timelines->items[i]));
	return sp41Animation_create(root->name, timelines, duration);
}

static void
_readVertices(sp41SkeletonJson *self, Json41 *attachmentMap, sp41VertexAttachment *attachment, int verticesLength) {
	Json41 *entry;
	float *vertices;
	int i, n, nn, entrySize;
	sp41FloatArray *weights;
	sp41IntArray *bones;

	attachment->worldVerticesLength = verticesLength;

	entry = Json41_getItem(attachmentMap, "vertices");
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

	weights = sp41FloatArray_create(verticesLength * 3 * 3);
	bones = sp41IntArray_create(verticesLength * 3);

	for (i = 0, n = entrySize; i < n;) {
		int boneCount = (int) vertices[i++];
		sp41IntArray_add(bones, boneCount);
		for (nn = i + boneCount * 4; i < nn; i += 4) {
			sp41IntArray_add(bones, (int) vertices[i]);
			sp41FloatArray_add(weights, vertices[i + 1] * self->scale);
			sp41FloatArray_add(weights, vertices[i + 2] * self->scale);
			sp41FloatArray_add(weights, vertices[i + 3]);
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

sp41SkeletonData *sp41SkeletonJson_readSkeletonDataFile(sp41SkeletonJson *self, const char *path) {
	int length;
	sp41SkeletonData *skeletonData;
	const char *json = _sp41Util_readFile(path, &length);
	if (length == 0 || !json) {
		_sp41SkeletonJson_setError(self, 0, "Unable to read skeleton file: ", path);
		return NULL;
	}
	skeletonData = sp41SkeletonJson_readSkeletonData(self, json);
	FREE(json);
	return skeletonData;
}

static int string_starts_with(const char *str, const char *needle) {
	int lenStr, lenNeedle, i;
	if (!str) return 0;
	lenStr = (int) strlen(str);
	lenNeedle = (int) strlen(needle);
	if (lenStr < lenNeedle) return 0;
	for (i = 0; i < lenNeedle; i++) {
		if (str[i] != needle[i]) return 0;
	}
	return -1;
}

sp41SkeletonData *sp41SkeletonJson_readSkeletonData(sp41SkeletonJson *self, const char *json) {
	int i, ii;
	sp41SkeletonData *skeletonData;
	Json41 *root, *skeleton, *bones, *boneMap, *ik, *transform, *pathJson, *slots, *skins, *animations, *events;
	_sp41SkeletonJson *internal = SUB_CAST(_sp41SkeletonJson, self);

	FREE(self->error);
	CONST_CAST(char *, self->error) = 0;
	internal->linkedMeshCount = 0;

	root = Json41_create(json);
	if (!root) {
		_sp41SkeletonJson_setError(self, 0, "Invalid skeleton JSON: ", Json41_getError());
		return NULL;
	}

	skeletonData = sp41SkeletonData_create();

	skeleton = Json41_getItem(root, "skeleton");
	if (skeleton) {
		MALLOC_STR(skeletonData->hash, Json41_getString(skeleton, "hash", 0));
		MALLOC_STR(skeletonData->version, Json41_getString(skeleton, "spine", 0));
		if (!string_starts_with(skeletonData->version, SPINE_VERSION_STRING)) {
			char errorMsg[255];
			sprintf(errorMsg, "Skeleton version %s does not match runtime version %s", skeletonData->version, SPINE_VERSION_STRING);
			_sp41SkeletonJson_setError(self, 0, errorMsg, NULL);
			return NULL;
		}
		skeletonData->x = Json41_getFloat(skeleton, "x", 0);
		skeletonData->y = Json41_getFloat(skeleton, "y", 0);
		skeletonData->width = Json41_getFloat(skeleton, "width", 0);
		skeletonData->height = Json41_getFloat(skeleton, "height", 0);
		skeletonData->fps = Json41_getFloat(skeleton, "fps", 30);
		skeletonData->imagesPath = Json41_getString(skeleton, "images", 0);
		if (skeletonData->imagesPath) {
			char *tmp = NULL;
			MALLOC_STR(tmp, skeletonData->imagesPath);
			skeletonData->imagesPath = tmp;
		}
		skeletonData->audioPath = Json41_getString(skeleton, "audio", 0);
		if (skeletonData->audioPath) {
			char *tmp = NULL;
			MALLOC_STR(tmp, skeletonData->audioPath);
			skeletonData->audioPath = tmp;
		}
	}

	/* Bones. */
	bones = Json41_getItem(root, "bones");
	skeletonData->bones = MALLOC(sp41BoneData *, bones->size);
	for (boneMap = bones->child, i = 0; boneMap; boneMap = boneMap->next, ++i) {
		sp41BoneData *data;
		const char *transformMode;
		const char *color;

		sp41BoneData *parent = 0;
		const char *parentName = Json41_getString(boneMap, "parent", 0);
		if (parentName) {
			parent = sp41SkeletonData_findBone(skeletonData, parentName);
			if (!parent) {
				sp41SkeletonData_dispose(skeletonData);
				_sp41SkeletonJson_setError(self, root, "Parent bone not found: ", parentName);
				return NULL;
			}
		}

		data = sp41BoneData_create(skeletonData->bonesCount, Json41_getString(boneMap, "name", 0), parent);
		data->length = Json41_getFloat(boneMap, "length", 0) * self->scale;
		data->x = Json41_getFloat(boneMap, "x", 0) * self->scale;
		data->y = Json41_getFloat(boneMap, "y", 0) * self->scale;
		data->rotation = Json41_getFloat(boneMap, "rotation", 0);
		data->scaleX = Json41_getFloat(boneMap, "scaleX", 1);
		data->scaleY = Json41_getFloat(boneMap, "scaleY", 1);
		data->shearX = Json41_getFloat(boneMap, "shearX", 0);
		data->shearY = Json41_getFloat(boneMap, "shearY", 0);
		transformMode = Json41_getString(boneMap, "transform", "normal");
		data->transformMode = SP_TRANSFORMMODE_NORMAL;
		if (strcmp(transformMode, "normal") == 0) data->transformMode = SP_TRANSFORMMODE_NORMAL;
		else if (strcmp(transformMode, "onlyTranslation") == 0)
			data->transformMode = SP_TRANSFORMMODE_ONLYTRANSLATION;
		else if (strcmp(transformMode, "noRotationOrReflection") == 0)
			data->transformMode = SP_TRANSFORMMODE_NOROTATIONORREFLECTION;
		else if (strcmp(transformMode, "noScale") == 0)
			data->transformMode = SP_TRANSFORMMODE_NOSCALE;
		else if (strcmp(transformMode, "noScaleOrReflection") == 0)
			data->transformMode = SP_TRANSFORMMODE_NOSCALEORREFLECTION;
		data->skinRequired = Json41_getInt(boneMap, "skin", 0) ? 1 : 0;

		color = Json41_getString(boneMap, "color", 0);
		if (color) toColor2(&data->color, color, -1);

		skeletonData->bones[i] = data;
		skeletonData->bonesCount++;
	}

	/* Slots. */
	slots = Json41_getItem(root, "slots");
	if (slots) {
		Json41 *slotMap;
		skeletonData->slotsCount = slots->size;
		skeletonData->slots = MALLOC(sp41SlotData *, slots->size);
		for (slotMap = slots->child, i = 0; slotMap; slotMap = slotMap->next, ++i) {
			sp41SlotData *data;
			const char *color;
			const char *dark;
			Json41 *item;

			const char *boneName = Json41_getString(slotMap, "bone", 0);
			sp41BoneData *boneData = sp41SkeletonData_findBone(skeletonData, boneName);
			if (!boneData) {
				sp41SkeletonData_dispose(skeletonData);
				_sp41SkeletonJson_setError(self, root, "Slot bone not found: ", boneName);
				return NULL;
			}

			data = sp41SlotData_create(i, Json41_getString(slotMap, "name", 0), boneData);

			color = Json41_getString(slotMap, "color", 0);
			if (color) {
				sp41Color_setFromFloats(&data->color,
									  toColor(color, 0),
									  toColor(color, 1),
									  toColor(color, 2),
									  toColor(color, 3));
			}

			dark = Json41_getString(slotMap, "dark", 0);
			if (dark) {
				data->darkColor = sp41Color_create();
				sp41Color_setFromFloats(data->darkColor,
									  toColor(dark, 0),
									  toColor(dark, 1),
									  toColor(dark, 2),
									  toColor(dark, 3));
			}

			item = Json41_getItem(slotMap, "attachment");
			if (item) sp41SlotData_setAttachmentName(data, item->valueString);

			item = Json41_getItem(slotMap, "blend");
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
	ik = Json41_getItem(root, "ik");
	if (ik) {
		Json41 *constraintMap;
		skeletonData->ikConstraintsCount = ik->size;
		skeletonData->ikConstraints = MALLOC(sp41IkConstraintData *, ik->size);
		for (constraintMap = ik->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char *targetName;

			sp41IkConstraintData *data = sp41IkConstraintData_create(Json41_getString(constraintMap, "name", 0));
			data->order = Json41_getInt(constraintMap, "order", 0);
			data->skinRequired = Json41_getInt(constraintMap, "skin", 0) ? 1 : 0;

			boneMap = Json41_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			data->bones = MALLOC(sp41BoneData *, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp41SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp41SkeletonData_dispose(skeletonData);
					_sp41SkeletonJson_setError(self, root, "IK bone not found: ", boneMap->valueString);
					return NULL;
				}
			}

			targetName = Json41_getString(constraintMap, "target", 0);
			data->target = sp41SkeletonData_findBone(skeletonData, targetName);
			if (!data->target) {
				sp41SkeletonData_dispose(skeletonData);
				_sp41SkeletonJson_setError(self, root, "Target bone not found: ", targetName);
				return NULL;
			}

			data->bendDirection = Json41_getInt(constraintMap, "bendPositive", 1) ? 1 : -1;
			data->compress = Json41_getInt(constraintMap, "compress", 0) ? 1 : 0;
			data->stretch = Json41_getInt(constraintMap, "stretch", 0) ? 1 : 0;
			data->uniform = Json41_getInt(constraintMap, "uniform", 0) ? 1 : 0;
			data->mix = Json41_getFloat(constraintMap, "mix", 1);
			data->softness = Json41_getFloat(constraintMap, "softness", 0) * self->scale;

			skeletonData->ikConstraints[i] = data;
		}
	}

	/* Transform constraints. */
	transform = Json41_getItem(root, "transform");
	if (transform) {
		Json41 *constraintMap;
		skeletonData->transformConstraintsCount = transform->size;
		skeletonData->transformConstraints = MALLOC(sp41TransformConstraintData *, transform->size);
		for (constraintMap = transform->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char *name;

			sp41TransformConstraintData *data = sp41TransformConstraintData_create(
					Json41_getString(constraintMap, "name", 0));
			data->order = Json41_getInt(constraintMap, "order", 0);
			data->skinRequired = Json41_getInt(constraintMap, "skin", 0) ? 1 : 0;

			boneMap = Json41_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			CONST_CAST(sp41BoneData **, data->bones) = MALLOC(sp41BoneData *, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp41SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp41SkeletonData_dispose(skeletonData);
					_sp41SkeletonJson_setError(self, root, "Transform bone not found: ", boneMap->valueString);
					return NULL;
				}
			}

			name = Json41_getString(constraintMap, "target", 0);
			data->target = sp41SkeletonData_findBone(skeletonData, name);
			if (!data->target) {
				sp41SkeletonData_dispose(skeletonData);
				_sp41SkeletonJson_setError(self, root, "Target bone not found: ", name);
				return NULL;
			}

			data->local = Json41_getInt(constraintMap, "local", 0);
			data->relative = Json41_getInt(constraintMap, "relative", 0);
			data->offsetRotation = Json41_getFloat(constraintMap, "rotation", 0);
			data->offsetX = Json41_getFloat(constraintMap, "x", 0) * self->scale;
			data->offsetY = Json41_getFloat(constraintMap, "y", 0) * self->scale;
			data->offsetScaleX = Json41_getFloat(constraintMap, "scaleX", 0);
			data->offsetScaleY = Json41_getFloat(constraintMap, "scaleY", 0);
			data->offsetShearY = Json41_getFloat(constraintMap, "shearY", 0);

			data->mixRotate = Json41_getFloat(constraintMap, "mixRotate", 1);
			data->mixX = Json41_getFloat(constraintMap, "mixX", 1);
			data->mixY = Json41_getFloat(constraintMap, "mixY", data->mixX);
			data->mixScaleX = Json41_getFloat(constraintMap, "mixScaleX", 1);
			data->mixScaleY = Json41_getFloat(constraintMap, "mixScaleY", data->mixScaleX);
			data->mixShearY = Json41_getFloat(constraintMap, "mixShearY", 1);

			skeletonData->transformConstraints[i] = data;
		}
	}

	/* Path constraints */
	pathJson = Json41_getItem(root, "path");
	if (pathJson) {
		Json41 *constraintMap;
		skeletonData->pathConstraintsCount = pathJson->size;
		skeletonData->pathConstraints = MALLOC(sp41PathConstraintData *, pathJson->size);
		for (constraintMap = pathJson->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char *name;
			const char *item;

			sp41PathConstraintData *data = sp41PathConstraintData_create(Json41_getString(constraintMap, "name", 0));
			data->order = Json41_getInt(constraintMap, "order", 0);
			data->skinRequired = Json41_getInt(constraintMap, "skin", 0) ? 1 : 0;

			boneMap = Json41_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			CONST_CAST(sp41BoneData **, data->bones) = MALLOC(sp41BoneData *, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp41SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp41SkeletonData_dispose(skeletonData);
					_sp41SkeletonJson_setError(self, root, "Path bone not found: ", boneMap->valueString);
					return NULL;
				}
			}

			name = Json41_getString(constraintMap, "target", 0);
			data->target = sp41SkeletonData_findSlot(skeletonData, name);
			if (!data->target) {
				sp41SkeletonData_dispose(skeletonData);
				_sp41SkeletonJson_setError(self, root, "Target slot not found: ", name);
				return NULL;
			}

			item = Json41_getString(constraintMap, "positionMode", "percent");
			if (strcmp(item, "fixed") == 0) data->positionMode = SP_POSITION_MODE_FIXED;
			else if (strcmp(item, "percent") == 0)
				data->positionMode = SP_POSITION_MODE_PERCENT;

			item = Json41_getString(constraintMap, "spacingMode", "length");
			if (strcmp(item, "length") == 0) data->spacingMode = SP_SPACING_MODE_LENGTH;
			else if (strcmp(item, "fixed") == 0)
				data->spacingMode = SP_SPACING_MODE_FIXED;
			else if (strcmp(item, "percent") == 0)
				data->spacingMode = SP_SPACING_MODE_PERCENT;

			item = Json41_getString(constraintMap, "rotateMode", "tangent");
			if (strcmp(item, "tangent") == 0) data->rotateMode = SP_ROTATE_MODE_TANGENT;
			else if (strcmp(item, "chain") == 0)
				data->rotateMode = SP_ROTATE_MODE_CHAIN;
			else if (strcmp(item, "chainScale") == 0)
				data->rotateMode = SP_ROTATE_MODE_CHAIN_SCALE;

			data->offsetRotation = Json41_getFloat(constraintMap, "rotation", 0);
			data->position = Json41_getFloat(constraintMap, "position", 0);
			if (data->positionMode == SP_POSITION_MODE_FIXED) data->position *= self->scale;
			data->spacing = Json41_getFloat(constraintMap, "spacing", 0);
			if (data->spacingMode == SP_SPACING_MODE_LENGTH || data->spacingMode == SP_SPACING_MODE_FIXED)
				data->spacing *= self->scale;
			data->mixRotate = Json41_getFloat(constraintMap, "mixRotate", 1);
			data->mixX = Json41_getFloat(constraintMap, "mixX", 1);
			data->mixY = Json41_getFloat(constraintMap, "mixY", data->mixX);

			skeletonData->pathConstraints[i] = data;
		}
	}

	/* Skins. */
	skins = Json41_getItem(root, "skins");
	if (skins) {
		Json41 *skinMap;
		skeletonData->skins = MALLOC(sp41Skin *, skins->size);
		for (skinMap = skins->child, i = 0; skinMap; skinMap = skinMap->next, ++i) {
			Json41 *attachmentsMap;
			Json41 *curves;
			Json41 *skinPart;
			sp41Skin *skin = sp41Skin_create(Json41_getString(skinMap, "name", ""));

			skinPart = Json41_getItem(skinMap, "bones");
			if (skinPart) {
				for (skinPart = skinPart->child; skinPart; skinPart = skinPart->next) {
					sp41BoneData *bone = sp41SkeletonData_findBone(skeletonData, skinPart->valueString);
					if (!bone) {
						sp41SkeletonData_dispose(skeletonData);
						_sp41SkeletonJson_setError(self, root, "Skin bone constraint not found: ", skinPart->valueString);
						return NULL;
					}
					sp41BoneDataArray_add(skin->bones, bone);
				}
			}

			skinPart = Json41_getItem(skinMap, "ik");
			if (skinPart) {
				for (skinPart = skinPart->child; skinPart; skinPart = skinPart->next) {
					sp41IkConstraintData *constraint = sp41SkeletonData_findIkConstraint(skeletonData,
																					 skinPart->valueString);
					if (!constraint) {
						sp41SkeletonData_dispose(skeletonData);
						_sp41SkeletonJson_setError(self, root, "Skin IK constraint not found: ", skinPart->valueString);
						return NULL;
					}
					sp41IkConstraintDataArray_add(skin->ikConstraints, constraint);
				}
			}

			skinPart = Json41_getItem(skinMap, "path");
			if (skinPart) {
				for (skinPart = skinPart->child; skinPart; skinPart = skinPart->next) {
					sp41PathConstraintData *constraint = sp41SkeletonData_findPathConstraint(skeletonData,
																						 skinPart->valueString);
					if (!constraint) {
						sp41SkeletonData_dispose(skeletonData);
						_sp41SkeletonJson_setError(self, root, "Skin path constraint not found: ", skinPart->valueString);
						return NULL;
					}
					sp41PathConstraintDataArray_add(skin->pathConstraints, constraint);
				}
			}

			skinPart = Json41_getItem(skinMap, "transform");
			if (skinPart) {
				for (skinPart = skinPart->child; skinPart; skinPart = skinPart->next) {
					sp41TransformConstraintData *constraint = sp41SkeletonData_findTransformConstraint(skeletonData,
																								   skinPart->valueString);
					if (!constraint) {
						sp41SkeletonData_dispose(skeletonData);
						_sp41SkeletonJson_setError(self, root, "Skin transform constraint not found: ",
												 skinPart->valueString);
						return NULL;
					}
					sp41TransformConstraintDataArray_add(skin->transformConstraints, constraint);
				}
			}

			skeletonData->skins[skeletonData->skinsCount++] = skin;
			if (strcmp(skin->name, "default") == 0) skeletonData->defaultSkin = skin;

			for (attachmentsMap = Json41_getItem(skinMap,
											   "attachments")
										  ->child;
				 attachmentsMap; attachmentsMap = attachmentsMap->next) {
				sp41SlotData *slot = sp41SkeletonData_findSlot(skeletonData, attachmentsMap->name);
				Json41 *attachmentMap;

				for (attachmentMap = attachmentsMap->child; attachmentMap; attachmentMap = attachmentMap->next) {
					sp41Attachment *attachment;
					const char *skinAttachmentName = attachmentMap->name;
					const char *attachmentName = Json41_getString(attachmentMap, "name", skinAttachmentName);
					const char *path = Json41_getString(attachmentMap, "path", attachmentName);
					const char *color;
					Json41 *entry;
					sp41Sequence *sequence;

					const char *typeString = Json41_getString(attachmentMap, "type", "region");
					sp41AttachmentType type;
					if (strcmp(typeString, "region") == 0) type = SP_ATTACHMENT_REGION;
					else if (strcmp(typeString, "mesh") == 0)
						type = SP_ATTACHMENT_MESH;
					else if (strcmp(typeString, "linkedmesh") == 0)
						type = SP_ATTACHMENT_LINKED_MESH;
					else if (strcmp(typeString, "boundingbox") == 0)
						type = SP_ATTACHMENT_BOUNDING_BOX;
					else if (strcmp(typeString, "path") == 0)
						type = SP_ATTACHMENT_PATH;
					else if (strcmp(typeString, "clipping") == 0)
						type = SP_ATTACHMENT_CLIPPING;
					else if (strcmp(typeString, "point") == 0)
						type = SP_ATTACHMENT_POINT;
					else {
						sp41SkeletonData_dispose(skeletonData);
						_sp41SkeletonJson_setError(self, root, "Unknown attachment type: ", typeString);
						return NULL;
					}

					sequence = readSequence(Json41_getItem(attachmentMap, "sequence"));
					attachment = sp41AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, attachmentName,
																	 path, sequence);
					if (!attachment) {
						if (self->attachmentLoader->error1) {
							sp41SkeletonData_dispose(skeletonData);
							_sp41SkeletonJson_setError(self, root, self->attachmentLoader->error1,
													 self->attachmentLoader->error2);
							return NULL;
						}
						continue;
					}

					switch (attachment->type) {
						case SP_ATTACHMENT_REGION: {
							sp41RegionAttachment *region = SUB_CAST(sp41RegionAttachment, attachment);
							if (path) MALLOC_STR(region->path, path);
							region->x = Json41_getFloat(attachmentMap, "x", 0) * self->scale;
							region->y = Json41_getFloat(attachmentMap, "y", 0) * self->scale;
							region->scaleX = Json41_getFloat(attachmentMap, "scaleX", 1);
							region->scaleY = Json41_getFloat(attachmentMap, "scaleY", 1);
							region->rotation = Json41_getFloat(attachmentMap, "rotation", 0);
							region->width = Json41_getFloat(attachmentMap, "width", 32) * self->scale;
							region->height = Json41_getFloat(attachmentMap, "height", 32) * self->scale;
							region->sequence = sequence;

							color = Json41_getString(attachmentMap, "color", 0);
							if (color) {
								sp41Color_setFromFloats(&region->color,
													  toColor(color, 0),
													  toColor(color, 1),
													  toColor(color, 2),
													  toColor(color, 3));
							}

							if (region->region != NULL) sp41RegionAttachment_updateRegion(region);

							sp41AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
							break;
						}
						case SP_ATTACHMENT_MESH:
						case SP_ATTACHMENT_LINKED_MESH: {
							sp41MeshAttachment *mesh = SUB_CAST(sp41MeshAttachment, attachment);

							MALLOC_STR(mesh->path, path);

							color = Json41_getString(attachmentMap, "color", 0);
							if (color) {
								sp41Color_setFromFloats(&mesh->color,
													  toColor(color, 0),
													  toColor(color, 1),
													  toColor(color, 2),
													  toColor(color, 3));
							}

							mesh->width = Json41_getFloat(attachmentMap, "width", 32) * self->scale;
							mesh->height = Json41_getFloat(attachmentMap, "height", 32) * self->scale;
							mesh->sequence = sequence;

							entry = Json41_getItem(attachmentMap, "parent");
							if (!entry) {
								int verticesLength;
								entry = Json41_getItem(attachmentMap, "triangles");
								mesh->trianglesCount = entry->size;
								mesh->triangles = MALLOC(unsigned short, entry->size);
								for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
									mesh->triangles[ii] = (unsigned short) entry->valueInt;

								entry = Json41_getItem(attachmentMap, "uvs");
								verticesLength = entry->size;
								mesh->regionUVs = MALLOC(float, verticesLength);
								for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
									mesh->regionUVs[ii] = entry->valueFloat;

								_readVertices(self, attachmentMap, SUPER(mesh), verticesLength);

								if (mesh->region != NULL) sp41MeshAttachment_updateRegion(mesh);

								mesh->hullLength = Json41_getInt(attachmentMap, "hull", 0);

								entry = Json41_getItem(attachmentMap, "edges");
								if (entry) {
									mesh->edgesCount = entry->size;
									mesh->edges = MALLOC(int, entry->size);
									for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
										mesh->edges[ii] = entry->valueInt;
								}

								sp41AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
							} else {
								int inheritTimelines = Json41_getInt(attachmentMap, "timelines", 1);
								_sp41SkeletonJson_addLinkedMesh(self, SUB_CAST(sp41MeshAttachment, attachment),
															  Json41_getString(attachmentMap, "skin", 0), slot->index,
															  entry->valueString, inheritTimelines);
							}
							break;
						}
						case SP_ATTACHMENT_BOUNDING_BOX: {
							sp41BoundingBoxAttachment *box = SUB_CAST(sp41BoundingBoxAttachment, attachment);
							int vertexCount = Json41_getInt(attachmentMap, "vertexCount", 0) << 1;
							_readVertices(self, attachmentMap, SUPER(box), vertexCount);
							box->super.verticesCount = vertexCount;
							color = Json41_getString(attachmentMap, "color", 0);
							if (color) {
								sp41Color_setFromFloats(&box->color,
													  toColor(color, 0),
													  toColor(color, 1),
													  toColor(color, 2),
													  toColor(color, 3));
							}
							sp41AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
							break;
						}
						case SP_ATTACHMENT_PATH: {
							sp41PathAttachment *pathAttachment = SUB_CAST(sp41PathAttachment, attachment);
							int vertexCount = 0;
							pathAttachment->closed = Json41_getInt(attachmentMap, "closed", 0);
							pathAttachment->constantSpeed = Json41_getInt(attachmentMap, "constantSpeed", 1);
							vertexCount = Json41_getInt(attachmentMap, "vertexCount", 0);
							_readVertices(self, attachmentMap, SUPER(pathAttachment), vertexCount << 1);

							pathAttachment->lengthsLength = vertexCount / 3;
							pathAttachment->lengths = MALLOC(float, pathAttachment->lengthsLength);

							curves = Json41_getItem(attachmentMap, "lengths");
							for (curves = curves->child, ii = 0; curves; curves = curves->next, ++ii)
								pathAttachment->lengths[ii] = curves->valueFloat * self->scale;
							color = Json41_getString(attachmentMap, "color", 0);
							if (color) {
								sp41Color_setFromFloats(&pathAttachment->color,
													  toColor(color, 0),
													  toColor(color, 1),
													  toColor(color, 2),
													  toColor(color, 3));
							}
							break;
						}
						case SP_ATTACHMENT_POINT: {
							sp41PointAttachment *point = SUB_CAST(sp41PointAttachment, attachment);
							point->x = Json41_getFloat(attachmentMap, "x", 0) * self->scale;
							point->y = Json41_getFloat(attachmentMap, "y", 0) * self->scale;
							point->rotation = Json41_getFloat(attachmentMap, "rotation", 0);

							color = Json41_getString(attachmentMap, "color", 0);
							if (color) {
								sp41Color_setFromFloats(&point->color,
													  toColor(color, 0),
													  toColor(color, 1),
													  toColor(color, 2),
													  toColor(color, 3));
							}
							break;
						}
						case SP_ATTACHMENT_CLIPPING: {
							sp41ClippingAttachment *clip = SUB_CAST(sp41ClippingAttachment, attachment);
							int vertexCount = 0;
							const char *end = Json41_getString(attachmentMap, "end", 0);
							if (end) {
								sp41SlotData *endSlot = sp41SkeletonData_findSlot(skeletonData, end);
								clip->endSlot = endSlot;
							}
							vertexCount = Json41_getInt(attachmentMap, "vertexCount", 0) << 1;
							_readVertices(self, attachmentMap, SUPER(clip), vertexCount);
							color = Json41_getString(attachmentMap, "color", 0);
							if (color) {
								sp41Color_setFromFloats(&clip->color,
													  toColor(color, 0),
													  toColor(color, 1),
													  toColor(color, 2),
													  toColor(color, 3));
							}
							sp41AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
							break;
						}
					}

					sp41Skin_setAttachment(skin, slot->index, skinAttachmentName, attachment);
				}
			}
		}
	}

	/* Linked meshes. */
	for (i = 0; i < internal->linkedMeshCount; ++i) {
		sp41Attachment *parent;
		_sp41LinkedMesh *linkedMesh = internal->linkedMeshes + i;
		sp41Skin *skin = !linkedMesh->skin ? skeletonData->defaultSkin : sp41SkeletonData_findSkin(skeletonData, linkedMesh->skin);
		if (!skin) {
			sp41SkeletonData_dispose(skeletonData);
			_sp41SkeletonJson_setError(self, 0, "Skin not found: ", linkedMesh->skin);
			return NULL;
		}
		parent = sp41Skin_getAttachment(skin, linkedMesh->slotIndex, linkedMesh->parent);
		if (!parent) {
			sp41SkeletonData_dispose(skeletonData);
			_sp41SkeletonJson_setError(self, 0, "Parent mesh not found: ", linkedMesh->parent);
			return NULL;
		}
		linkedMesh->mesh->super.timelineAttachment = linkedMesh->inheritTimeline ? parent
																				 : SUPER(SUPER(linkedMesh->mesh));
		sp41MeshAttachment_setParentMesh(linkedMesh->mesh, SUB_CAST(sp41MeshAttachment, parent));
		if (linkedMesh->mesh->region != NULL) sp41MeshAttachment_updateRegion(linkedMesh->mesh);
		sp41AttachmentLoader_configureAttachment(self->attachmentLoader, SUPER(SUPER(linkedMesh->mesh)));
	}

	/* Events. */
	events = Json41_getItem(root, "events");
	if (events) {
		Json41 *eventMap;
		const char *stringValue;
		const char *audioPath;
		skeletonData->eventsCount = events->size;
		skeletonData->events = MALLOC(sp41EventData *, events->size);
		for (eventMap = events->child, i = 0; eventMap; eventMap = eventMap->next, ++i) {
			sp41EventData *eventData = sp41EventData_create(eventMap->name);
			eventData->intValue = Json41_getInt(eventMap, "int", 0);
			eventData->floatValue = Json41_getFloat(eventMap, "float", 0);
			stringValue = Json41_getString(eventMap, "string", 0);
			if (stringValue) MALLOC_STR(eventData->stringValue, stringValue);
			audioPath = Json41_getString(eventMap, "audio", 0);
			if (audioPath) {
				MALLOC_STR(eventData->audioPath, audioPath);
				eventData->volume = Json41_getFloat(eventMap, "volume", 1);
				eventData->balance = Json41_getFloat(eventMap, "balance", 0);
			}
			skeletonData->events[i] = eventData;
		}
	}

	/* Animations. */
	animations = Json41_getItem(root, "animations");
	if (animations) {
		Json41 *animationMap;
		skeletonData->animations = MALLOC(sp41Animation *, animations->size);
		for (animationMap = animations->child; animationMap; animationMap = animationMap->next) {
			sp41Animation *animation = _sp41SkeletonJson_readAnimation(self, animationMap, skeletonData);
			if (!animation) {
				sp41SkeletonData_dispose(skeletonData);
				return NULL;
			}
			skeletonData->animations[skeletonData->animationsCount++] = animation;
		}
	}

	Json41_dispose(root);
	return skeletonData;
}

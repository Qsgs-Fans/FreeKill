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

#include "Json.h"
#include <spine/Array.h>
#include <spine/AtlasAttachmentLoader.h>
#include <spine/SkeletonJson.h>
#include <spine/extension.h>
#include <stdio.h>

typedef struct {
	const char *parent;
	const char *skin;
	int slotIndex;
	sp40MeshAttachment *mesh;
	int inheritDeform;
} _sp40LinkedMesh;

typedef struct {
	sp40SkeletonJson super;
	int ownsLoader;

	int linkedMeshCount;
	int linkedMeshCapacity;
	_sp40LinkedMesh *linkedMeshes;
} _sp40SkeletonJson;

sp40SkeletonJson *sp40SkeletonJson_createWithLoader(sp40AttachmentLoader *attachmentLoader) {
	sp40SkeletonJson *self = SUPER(NEW(_sp40SkeletonJson));
	self->scale = 1;
	self->attachmentLoader = attachmentLoader;
	return self;
}

sp40SkeletonJson *sp40SkeletonJson_create(sp40Atlas *atlas) {
	sp40AtlasAttachmentLoader *attachmentLoader = sp40AtlasAttachmentLoader_create(atlas);
	sp40SkeletonJson *self = sp40SkeletonJson_createWithLoader(SUPER(attachmentLoader));
	SUB_CAST(_sp40SkeletonJson, self)->ownsLoader = 1;
	return self;
}

void sp40SkeletonJson_dispose(sp40SkeletonJson *self) {
	_sp40SkeletonJson *internal = SUB_CAST(_sp40SkeletonJson, self);
	if (internal->ownsLoader) sp40AttachmentLoader_dispose(self->attachmentLoader);
	FREE(internal->linkedMeshes);
	FREE(self->error);
	FREE(self);
}

void _sp40SkeletonJson_setError(sp40SkeletonJson *self, Json40 *root, const char *value1, const char *value2) {
	char message[256];
	int length;
	FREE(self->error);
	strcpy(message, value1);
	length = (int) strlen(value1);
	if (value2) strncat(message + length, value2, 255 - length);
	MALLOC_STR(self->error, message);
	if (root) Json40_dispose(root);
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

static void toColor2(sp40Color *color, const char *value, int /*bool*/ hasAlpha) {
	color->r = toColor(value, 0);
	color->g = toColor(value, 1);
	color->b = toColor(value, 2);
	if (hasAlpha) color->a = toColor(value, 3);
}

static void
setBezier(sp40CurveTimeline *timeline, int frame, int value, int bezier, float time1, float value1, float cx1, float cy1,
		  float cx2, float cy2, float time2, float value2) {
	sp40Timeline_setBezier(SUPER(timeline), bezier, frame, value, time1, value1, cx1, cy1, cx2, cy2, time2, value2);
}

static int readCurve(Json40 *curve, sp40CurveTimeline *timeline, int bezier, int frame, int value, float time1, float time2,
					 float value1, float value2, float scale) {
	float cx1, cy1, cx2, cy2;
	if (curve->type == Json40_String && strcmp(curve->valueString, "stepped") == 0) {
		if (value != 0) sp40CurveTimeline_setStepped(timeline, frame);
		return bezier;
	}
	curve = Json40_getItemAtIndex(curve, value << 2);
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

static sp40Timeline *readTimeline(Json40 *keyMap, sp40CurveTimeline1 *timeline, float defaultValue, float scale) {
	float time = Json40_getFloat(keyMap, "time", 0);
	float value = Json40_getFloat(keyMap, "value", defaultValue) * scale;
	int frame, bezier = 0;
	for (frame = 0;; ++frame) {
		Json40 *nextMap, *curve;
		float time2, value2;
		sp40CurveTimeline1_setFrame(timeline, frame, time, value);
		nextMap = keyMap->next;
		if (nextMap == NULL) break;
		time2 = Json40_getFloat(nextMap, "time", 0);
		value2 = Json40_getFloat(nextMap, "value", defaultValue) * scale;
		curve = Json40_getItem(keyMap, "curve");
		if (curve != NULL) bezier = readCurve(curve, timeline, bezier, frame, 0, time, time2, value, value2, scale);
		time = time2;
		value = value2;
		keyMap = nextMap;
	}
	/* timeline.shrink(); // BOZO */
	return SUPER(timeline);
}

static sp40Timeline *
readTimeline2(Json40 *keyMap, sp40CurveTimeline2 *timeline, const char *name1, const char *name2, float defaultValue,
			  float scale) {
	float time = Json40_getFloat(keyMap, "time", 0);
	float value1 = Json40_getFloat(keyMap, name1, defaultValue) * scale;
	float value2 = Json40_getFloat(keyMap, name2, defaultValue) * scale;
	int frame, bezier = 0;
	for (frame = 0;; ++frame) {
		Json40 *nextMap, *curve;
		float time2, nvalue1, nvalue2;
		sp40CurveTimeline2_setFrame(timeline, frame, time, value1, value2);
		nextMap = keyMap->next;
		if (nextMap == NULL) break;
		time2 = Json40_getFloat(nextMap, "time", 0);
		nvalue1 = Json40_getFloat(nextMap, name1, defaultValue) * scale;
		nvalue2 = Json40_getFloat(nextMap, name2, defaultValue) * scale;
		curve = Json40_getItem(keyMap, "curve");
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

static void _sp40SkeletonJson_addLinkedMesh(sp40SkeletonJson *self, sp40MeshAttachment *mesh, const char *skin, int slotIndex,
										  const char *parent, int inheritDeform) {
	_sp40LinkedMesh *linkedMesh;
	_sp40SkeletonJson *internal = SUB_CAST(_sp40SkeletonJson, self);

	if (internal->linkedMeshCount == internal->linkedMeshCapacity) {
		_sp40LinkedMesh *linkedMeshes;
		internal->linkedMeshCapacity *= 2;
		if (internal->linkedMeshCapacity < 8) internal->linkedMeshCapacity = 8;
		linkedMeshes = MALLOC(_sp40LinkedMesh, internal->linkedMeshCapacity);
		memcpy(linkedMeshes, internal->linkedMeshes, sizeof(_sp40LinkedMesh) * internal->linkedMeshCount);
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

static void cleanUpTimelines(sp40TimelineArray *timelines) {
	int i, n;
	for (i = 0, n = timelines->size; i < n; ++i)
		sp40Timeline_dispose(timelines->items[i]);
	sp40TimelineArray_dispose(timelines);
}

static int findSlotIndex(sp40SkeletonJson *json, const sp40SkeletonData *skeletonData, const char *slotName, sp40TimelineArray *timelines) {
	sp40SlotData *slot = sp40SkeletonData_findSlot(skeletonData, slotName);
	if (slot) return slot->index;
	cleanUpTimelines(timelines);
	_sp40SkeletonJson_setError(json, NULL, "Slot not found: ", slotName);
	return -1;
}

static int findIkConstraintIndex(sp40SkeletonJson *json, const sp40SkeletonData *skeletonData, const sp40IkConstraintData *constraint, sp40TimelineArray *timelines) {
	if (constraint) {
		int i;
		for (i = 0; i < skeletonData->ikConstraintsCount; ++i)
			if (skeletonData->ikConstraints[i] == constraint) return i;
	}
	cleanUpTimelines(timelines);
	_sp40SkeletonJson_setError(json, NULL, "IK constraint not found: ", constraint->name);
	return -1;
}

static int findTransformConstraintIndex(sp40SkeletonJson *json, const sp40SkeletonData *skeletonData, const sp40TransformConstraintData *constraint, sp40TimelineArray *timelines) {
	if (constraint) {
		int i;
		for (i = 0; i < skeletonData->transformConstraintsCount; ++i)
			if (skeletonData->transformConstraints[i] == constraint) return i;
	}
	cleanUpTimelines(timelines);
	_sp40SkeletonJson_setError(json, NULL, "Transform constraint not found: ", constraint->name);
	return -1;
}

static int findPathConstraintIndex(sp40SkeletonJson *json, const sp40SkeletonData *skeletonData, const sp40PathConstraintData *constraint, sp40TimelineArray *timelines) {
	if (constraint) {
		int i;
		for (i = 0; i < skeletonData->pathConstraintsCount; ++i)
			if (skeletonData->pathConstraints[i] == constraint) return i;
	}
	cleanUpTimelines(timelines);
	_sp40SkeletonJson_setError(json, NULL, "Path constraint not found: ", constraint->name);
	return -1;
}

static sp40Animation *_sp40SkeletonJson_readAnimation(sp40SkeletonJson *self, Json40 *root, sp40SkeletonData *skeletonData) {
	sp40TimelineArray *timelines = sp40TimelineArray_create(8);

	float scale = self->scale, duration;
	Json40 *bones = Json40_getItem(root, "bones");
	Json40 *slots = Json40_getItem(root, "slots");
	Json40 *ik = Json40_getItem(root, "ik");
	Json40 *transform = Json40_getItem(root, "transform");
	Json40 *paths = Json40_getItem(root, "path");
	Json40 *deformJson = Json40_getItem(root, "deform");
	Json40 *drawOrderJson = Json40_getItem(root, "drawOrder");
	Json40 *events = Json40_getItem(root, "events");
	Json40 *boneMap, *slotMap, *constraintMap, *keyMap, *nextMap, *curve, *timelineMap;
	int frame, bezier, i, n;
	sp40Color color, color2, newColor, newColor2;

	/* Slot timelines. */
	for (slotMap = slots ? slots->child : 0; slotMap; slotMap = slotMap->next) {
		int slotIndex = findSlotIndex(self, skeletonData, slotMap->name, timelines);
		if (slotIndex == -1) return NULL;

		for (timelineMap = slotMap->child; timelineMap; timelineMap = timelineMap->next) {
			int frames = timelineMap->size;
			if (strcmp(timelineMap->name, "attachment") == 0) {
				sp40AttachmentTimeline *timeline = sp40AttachmentTimeline_create(frames, slotIndex);
				for (keyMap = timelineMap->child, frame = 0; keyMap; keyMap = keyMap->next, ++frame) {
					sp40AttachmentTimeline_setFrame(timeline, frame, Json40_getFloat(keyMap, "time", 0),
												  Json40_getItem(keyMap, "name")->valueString);
				}
				sp40TimelineArray_add(timelines, SUPER(timeline));

			} else if (strcmp(timelineMap->name, "rgba") == 0) {
				float time;
				sp40RGBATimeline *timeline = sp40RGBATimeline_create(frames, frames << 2, slotIndex);
				keyMap = timelineMap->child;
				time = Json40_getFloat(keyMap, "time", 0);
				toColor2(&color, Json40_getString(keyMap, "color", 0), 1);

				for (frame = 0, bezier = 0;; ++frame) {
					float time2;
					sp40RGBATimeline_setFrame(timeline, frame, time, color.r, color.g, color.b, color.a);
					nextMap = keyMap->next;
					if (!nextMap) {
						/* timeline.shrink(); // BOZO */
						break;
					}
					time2 = Json40_getFloat(nextMap, "time", 0);
					toColor2(&newColor, Json40_getString(nextMap, "color", 0), 1);
					curve = Json40_getItem(keyMap, "curve");
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
				sp40TimelineArray_add(timelines, SUPER(SUPER(timeline)));
			} else if (strcmp(timelineMap->name, "rgb") == 0) {
				float time;
				sp40RGBTimeline *timeline = sp40RGBTimeline_create(frames, frames * 3, slotIndex);
				keyMap = timelineMap->child;
				time = Json40_getFloat(keyMap, "time", 0);
				toColor2(&color, Json40_getString(keyMap, "color", 0), 1);

				for (frame = 0, bezier = 0;; ++frame) {
					float time2;
					sp40RGBTimeline_setFrame(timeline, frame, time, color.r, color.g, color.b);
					nextMap = keyMap->next;
					if (!nextMap) {
						/* timeline.shrink(); // BOZO */
						break;
					}
					time2 = Json40_getFloat(nextMap, "time", 0);
					toColor2(&newColor, Json40_getString(nextMap, "color", 0), 1);
					curve = Json40_getItem(keyMap, "curve");
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
				sp40TimelineArray_add(timelines, SUPER(SUPER(timeline)));
			} else if (strcmp(timelineMap->name, "alpha") == 0) {
				sp40TimelineArray_add(timelines, readTimeline(timelineMap->child,
															SUPER(sp40AlphaTimeline_create(frames,
																						 frames, slotIndex)),
															0, 1));
			} else if (strcmp(timelineMap->name, "rgba2") == 0) {
				float time;
				sp40RGBA2Timeline *timeline = sp40RGBA2Timeline_create(frames, frames * 7, slotIndex);
				keyMap = timelineMap->child;
				time = Json40_getFloat(keyMap, "time", 0);
				toColor2(&color, Json40_getString(keyMap, "light", 0), 1);
				toColor2(&color2, Json40_getString(keyMap, "dark", 0), 0);

				for (frame = 0, bezier = 0;; ++frame) {
					float time2;
					sp40RGBA2Timeline_setFrame(timeline, frame, time, color.r, color.g, color.b, color.a, color2.g,
											 color2.g, color2.b);
					nextMap = keyMap->next;
					if (!nextMap) {
						/* timeline.shrink(); // BOZO */
						break;
					}
					time2 = Json40_getFloat(nextMap, "time", 0);
					toColor2(&newColor, Json40_getString(nextMap, "light", 0), 1);
					toColor2(&newColor2, Json40_getString(nextMap, "dark", 0), 0);
					curve = Json40_getItem(keyMap, "curve");
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
				sp40TimelineArray_add(timelines, SUPER(SUPER(timeline)));
			} else if (strcmp(timelineMap->name, "rgb2") == 0) {
				float time;
				sp40RGBA2Timeline *timeline = sp40RGBA2Timeline_create(frames, frames * 6, slotIndex);
				keyMap = timelineMap->child;
				time = Json40_getFloat(keyMap, "time", 0);
				toColor2(&color, Json40_getString(keyMap, "light", 0), 0);
				toColor2(&color2, Json40_getString(keyMap, "dark", 0), 0);

				for (frame = 0, bezier = 0;; ++frame) {
					float time2;
					sp40RGBA2Timeline_setFrame(timeline, frame, time, color.r, color.g, color.b, color.a, color2.r,
											 color2.g, color2.b);
					nextMap = keyMap->next;
					if (!nextMap) {
						/* timeline.shrink(); // BOZO */
						break;
					}
					time2 = Json40_getFloat(nextMap, "time", 0);
					toColor2(&newColor, Json40_getString(nextMap, "light", 0), 0);
					toColor2(&newColor2, Json40_getString(nextMap, "dark", 0), 0);
					curve = Json40_getItem(keyMap, "curve");
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
				sp40TimelineArray_add(timelines, SUPER(SUPER(timeline)));
			} else {
				cleanUpTimelines(timelines);
				_sp40SkeletonJson_setError(self, NULL, "Invalid timeline type for a slot: ", timelineMap->name);
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
			_sp40SkeletonJson_setError(self, NULL, "Bone not found: ", boneMap->name);
			return NULL;
		}

		for (timelineMap = boneMap->child; timelineMap; timelineMap = timelineMap->next) {
			int frames = timelineMap->size;
			if (frames == 0) continue;

			if (strcmp(timelineMap->name, "rotate") == 0) {
				sp40TimelineArray_add(timelines, readTimeline(timelineMap->child,
															SUPER(sp40RotateTimeline_create(frames,
																						  frames,
																						  boneIndex)),
															0, 1));
			} else if (strcmp(timelineMap->name, "translate") == 0) {
				sp40TranslateTimeline *timeline = sp40TranslateTimeline_create(frames, frames << 1,
																		   boneIndex);
				sp40TimelineArray_add(timelines, readTimeline2(timelineMap->child, SUPER(timeline), "x", "y", 0, scale));
			} else if (strcmp(timelineMap->name, "translatex") == 0) {
				sp40TranslateXTimeline *timeline = sp40TranslateXTimeline_create(frames, frames,
																			 boneIndex);
				sp40TimelineArray_add(timelines, readTimeline(timelineMap->child, SUPER(timeline), 0, scale));
			} else if (strcmp(timelineMap->name, "translatey") == 0) {
				sp40TranslateYTimeline *timeline = sp40TranslateYTimeline_create(frames, frames,
																			 boneIndex);
				sp40TimelineArray_add(timelines, readTimeline(timelineMap->child, SUPER(timeline), 0, scale));
			} else if (strcmp(timelineMap->name, "scale") == 0) {
				sp40ScaleTimeline *timeline = sp40ScaleTimeline_create(frames, frames << 1,
																   boneIndex);
				sp40TimelineArray_add(timelines, readTimeline2(timelineMap->child, SUPER(timeline), "x", "y", 1, 1));
			} else if (strcmp(timelineMap->name, "scalex") == 0) {
				sp40ScaleXTimeline *timeline = sp40ScaleXTimeline_create(frames, frames, boneIndex);
				sp40TimelineArray_add(timelines, readTimeline(timelineMap->child, SUPER(timeline), 1, 1));
			} else if (strcmp(timelineMap->name, "scaley") == 0) {
				sp40ScaleYTimeline *timeline = sp40ScaleYTimeline_create(frames, frames, boneIndex);
				sp40TimelineArray_add(timelines, readTimeline(timelineMap->child, SUPER(timeline), 1, 1));
			} else if (strcmp(timelineMap->name, "shear") == 0) {
				sp40ShearTimeline *timeline = sp40ShearTimeline_create(frames, frames << 1,
																   boneIndex);
				sp40TimelineArray_add(timelines, readTimeline2(timelineMap->child, SUPER(timeline), "x", "y", 0, 1));
			} else if (strcmp(timelineMap->name, "shearx") == 0) {
				sp40ShearXTimeline *timeline = sp40ShearXTimeline_create(frames, frames, boneIndex);
				sp40TimelineArray_add(timelines, readTimeline(timelineMap->child, SUPER(timeline), 0, 1));
			} else if (strcmp(timelineMap->name, "sheary") == 0) {
				sp40ShearYTimeline *timeline = sp40ShearYTimeline_create(frames, frames, boneIndex);
				sp40TimelineArray_add(timelines, readTimeline(timelineMap->child, SUPER(timeline), 0, 1));
			} else {
				cleanUpTimelines(timelines);
				_sp40SkeletonJson_setError(self, NULL, "Invalid timeline type for a bone: ", timelineMap->name);
				return NULL;
			}
		}
	}

	/* IK constraint timelines. */
	for (constraintMap = ik ? ik->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp40IkConstraintData *constraint;
		sp40IkConstraintTimeline *timeline;
		int constraintIndex;
		float time, mix, softness;
		keyMap = constraintMap->child;
		if (keyMap == NULL) continue;

		constraint = sp40SkeletonData_findIkConstraint(skeletonData, constraintMap->name);
		constraintIndex = findIkConstraintIndex(self, skeletonData, constraint, timelines);
		if (constraintIndex == -1) return NULL;
		timeline = sp40IkConstraintTimeline_create(constraintMap->size, constraintMap->size << 1, constraintIndex);

		time = Json40_getFloat(keyMap, "time", 0);
		mix = Json40_getFloat(keyMap, "mix", 1);
		softness = Json40_getFloat(keyMap, "softness", 0) * scale;

		for (frame = 0, bezier = 0;; ++frame) {
			float time2, mix2, softness2;
			int bendDirection = Json40_getInt(keyMap, "bendPositive", 1) ? 1 : -1;
			sp40IkConstraintTimeline_setFrame(timeline, frame, time, mix, softness, bendDirection,
											Json40_getInt(keyMap, "compress", 0) ? 1 : 0,
											Json40_getInt(keyMap, "stretch", 0) ? 1 : 0);
			nextMap = keyMap->next;
			if (!nextMap) {
				/* timeline.shrink(); // BOZO */
				break;
			}

			time2 = Json40_getFloat(nextMap, "time", 0);
			mix2 = Json40_getFloat(nextMap, "mix", 1);
			softness2 = Json40_getFloat(nextMap, "softness", 0) * scale;
			curve = Json40_getItem(keyMap, "curve");
			if (curve) {
				bezier = readCurve(curve, SUPER(timeline), bezier, frame, 0, time, time2, mix, mix2, 1);
				bezier = readCurve(curve, SUPER(timeline), bezier, frame, 1, time, time2, softness, softness2, scale);
			}

			time = time2;
			mix = mix2;
			softness = softness2;
			keyMap = nextMap;
		}

		sp40TimelineArray_add(timelines, SUPER(SUPER(timeline)));
	}

	/* Transform constraint timelines. */
	for (constraintMap = transform ? transform->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp40TransformConstraintData *constraint;
		sp40TransformConstraintTimeline *timeline;
		int constraintIndex;
		float time, mixRotate, mixShearY, mixX, mixY, mixScaleX, mixScaleY;
		keyMap = constraintMap->child;
		if (keyMap == NULL) continue;

		constraint = sp40SkeletonData_findTransformConstraint(skeletonData, constraintMap->name);
		constraintIndex = findTransformConstraintIndex(self, skeletonData, constraint, timelines);
		if (constraintIndex == -1) return NULL;
		timeline = sp40TransformConstraintTimeline_create(constraintMap->size, constraintMap->size * 6, constraintIndex);

		time = Json40_getFloat(keyMap, "time", 0);
		mixRotate = Json40_getFloat(keyMap, "mixRotate", 1);
		mixShearY = Json40_getFloat(keyMap, "mixShearY", 1);
		mixX = Json40_getFloat(keyMap, "mixX", 1);
		mixY = Json40_getFloat(keyMap, "mixY", mixX);
		mixScaleX = Json40_getFloat(keyMap, "mixScaleX", 1);
		mixScaleY = Json40_getFloat(keyMap, "mixScaleY", mixScaleX);

		for (frame = 0, bezier = 0;; ++frame) {
			float time2, mixRotate2, mixShearY2, mixX2, mixY2, mixScaleX2, mixScaleY2;
			sp40TransformConstraintTimeline_setFrame(timeline, frame, time, mixRotate, mixX, mixY, mixScaleX, mixScaleY,
												   mixShearY);
			nextMap = keyMap->next;
			if (!nextMap) {
				/* timeline.shrink(); // BOZO */
				break;
			}

			time2 = Json40_getFloat(nextMap, "time", 0);
			mixRotate2 = Json40_getFloat(nextMap, "mixRotate", 1);
			mixShearY2 = Json40_getFloat(nextMap, "mixShearY", 1);
			mixX2 = Json40_getFloat(nextMap, "mixX", 1);
			mixY2 = Json40_getFloat(nextMap, "mixY", mixX2);
			mixScaleX2 = Json40_getFloat(nextMap, "mixScaleX", 1);
			mixScaleY2 = Json40_getFloat(nextMap, "mixScaleY", mixScaleX2);
			curve = Json40_getItem(keyMap, "curve");
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

		sp40TimelineArray_add(timelines, SUPER(SUPER(timeline)));
	}

	/** Path constraint timelines. */
	for (constraintMap = paths ? paths->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp40PathConstraintData *constraint = sp40SkeletonData_findPathConstraint(skeletonData, constraintMap->name);
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
				sp40PathConstraintPositionTimeline *timeline = sp40PathConstraintPositionTimeline_create(frames,
																									 frames,
																									 constraintIndex);
				sp40TimelineArray_add(timelines, readTimeline(keyMap, SUPER(timeline), 0,
															constraint->positionMode == SP_POSITION_MODE_FIXED ? scale : 1));
			} else if (strcmp(timelineName, "spacing") == 0) {
				sp40CurveTimeline1 *timeline = SUPER(
						sp40PathConstraintSpacingTimeline_create(frames, frames, constraintIndex));
				sp40TimelineArray_add(timelines, readTimeline(keyMap, timeline, 0,
															constraint->spacingMode == SP_SPACING_MODE_LENGTH ||
																			constraint->spacingMode == SP_SPACING_MODE_FIXED
																	? scale
																	: 1));
			} else if (strcmp(timelineName, "mix") == 0) {
				sp40PathConstraintMixTimeline *timeline = sp40PathConstraintMixTimeline_create(frames,
																						   frames * 3,
																						   constraintIndex);
				float time = Json40_getFloat(keyMap, "time", 0);
				float mixRotate = Json40_getFloat(keyMap, "mixRotate", 1);
				float mixX = Json40_getFloat(keyMap, "mixX", 1);
				float mixY = Json40_getFloat(keyMap, "mixY", mixX);
				for (frame = 0, bezier = 0;; ++frame) {
					float time2, mixRotate2, mixX2, mixY2;
					sp40PathConstraintMixTimeline_setFrame(timeline, frame, time, mixRotate, mixX, mixY);
					nextMap = keyMap->next;
					if (!nextMap) {
						/* timeline.shrink(); // BOZO */
						break;
					}

					time2 = Json40_getFloat(nextMap, "time", 0);
					mixRotate2 = Json40_getFloat(nextMap, "mixRotate", 1);
					mixX2 = Json40_getFloat(nextMap, "mixX", 1);
					mixY2 = Json40_getFloat(nextMap, "mixY", mixX2);
					curve = Json40_getItem(keyMap, "curve");
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
				sp40TimelineArray_add(timelines, SUPER(SUPER(timeline)));
			}
		}
	}

	/* Deform timelines. */
	for (constraintMap = deformJson ? deformJson->child : 0; constraintMap; constraintMap = constraintMap->next) {
		sp40Skin *skin = sp40SkeletonData_findSkin(skeletonData, constraintMap->name);
		for (slotMap = constraintMap->child; slotMap; slotMap = slotMap->next) {
			int slotIndex = findSlotIndex(self, skeletonData, slotMap->name, timelines);
			if (slotIndex == -1) return NULL;

			for (timelineMap = slotMap->child; timelineMap; timelineMap = timelineMap->next) {
				float *tempDeform;
				sp40VertexAttachment *attachment;
				int weighted, deformLength;
				sp40DeformTimeline *timeline;
				float time;
				keyMap = timelineMap->child;
				if (keyMap == NULL) continue;

				attachment = SUB_CAST(sp40VertexAttachment, sp40Skin_getAttachment(skin, slotIndex, timelineMap->name));
				if (!attachment) {
					cleanUpTimelines(timelines);
					_sp40SkeletonJson_setError(self, 0, "Attachment not found: ", timelineMap->name);
					return NULL;
				}
				weighted = attachment->bones != 0;
				deformLength = weighted ? attachment->verticesCount / 3 * 2 : attachment->verticesCount;
				tempDeform = MALLOC(float, deformLength);
				timeline = sp40DeformTimeline_create(timelineMap->size, deformLength, timelineMap->size, slotIndex,
												   attachment);

				time = Json40_getFloat(keyMap, "time", 0);
				for (frame = 0, bezier = 0;; ++frame) {
					Json40 *vertices = Json40_getItem(keyMap, "vertices");
					float *deform;
					float time2;

					if (!vertices) {
						if (weighted) {
							deform = tempDeform;
							memset(deform, 0, sizeof(float) * deformLength);
						} else
							deform = attachment->vertices;
					} else {
						int v, start = Json40_getInt(keyMap, "offset", 0);
						Json40 *vertex;
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
							float *verticesValues = attachment->vertices;
							for (v = 0; v < deformLength; ++v)
								deform[v] += verticesValues[v];
						}
					}
					sp40DeformTimeline_setFrame(timeline, frame, time, deform);
					nextMap = keyMap->next;
					if (!nextMap) {
						/* timeline.shrink(); // BOZO */
						break;
					}
					time2 = Json40_getFloat(nextMap, "time", 0);
					curve = Json40_getItem(keyMap, "curve");
					if (curve) {
						bezier = readCurve(curve, SUPER(timeline), bezier, frame, 0, time, time2, 0, 1, 1);
					}
					time = time2;
					keyMap = nextMap;
				}
				FREE(tempDeform);

				sp40TimelineArray_add(timelines, SUPER(SUPER(timeline)));
			}
		}
	}

	/* Draw order timeline. */
	if (drawOrderJson) {
		sp40DrawOrderTimeline *timeline = sp40DrawOrderTimeline_create(drawOrderJson->size, skeletonData->slotsCount);
		for (keyMap = drawOrderJson->child, frame = 0; keyMap; keyMap = keyMap->next, ++frame) {
			int ii;
			int *drawOrder = 0;
			Json40 *offsets = Json40_getItem(keyMap, "offsets");
			if (offsets) {
				Json40 *offsetMap;
				int *unchanged = MALLOC(int, skeletonData->slotsCount - offsets->size);
				int originalIndex = 0, unchangedIndex = 0;

				drawOrder = MALLOC(int, skeletonData->slotsCount);
				for (ii = skeletonData->slotsCount - 1; ii >= 0; --ii)
					drawOrder[ii] = -1;

				for (offsetMap = offsets->child; offsetMap; offsetMap = offsetMap->next) {
					int slotIndex = findSlotIndex(self, skeletonData, Json40_getString(offsetMap, "slot", 0), timelines);
					if (slotIndex == -1) return NULL;

					/* Collect unchanged items. */
					while (originalIndex != slotIndex)
						unchanged[unchangedIndex++] = originalIndex++;
					/* Set changed items. */
					drawOrder[originalIndex + Json40_getInt(offsetMap, "offset", 0)] = originalIndex;
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
			sp40DrawOrderTimeline_setFrame(timeline, frame, Json40_getFloat(keyMap, "time", 0), drawOrder);
			FREE(drawOrder);
		}

		sp40TimelineArray_add(timelines, SUPER(timeline));
	}

	/* Event timeline. */
	if (events) {
		sp40EventTimeline *timeline = sp40EventTimeline_create(events->size);
		for (keyMap = events->child, frame = 0; keyMap; keyMap = keyMap->next, ++frame) {
			sp40Event *event;
			const char *stringValue;
			sp40EventData *eventData = sp40SkeletonData_findEvent(skeletonData, Json40_getString(keyMap, "name", 0));
			if (!eventData) {
				cleanUpTimelines(timelines);
				_sp40SkeletonJson_setError(self, 0, "Event not found: ", Json40_getString(keyMap, "name", 0));
				return NULL;
			}
			event = sp40Event_create(Json40_getFloat(keyMap, "time", 0), eventData);
			event->intValue = Json40_getInt(keyMap, "int", eventData->intValue);
			event->floatValue = Json40_getFloat(keyMap, "float", eventData->floatValue);
			stringValue = Json40_getString(keyMap, "string", eventData->stringValue);
			if (stringValue) MALLOC_STR(event->stringValue, stringValue);
			if (eventData->audioPath) {
				event->volume = Json40_getFloat(keyMap, "volume", 1);
				event->balance = Json40_getFloat(keyMap, "volume", 0);
			}
			sp40EventTimeline_setFrame(timeline, frame, event);
		}
		sp40TimelineArray_add(timelines, SUPER(timeline));
	}

	duration = 0;
	for (i = 0, n = timelines->size; i < n; ++i)
		duration = MAX(duration, sp40Timeline_getDuration(timelines->items[i]));
	return sp40Animation_create(root->name, timelines, duration);
}

static void
_readVertices(sp40SkeletonJson *self, Json40 *attachmentMap, sp40VertexAttachment *attachment, int verticesLength) {
	Json40 *entry;
	float *vertices;
	int i, n, nn, entrySize;
	sp40FloatArray *weights;
	sp40IntArray *bones;

	attachment->worldVerticesLength = verticesLength;

	entry = Json40_getItem(attachmentMap, "vertices");
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

	weights = sp40FloatArray_create(verticesLength * 3 * 3);
	bones = sp40IntArray_create(verticesLength * 3);

	for (i = 0, n = entrySize; i < n;) {
		int boneCount = (int) vertices[i++];
		sp40IntArray_add(bones, boneCount);
		for (nn = i + boneCount * 4; i < nn; i += 4) {
			sp40IntArray_add(bones, (int) vertices[i]);
			sp40FloatArray_add(weights, vertices[i + 1] * self->scale);
			sp40FloatArray_add(weights, vertices[i + 2] * self->scale);
			sp40FloatArray_add(weights, vertices[i + 3]);
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

sp40SkeletonData *sp40SkeletonJson_readSkeletonDataFile(sp40SkeletonJson *self, const char *path) {
	int length;
	sp40SkeletonData *skeletonData;
	const char *json = _sp40Util_readFile(path, &length);
	if (length == 0 || !json) {
		_sp40SkeletonJson_setError(self, 0, "Unable to read skeleton file: ", path);
		return NULL;
	}
	skeletonData = sp40SkeletonJson_readSkeletonData(self, json);
	FREE(json);
	return skeletonData;
}

sp40SkeletonData *sp40SkeletonJson_readSkeletonData(sp40SkeletonJson *self, const char *json) {
	int i, ii;
	sp40SkeletonData *skeletonData;
	Json40 *root, *skeleton, *bones, *boneMap, *ik, *transform, *pathJson, *slots, *skins, *animations, *events;
	_sp40SkeletonJson *internal = SUB_CAST(_sp40SkeletonJson, self);

	FREE(self->error);
	CONST_CAST(char *, self->error) = 0;
	internal->linkedMeshCount = 0;

	root = Json40_create(json);
	if (!root) {
		_sp40SkeletonJson_setError(self, 0, "Invalid skeleton JSON: ", Json40_getError());
		return NULL;
	}

	skeletonData = sp40SkeletonData_create();

	skeleton = Json40_getItem(root, "skeleton");
	if (skeleton) {
		MALLOC_STR(skeletonData->hash, Json40_getString(skeleton, "hash", 0));
		MALLOC_STR(skeletonData->version, Json40_getString(skeleton, "spine", 0));
		skeletonData->x = Json40_getFloat(skeleton, "x", 0);
		skeletonData->y = Json40_getFloat(skeleton, "y", 0);
		skeletonData->width = Json40_getFloat(skeleton, "width", 0);
		skeletonData->height = Json40_getFloat(skeleton, "height", 0);
		skeletonData->fps = Json40_getFloat(skeleton, "fps", 30);
		skeletonData->imagesPath = Json40_getString(skeleton, "images", 0);
		if (skeletonData->imagesPath) {
			char *tmp = NULL;
			MALLOC_STR(tmp, skeletonData->imagesPath);
			skeletonData->imagesPath = tmp;
		}
		skeletonData->audioPath = Json40_getString(skeleton, "audio", 0);
		if (skeletonData->audioPath) {
			char *tmp = NULL;
			MALLOC_STR(tmp, skeletonData->audioPath);
			skeletonData->audioPath = tmp;
		}
	}

	/* Bones. */
	bones = Json40_getItem(root, "bones");
	skeletonData->bones = MALLOC(sp40BoneData *, bones->size);
	for (boneMap = bones->child, i = 0; boneMap; boneMap = boneMap->next, ++i) {
		sp40BoneData *data;
		const char *transformMode;
		const char *color;

		sp40BoneData *parent = 0;
		const char *parentName = Json40_getString(boneMap, "parent", 0);
		if (parentName) {
			parent = sp40SkeletonData_findBone(skeletonData, parentName);
			if (!parent) {
				sp40SkeletonData_dispose(skeletonData);
				_sp40SkeletonJson_setError(self, root, "Parent bone not found: ", parentName);
				return NULL;
			}
		}

		data = sp40BoneData_create(skeletonData->bonesCount, Json40_getString(boneMap, "name", 0), parent);
		data->length = Json40_getFloat(boneMap, "length", 0) * self->scale;
		data->x = Json40_getFloat(boneMap, "x", 0) * self->scale;
		data->y = Json40_getFloat(boneMap, "y", 0) * self->scale;
		data->rotation = Json40_getFloat(boneMap, "rotation", 0);
		data->scaleX = Json40_getFloat(boneMap, "scaleX", 1);
		data->scaleY = Json40_getFloat(boneMap, "scaleY", 1);
		data->shearX = Json40_getFloat(boneMap, "shearX", 0);
		data->shearY = Json40_getFloat(boneMap, "shearY", 0);
		transformMode = Json40_getString(boneMap, "transform", "normal");
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
		data->skinRequired = Json40_getInt(boneMap, "skin", 0) ? 1 : 0;

		color = Json40_getString(boneMap, "color", 0);
		if (color) toColor2(&data->color, color, -1);

		skeletonData->bones[i] = data;
		skeletonData->bonesCount++;
	}

	/* Slots. */
	slots = Json40_getItem(root, "slots");
	if (slots) {
		Json40 *slotMap;
		skeletonData->slotsCount = slots->size;
		skeletonData->slots = MALLOC(sp40SlotData *, slots->size);
		for (slotMap = slots->child, i = 0; slotMap; slotMap = slotMap->next, ++i) {
			sp40SlotData *data;
			const char *color;
			const char *dark;
			Json40 *item;

			const char *boneName = Json40_getString(slotMap, "bone", 0);
			sp40BoneData *boneData = sp40SkeletonData_findBone(skeletonData, boneName);
			if (!boneData) {
				sp40SkeletonData_dispose(skeletonData);
				_sp40SkeletonJson_setError(self, root, "Slot bone not found: ", boneName);
				return NULL;
			}

			data = sp40SlotData_create(i, Json40_getString(slotMap, "name", 0), boneData);

			color = Json40_getString(slotMap, "color", 0);
			if (color) {
				sp40Color_setFromFloats(&data->color,
									  toColor(color, 0),
									  toColor(color, 1),
									  toColor(color, 2),
									  toColor(color, 3));
			}

			dark = Json40_getString(slotMap, "dark", 0);
			if (dark) {
				data->darkColor = sp40Color_create();
				sp40Color_setFromFloats(data->darkColor,
									  toColor(dark, 0),
									  toColor(dark, 1),
									  toColor(dark, 2),
									  toColor(dark, 3));
			}

			item = Json40_getItem(slotMap, "attachment");
			if (item) sp40SlotData_setAttachmentName(data, item->valueString);

			item = Json40_getItem(slotMap, "blend");
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
	ik = Json40_getItem(root, "ik");
	if (ik) {
		Json40 *constraintMap;
		skeletonData->ikConstraintsCount = ik->size;
		skeletonData->ikConstraints = MALLOC(sp40IkConstraintData *, ik->size);
		for (constraintMap = ik->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char *targetName;

			sp40IkConstraintData *data = sp40IkConstraintData_create(Json40_getString(constraintMap, "name", 0));
			data->order = Json40_getInt(constraintMap, "order", 0);
			data->skinRequired = Json40_getInt(constraintMap, "skin", 0) ? 1 : 0;

			boneMap = Json40_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			data->bones = MALLOC(sp40BoneData *, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp40SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp40SkeletonData_dispose(skeletonData);
					_sp40SkeletonJson_setError(self, root, "IK bone not found: ", boneMap->valueString);
					return NULL;
				}
			}

			targetName = Json40_getString(constraintMap, "target", 0);
			data->target = sp40SkeletonData_findBone(skeletonData, targetName);
			if (!data->target) {
				sp40SkeletonData_dispose(skeletonData);
				_sp40SkeletonJson_setError(self, root, "Target bone not found: ", targetName);
				return NULL;
			}

			data->bendDirection = Json40_getInt(constraintMap, "bendPositive", 1) ? 1 : -1;
			data->compress = Json40_getInt(constraintMap, "compress", 0) ? 1 : 0;
			data->stretch = Json40_getInt(constraintMap, "stretch", 0) ? 1 : 0;
			data->uniform = Json40_getInt(constraintMap, "uniform", 0) ? 1 : 0;
			data->mix = Json40_getFloat(constraintMap, "mix", 1);
			data->softness = Json40_getFloat(constraintMap, "softness", 0) * self->scale;

			skeletonData->ikConstraints[i] = data;
		}
	}

	/* Transform constraints. */
	transform = Json40_getItem(root, "transform");
	if (transform) {
		Json40 *constraintMap;
		skeletonData->transformConstraintsCount = transform->size;
		skeletonData->transformConstraints = MALLOC(sp40TransformConstraintData *, transform->size);
		for (constraintMap = transform->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char *name;

			sp40TransformConstraintData *data = sp40TransformConstraintData_create(
					Json40_getString(constraintMap, "name", 0));
			data->order = Json40_getInt(constraintMap, "order", 0);
			data->skinRequired = Json40_getInt(constraintMap, "skin", 0) ? 1 : 0;

			boneMap = Json40_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			CONST_CAST(sp40BoneData **, data->bones) = MALLOC(sp40BoneData *, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp40SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp40SkeletonData_dispose(skeletonData);
					_sp40SkeletonJson_setError(self, root, "Transform bone not found: ", boneMap->valueString);
					return NULL;
				}
			}

			name = Json40_getString(constraintMap, "target", 0);
			data->target = sp40SkeletonData_findBone(skeletonData, name);
			if (!data->target) {
				sp40SkeletonData_dispose(skeletonData);
				_sp40SkeletonJson_setError(self, root, "Target bone not found: ", name);
				return NULL;
			}

			data->local = Json40_getInt(constraintMap, "local", 0);
			data->relative = Json40_getInt(constraintMap, "relative", 0);
			data->offsetRotation = Json40_getFloat(constraintMap, "rotation", 0);
			data->offsetX = Json40_getFloat(constraintMap, "x", 0) * self->scale;
			data->offsetY = Json40_getFloat(constraintMap, "y", 0) * self->scale;
			data->offsetScaleX = Json40_getFloat(constraintMap, "scaleX", 0);
			data->offsetScaleY = Json40_getFloat(constraintMap, "scaleY", 0);
			data->offsetShearY = Json40_getFloat(constraintMap, "shearY", 0);

			data->mixX = Json40_getFloat(constraintMap, "mixX", 1);
			data->mixY = Json40_getFloat(constraintMap, "mixY", data->mixX);
			data->mixScaleX = Json40_getFloat(constraintMap, "mixScaleX", 1);
			data->mixScaleY = Json40_getFloat(constraintMap, "mixScaleY", data->mixScaleX);
			data->mixShearY = Json40_getFloat(constraintMap, "mixShearY", 1);

			skeletonData->transformConstraints[i] = data;
		}
	}

	/* Path constraints */
	pathJson = Json40_getItem(root, "path");
	if (pathJson) {
		Json40 *constraintMap;
		skeletonData->pathConstraintsCount = pathJson->size;
		skeletonData->pathConstraints = MALLOC(sp40PathConstraintData *, pathJson->size);
		for (constraintMap = pathJson->child, i = 0; constraintMap; constraintMap = constraintMap->next, ++i) {
			const char *name;
			const char *item;

			sp40PathConstraintData *data = sp40PathConstraintData_create(Json40_getString(constraintMap, "name", 0));
			data->order = Json40_getInt(constraintMap, "order", 0);
			data->skinRequired = Json40_getInt(constraintMap, "skin", 0) ? 1 : 0;

			boneMap = Json40_getItem(constraintMap, "bones");
			data->bonesCount = boneMap->size;
			CONST_CAST(sp40BoneData **, data->bones) = MALLOC(sp40BoneData *, boneMap->size);
			for (boneMap = boneMap->child, ii = 0; boneMap; boneMap = boneMap->next, ++ii) {
				data->bones[ii] = sp40SkeletonData_findBone(skeletonData, boneMap->valueString);
				if (!data->bones[ii]) {
					sp40SkeletonData_dispose(skeletonData);
					_sp40SkeletonJson_setError(self, root, "Path bone not found: ", boneMap->valueString);
					return NULL;
				}
			}

			name = Json40_getString(constraintMap, "target", 0);
			data->target = sp40SkeletonData_findSlot(skeletonData, name);
			if (!data->target) {
				sp40SkeletonData_dispose(skeletonData);
				_sp40SkeletonJson_setError(self, root, "Target slot not found: ", name);
				return NULL;
			}

			item = Json40_getString(constraintMap, "positionMode", "percent");
			if (strcmp(item, "fixed") == 0) data->positionMode = SP_POSITION_MODE_FIXED;
			else if (strcmp(item, "percent") == 0)
				data->positionMode = SP_POSITION_MODE_PERCENT;

			item = Json40_getString(constraintMap, "spacingMode", "length");
			if (strcmp(item, "length") == 0) data->spacingMode = SP_SPACING_MODE_LENGTH;
			else if (strcmp(item, "fixed") == 0)
				data->spacingMode = SP_SPACING_MODE_FIXED;
			else if (strcmp(item, "percent") == 0)
				data->spacingMode = SP_SPACING_MODE_PERCENT;

			item = Json40_getString(constraintMap, "rotateMode", "tangent");
			if (strcmp(item, "tangent") == 0) data->rotateMode = SP_ROTATE_MODE_TANGENT;
			else if (strcmp(item, "chain") == 0)
				data->rotateMode = SP_ROTATE_MODE_CHAIN;
			else if (strcmp(item, "chainScale") == 0)
				data->rotateMode = SP_ROTATE_MODE_CHAIN_SCALE;

			data->offsetRotation = Json40_getFloat(constraintMap, "rotation", 0);
			data->position = Json40_getFloat(constraintMap, "position", 0);
			if (data->positionMode == SP_POSITION_MODE_FIXED) data->position *= self->scale;
			data->spacing = Json40_getFloat(constraintMap, "spacing", 0);
			if (data->spacingMode == SP_SPACING_MODE_LENGTH || data->spacingMode == SP_SPACING_MODE_FIXED)
				data->spacing *= self->scale;
			data->mixRotate = Json40_getFloat(constraintMap, "mixRotate", 1);
			data->mixX = Json40_getFloat(constraintMap, "mixX", 1);
			data->mixY = Json40_getFloat(constraintMap, "mixY", data->mixX);

			skeletonData->pathConstraints[i] = data;
		}
	}

	/* Skins. */
	skins = Json40_getItem(root, "skins");
	if (skins) {
		Json40 *skinMap;
		skeletonData->skins = MALLOC(sp40Skin *, skins->size);
		for (skinMap = skins->child, i = 0; skinMap; skinMap = skinMap->next, ++i) {
			Json40 *attachmentsMap;
			Json40 *curves;
			Json40 *skinPart;
			sp40Skin *skin = sp40Skin_create(Json40_getString(skinMap, "name", ""));

			skinPart = Json40_getItem(skinMap, "bones");
			if (skinPart) {
				for (skinPart = skinPart->child; skinPart; skinPart = skinPart->next) {
					sp40BoneData *bone = sp40SkeletonData_findBone(skeletonData, skinPart->valueString);
					if (!bone) {
						sp40SkeletonData_dispose(skeletonData);
						_sp40SkeletonJson_setError(self, root, "Skin bone constraint not found: ", skinPart->valueString);
						return NULL;
					}
					sp40BoneDataArray_add(skin->bones, bone);
				}
			}

			skinPart = Json40_getItem(skinMap, "ik");
			if (skinPart) {
				for (skinPart = skinPart->child; skinPart; skinPart = skinPart->next) {
					sp40IkConstraintData *constraint = sp40SkeletonData_findIkConstraint(skeletonData,
																					 skinPart->valueString);
					if (!constraint) {
						sp40SkeletonData_dispose(skeletonData);
						_sp40SkeletonJson_setError(self, root, "Skin IK constraint not found: ", skinPart->valueString);
						return NULL;
					}
					sp40IkConstraintDataArray_add(skin->ikConstraints, constraint);
				}
			}

			skinPart = Json40_getItem(skinMap, "path");
			if (skinPart) {
				for (skinPart = skinPart->child; skinPart; skinPart = skinPart->next) {
					sp40PathConstraintData *constraint = sp40SkeletonData_findPathConstraint(skeletonData,
																						 skinPart->valueString);
					if (!constraint) {
						sp40SkeletonData_dispose(skeletonData);
						_sp40SkeletonJson_setError(self, root, "Skin path constraint not found: ", skinPart->valueString);
						return NULL;
					}
					sp40PathConstraintDataArray_add(skin->pathConstraints, constraint);
				}
			}

			skinPart = Json40_getItem(skinMap, "transform");
			if (skinPart) {
				for (skinPart = skinPart->child; skinPart; skinPart = skinPart->next) {
					sp40TransformConstraintData *constraint = sp40SkeletonData_findTransformConstraint(skeletonData,
																								   skinPart->valueString);
					if (!constraint) {
						sp40SkeletonData_dispose(skeletonData);
						_sp40SkeletonJson_setError(self, root, "Skin transform constraint not found: ",
												 skinPart->valueString);
						return NULL;
					}
					sp40TransformConstraintDataArray_add(skin->transformConstraints, constraint);
				}
			}

			skeletonData->skins[skeletonData->skinsCount++] = skin;
			if (strcmp(skin->name, "default") == 0) skeletonData->defaultSkin = skin;

			for (attachmentsMap = Json40_getItem(skinMap,
											   "attachments")
										  ->child;
				 attachmentsMap; attachmentsMap = attachmentsMap->next) {
				sp40SlotData *slot = sp40SkeletonData_findSlot(skeletonData, attachmentsMap->name);
				Json40 *attachmentMap;

				for (attachmentMap = attachmentsMap->child; attachmentMap; attachmentMap = attachmentMap->next) {
					sp40Attachment *attachment;
					const char *skinAttachmentName = attachmentMap->name;
					const char *attachmentName = Json40_getString(attachmentMap, "name", skinAttachmentName);
					const char *path = Json40_getString(attachmentMap, "path", attachmentName);
					const char *color;
					Json40 *entry;

					const char *typeString = Json40_getString(attachmentMap, "type", "region");
					sp40AttachmentType type;
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
						sp40SkeletonData_dispose(skeletonData);
						_sp40SkeletonJson_setError(self, root, "Unknown attachment type: ", typeString);
						return NULL;
					}

					attachment = sp40AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, attachmentName,
																	 path);
					if (!attachment) {
						if (self->attachmentLoader->error1) {
							sp40SkeletonData_dispose(skeletonData);
							_sp40SkeletonJson_setError(self, root, self->attachmentLoader->error1,
													 self->attachmentLoader->error2);
							return NULL;
						}
						continue;
					}

					switch (attachment->type) {
						case SP_ATTACHMENT_REGION: {
							sp40RegionAttachment *region = SUB_CAST(sp40RegionAttachment, attachment);
							if (path) MALLOC_STR(region->path, path);
							region->x = Json40_getFloat(attachmentMap, "x", 0) * self->scale;
							region->y = Json40_getFloat(attachmentMap, "y", 0) * self->scale;
							region->scaleX = Json40_getFloat(attachmentMap, "scaleX", 1);
							region->scaleY = Json40_getFloat(attachmentMap, "scaleY", 1);
							region->rotation = Json40_getFloat(attachmentMap, "rotation", 0);
							region->width = Json40_getFloat(attachmentMap, "width", 32) * self->scale;
							region->height = Json40_getFloat(attachmentMap, "height", 32) * self->scale;

							color = Json40_getString(attachmentMap, "color", 0);
							if (color) {
								sp40Color_setFromFloats(&region->color,
													  toColor(color, 0),
													  toColor(color, 1),
													  toColor(color, 2),
													  toColor(color, 3));
							}

							sp40RegionAttachment_updateOffset(region);

							sp40AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
							break;
						}
						case SP_ATTACHMENT_MESH:
						case SP_ATTACHMENT_LINKED_MESH: {
							sp40MeshAttachment *mesh = SUB_CAST(sp40MeshAttachment, attachment);

							MALLOC_STR(mesh->path, path);

							color = Json40_getString(attachmentMap, "color", 0);
							if (color) {
								sp40Color_setFromFloats(&mesh->color,
													  toColor(color, 0),
													  toColor(color, 1),
													  toColor(color, 2),
													  toColor(color, 3));
							}

							mesh->width = Json40_getFloat(attachmentMap, "width", 32) * self->scale;
							mesh->height = Json40_getFloat(attachmentMap, "height", 32) * self->scale;

							entry = Json40_getItem(attachmentMap, "parent");
							if (!entry) {
								int verticesLength;
								entry = Json40_getItem(attachmentMap, "triangles");
								mesh->trianglesCount = entry->size;
								mesh->triangles = MALLOC(unsigned short, entry->size);
								for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
									mesh->triangles[ii] = (unsigned short) entry->valueInt;

								entry = Json40_getItem(attachmentMap, "uvs");
								verticesLength = entry->size;
								mesh->regionUVs = MALLOC(float, verticesLength);
								for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
									mesh->regionUVs[ii] = entry->valueFloat;

								_readVertices(self, attachmentMap, SUPER(mesh), verticesLength);

								sp40MeshAttachment_updateUVs(mesh);

								mesh->hullLength = Json40_getInt(attachmentMap, "hull", 0);

								entry = Json40_getItem(attachmentMap, "edges");
								if (entry) {
									mesh->edgesCount = entry->size;
									mesh->edges = MALLOC(int, entry->size);
									for (entry = entry->child, ii = 0; entry; entry = entry->next, ++ii)
										mesh->edges[ii] = entry->valueInt;
								}

								sp40AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
							} else {
								int inheritDeform = Json40_getInt(attachmentMap, "deform", 1);
								_sp40SkeletonJson_addLinkedMesh(self, SUB_CAST(sp40MeshAttachment, attachment),
															  Json40_getString(attachmentMap, "skin", 0), slot->index,
															  entry->valueString, inheritDeform);
							}
							break;
						}
						case SP_ATTACHMENT_BOUNDING_BOX: {
							sp40BoundingBoxAttachment *box = SUB_CAST(sp40BoundingBoxAttachment, attachment);
							int vertexCount = Json40_getInt(attachmentMap, "vertexCount", 0) << 1;
							_readVertices(self, attachmentMap, SUPER(box), vertexCount);
							box->super.verticesCount = vertexCount;
							color = Json40_getString(attachmentMap, "color", 0);
							if (color) {
								sp40Color_setFromFloats(&box->color,
													  toColor(color, 0),
													  toColor(color, 1),
													  toColor(color, 2),
													  toColor(color, 3));
							}
							sp40AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
							break;
						}
						case SP_ATTACHMENT_PATH: {
							sp40PathAttachment *pathAttachment = SUB_CAST(sp40PathAttachment, attachment);
							int vertexCount = 0;
							pathAttachment->closed = Json40_getInt(attachmentMap, "closed", 0);
							pathAttachment->constantSpeed = Json40_getInt(attachmentMap, "constantSpeed", 1);
							vertexCount = Json40_getInt(attachmentMap, "vertexCount", 0);
							_readVertices(self, attachmentMap, SUPER(pathAttachment), vertexCount << 1);

							pathAttachment->lengthsLength = vertexCount / 3;
							pathAttachment->lengths = MALLOC(float, pathAttachment->lengthsLength);

							curves = Json40_getItem(attachmentMap, "lengths");
							for (curves = curves->child, ii = 0; curves; curves = curves->next, ++ii)
								pathAttachment->lengths[ii] = curves->valueFloat * self->scale;
							color = Json40_getString(attachmentMap, "color", 0);
							if (color) {
								sp40Color_setFromFloats(&pathAttachment->color,
													  toColor(color, 0),
													  toColor(color, 1),
													  toColor(color, 2),
													  toColor(color, 3));
							}
							break;
						}
						case SP_ATTACHMENT_POINT: {
							sp40PointAttachment *point = SUB_CAST(sp40PointAttachment, attachment);
							point->x = Json40_getFloat(attachmentMap, "x", 0) * self->scale;
							point->y = Json40_getFloat(attachmentMap, "y", 0) * self->scale;
							point->rotation = Json40_getFloat(attachmentMap, "rotation", 0);

							color = Json40_getString(attachmentMap, "color", 0);
							if (color) {
								sp40Color_setFromFloats(&point->color,
													  toColor(color, 0),
													  toColor(color, 1),
													  toColor(color, 2),
													  toColor(color, 3));
							}
							break;
						}
						case SP_ATTACHMENT_CLIPPING: {
							sp40ClippingAttachment *clip = SUB_CAST(sp40ClippingAttachment, attachment);
							int vertexCount = 0;
							const char *end = Json40_getString(attachmentMap, "end", 0);
							if (end) {
								sp40SlotData *endSlot = sp40SkeletonData_findSlot(skeletonData, end);
								clip->endSlot = endSlot;
							}
							vertexCount = Json40_getInt(attachmentMap, "vertexCount", 0) << 1;
							_readVertices(self, attachmentMap, SUPER(clip), vertexCount);
							color = Json40_getString(attachmentMap, "color", 0);
							if (color) {
								sp40Color_setFromFloats(&clip->color,
													  toColor(color, 0),
													  toColor(color, 1),
													  toColor(color, 2),
													  toColor(color, 3));
							}
							sp40AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
							break;
						}
					}

					sp40Skin_setAttachment(skin, slot->index, skinAttachmentName, attachment);
				}
			}
		}
	}

	/* Linked meshes. */
	for (i = 0; i < internal->linkedMeshCount; ++i) {
		sp40Attachment *parent;
		_sp40LinkedMesh *linkedMesh = internal->linkedMeshes + i;
		sp40Skin *skin = !linkedMesh->skin ? skeletonData->defaultSkin : sp40SkeletonData_findSkin(skeletonData, linkedMesh->skin);
		if (!skin) {
			sp40SkeletonData_dispose(skeletonData);
			_sp40SkeletonJson_setError(self, 0, "Skin not found: ", linkedMesh->skin);
			return NULL;
		}
		parent = sp40Skin_getAttachment(skin, linkedMesh->slotIndex, linkedMesh->parent);
		if (!parent) {
			sp40SkeletonData_dispose(skeletonData);
			_sp40SkeletonJson_setError(self, 0, "Parent mesh not found: ", linkedMesh->parent);
			return NULL;
		}
		linkedMesh->mesh->super.deformAttachment = linkedMesh->inheritDeform ? SUB_CAST(sp40VertexAttachment, parent)
																			 : SUB_CAST(sp40VertexAttachment,
																						linkedMesh->mesh);
		sp40MeshAttachment_setParentMesh(linkedMesh->mesh, SUB_CAST(sp40MeshAttachment, parent));
		sp40MeshAttachment_updateUVs(linkedMesh->mesh);
		sp40AttachmentLoader_configureAttachment(self->attachmentLoader, SUPER(SUPER(linkedMesh->mesh)));
	}

	/* Events. */
	events = Json40_getItem(root, "events");
	if (events) {
		Json40 *eventMap;
		const char *stringValue;
		const char *audioPath;
		skeletonData->eventsCount = events->size;
		skeletonData->events = MALLOC(sp40EventData *, events->size);
		for (eventMap = events->child, i = 0; eventMap; eventMap = eventMap->next, ++i) {
			sp40EventData *eventData = sp40EventData_create(eventMap->name);
			eventData->intValue = Json40_getInt(eventMap, "int", 0);
			eventData->floatValue = Json40_getFloat(eventMap, "float", 0);
			stringValue = Json40_getString(eventMap, "string", 0);
			if (stringValue) MALLOC_STR(eventData->stringValue, stringValue);
			audioPath = Json40_getString(eventMap, "audio", 0);
			if (audioPath) {
				MALLOC_STR(eventData->audioPath, audioPath);
				eventData->volume = Json40_getFloat(eventMap, "volume", 1);
				eventData->balance = Json40_getFloat(eventMap, "balance", 0);
			}
			skeletonData->events[i] = eventData;
		}
	}

	/* Animations. */
	animations = Json40_getItem(root, "animations");
	if (animations) {
		Json40 *animationMap;
		skeletonData->animations = MALLOC(sp40Animation *, animations->size);
		for (animationMap = animations->child; animationMap; animationMap = animationMap->next) {
			sp40Animation *animation = _sp40SkeletonJson_readAnimation(self, animationMap, skeletonData);
			if (!animation) {
				sp40SkeletonData_dispose(skeletonData);
				return NULL;
			}
			skeletonData->animations[skeletonData->animationsCount++] = animation;
		}
	}

	Json40_dispose(root);
	return skeletonData;
}

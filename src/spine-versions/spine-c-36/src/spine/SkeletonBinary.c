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

#include <spine/SkeletonBinary.h>
#include <stdio.h>
#include <spine/extension.h>
#include <spine/AtlasAttachmentLoader.h>
#include <spine/Animation.h>
#include "kvec.h"

typedef struct {
	const unsigned char* cursor; 
	const unsigned char* end;
} _dataInput;

typedef struct {
	const char* parent;
	const char* skin;
	int slotIndex;
	sp36MeshAttachment* mesh;
} _sp36LinkedMesh;

typedef struct {
	sp36SkeletonBinary super;
	int ownsLoader;

	int linkedMeshCount;
	int linkedMeshCapacity;
	_sp36LinkedMesh* linkedMeshes;
} _sp36SkeletonBinary;

sp36SkeletonBinary* sp36SkeletonBinary_createWithLoader (sp36AttachmentLoader* attachmentLoader) {
	sp36SkeletonBinary* self = SUPER(NEW(_sp36SkeletonBinary));
	self->scale = 1;
	self->attachmentLoader = attachmentLoader;
	return self;
}

sp36SkeletonBinary* sp36SkeletonBinary_create (sp36Atlas* atlas) {
	sp36AtlasAttachmentLoader* attachmentLoader = sp36AtlasAttachmentLoader_create(atlas);
	sp36SkeletonBinary* self = sp36SkeletonBinary_createWithLoader(SUPER(attachmentLoader));
	SUB_CAST(_sp36SkeletonBinary, self)->ownsLoader = 1;
	return self;
}

void sp36SkeletonBinary_dispose (sp36SkeletonBinary* self) {
	int i;
	_sp36SkeletonBinary* internal = SUB_CAST(_sp36SkeletonBinary, self);
	if (internal->ownsLoader) sp36AttachmentLoader_dispose(self->attachmentLoader);
	for (i = 0; i < internal->linkedMeshCount; ++i) {
		FREE(internal->linkedMeshes[i].parent);
		FREE(internal->linkedMeshes[i].skin);
	}
	FREE(internal->linkedMeshes);
	FREE(self->error);
	FREE(self);
}

void _sp36SkeletonBinary_setError (sp36SkeletonBinary* self, const char* value1, const char* value2) {
	char message[256];
	int length;
	FREE(self->error);
	strcpy(message, value1);
	length = (int)strlen(value1);
	if (value2) strncat(message + length, value2, 255 - length);
	MALLOC_STR(self->error, message);
}

static unsigned char readByte (_dataInput* input) {
	return *input->cursor++;
}

static signed char readSByte (_dataInput* input) {
	return (signed char)readByte(input);
}

static int readBoolean (_dataInput* input) {
	return readByte(input) != 0;
}

static int readInt (_dataInput* input) {
	int result = readByte(input);
	result <<= 8;
	result |= readByte(input);
	result <<= 8;
	result |= readByte(input);
	result <<= 8;
	result |= readByte(input);
	return result;
}

static int readVarint (_dataInput* input, int/*bool*/optimizePositive) {
	unsigned char b = readByte(input);
	int value = b & 0x7F;
	if (b & 0x80) {
		b = readByte(input);
		value |= (b & 0x7F) << 7;
		if (b & 0x80) {
				b = readByte(input);
				value |= (b & 0x7F) << 14;
				if (b & 0x80) {
					b = readByte(input);
					value |= (b & 0x7F) << 21;
					if (b & 0x80) value |= (readByte(input) & 0x7F) << 28;
				}
		}
	}
	if (!optimizePositive) value = (((unsigned int)value >> 1) ^ -(value & 1));
	return value;
}

static float readFloat (_dataInput* input) {
	union {
		int intValue;
		float floatValue;
	} intToFloat;
	intToFloat.intValue = readInt(input);
	return intToFloat.floatValue;
}

static char* readString (_dataInput* input) {
	int length = readVarint(input, 1);
	char* string;
	if (length == 0) {
		return 0;
	}
	string = MALLOC(char, length);
	memcpy(string, input->cursor, length - 1);
	input->cursor += length - 1;
	string[length - 1] = '\0';
	return string;
}

static void readColor (_dataInput* input, float *r, float *g, float *b, float *a) {
	*r = readByte(input) / 255.0f;
	*g = readByte(input) / 255.0f;
	*b = readByte(input) / 255.0f;
	*a = readByte(input) / 255.0f;
}

#define ATTACHMENT_REGION 0
#define ATTACHMENT_BOUNDING_BOX 1
#define ATTACHMENT_MESH 2
#define ATTACHMENT_LINKED_MESH 3
#define ATTACHMENT_PATH 4

#define BLEND_MODE_NORMAL 0
#define BLEND_MODE_ADDITIVE 1
#define BLEND_MODE_MULTIPLY 2
#define BLEND_MODE_SCREEN 3

#define CURVE_LINEAR 0
#define CURVE_STEPPED 1
#define CURVE_BEZIER 2

#define BONE_ROTATE 0
#define BONE_TRANSLATE 1
#define BONE_SCALE 2
#define BONE_SHEAR 3

#define SLOT_ATTACHMENT 0
#define SLOT_COLOR 1
#define SLOT_TWO_COLOR 2

#define PATH_POSITION 0
#define PATH_SPACING 1
#define PATH_MIX 2

#define PATH_POSITION_FIXED 0
#define PATH_POSITION_PERCENT 1

#define PATH_SPACING_LENGTH 0
#define PATH_SPACING_FIXED 1
#define PATH_SPACING_PERCENT 2

#define PATH_ROTATE_TANGENT 0
#define PATH_ROTATE_CHAIN 1
#define PATH_ROTATE_CHAIN_SCALE 2

static void readCurve (_dataInput* input, sp36CurveTimeline* timeline, int frameIndex) {
	switch (readByte(input)) {
		case CURVE_STEPPED: {
			sp36CurveTimeline_setStepped(timeline, frameIndex);
			break;
		}
		case CURVE_BEZIER: {
			float cx1 = readFloat(input);
			float cy1 = readFloat(input);
			float cx2 = readFloat(input);
			float cy2 = readFloat(input);
			sp36CurveTimeline_setCurve(timeline, frameIndex, cx1, cy1, cx2, cy2);
			break;
		}
	}
}

static void _sp36SkeletonBinary_addLinkedMesh (sp36SkeletonBinary* self, sp36MeshAttachment* mesh,
		const char* skin, int slotIndex, const char* parent) {
	_sp36LinkedMesh* linkedMesh;
	_sp36SkeletonBinary* internal = SUB_CAST(_sp36SkeletonBinary, self);

	if (internal->linkedMeshCount == internal->linkedMeshCapacity) {
		_sp36LinkedMesh* linkedMeshes;
		internal->linkedMeshCapacity *= 2;
		if (internal->linkedMeshCapacity < 8) internal->linkedMeshCapacity = 8;
		/* TODO Why not realloc? */
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

static sp36Animation* _sp36SkeletonBinary_readAnimation (sp36SkeletonBinary* self, const char* name,
		_dataInput* input, sp36SkeletonData *skeletonData) {
	kvec_t(sp36Timeline*) timelines;
	float duration = 0;
	int i, n, ii, nn, iii, nnn;
	int frameIndex;
	int drawOrderCount, eventCount;
	sp36Animation* animation;

	kv_init(timelines);

	/* Slot timelines. */
	for (i = 0, n = readVarint(input, 1); i < n; ++i) {
		int slotIndex = readVarint(input, 1);
		for (ii = 0, nn = readVarint(input, 1); ii < nn; ++ii) {
			unsigned char timelineType = readByte(input);
			int frameCount = readVarint(input, 1);
			switch (timelineType) {
				case SLOT_ATTACHMENT: {
					sp36AttachmentTimeline* timeline = sp36AttachmentTimeline_create(frameCount);
					timeline->slotIndex = slotIndex;
					for (frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
						float time = readFloat(input);
						const char* attachmentName = readString(input);
						/* TODO Avoid copying of attachmentName inside */
						sp36AttachmentTimeline_setFrame(timeline, frameIndex, time, attachmentName);
						FREE(attachmentName);
					}
					kv_push(sp36Timeline*, timelines, SUPER(timeline));
					duration = MAX(duration, timeline->frames[frameCount - 1]);
					break;
				}
				case SLOT_COLOR: {
					sp36ColorTimeline* timeline = sp36ColorTimeline_create(frameCount);
					timeline->slotIndex = slotIndex;
					for (frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
						float time = readFloat(input);
						float r, g, b, a;
						readColor(input, &r, &g, &b, &a);
						sp36ColorTimeline_setFrame(timeline, frameIndex, time, r, g, b, a);
						if (frameIndex < frameCount - 1) readCurve(input, SUPER(timeline), frameIndex);
					}
					kv_push(sp36Timeline*, timelines, SUPER(SUPER(timeline)));
					duration = MAX(duration, timeline->frames[(frameCount - 1) * COLOR_ENTRIES]);
					break;
				}
				case SLOT_TWO_COLOR: {
					sp36TwoColorTimeline* timeline = sp36TwoColorTimeline_create(frameCount);
					timeline->slotIndex = slotIndex;
					for (frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
						float time = readFloat(input);
						float r, g, b, a;
						float r2, g2, b2, a2;
						readColor(input, &r, &g, &b, &a);
						readColor(input, &a2, &r2, &g2, &b2);
						sp36TwoColorTimeline_setFrame(timeline, frameIndex, time, r, g, b, a, r2, g2, b2);
						if (frameIndex < frameCount - 1) readCurve(input, SUPER(timeline), frameIndex);
					}
					kv_push(sp36Timeline*, timelines, SUPER(SUPER(timeline)));
					duration = MAX(duration, timeline->frames[(frameCount - 1) * TWOCOLOR_ENTRIES]);
					break;
				}
				default: {
					int i;
					for (i = 0; i < kv_size(timelines); ++i)
						sp36Timeline_dispose(kv_A(timelines, i));
					kv_destroy(timelines);
					_sp36SkeletonBinary_setError(self, "Invalid timeline type for a slot: ", skeletonData->slots[slotIndex]->name);
					return 0;
				}
			}
		}
	}

	/* Bone timelines. */
	for (i = 0, n = readVarint(input, 1); i < n; ++i) {
		int boneIndex = readVarint(input, 1);
		for (ii = 0, nn = readVarint(input, 1); ii < nn; ++ii) {
			unsigned char timelineType = readByte(input);
			int frameCount = readVarint(input, 1);
			switch (timelineType) {
				case BONE_ROTATE: {
					sp36RotateTimeline *timeline = sp36RotateTimeline_create(frameCount);
					timeline->boneIndex = boneIndex;
					for (frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
						float time = readFloat(input);
						float degrees = readFloat(input);
						sp36RotateTimeline_setFrame(timeline, frameIndex, time, degrees);
						if (frameIndex < frameCount - 1) readCurve(input, SUPER(timeline), frameIndex);
					}
					kv_push(sp36Timeline*, timelines, SUPER(SUPER(timeline)));
					duration = MAX(duration, timeline->frames[(frameCount - 1) * ROTATE_ENTRIES]);
					break;
				}
				case BONE_TRANSLATE:
				case BONE_SCALE:
				case BONE_SHEAR: {
					float timelineScale = 1;
					sp36TranslateTimeline *timeline = 0;
					switch (timelineType) {
						case BONE_SCALE:
							timeline = sp36ScaleTimeline_create(frameCount);
							break;
						case BONE_SHEAR:
							timeline = sp36ShearTimeline_create(frameCount);
							break;
						case BONE_TRANSLATE:
							timeline = sp36TranslateTimeline_create(frameCount);
							timelineScale = self->scale;
							break;
						default:
							break;
					}
					timeline->boneIndex = boneIndex;
					for (frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
						float time = readFloat(input);
						float x = readFloat(input) * timelineScale;
						float y = readFloat(input) * timelineScale;
						sp36TranslateTimeline_setFrame(timeline, frameIndex, time, x, y);
						if (frameIndex < frameCount - 1) readCurve(input, SUPER(timeline), frameIndex);
					}
					kv_push(sp36Timeline*, timelines, SUPER_CAST(sp36Timeline, timeline));
					duration = MAX(duration, timeline->frames[(frameCount - 1) * TRANSLATE_ENTRIES]);
					break;
				}
				default: {
					int i;
					for (i = 0; i < kv_size(timelines); ++i)
						sp36Timeline_dispose(kv_A(timelines, i));
					kv_destroy(timelines);
					_sp36SkeletonBinary_setError(self, "Invalid timeline type for a bone: ", skeletonData->bones[boneIndex]->name);
					return 0;
				}
			}
		}
	}

	/* IK constraint timelines. */
	for (i = 0, n = readVarint(input, 1); i < n; ++i) {
		int index = readVarint(input, 1);
		int frameCount = readVarint(input, 1);
		sp36IkConstraintTimeline* timeline = sp36IkConstraintTimeline_create(frameCount);
		timeline->ikConstraintIndex = index;
		for (frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
			float time = readFloat(input);
			float mix = readFloat(input);
			signed char bendDirection = readSByte(input);
			sp36IkConstraintTimeline_setFrame(timeline, frameIndex, time, mix, bendDirection);
			if (frameIndex < frameCount - 1) readCurve(input, SUPER(timeline), frameIndex);
		}
		kv_push(sp36Timeline*, timelines, SUPER(SUPER(timeline)));
		duration = MAX(duration, timeline->frames[(frameCount - 1) * IKCONSTRAINT_ENTRIES]);
	}

	/* Transform constraint timelines. */
	for (i = 0, n = readVarint(input, 1); i < n; ++i) {
		int index = readVarint(input, 1);
		int frameCount = readVarint(input, 1);
		sp36TransformConstraintTimeline* timeline = sp36TransformConstraintTimeline_create(frameCount);
		timeline->transformConstraintIndex = index;
		for (frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
			float time = readFloat(input);
			float rotateMix = readFloat(input);
			float translateMix = readFloat(input);
			float scaleMix = readFloat(input);
			float shearMix = readFloat(input);
			sp36TransformConstraintTimeline_setFrame(timeline, frameIndex, time, rotateMix, translateMix,
					scaleMix, shearMix);
			if (frameIndex < frameCount - 1) readCurve(input, SUPER(timeline), frameIndex);
		}
		kv_push(sp36Timeline*, timelines, SUPER(SUPER(timeline)));
		duration = MAX(duration, timeline->frames[(frameCount - 1) * TRANSFORMCONSTRAINT_ENTRIES]);
	}

	/* Path constraint timelines. */
	for (i = 0, n = readVarint(input, 1); i < n; ++i) {
		int index = readVarint(input, 1);
		sp36PathConstraintData* data = skeletonData->pathConstraints[index];
		for (ii = 0, nn = readVarint(input, 1); ii < nn; ++ii) {
			unsigned char timelineType = readByte(input);
			int frameCount = readVarint(input, 1);
			switch (timelineType) {
				case PATH_POSITION:
				case PATH_SPACING: {
					sp36PathConstraintPositionTimeline* timeline = 0;
					float timelineScale = 1;
					if (timelineType == PATH_SPACING) {
						timeline = (sp36PathConstraintPositionTimeline*)sp36PathConstraintSpacingTimeline_create(frameCount);
						if (data->spacingMode == SP_SPACING_MODE_LENGTH || data->spacingMode == SP_SPACING_MODE_FIXED)
							timelineScale = self->scale;
					} else {
						timeline = sp36PathConstraintPositionTimeline_create(frameCount);
						if (data->positionMode == SP_POSITION_MODE_FIXED)
							timelineScale = self->scale;
					}
					timeline->pathConstraintIndex = index;
					for (frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
						float time = readFloat(input);
						float value = readFloat(input) * timelineScale;
						sp36PathConstraintPositionTimeline_setFrame(timeline, frameIndex, time, value);
						if (frameIndex < frameCount - 1) readCurve(input, SUPER(timeline), frameIndex);
					}
					kv_push(sp36Timeline*, timelines, SUPER(SUPER(timeline)));
					duration = MAX(duration, timeline->frames[(frameCount - 1) * PATHCONSTRAINTPOSITION_ENTRIES]);
					break;
				}
				case PATH_MIX: {
					sp36PathConstraintMixTimeline* timeline = sp36PathConstraintMixTimeline_create(frameCount);
					timeline->pathConstraintIndex = index;
					for (frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
						float time = readFloat(input);
						float rotateMix = readFloat(input);
						float translateMix = readFloat(input);
						sp36PathConstraintMixTimeline_setFrame(timeline, frameIndex, time, rotateMix, translateMix);
						if (frameIndex < frameCount - 1) readCurve(input, SUPER(timeline), frameIndex);
					}
					kv_push(sp36Timeline*, timelines, SUPER(SUPER(timeline)));
					duration = MAX(duration, timeline->frames[(frameCount - 1) * PATHCONSTRAINTMIX_ENTRIES]);
				}
			}
		}
	}

	/* Deform timelines. */
	for (i = 0, n = readVarint(input, 1); i < n; ++i) {
		sp36Skin* skin = skeletonData->skins[readVarint(input, 1)];
		for (ii = 0, nn = readVarint(input, 1); ii < nn; ++ii) {
			int slotIndex = readVarint(input, 1);
			for (iii = 0, nnn = readVarint(input, 1); iii < nnn; ++iii) {
				float* tempDeform;
				sp36DeformTimeline *timeline;
				int weighted, deformLength;
				const char* attachmentName = readString(input);
				int frameCount;

				sp36VertexAttachment* attachment = SUB_CAST(sp36VertexAttachment,
						sp36Skin_getAttachment(skin, slotIndex, attachmentName));
				if (!attachment) {
					int i;
					for (i = 0; i < kv_size(timelines); ++i)
						sp36Timeline_dispose(kv_A(timelines, i));
					kv_destroy(timelines);
					_sp36SkeletonBinary_setError(self, "Attachment not found: ", attachmentName);
					FREE(attachmentName);
					return 0;
				}
				FREE(attachmentName);

				weighted = attachment->bones != 0;
				deformLength = weighted ? attachment->verticesCount / 3 * 2 : attachment->verticesCount;
				tempDeform = MALLOC(float, deformLength);

				frameCount = readVarint(input, 1);
				timeline = sp36DeformTimeline_create(frameCount, deformLength);
				timeline->slotIndex = slotIndex;
				timeline->attachment = SUPER(attachment);

				for (frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
					float time = readFloat(input);
					float* deform;
					int end = readVarint(input, 1);
					if (!end) {
						if (weighted) {
							deform = tempDeform;
							memset(deform, 0, sizeof(float) * deformLength);
						} else
							deform = attachment->vertices;
					} else {
						int v, start = readVarint(input, 1);
						deform = tempDeform;
						memset(deform, 0, sizeof(float) * start);
						end += start;
						if (self->scale == 1) {
							for (v = start; v < end; ++v)
								deform[v] = readFloat(input);
						} else {
							for (v = start; v < end; ++v)
								deform[v] = readFloat(input) * self->scale;
						}
						memset(deform + v, 0, sizeof(float) * (deformLength - v));
						if (!weighted) {
							float* vertices = attachment->vertices;
							for (v = 0; v < deformLength; ++v)
								deform[v] += vertices[v];
						}
					}
					sp36DeformTimeline_setFrame(timeline, frameIndex, time, deform);
					if (frameIndex < frameCount - 1) readCurve(input, SUPER(timeline), frameIndex);
				}
				FREE(tempDeform);

				kv_push(sp36Timeline*, timelines, SUPER(SUPER(timeline)));
				duration = MAX(duration, timeline->frames[frameCount - 1]);
			}
		}
	}

	/* Draw order timeline. */
	drawOrderCount = readVarint(input, 1);
	if (drawOrderCount) {
		sp36DrawOrderTimeline* timeline = sp36DrawOrderTimeline_create(drawOrderCount, skeletonData->slotsCount);
		for (i = 0; i < drawOrderCount; ++i) {
			float time = readFloat(input);
			int offsetCount = readVarint(input, 1);
			int* drawOrder = MALLOC(int, skeletonData->slotsCount);
			int* unchanged = MALLOC(int, skeletonData->slotsCount - offsetCount);
			int originalIndex = 0, unchangedIndex = 0;
			memset(drawOrder, -1, sizeof(int) * skeletonData->slotsCount);
			for (ii = 0; ii < offsetCount; ++ii) {
				int slotIndex = readVarint(input, 1);
				/* Collect unchanged items. */
				while (originalIndex != slotIndex)
					unchanged[unchangedIndex++] = originalIndex++;
				/* Set changed items. */
				drawOrder[originalIndex + readVarint(input, 1)] = originalIndex;
				++originalIndex;
			}
			/* Collect remaining unchanged items. */
			while (originalIndex < skeletonData->slotsCount)
				unchanged[unchangedIndex++] = originalIndex++;
			/* Fill in unchanged items. */
			for (ii = skeletonData->slotsCount - 1; ii >= 0; ii--)
				if (drawOrder[ii] == -1) drawOrder[ii] = unchanged[--unchangedIndex];
			FREE(unchanged);
			/* TODO Avoid copying of drawOrder inside */
			sp36DrawOrderTimeline_setFrame(timeline, i, time, drawOrder);
			FREE(drawOrder);
		}
		kv_push(sp36Timeline*, timelines, SUPER(timeline));
		duration = MAX(duration, timeline->frames[drawOrderCount - 1]);
	}

	/* Event timeline. */
	eventCount = readVarint(input, 1);
	if (eventCount) {
		sp36EventTimeline* timeline = sp36EventTimeline_create(eventCount);
		for (i = 0; i < eventCount; ++i) {
			float time = readFloat(input);
			sp36EventData* eventData = skeletonData->events[readVarint(input, 1)];
			sp36Event* event = sp36Event_create(time, eventData);
			event->intValue = readVarint(input, 0);
			event->floatValue = readFloat(input);
			if (readBoolean(input))
				event->stringValue = readString(input);
			else
				MALLOC_STR(event->stringValue, eventData->stringValue);
			sp36EventTimeline_setFrame(timeline, i, event);
		}
		kv_push(sp36Timeline*, timelines, SUPER(timeline));
		duration = MAX(duration, timeline->frames[eventCount - 1]);
	}

	kv_trim(sp36Timeline*, timelines);

	animation = sp36Animation_create(name, 0);
	FREE(animation->timelines);
	animation->duration = duration;
	animation->timelinesCount = kv_size(timelines);
	animation->timelines = kv_array(timelines);
	return animation;
}

static float* _readFloatArray(_dataInput *input, int n, float scale) {
	float* array = MALLOC(float, n);
	int i;
	if (scale == 1)
		for (i = 0; i < n; ++i)
			array[i] = readFloat(input);
	else
		for (i = 0; i < n; ++i)
			array[i] = readFloat(input) * scale;
	return array;
}

static short* _readShortArray(_dataInput *input, int *length) {
	int n = readVarint(input, 1);
	short* array = MALLOC(short, n);
	int i;
	*length = n;
	for (i = 0; i < n; ++i) {
		array[i] = readByte(input) << 8;
		array[i] |= readByte(input);
	}
	return array;
}

static void _readVertices(sp36SkeletonBinary* self, _dataInput* input, sp36VertexAttachment* attachment,
		int vertexCount) {
	int i, ii;
	int verticesLength = vertexCount << 1;
	kvec_t(float) weights;
	kvec_t(int) bones;

	attachment->worldVerticesLength = verticesLength;

	if (!readBoolean(input)) {
		attachment->verticesCount = verticesLength;
		attachment->vertices = _readFloatArray(input, verticesLength, self->scale);
		attachment->bonesCount = 0;
		attachment->bones = 0;
		return;
	}

	kv_init(weights);
	kv_resize(float, weights, verticesLength * 3 * 3);

	kv_init(bones);
	kv_resize(int, bones, verticesLength * 3);

	for (i = 0; i < vertexCount; ++i) {
		int boneCount = readVarint(input, 1);
		kv_push(int, bones, boneCount);
		for (ii = 0; ii < boneCount; ++ii) {
			kv_push(int, bones, readVarint(input, 1));
			kv_push(float, weights, readFloat(input) * self->scale);
			kv_push(float, weights, readFloat(input) * self->scale);
			kv_push(float, weights, readFloat(input));
		}
	}

	kv_trim(float, weights);
	attachment->verticesCount = kv_size(weights);
	attachment->vertices = kv_array(weights);

	kv_trim(int, bones);
	attachment->bonesCount = kv_size(bones);
	attachment->bones = kv_array(bones);
}

sp36Attachment* sp36SkeletonBinary_readAttachment(sp36SkeletonBinary* self, _dataInput* input,
		sp36Skin* skin, int slotIndex, const char* attachmentName, sp36SkeletonData* skeletonData, int/*bool*/ nonessential) {
	int i;
	sp36AttachmentType type;
	const char* name = readString(input);
	int freeName = name != 0;
	if (!name) {
		freeName = 0;
		name = attachmentName;
	}

	type = (sp36AttachmentType)readByte(input);

	switch (type) {
		case SP_ATTACHMENT_REGION: {
			const char* path = readString(input);
			sp36Attachment* attachment;
			sp36RegionAttachment* region;
			if (!path) MALLOC_STR(path, name);
			attachment = sp36AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, name, path);
			region = SUB_CAST(sp36RegionAttachment, attachment);
			region->path = path;
			region->rotation = readFloat(input);
			region->x = readFloat(input) * self->scale;
			region->y = readFloat(input) * self->scale;
			region->scaleX = readFloat(input);
			region->scaleY = readFloat(input);
			region->width = readFloat(input) * self->scale;
			region->height = readFloat(input) * self->scale;
			readColor(input, &region->color.r, &region->color.g, &region->color.b, &region->color.a);
			sp36RegionAttachment_updateOffset(region);
			sp36AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
			if (freeName) FREE(name);
			return attachment;
		}
		case SP_ATTACHMENT_BOUNDING_BOX: {
			int vertexCount = readVarint(input, 1);
			sp36Attachment* attachment = sp36AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, name, 0);
			_readVertices(self, input, SUB_CAST(sp36VertexAttachment, attachment), vertexCount);
			if (nonessential) readInt(input); /* Skip color. */
			sp36AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
			if (freeName) FREE(name);
			return attachment;
		}
		case SP_ATTACHMENT_MESH: {
			int vertexCount;
			sp36Attachment* attachment;
			sp36MeshAttachment* mesh;
			const char* path = readString(input);
			if (!path) MALLOC_STR(path, name);
			attachment = sp36AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, name, path);
			mesh = SUB_CAST(sp36MeshAttachment, attachment);
			mesh->path = path;
			readColor(input, &mesh->color.r, &mesh->color.g, &mesh->color.b, &mesh->color.a);
			vertexCount = readVarint(input, 1);
			mesh->regionUVs = _readFloatArray(input, vertexCount << 1, 1);
			mesh->triangles = (unsigned short*)_readShortArray(input, &mesh->trianglesCount);
			_readVertices(self, input, SUPER(mesh), vertexCount);
			sp36MeshAttachment_updateUVs(mesh);
			mesh->hullLength = readVarint(input, 1) << 1;
			if (nonessential) {
				mesh->edges = (int*)_readShortArray(input, &mesh->edgesCount);
				mesh->width = readFloat(input) * self->scale;
				mesh->height = readFloat(input) * self->scale;
			} else {
				mesh->edges = 0;
				mesh->width = 0;
				mesh->height = 0;
			}
			sp36AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
			if (freeName) FREE(name);
			return attachment;
		}
		case SP_ATTACHMENT_LINKED_MESH: {
			const char* skinName;
			const char* parent;
			sp36Attachment* attachment;
			sp36MeshAttachment* mesh;
			const char* path = readString(input);
			if (!path) MALLOC_STR(path, name);
			attachment = sp36AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, name, path);
			mesh = SUB_CAST(sp36MeshAttachment, attachment);
			mesh->path = path;
			readColor(input, &mesh->color.r, &mesh->color.g, &mesh->color.b, &mesh->color.a);
			skinName = readString(input);
			parent = readString(input);
			mesh->inheritDeform = readBoolean(input);
			if (nonessential) {
				mesh->width = readFloat(input) * self->scale;
				mesh->height = readFloat(input) * self->scale;
			}
			_sp36SkeletonBinary_addLinkedMesh(self, mesh, skinName, slotIndex, parent);
			if (freeName) FREE(name);
			return attachment;
		}
		case SP_ATTACHMENT_PATH: {
			sp36Attachment* attachment = sp36AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, name, 0);
			sp36PathAttachment* path = SUB_CAST(sp36PathAttachment, attachment);
			int vertexCount = 0;
			path->closed = readBoolean(input);
			path->constantSpeed = readBoolean(input);
			vertexCount = readVarint(input, 1);
			_readVertices(self, input, SUPER(path), vertexCount);
			path->lengthsLength = vertexCount / 3;
			path->lengths = MALLOC(float, path->lengthsLength);
			for (i = 0; i < path->lengthsLength; ++i) {
				path->lengths[i] = readFloat(input) * self->scale;
			}
			if (nonessential) readInt(input); /* Skip color. */
			if (freeName) FREE(name);
			return attachment;
		}
		case SP_ATTACHMENT_POINT: {
			sp36Attachment* attachment = sp36AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, name, 0);
			sp36PointAttachment* point = SUB_CAST(sp36PointAttachment, attachment);
			point->rotation = readFloat(input);
			point->x = readFloat(input) * self->scale;
			point->y = readFloat(input) * self->scale;

			if (nonessential) {
				readColor(input, &point->color.r, &point->color.g, &point->color.b, &point->color.a);
			}
			return attachment;
		}
		case SP_ATTACHMENT_CLIPPING: {
			int endSlotIndex = readVarint(input, 1);
			int vertexCount = readVarint(input, 1);
			sp36Attachment* attachment = sp36AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, name, 0);
			sp36ClippingAttachment* clip = SUB_CAST(sp36ClippingAttachment, attachment);
			_readVertices(self, input, SUB_CAST(sp36VertexAttachment, attachment), vertexCount);
			if (nonessential) readInt(input); /* Skip color. */
			clip->endSlot = skeletonData->slots[endSlotIndex];
			sp36AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
			if (freeName) FREE(name);
			return attachment;
		}
	}

	if (freeName) FREE(name);
	return 0;
}

sp36Skin* sp36SkeletonBinary_readSkin(sp36SkeletonBinary* self, _dataInput* input,
		const char* skinName, sp36SkeletonData* skeletonData, int/*bool*/ nonessential) {
	sp36Skin* skin;
	int slotCount = readVarint(input, 1);
	int i, ii, nn;
	if (slotCount == 0)
		return 0;
	skin = sp36Skin_create(skinName);
	for (i = 0; i < slotCount; ++i) {
		int slotIndex = readVarint(input, 1);
		for (ii = 0, nn = readVarint(input, 1); ii < nn; ++ii) {
			const char* name = readString(input);
			sp36Attachment* attachment = sp36SkeletonBinary_readAttachment(self, input, skin, slotIndex, name, skeletonData, nonessential);
			if (attachment) sp36Skin_addAttachment(skin, slotIndex, name, attachment);
			FREE(name);
		}
	}
	return skin;
}

sp36SkeletonData* sp36SkeletonBinary_readSkeletonDataFile (sp36SkeletonBinary* self, const char* path) {
	int length;
	sp36SkeletonData* skeletonData;
	const char* binary = _sp36Util_readFile(path, &length);
	if (length == 0 || !binary) {
		_sp36SkeletonBinary_setError(self, "Unable to read skeleton file: ", path);
		return 0;
	}
	skeletonData = sp36SkeletonBinary_readSkeletonData(self, (unsigned char*)binary, length);
	FREE(binary);
	return skeletonData;
}

sp36SkeletonData* sp36SkeletonBinary_readSkeletonData (sp36SkeletonBinary* self, const unsigned char* binary,
		const int length) {
	int i, ii, nonessential;
	sp36SkeletonData* skeletonData;
	_sp36SkeletonBinary* internal = SUB_CAST(_sp36SkeletonBinary, self);

	_dataInput* input = NEW(_dataInput);
	input->cursor = binary;
	input->end = binary + length;

	FREE(self->error);
	CONST_CAST(char*, self->error) = 0;
	internal->linkedMeshCount = 0;

	skeletonData = sp36SkeletonData_create();

	skeletonData->hash = readString(input);
	if (!strlen(skeletonData->hash)) {
		FREE(skeletonData->hash);
		skeletonData->hash = 0;
	}

	skeletonData->version = readString(input);
	if (!strlen(skeletonData->version)) {
		FREE(skeletonData->version);
		skeletonData->version = 0;
	}

	skeletonData->width = readFloat(input);
	skeletonData->height = readFloat(input);

	nonessential = readBoolean(input);

	if (nonessential) {
		/* Skip images path & fps */
		readFloat(input);
		FREE(readString(input));
	}

	/* Bones. */
	skeletonData->bonesCount = readVarint(input, 1);
	skeletonData->bones = MALLOC(sp36BoneData*, skeletonData->bonesCount);
	for (i = 0; i < skeletonData->bonesCount; ++i) {
		sp36BoneData* data;
		int mode;
		const char* name = readString(input);
		sp36BoneData* parent = i == 0 ? 0 : skeletonData->bones[readVarint(input, 1)];
		/* TODO Avoid copying of name */
		data = sp36BoneData_create(i, name, parent);
		FREE(name);
		data->rotation = readFloat(input);
		data->x = readFloat(input) * self->scale;
		data->y = readFloat(input) * self->scale;
		data->scaleX = readFloat(input);
		data->scaleY = readFloat(input);
		data->shearX = readFloat(input);
		data->shearY = readFloat(input);
		data->length = readFloat(input) * self->scale;
		mode = readVarint(input, 1);
		switch (mode) {
			case 0: data->transformMode = SP_TRANSFORMMODE_NORMAL; break;
			case 1: data->transformMode = SP_TRANSFORMMODE_ONLYTRANSLATION; break;
			case 2: data->transformMode = SP_TRANSFORMMODE_NOROTATIONORREFLECTION; break;
			case 3: data->transformMode = SP_TRANSFORMMODE_NOSCALE; break;
			case 4: data->transformMode = SP_TRANSFORMMODE_NOSCALEORREFLECTION; break;
		}
		if (nonessential) readInt(input); /* Skip bone color. */
		skeletonData->bones[i] = data;
	}

	/* Slots. */
	skeletonData->slotsCount = readVarint(input, 1);
	skeletonData->slots = MALLOC(sp36SlotData*, skeletonData->slotsCount);
	for (i = 0; i < skeletonData->slotsCount; ++i) {
		int r, g, b, a;
		const char* slotName = readString(input);
		sp36BoneData* boneData = skeletonData->bones[readVarint(input, 1)];
		/* TODO Avoid copying of slotName */
		sp36SlotData* slotData = sp36SlotData_create(i, slotName, boneData);
		FREE(slotName);
		readColor(input, &slotData->color.r, &slotData->color.g, &slotData->color.b, &slotData->color.a);
		a = readByte(input);
		r = readByte(input);
		g = readByte(input);
		b = readByte(input);
		if (!(r == 0xff && g == 0xff && b == 0xff && a == 0xff)) {
			slotData->darkColor = sp36Color_create();
			sp36Color_setFromFloats(slotData->darkColor, r / 255.0f, g / 255.0f, b / 255.0f, 1);
		}
		slotData->attachmentName = readString(input);
		slotData->blendMode = (sp36BlendMode)readVarint(input, 1);
		skeletonData->slots[i] = slotData;
	}

	/* IK constraints. */
	skeletonData->ikConstraintsCount = readVarint(input, 1);
	skeletonData->ikConstraints = MALLOC(sp36IkConstraintData*, skeletonData->ikConstraintsCount);
	for (i = 0; i < skeletonData->ikConstraintsCount; ++i) {
		const char* name = readString(input);
		/* TODO Avoid copying of name */
		sp36IkConstraintData* data = sp36IkConstraintData_create(name);
		data->order = readVarint(input, 1);
		FREE(name);
		data->bonesCount = readVarint(input, 1);
		data->bones = MALLOC(sp36BoneData*, data->bonesCount);
		for (ii = 0; ii < data->bonesCount; ++ii)
			data->bones[ii] = skeletonData->bones[readVarint(input, 1)];
		data->target = skeletonData->bones[readVarint(input, 1)];
		data->mix = readFloat(input);
		data->bendDirection = readSByte(input);
		skeletonData->ikConstraints[i] = data;
	}

	/* Transform constraints. */
	skeletonData->transformConstraintsCount = readVarint(input, 1);
	skeletonData->transformConstraints = MALLOC(
			sp36TransformConstraintData*, skeletonData->transformConstraintsCount);
	for (i = 0; i < skeletonData->transformConstraintsCount; ++i) {
		const char* name = readString(input);
		/* TODO Avoid copying of name */
		sp36TransformConstraintData* data = sp36TransformConstraintData_create(name);
		data->order = readVarint(input, 1);
		FREE(name);
		data->bonesCount = readVarint(input, 1);
		CONST_CAST(sp36BoneData**, data->bones) = MALLOC(sp36BoneData*, data->bonesCount);
		for (ii = 0; ii < data->bonesCount; ++ii)
			data->bones[ii] = skeletonData->bones[readVarint(input, 1)];
		data->target = skeletonData->bones[readVarint(input, 1)];
		data->local = readBoolean(input);
		data->relative = readBoolean(input);
		data->offsetRotation = readFloat(input);
		data->offsetX = readFloat(input) * self->scale;
		data->offsetY = readFloat(input) * self->scale;
		data->offsetScaleX = readFloat(input);
		data->offsetScaleY = readFloat(input);
		data->offsetShearY = readFloat(input);
		data->rotateMix = readFloat(input);
		data->translateMix = readFloat(input);
		data->scaleMix = readFloat(input);
		data->shearMix = readFloat(input);
		skeletonData->transformConstraints[i] = data;
	}

	/* Path constraints */
	skeletonData->pathConstraintsCount = readVarint(input, 1);
	skeletonData->pathConstraints = MALLOC(sp36PathConstraintData*, skeletonData->pathConstraintsCount);
	for (i = 0; i < skeletonData->pathConstraintsCount; ++i) {
		const char* name = readString(input);
		/* TODO Avoid copying of name */
		sp36PathConstraintData* data = sp36PathConstraintData_create(name);
		data->order = readVarint(input, 1);
		FREE(name);
		data->bonesCount = readVarint(input, 1);
		CONST_CAST(sp36BoneData**, data->bones) = MALLOC(sp36BoneData*, data->bonesCount);
		for (ii = 0; ii < data->bonesCount; ++ii)
			data->bones[ii] = skeletonData->bones[readVarint(input, 1)];
		data->target = skeletonData->slots[readVarint(input, 1)];
		data->positionMode = (sp36PositionMode)readVarint(input, 1);
		data->spacingMode = (sp36SpacingMode)readVarint(input, 1);
		data->rotateMode = (sp36RotateMode)readVarint(input, 1);
		data->offsetRotation = readFloat(input);
		data->position = readFloat(input);
		if (data->positionMode == SP_POSITION_MODE_FIXED) data->position *= self->scale;
		data->spacing = readFloat(input);
		if (data->spacingMode == SP_SPACING_MODE_LENGTH || data->spacingMode == SP_SPACING_MODE_FIXED) data->spacing *= self->scale;
		data->rotateMix = readFloat(input);
		data->translateMix = readFloat(input);
		skeletonData->pathConstraints[i] = data;
	}

	/* Default skin. */
	skeletonData->defaultSkin = sp36SkeletonBinary_readSkin(self, input, "default", skeletonData, nonessential);
	skeletonData->skinsCount = readVarint(input, 1);

	if (skeletonData->defaultSkin)
		++skeletonData->skinsCount;

	skeletonData->skins = MALLOC(sp36Skin*, skeletonData->skinsCount);

	if (skeletonData->defaultSkin)
		skeletonData->skins[0] = skeletonData->defaultSkin;

	/* Skins. */
	for (i = skeletonData->defaultSkin ? 1 : 0; i < skeletonData->skinsCount; ++i) {
		const char* skinName = readString(input);
		/* TODO Avoid copying of skinName */
		skeletonData->skins[i] = sp36SkeletonBinary_readSkin(self, input, skinName, skeletonData, nonessential);
		FREE(skinName);
	}

	/* Linked meshes. */
	for (i = 0; i < internal->linkedMeshCount; ++i) {
		_sp36LinkedMesh* linkedMesh = internal->linkedMeshes + i;
		sp36Skin* skin = !linkedMesh->skin ? skeletonData->defaultSkin : sp36SkeletonData_findSkin(skeletonData, linkedMesh->skin);
		sp36Attachment* parent;
		if (!skin) {
			FREE(input);
			sp36SkeletonData_dispose(skeletonData);
			_sp36SkeletonBinary_setError(self, "Skin not found: ", linkedMesh->skin);
			return 0;
		}
		parent = sp36Skin_getAttachment(skin, linkedMesh->slotIndex, linkedMesh->parent);
		if (!parent) {
			FREE(input);
			sp36SkeletonData_dispose(skeletonData);
			_sp36SkeletonBinary_setError(self, "Parent mesh not found: ", linkedMesh->parent);
			return 0;
		}
		sp36MeshAttachment_setParentMesh(linkedMesh->mesh, SUB_CAST(sp36MeshAttachment, parent));
		sp36MeshAttachment_updateUVs(linkedMesh->mesh);
		sp36AttachmentLoader_configureAttachment(self->attachmentLoader, SUPER(SUPER(linkedMesh->mesh)));
	}

	/* Events. */
	skeletonData->eventsCount = readVarint(input, 1);
	skeletonData->events = MALLOC(sp36EventData*, skeletonData->eventsCount);
	for (i = 0; i < skeletonData->eventsCount; ++i) {
		const char* name = readString(input);
		/* TODO Avoid copying of skinName */
		sp36EventData* eventData = sp36EventData_create(name);
		FREE(name);
		eventData->intValue = readVarint(input, 0);
		eventData->floatValue = readFloat(input);
		eventData->stringValue = readString(input);
		skeletonData->events[i] = eventData;
	}

	/* Animations. */
	skeletonData->animationsCount = readVarint(input, 1);
	skeletonData->animations = MALLOC(sp36Animation*, skeletonData->animationsCount);
	for (i = 0; i < skeletonData->animationsCount; ++i) {
		const char* name = readString(input);
		sp36Animation* animation = _sp36SkeletonBinary_readAnimation(self, name, input, skeletonData);
		FREE(name);
		if (!animation) {
			FREE(input);
			sp36SkeletonData_dispose(skeletonData);
			return 0;
		}
		skeletonData->animations[i] = animation;
	}

	FREE(input);
	return skeletonData;
}

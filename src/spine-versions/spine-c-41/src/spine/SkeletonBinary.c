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

#include <spine/Animation.h>
#include <spine/Array.h>
#include <spine/AtlasAttachmentLoader.h>
#include <spine/SkeletonBinary.h>
#include <spine/extension.h>
#include <stdio.h>
#include <spine/Version.h>

typedef struct {
	const unsigned char *cursor;
	const unsigned char *end;
} _dataInput;

typedef struct {
	const char *parent;
	const char *skin;
	int slotIndex;
	sp41MeshAttachment *mesh;
	int inheritTimeline;
} _sp41LinkedMesh;

typedef struct {
	sp41SkeletonBinary super;
	int ownsLoader;

	int linkedMeshCount;
	int linkedMeshCapacity;
	_sp41LinkedMesh *linkedMeshes;
} _sp41SkeletonBinary;

sp41SkeletonBinary *sp41SkeletonBinary_createWithLoader(sp41AttachmentLoader *attachmentLoader) {
	sp41SkeletonBinary *self = SUPER(NEW(_sp41SkeletonBinary));
	self->scale = 1;
	self->attachmentLoader = attachmentLoader;
	return self;
}

sp41SkeletonBinary *sp41SkeletonBinary_create(sp41Atlas *atlas) {
	sp41AtlasAttachmentLoader *attachmentLoader = sp41AtlasAttachmentLoader_create(atlas);
	sp41SkeletonBinary *self = sp41SkeletonBinary_createWithLoader(SUPER(attachmentLoader));
	SUB_CAST(_sp41SkeletonBinary, self)->ownsLoader = 1;
	return self;
}

void sp41SkeletonBinary_dispose(sp41SkeletonBinary *self) {
	_sp41SkeletonBinary *internal = SUB_CAST(_sp41SkeletonBinary, self);
	if (internal->ownsLoader) sp41AttachmentLoader_dispose(self->attachmentLoader);
	FREE(internal->linkedMeshes);
	FREE(self->error);
	FREE(self);
}

void _sp41SkeletonBinary_setError(sp41SkeletonBinary *self, const char *value1, const char *value2) {
	char message[256];
	int length;
	FREE(self->error);
	strcpy(message, value1);
	length = (int) strlen(value1);
	if (value2) strncat(message + length, value2, 255 - length);
	MALLOC_STR(self->error, message);
}

static unsigned char readByte(_dataInput *input) {
	return *input->cursor++;
}

static signed char readSByte(_dataInput *input) {
	return (signed char) readByte(input);
}

static int readBoolean(_dataInput *input) {
	return readByte(input) != 0;
}

static int readInt(_dataInput *input) {
	uint32_t result = readByte(input);
	result <<= 8;
	result |= readByte(input);
	result <<= 8;
	result |= readByte(input);
	result <<= 8;
	result |= readByte(input);
	return (int) result;
}

static int readVarint(_dataInput *input, int /*bool*/ optimizePositive) {
	unsigned char b = readByte(input);
	uint32_t value = b & 0x7F;
	if (b & 0x80) {
		b = readByte(input);
		value |= (b & 0x7F) << 7;
		if (b & 0x80) {
			b = readByte(input);
			value |= (b & 0x7F) << 14;
			if (b & 0x80) {
				b = readByte(input);
				value |= (b & 0x7F) << 21;
				if (b & 0x80) value |= (uint32_t) (readByte(input) & 0x7F) << 28;
			}
		}
	}
	if (!optimizePositive) value = (((unsigned int) value >> 1) ^ -(value & 1));
	return (int) value;
}

static float readFloat(_dataInput *input) {
	union {
		int intValue;
		float floatValue;
	} intToFloat;
	intToFloat.intValue = readInt(input);
	return intToFloat.floatValue;
}

static char *readString(_dataInput *input) {
	int length = readVarint(input, 1);
	char *string;
	if (length == 0) return NULL;
	string = MALLOC(char, length);
	memcpy(string, input->cursor, length - 1);
	input->cursor += length - 1;
	string[length - 1] = '\0';
	return string;
}

static char *readStringRef(_dataInput *input, sp41SkeletonData *skeletonData) {
	int index = readVarint(input, 1);
	return index == 0 ? 0 : skeletonData->strings[index - 1];
}

static void readColor(_dataInput *input, float *r, float *g, float *b, float *a) {
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

#define BONE_ROTATE 0
#define BONE_TRANSLATE 1
#define BONE_TRANSLATEX 2
#define BONE_TRANSLATEY 3
#define BONE_SCALE 4
#define BONE_SCALEX 5
#define BONE_SCALEY 6
#define BONE_SHEAR 7
#define BONE_SHEARX 8
#define BONE_SHEARY 9

#define SLOT_ATTACHMENT 0
#define SLOT_RGBA 1
#define SLOT_RGB 2
#define SLOT_RGBA2 3
#define SLOT_RGB2 4
#define SLOT_ALPHA 5

#define ATTACHMENT_DEFORM 0
#define ATTACHMENT_SEQUENCE 1

#define PATH_POSITION 0
#define PATH_SPACING 1
#define PATH_MIX 2

#define CURVE_LINEAR 0
#define CURVE_STEPPED 1
#define CURVE_BEZIER 2

#define PATH_POSITION_FIXED 0
#define PATH_POSITION_PERCENT 1

#define PATH_SPACING_LENGTH 0
#define PATH_SPACING_FIXED 1
#define PATH_SPACING_PERCENT 2

#define PATH_ROTATE_TANGENT 0
#define PATH_ROTATE_CHAIN 1
#define PATH_ROTATE_CHAIN_SCALE 2

static sp41Sequence *readSequence(_dataInput *input) {
	sp41Sequence *sequence = NULL;
	if (!readBoolean(input)) return NULL;
	sequence = sp41Sequence_create(readVarint(input, -1));
	sequence->start = readVarint(input, -1);
	sequence->digits = readVarint(input, -1);
	sequence->setupIndex = readVarint(input, -1);
	return sequence;
}

static void
setBezier(_dataInput *input, sp41Timeline *timeline, int bezier, int frame, int value, float time1, float time2,
		  float value1, float value2, float scale) {
	float cx1 = readFloat(input);
	float cy1 = readFloat(input);
	float cx2 = readFloat(input);
	float cy2 = readFloat(input);
	sp41Timeline_setBezier(timeline, bezier, frame, value, time1, value1, cx1, cy1 * scale, cx2, cy2 * scale, time2,
						 value2);
}

static sp41Timeline *readTimeline(_dataInput *input, sp41CurveTimeline1 *timeline, float scale) {
	int frame, bezier, frameLast;
	float time2, value2;
	float time = readFloat(input);
	float value = readFloat(input) * scale;
	for (frame = 0, bezier = 0, frameLast = timeline->super.frameCount - 1;; frame++) {
		sp41CurveTimeline1_setFrame(timeline, frame, time, value);
		if (frame == frameLast) break;
		time2 = readFloat(input);
		value2 = readFloat(input) * scale;
		switch (readSByte(input)) {
			case CURVE_STEPPED:
				sp41CurveTimeline_setStepped(timeline, frame);
				break;
			case CURVE_BEZIER:
				setBezier(input, SUPER(timeline), bezier++, frame, 0, time, time2, value, value2, scale);
		}
		time = time2;
		value = value2;
	}
	return SUPER(timeline);
}

static sp41Timeline *readTimeline2(_dataInput *input, sp41CurveTimeline2 *timeline, float scale) {
	int frame, bezier, frameLast;
	float time2, nvalue1, nvalue2;
	float time = readFloat(input);
	float value1 = readFloat(input) * scale;
	float value2 = readFloat(input) * scale;
	for (frame = 0, bezier = 0, frameLast = timeline->super.frameCount - 1;; frame++) {
		sp41CurveTimeline2_setFrame(timeline, frame, time, value1, value2);
		if (frame == frameLast) break;
		time2 = readFloat(input);
		nvalue1 = readFloat(input) * scale;
		nvalue2 = readFloat(input) * scale;
		switch (readSByte(input)) {
			case CURVE_STEPPED:
				sp41CurveTimeline_setStepped(timeline, frame);
				break;
			case CURVE_BEZIER:
				setBezier(input, SUPER(timeline), bezier++, frame, 0, time, time2, value1, nvalue1, scale);
				setBezier(input, SUPER(timeline), bezier++, frame, 1, time, time2, value2, nvalue2, scale);
		}
		time = time2;
		value1 = nvalue1;
		value2 = nvalue2;
	}
	return SUPER(timeline);
}

static void _sp41SkeletonBinary_addLinkedMesh(sp41SkeletonBinary *self, sp41MeshAttachment *mesh,
											const char *skin, int slotIndex, const char *parent, int inheritDeform) {
	_sp41LinkedMesh *linkedMesh;
	_sp41SkeletonBinary *internal = SUB_CAST(_sp41SkeletonBinary, self);

	if (internal->linkedMeshCount == internal->linkedMeshCapacity) {
		_sp41LinkedMesh *linkedMeshes;
		internal->linkedMeshCapacity *= 2;
		if (internal->linkedMeshCapacity < 8) internal->linkedMeshCapacity = 8;
		/* TODO Why not realloc? */
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

static sp41Animation *_sp41SkeletonBinary_readAnimation(sp41SkeletonBinary *self, const char *name,
													_dataInput *input, sp41SkeletonData *skeletonData) {
	sp41TimelineArray *timelines = sp41TimelineArray_create(18);
	float duration = 0;
	int i, n, ii, nn, iii, nnn;
	int frame, bezier;
	int drawOrderCount, eventCount;
	sp41Animation *animation;
	float scale = self->scale;

	int numTimelines = readVarint(input, 1);
	UNUSED(numTimelines);

	/* Slot timelines. */
	for (i = 0, n = readVarint(input, 1); i < n; ++i) {
		int slotIndex = readVarint(input, 1);
		for (ii = 0, nn = readVarint(input, 1); ii < nn; ++ii) {
			unsigned char timelineType = readByte(input);
			int frameCount = readVarint(input, 1);
			int frameLast = frameCount - 1;
			switch (timelineType) {
				case SLOT_ATTACHMENT: {
					sp41AttachmentTimeline *timeline = sp41AttachmentTimeline_create(frameCount, slotIndex);
					for (frame = 0; frame < frameCount; ++frame) {
						float time = readFloat(input);
						const char *attachmentName = readStringRef(input, skeletonData);
						sp41AttachmentTimeline_setFrame(timeline, frame, time, attachmentName);
					}
					sp41TimelineArray_add(timelines, SUPER(timeline));
					break;
				}
				case SLOT_RGBA: {
					int bezierCount = readVarint(input, 1);
					sp41RGBATimeline *timeline = sp41RGBATimeline_create(frameCount, bezierCount, slotIndex);

					float time = readFloat(input);
					float r = readByte(input) / 255.0;
					float g = readByte(input) / 255.0;
					float b = readByte(input) / 255.0;
					float a = readByte(input) / 255.0;

					for (frame = 0, bezier = 0;; frame++) {
						float time2, r2, g2, b2, a2;
						sp41RGBATimeline_setFrame(timeline, frame, time, r, g, b, a);
						if (frame == frameLast) break;

						time2 = readFloat(input);
						r2 = readByte(input) / 255.0;
						g2 = readByte(input) / 255.0;
						b2 = readByte(input) / 255.0;
						a2 = readByte(input) / 255.0;

						switch (readSByte(input)) {
							case CURVE_STEPPED:
								sp41CurveTimeline_setStepped(SUPER(timeline), frame);
								break;
							case CURVE_BEZIER:
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 0, time, time2, r, r2, 1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 1, time, time2, g, g2, 1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 2, time, time2, b, b2, 1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 3, time, time2, a, a2, 1);
						}
						time = time2;
						r = r2;
						g = g2;
						b = b2;
						a = a2;
					}
					sp41TimelineArray_add(timelines, SUPER(SUPER(timeline)));
					break;
				}
				case SLOT_RGB: {
					int bezierCount = readVarint(input, 1);
					sp41RGBTimeline *timeline = sp41RGBTimeline_create(frameCount, bezierCount, slotIndex);

					float time = readFloat(input);
					float r = readByte(input) / 255.0;
					float g = readByte(input) / 255.0;
					float b = readByte(input) / 255.0;

					for (frame = 0, bezier = 0;; frame++) {
						float time2, r2, g2, b2;
						sp41RGBTimeline_setFrame(timeline, frame, time, r, g, b);
						if (frame == frameLast) break;

						time2 = readFloat(input);
						r2 = readByte(input) / 255.0;
						g2 = readByte(input) / 255.0;
						b2 = readByte(input) / 255.0;

						switch (readSByte(input)) {
							case CURVE_STEPPED:
								sp41CurveTimeline_setStepped(SUPER(timeline), frame);
								break;
							case CURVE_BEZIER:
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 0, time, time2, r, r2, 1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 1, time, time2, g, g2, 1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 2, time, time2, b, b2, 1);
						}
						time = time2;
						r = r2;
						g = g2;
						b = b2;
					}
					sp41TimelineArray_add(timelines, SUPER(SUPER(timeline)));
					break;
				}
				case SLOT_RGBA2: {
					int bezierCount = readVarint(input, 1);
					sp41RGBA2Timeline *timeline = sp41RGBA2Timeline_create(frameCount, bezierCount, slotIndex);

					float time = readFloat(input);
					float r = readByte(input) / 255.0;
					float g = readByte(input) / 255.0;
					float b = readByte(input) / 255.0;
					float a = readByte(input) / 255.0;
					float r2 = readByte(input) / 255.0;
					float g2 = readByte(input) / 255.0;
					float b2 = readByte(input) / 255.0;

					for (frame = 0, bezier = 0;; frame++) {
						float time2, nr, ng, nb, na, nr2, ng2, nb2;
						sp41RGBA2Timeline_setFrame(timeline, frame, time, r, g, b, a, r2, g2, b2);
						if (frame == frameLast) break;
						time2 = readFloat(input);
						nr = readByte(input) / 255.0;
						ng = readByte(input) / 255.0;
						nb = readByte(input) / 255.0;
						na = readByte(input) / 255.0;
						nr2 = readByte(input) / 255.0;
						ng2 = readByte(input) / 255.0;
						nb2 = readByte(input) / 255.0;

						switch (readSByte(input)) {
							case CURVE_STEPPED:
								sp41CurveTimeline_setStepped(SUPER(timeline), frame);
								break;
							case CURVE_BEZIER:
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 0, time, time2, r, nr, 1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 1, time, time2, g, ng, 1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 2, time, time2, b, nb, 1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 3, time, time2, a, na, 1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 4, time, time2, r2, nr2, 1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 5, time, time2, g2, ng2, 1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 6, time, time2, b2, nb2, 1);
						}
						time = time2;
						r = nr;
						g = ng;
						b = nb;
						a = na;
						r2 = nr2;
						g2 = ng2;
						b2 = nb2;
					}
					sp41TimelineArray_add(timelines, SUPER(SUPER(timeline)));
					break;
				}
				case SLOT_RGB2: {
					int bezierCount = readVarint(input, 1);
					sp41RGB2Timeline *timeline = sp41RGB2Timeline_create(frameCount, bezierCount, slotIndex);

					float time = readFloat(input);
					float r = readByte(input) / 255.0;
					float g = readByte(input) / 255.0;
					float b = readByte(input) / 255.0;
					float r2 = readByte(input) / 255.0;
					float g2 = readByte(input) / 255.0;
					float b2 = readByte(input) / 255.0;

					for (frame = 0, bezier = 0;; frame++) {
						float time2, nr, ng, nb, nr2, ng2, nb2;
						sp41RGB2Timeline_setFrame(timeline, frame, time, r, g, b, r2, g2, b2);
						if (frame == frameLast) break;
						time2 = readFloat(input);
						nr = readByte(input) / 255.0;
						ng = readByte(input) / 255.0;
						nb = readByte(input) / 255.0;
						nr2 = readByte(input) / 255.0;
						ng2 = readByte(input) / 255.0;
						nb2 = readByte(input) / 255.0;

						switch (readSByte(input)) {
							case CURVE_STEPPED:
								sp41CurveTimeline_setStepped(SUPER(timeline), frame);
								break;
							case CURVE_BEZIER:
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 0, time, time2, r, nr, 1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 1, time, time2, g, ng, 1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 2, time, time2, b, nb, 1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 3, time, time2, r2, nr2, 1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 4, time, time2, g2, ng2, 1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 5, time, time2, b2, nb2, 1);
						}
						time = time2;
						r = nr;
						g = ng;
						b = nb;
						r2 = nr2;
						g2 = ng2;
						b2 = nb2;
					}
					sp41TimelineArray_add(timelines, SUPER(SUPER(timeline)));
					break;
				}
				case SLOT_ALPHA: {
					int bezierCount = readVarint(input, 1);
					sp41AlphaTimeline *timeline = sp41AlphaTimeline_create(frameCount, bezierCount, slotIndex);
					float time = readFloat(input);
					float a = readByte(input) / 255.0;
					for (frame = 0, bezier = 0;; frame++) {
						float time2, a2;
						sp41AlphaTimeline_setFrame(timeline, frame, time, a);
						if (frame == frameLast) break;
						time2 = readFloat(input);
						a2 = readByte(input) / 255;
						switch (readSByte(input)) {
							case CURVE_STEPPED:
								sp41CurveTimeline_setStepped(SUPER(timeline), frame);
								break;
							case CURVE_BEZIER:
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 0, time, time2, a, a2, 1);
						}
						time = time2;
						a = a2;
					}
					sp41TimelineArray_add(timelines, SUPER(SUPER(timeline)));
					break;
				}
				default: {
					return NULL;
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
			int bezierCount = readVarint(input, 1);
			sp41Timeline *timeline = NULL;
			switch (timelineType) {
				case BONE_ROTATE:
					timeline = readTimeline(input, SUPER(sp41RotateTimeline_create(frameCount, bezierCount, boneIndex)),
											1);
					break;
				case BONE_TRANSLATE:
					timeline = readTimeline2(input,
											 SUPER(sp41TranslateTimeline_create(frameCount, bezierCount, boneIndex)),
											 scale);
					break;
				case BONE_TRANSLATEX:
					timeline = readTimeline(input,
											SUPER(sp41TranslateXTimeline_create(frameCount, bezierCount, boneIndex)),
											scale);
					break;
				case BONE_TRANSLATEY:
					timeline = readTimeline(input,
											SUPER(sp41TranslateYTimeline_create(frameCount, bezierCount, boneIndex)),
											scale);
					break;
				case BONE_SCALE:
					timeline = readTimeline2(input, SUPER(sp41ScaleTimeline_create(frameCount, bezierCount, boneIndex)),
											 1);
					break;
				case BONE_SCALEX:
					timeline = readTimeline(input, SUPER(sp41ScaleXTimeline_create(frameCount, bezierCount, boneIndex)),
											1);
					break;
				case BONE_SCALEY:
					timeline = readTimeline(input, SUPER(sp41ScaleYTimeline_create(frameCount, bezierCount, boneIndex)),
											1);
					break;
				case BONE_SHEAR:
					timeline = readTimeline2(input, SUPER(sp41ShearTimeline_create(frameCount, bezierCount, boneIndex)),
											 1);
					break;
				case BONE_SHEARX:
					timeline = readTimeline(input, SUPER(sp41ShearXTimeline_create(frameCount, bezierCount, boneIndex)),
											1);
					break;
				case BONE_SHEARY:
					timeline = readTimeline(input, SUPER(sp41ShearYTimeline_create(frameCount, bezierCount, boneIndex)),
											1);
					break;
				default: {
					for (iii = 0; iii < timelines->size; ++iii)
						sp41Timeline_dispose(timelines->items[iii]);
					sp41TimelineArray_dispose(timelines);
					_sp41SkeletonBinary_setError(self, "Invalid timeline type for a bone: ",
											   skeletonData->bones[boneIndex]->name);
					return NULL;
				}
			}
			sp41TimelineArray_add(timelines, timeline);
		}
	}

	/* IK constraint timelines. */
	for (i = 0, n = readVarint(input, 1); i < n; ++i) {
		int index = readVarint(input, 1);
		int frameCount = readVarint(input, 1);
		int frameLast = frameCount - 1;
		int bezierCount = readVarint(input, 1);
		sp41IkConstraintTimeline *timeline = sp41IkConstraintTimeline_create(frameCount, bezierCount, index);
		float time = readFloat(input);
		float mix = readFloat(input);
		float softness = readFloat(input) * scale;
		for (frame = 0, bezier = 0;; frame++) {
			float time2, mix2, softness2;
			int bendDirection = readSByte(input);
			int compress = readBoolean(input);
			int stretch = readBoolean(input);
			sp41IkConstraintTimeline_setFrame(timeline, frame, time, mix, softness, bendDirection, compress, stretch);
			if (frame == frameLast) break;
			time2 = readFloat(input);
			mix2 = readFloat(input);
			softness2 = readFloat(input) * scale;
			switch (readSByte(input)) {
				case CURVE_STEPPED:
					sp41CurveTimeline_setStepped(SUPER(timeline), frame);
					break;
				case CURVE_BEZIER:
					setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 0, time, time2, mix, mix2, 1);
					setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 1, time, time2, softness, softness2,
							  scale);
			}
			time = time2;
			mix = mix2;
			softness = softness2;
		}
		sp41TimelineArray_add(timelines, SUPER(SUPER(timeline)));
	}

	/* Transform constraint timelines. */
	for (i = 0, n = readVarint(input, 1); i < n; ++i) {
		int index = readVarint(input, 1);
		int frameCount = readVarint(input, 1);
		int frameLast = frameCount - 1;
		int bezierCount = readVarint(input, 1);
		sp41TransformConstraintTimeline *timeline = sp41TransformConstraintTimeline_create(frameCount, bezierCount, index);
		float time = readFloat(input);
		float mixRotate = readFloat(input);
		float mixX = readFloat(input);
		float mixY = readFloat(input);
		float mixScaleX = readFloat(input);
		float mixScaleY = readFloat(input);
		float mixShearY = readFloat(input);
		for (frame = 0, bezier = 0;; frame++) {
			float time2, mixRotate2, mixX2, mixY2, mixScaleX2, mixScaleY2, mixShearY2;
			sp41TransformConstraintTimeline_setFrame(timeline, frame, time, mixRotate, mixX, mixY, mixScaleX, mixScaleY,
												   mixShearY);
			if (frame == frameLast) break;
			time2 = readFloat(input);
			mixRotate2 = readFloat(input);
			mixX2 = readFloat(input);
			mixY2 = readFloat(input);
			mixScaleX2 = readFloat(input);
			mixScaleY2 = readFloat(input);
			mixShearY2 = readFloat(input);
			switch (readSByte(input)) {
				case CURVE_STEPPED:
					sp41CurveTimeline_setStepped(SUPER(timeline), frame);
					break;
				case CURVE_BEZIER:
					setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 0, time, time2, mixRotate, mixRotate2, 1);
					setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 1, time, time2, mixX, mixX2, 1);
					setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 2, time, time2, mixY, mixY2, 1);
					setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 3, time, time2, mixScaleX, mixScaleX2, 1);
					setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 4, time, time2, mixScaleY, mixScaleY2, 1);
					setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 5, time, time2, mixShearY, mixShearY2, 1);
			}
			time = time2;
			mixRotate = mixRotate2;
			mixX = mixX2;
			mixY = mixY2;
			mixScaleX = mixScaleX2;
			mixScaleY = mixScaleY2;
			mixShearY = mixShearY2;
		}
		sp41TimelineArray_add(timelines, SUPER(SUPER(timeline)));
	}

	/* Path constraint timelines. */
	for (i = 0, n = readVarint(input, 1); i < n; ++i) {
		int index = readVarint(input, 1);
		sp41PathConstraintData *data = skeletonData->pathConstraints[index];
		for (ii = 0, nn = readVarint(input, 1); ii < nn; ++ii) {
			int type = readSByte(input);
			int frameCount = readVarint(input, 1);
			int bezierCount = readVarint(input, 1);
			switch (type) {
				case PATH_POSITION: {
					sp41TimelineArray_add(timelines, readTimeline(input, SUPER(sp41PathConstraintPositionTimeline_create(frameCount, bezierCount, index)),
																data->positionMode == SP_POSITION_MODE_FIXED ? scale
																											 : 1));
					break;
				}
				case PATH_SPACING: {
					sp41TimelineArray_add(timelines, readTimeline(input,
																SUPER(sp41PathConstraintSpacingTimeline_create(frameCount,
																											 bezierCount,
																											 index)),
																data->spacingMode == SP_SPACING_MODE_LENGTH ||
																				data->spacingMode == SP_SPACING_MODE_FIXED
																		? scale
																		: 1));
					break;
				}
				case PATH_MIX: {
					float time, mixRotate, mixX, mixY;
					int frameLast;
					sp41PathConstraintMixTimeline *timeline = sp41PathConstraintMixTimeline_create(frameCount, bezierCount,
																							   index);
					time = readFloat(input);
					mixRotate = readFloat(input);
					mixX = readFloat(input);
					mixY = readFloat(input);
					for (frame = 0, bezier = 0, frameLast = timeline->super.super.frameCount - 1;; frame++) {
						float time2, mixRotate2, mixX2, mixY2;
						sp41PathConstraintMixTimeline_setFrame(timeline, frame, time, mixRotate, mixX, mixY);
						if (frame == frameLast) break;
						time2 = readFloat(input);
						mixRotate2 = readFloat(input);
						mixX2 = readFloat(input);
						mixY2 = readFloat(input);
						switch (readSByte(input)) {
							case CURVE_STEPPED:
								sp41CurveTimeline_setStepped(SUPER(timeline), frame);
								break;
							case CURVE_BEZIER:
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 0, time, time2, mixRotate,
										  mixRotate2, 1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 1, time, time2, mixX, mixX2,
										  1);
								setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 2, time, time2, mixY, mixY2,
										  1);
						}
						time = time2;
						mixRotate = mixRotate2;
						mixX = mixX2;
						mixY = mixY2;
					}
					sp41TimelineArray_add(timelines, SUPER(SUPER(timeline)));
				}
			}
		}
	}

	/* Attachment timelines. */
	for (i = 0, n = readVarint(input, 1); i < n; ++i) {
		sp41Skin *skin = skeletonData->skins[readVarint(input, 1)];
		for (ii = 0, nn = readVarint(input, 1); ii < nn; ++ii) {
			int slotIndex = readVarint(input, 1);
			for (iii = 0, nnn = readVarint(input, 1); iii < nnn; ++iii) {
				int frameCount, frameLast, bezierCount;
				float time, time2;
				unsigned int timelineType;

				const char *attachmentName = readStringRef(input, skeletonData);
				sp41VertexAttachment *attachment = SUB_CAST(sp41VertexAttachment,
														  sp41Skin_getAttachment(skin, slotIndex, attachmentName));
				if (!attachment) {
					for (i = 0; i < timelines->size; ++i)
						sp41Timeline_dispose(timelines->items[i]);
					sp41TimelineArray_dispose(timelines);
					_sp41SkeletonBinary_setError(self, "Attachment not found: ", attachmentName);
					return NULL;
				}

				timelineType = readByte(input);
				frameCount = readVarint(input, 1);
				frameLast = frameCount - 1;

				switch (timelineType) {
					case ATTACHMENT_DEFORM: {
						float *tempDeform;
						int weighted, deformLength;
						sp41DeformTimeline *timeline;
						weighted = attachment->bones != 0;
						deformLength = weighted ? attachment->verticesCount / 3 * 2 : attachment->verticesCount;
						tempDeform = MALLOC(float, deformLength);

						bezierCount = readVarint(input, 1);
						timeline = sp41DeformTimeline_create(frameCount, deformLength, bezierCount, slotIndex,
														   attachment);

						time = readFloat(input);
						for (frame = 0, bezier = 0;; ++frame) {
							float *deform;
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
									float *vertices = attachment->vertices;
									for (v = 0; v < deformLength; ++v)
										deform[v] += vertices[v];
								}
							}
							sp41DeformTimeline_setFrame(timeline, frame, time, deform);
							if (frame == frameLast) break;
							time2 = readFloat(input);
							switch (readSByte(input)) {
								case CURVE_STEPPED:
									sp41CurveTimeline_setStepped(SUPER(timeline), frame);
									break;
								case CURVE_BEZIER:
									setBezier(input, SUPER(SUPER(timeline)), bezier++, frame, 0, time, time2, 0, 1, 1);
							}
							time = time2;
						}
						FREE(tempDeform);

						sp41TimelineArray_add(timelines, (sp41Timeline *) timeline);
						break;
					}
					case ATTACHMENT_SEQUENCE: {
						int modeAndIndex;
						float delay;
						sp41SequenceTimeline *timeline = sp41SequenceTimeline_create(frameCount, slotIndex, (sp41Attachment *) attachment);
						for (frame = 0; frame < frameCount; frame++) {
							time = readFloat(input);
							modeAndIndex = readInt(input);
							delay = readFloat(input);
							sp41SequenceTimeline_setFrame(timeline, frame, time, modeAndIndex & 0xf, modeAndIndex >> 4, delay);
						}
						sp41TimelineArray_add(timelines, (sp41Timeline *) timeline);
						break;
					}
				}
			}
		}
	}

	/* Draw order timeline. */
	drawOrderCount = readVarint(input, 1);
	if (drawOrderCount) {
		sp41DrawOrderTimeline *timeline = sp41DrawOrderTimeline_create(drawOrderCount, skeletonData->slotsCount);
		for (i = 0; i < drawOrderCount; ++i) {
			float time = readFloat(input);
			int offsetCount = readVarint(input, 1);
			int *drawOrder = MALLOC(int, skeletonData->slotsCount);
			int *unchanged = MALLOC(int, skeletonData->slotsCount - offsetCount);
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
			sp41DrawOrderTimeline_setFrame(timeline, i, time, drawOrder);
			FREE(drawOrder);
		}
		sp41TimelineArray_add(timelines, (sp41Timeline *) timeline);
	}

	/* Event timeline. */
	eventCount = readVarint(input, 1);
	if (eventCount) {
		sp41EventTimeline *timeline = sp41EventTimeline_create(eventCount);
		for (i = 0; i < eventCount; ++i) {
			float time = readFloat(input);
			sp41EventData *eventData = skeletonData->events[readVarint(input, 1)];
			sp41Event *event = sp41Event_create(time, eventData);
			event->intValue = readVarint(input, 0);
			event->floatValue = readFloat(input);
			if (readBoolean(input))
				event->stringValue = readString(input);
			else
				MALLOC_STR(event->stringValue, eventData->stringValue);
			if (eventData->audioPath) {
				event->volume = readFloat(input);
				event->balance = readFloat(input);
			}
			sp41EventTimeline_setFrame(timeline, i, event);
		}
		sp41TimelineArray_add(timelines, (sp41Timeline *) timeline);
	}

	duration = 0;
	for (i = 0, n = timelines->size; i < n; i++) {
		duration = MAX(duration, sp41Timeline_getDuration(timelines->items[i]));
	}
	animation = sp41Animation_create(name, timelines, duration);
	return animation;
}

static float *_readFloatArray(_dataInput *input, int n, float scale) {
	float *array = MALLOC(float, n);
	int i;
	if (scale == 1)
		for (i = 0; i < n; ++i)
			array[i] = readFloat(input);
	else
		for (i = 0; i < n; ++i)
			array[i] = readFloat(input) * scale;
	return array;
}

static short *_readShortArray(_dataInput *input, int *length) {
	int n = readVarint(input, 1);
	short *array = MALLOC(short, n);
	int i;
	*length = n;
	for (i = 0; i < n; ++i) {
		array[i] = readByte(input) << 8;
		array[i] |= readByte(input);
	}
	return array;
}

static void _readVertices(sp41SkeletonBinary *self, _dataInput *input, int *bonesCount, int **bones2, int *verticesCount,
						  float **vertices, int *worldVerticesLength, int vertexCount) {
	int i, ii;
	int verticesLength = vertexCount << 1;
	sp41FloatArray *weights = sp41FloatArray_create(8);
	sp41IntArray *bones = sp41IntArray_create(8);

	*worldVerticesLength = verticesLength;

	if (!readBoolean(input)) {
		*verticesCount = verticesLength;
		*vertices = _readFloatArray(input, verticesLength, self->scale);
		*bonesCount = 0;
		*bones2 = NULL;
		sp41FloatArray_dispose(weights);
		sp41IntArray_dispose(bones);
		return;
	}

	sp41FloatArray_ensureCapacity(weights, verticesLength * 3 * 3);
	sp41IntArray_ensureCapacity(bones, verticesLength * 3);

	for (i = 0; i < vertexCount; ++i) {
		int boneCount = readVarint(input, 1);
		sp41IntArray_add(bones, boneCount);
		for (ii = 0; ii < boneCount; ++ii) {
			sp41IntArray_add(bones, readVarint(input, 1));
			sp41FloatArray_add(weights, readFloat(input) * self->scale);
			sp41FloatArray_add(weights, readFloat(input) * self->scale);
			sp41FloatArray_add(weights, readFloat(input));
		}
	}

	*verticesCount = weights->size;
	*vertices = weights->items;
	FREE(weights);

	*bonesCount = bones->size;
	*bones2 = bones->items;
	FREE(bones);
}

sp41Attachment *sp41SkeletonBinary_readAttachment(sp41SkeletonBinary *self, _dataInput *input,
											  sp41Skin *skin, int slotIndex, const char *attachmentName,
											  sp41SkeletonData *skeletonData, int /*bool*/ nonessential) {
	int i;
	sp41AttachmentType type;
	const char *name = readStringRef(input, skeletonData);
	if (!name) name = attachmentName;

	type = (sp41AttachmentType) readByte(input);

	switch (type) {
		case SP_ATTACHMENT_REGION: {
			const char *path = readStringRef(input, skeletonData);
			float rotation, x, y, scaleX, scaleY, width, height;
			sp41Color color;
			sp41Sequence *sequence;
			if (!path) MALLOC_STR(path, name);
			else {
				const char *tmp = 0;
				MALLOC_STR(tmp, path);
				path = tmp;
			}

			rotation = readFloat(input);
			x = readFloat(input) * self->scale;
			y = readFloat(input) * self->scale;
			scaleX = readFloat(input);
			scaleY = readFloat(input);
			width = readFloat(input) * self->scale;
			height = readFloat(input) * self->scale;
			readColor(input, &color.r, &color.g, &color.b, &color.a);
			sequence = readSequence(input);
			{
				sp41Attachment *attachment = sp41AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, name,
																			   path, sequence);
				sp41RegionAttachment *region = SUB_CAST(sp41RegionAttachment, attachment);
				region->path = path;
				region->rotation = rotation;
				region->x = x;
				region->y = y;
				region->scaleX = scaleX;
				region->scaleY = scaleY;
				region->width = width;
				region->height = height;
				sp41Color_setFromColor(&region->color, &color);
				region->sequence = sequence;
				if (sequence == NULL) sp41RegionAttachment_updateRegion(region);
				sp41AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
				return attachment;
			}
		}
		case SP_ATTACHMENT_BOUNDING_BOX: {
			int vertexCount = readVarint(input, 1);
			sp41Attachment *attachment = sp41AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, name, 0,
																		   NULL);
			sp41VertexAttachment *vertexAttachment = SUB_CAST(sp41VertexAttachment, attachment);
			_readVertices(self, input, &vertexAttachment->bonesCount, &vertexAttachment->bones,
						  &vertexAttachment->verticesCount, &vertexAttachment->vertices,
						  &vertexAttachment->worldVerticesLength, vertexCount);
			if (nonessential) {
				sp41BoundingBoxAttachment *bbox = SUB_CAST(sp41BoundingBoxAttachment, attachment);
				readColor(input, &bbox->color.r, &bbox->color.g, &bbox->color.b, &bbox->color.a);
			}
			sp41AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
			return attachment;
		}
		case SP_ATTACHMENT_MESH: {
			int vertexCount;
			const char *path = readStringRef(input, skeletonData);
			sp41Color color;
			float *regionUVs;
			unsigned short *triangles;
			int trianglesCount;
			int *bones;
			int bonesCount;
			float *vertices;
			int verticesCount;
			int worldVerticesLength;
			int hullLength;
			sp41Sequence *sequence;
			int *edges = NULL;
			int edgesCount = 0;
			float width = 0;
			float height = 0;
			if (!path) MALLOC_STR(path, name);
			else {
				const char *tmp = 0;
				MALLOC_STR(tmp, path);
				path = tmp;
			}

			readColor(input, &color.r, &color.g, &color.b, &color.a);
			vertexCount = readVarint(input, 1);
			regionUVs = _readFloatArray(input, vertexCount << 1, 1);
			triangles = (unsigned short *) _readShortArray(input, &trianglesCount);
			_readVertices(self, input, &bonesCount, &bones, &verticesCount, &vertices, &worldVerticesLength, vertexCount);
			hullLength = readVarint(input, 1) << 1;
			sequence = readSequence(input);
			if (nonessential) {
				edges = (int *) _readShortArray(input, &edgesCount);
				width = readFloat(input) * self->scale;
				height = readFloat(input) * self->scale;
			}

			{
				sp41Attachment *attachment = sp41AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, name, path, sequence);
				sp41MeshAttachment *mesh = SUB_CAST(sp41MeshAttachment, attachment);
				mesh->path = path;
				sp41Color_setFromColor(&mesh->color, &color);
				mesh->regionUVs = regionUVs;
				mesh->triangles = triangles;
				mesh->trianglesCount = trianglesCount;
				mesh->super.vertices = vertices;
				mesh->super.verticesCount = verticesCount;
				mesh->super.bones = bones;
				mesh->super.bonesCount = bonesCount;
				mesh->super.worldVerticesLength = worldVerticesLength;
				mesh->hullLength = hullLength;
				mesh->edges = edges;
				mesh->edgesCount = edgesCount;
				mesh->width = width;
				mesh->height = height;
				mesh->sequence = sequence;
				if (sequence == NULL) sp41MeshAttachment_updateRegion(mesh);
				sp41AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
				return attachment;
			}
		}
		case SP_ATTACHMENT_LINKED_MESH: {
			sp41Color color;
			float width = 0, height = 0;
			const char *skinName;
			const char *parent;
			int inheritTimeline;
			sp41Sequence *sequence;
			const char *path = readStringRef(input, skeletonData);
			if (!path) MALLOC_STR(path, name);
			else {
				const char *tmp = 0;
				MALLOC_STR(tmp, path);
				path = tmp;
			}

			readColor(input, &color.r, &color.g, &color.b, &color.a);
			skinName = readStringRef(input, skeletonData);
			parent = readStringRef(input, skeletonData);
			inheritTimeline = readBoolean(input);
			sequence = readSequence(input);
			if (nonessential) {
				width = readFloat(input) * self->scale;
				height = readFloat(input) * self->scale;
			}

			{
				sp41Attachment *attachment = sp41AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, name, path, sequence);
				sp41MeshAttachment *mesh = SUB_CAST(sp41MeshAttachment, attachment);
				mesh->path = path;
				sp41Color_setFromColor(&mesh->color, &color);
				mesh->sequence = sequence;
				mesh->width = width;
				mesh->height = height;
				_sp41SkeletonBinary_addLinkedMesh(self, mesh, skinName, slotIndex, parent, inheritTimeline);
				return attachment;
			}
		}
		case SP_ATTACHMENT_PATH: {
			sp41Attachment *attachment = sp41AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, name, 0,
																		   NULL);
			sp41PathAttachment *path = SUB_CAST(sp41PathAttachment, attachment);
			sp41VertexAttachment *vertexAttachment = SUPER(path);
			int vertexCount = 0;
			path->closed = readBoolean(input);
			path->constantSpeed = readBoolean(input);
			vertexCount = readVarint(input, 1);
			_readVertices(self, input, &vertexAttachment->bonesCount, &vertexAttachment->bones,
						  &vertexAttachment->verticesCount, &vertexAttachment->vertices,
						  &vertexAttachment->worldVerticesLength, vertexCount);
			path->lengthsLength = vertexCount / 3;
			path->lengths = MALLOC(float, path->lengthsLength);
			for (i = 0; i < path->lengthsLength; ++i) {
				path->lengths[i] = readFloat(input) * self->scale;
			}
			if (nonessential) {
				readColor(input, &path->color.r, &path->color.g, &path->color.b, &path->color.a);
			}
			sp41AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
			return attachment;
		}
		case SP_ATTACHMENT_POINT: {
			sp41Attachment *attachment = sp41AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, name, 0,
																		   NULL);
			sp41PointAttachment *point = SUB_CAST(sp41PointAttachment, attachment);
			point->rotation = readFloat(input);
			point->x = readFloat(input) * self->scale;
			point->y = readFloat(input) * self->scale;

			if (nonessential) {
				readColor(input, &point->color.r, &point->color.g, &point->color.b, &point->color.a);
			}
			sp41AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
			return attachment;
		}
		case SP_ATTACHMENT_CLIPPING: {
			int endSlotIndex = readVarint(input, 1);
			int vertexCount = readVarint(input, 1);
			sp41Attachment *attachment = sp41AttachmentLoader_createAttachment(self->attachmentLoader, skin, type, name, 0,
																		   NULL);
			sp41ClippingAttachment *clip = SUB_CAST(sp41ClippingAttachment, attachment);
			sp41VertexAttachment *vertexAttachment = SUPER(clip);
			_readVertices(self, input, &vertexAttachment->bonesCount, &vertexAttachment->bones,
						  &vertexAttachment->verticesCount, &vertexAttachment->vertices,
						  &vertexAttachment->worldVerticesLength, vertexCount);
			if (nonessential) {
				readColor(input, &clip->color.r, &clip->color.g, &clip->color.b, &clip->color.a);
			}
			clip->endSlot = skeletonData->slots[endSlotIndex];
			sp41AttachmentLoader_configureAttachment(self->attachmentLoader, attachment);
			return attachment;
		}
	}

	return NULL;
}

sp41Skin *sp41SkeletonBinary_readSkin(sp41SkeletonBinary *self, _dataInput *input, int /*bool*/ defaultSkin,
								  sp41SkeletonData *skeletonData, int /*bool*/ nonessential) {
	sp41Skin *skin;
	int i, n, ii, nn, slotCount;

	if (defaultSkin) {
		slotCount = readVarint(input, 1);
		if (slotCount == 0) return NULL;
		skin = sp41Skin_create("default");
	} else {
		skin = sp41Skin_create(readStringRef(input, skeletonData));
		for (i = 0, n = readVarint(input, 1); i < n; i++)
			sp41BoneDataArray_add(skin->bones, skeletonData->bones[readVarint(input, 1)]);

		for (i = 0, n = readVarint(input, 1); i < n; i++)
			sp41IkConstraintDataArray_add(skin->ikConstraints, skeletonData->ikConstraints[readVarint(input, 1)]);

		for (i = 0, n = readVarint(input, 1); i < n; i++)
			sp41TransformConstraintDataArray_add(skin->transformConstraints,
											   skeletonData->transformConstraints[readVarint(input, 1)]);

		for (i = 0, n = readVarint(input, 1); i < n; i++)
			sp41PathConstraintDataArray_add(skin->pathConstraints, skeletonData->pathConstraints[readVarint(input, 1)]);

		slotCount = readVarint(input, 1);
	}

	for (i = 0; i < slotCount; ++i) {
		int slotIndex = readVarint(input, 1);
		for (ii = 0, nn = readVarint(input, 1); ii < nn; ++ii) {
			const char *name = readStringRef(input, skeletonData);
			sp41Attachment *attachment = sp41SkeletonBinary_readAttachment(self, input, skin, slotIndex, name, skeletonData,
																	   nonessential);
			if (attachment) sp41Skin_setAttachment(skin, slotIndex, name, attachment);
		}
	}
	return skin;
}

sp41SkeletonData *sp41SkeletonBinary_readSkeletonDataFile(sp41SkeletonBinary *self, const char *path) {
	int length;
	sp41SkeletonData *skeletonData;
	const char *binary = _sp41Util_readFile(path, &length);
	if (length == 0 || !binary) {
		_sp41SkeletonBinary_setError(self, "Unable to read skeleton file: ", path);
		return NULL;
	}
	skeletonData = sp41SkeletonBinary_readSkeletonData(self, (unsigned char *) binary, length);
	FREE(binary);
	return skeletonData;
}

static int string_starts_with(const char *str, const char *needle) {
	int lenStr, lenNeedle, i;
	if (!str) return 0;
	lenStr = strlen(str);
	lenNeedle = strlen(needle);
	if (lenStr < lenNeedle) return 0;
	for (i = 0; i < lenNeedle; i++) {
		if (str[i] != needle[i]) return 0;
	}
	return -1;
}

sp41SkeletonData *sp41SkeletonBinary_readSkeletonData(sp41SkeletonBinary *self, const unsigned char *binary,
												  const int length) {
	int i, n, ii, nonessential;
	char buffer[32];
	int lowHash, highHash;
	sp41SkeletonData *skeletonData;
	_sp41SkeletonBinary *internal = SUB_CAST(_sp41SkeletonBinary, self);

	_dataInput *input = NEW(_dataInput);
	input->cursor = binary;
	input->end = binary + length;

	FREE(self->error);
	CONST_CAST(char *, self->error) = 0;
	internal->linkedMeshCount = 0;

	skeletonData = sp41SkeletonData_create();
	lowHash = readInt(input);
	highHash = readInt(input);
	sprintf(buffer, "%x%x", highHash, lowHash);
	buffer[31] = 0;
	MALLOC_STR(skeletonData->hash, buffer);

	skeletonData->version = readString(input);
	if (!strlen(skeletonData->version)) {
		FREE(skeletonData->version);
		skeletonData->version = 0;
	} else {
		if (!string_starts_with(skeletonData->version, SPINE_VERSION_STRING)) {
			char errorMsg[255];
			sprintf(errorMsg, "Skeleton version %s does not match runtime version %s", skeletonData->version, SPINE_VERSION_STRING);
			_sp41SkeletonBinary_setError(self, errorMsg, NULL);
			return NULL;
		}
	}

	skeletonData->x = readFloat(input);
	skeletonData->y = readFloat(input);
	skeletonData->width = readFloat(input);
	skeletonData->height = readFloat(input);

	nonessential = readBoolean(input);

	if (nonessential) {
		skeletonData->fps = readFloat(input);
		skeletonData->imagesPath = readString(input);
		if (!strlen(skeletonData->imagesPath)) {
			FREE(skeletonData->imagesPath);
			skeletonData->imagesPath = 0;
		}
		skeletonData->audioPath = readString(input);
		if (!strlen(skeletonData->audioPath)) {
			FREE(skeletonData->audioPath);
			skeletonData->audioPath = 0;
		}
	}

	skeletonData->stringsCount = n = readVarint(input, 1);
	skeletonData->strings = MALLOC(char *, skeletonData->stringsCount);
	for (i = 0; i < n; i++) {
		skeletonData->strings[i] = readString(input);
	}

	/* Bones. */
	skeletonData->bonesCount = readVarint(input, 1);
	skeletonData->bones = MALLOC(sp41BoneData *, skeletonData->bonesCount);
	for (i = 0; i < skeletonData->bonesCount; ++i) {
		sp41BoneData *data;
		int mode;
		const char *name = readString(input);
		sp41BoneData *parent = i == 0 ? 0 : skeletonData->bones[readVarint(input, 1)];
		/* TODO Avoid copying of name */
		data = sp41BoneData_create(i, name, parent);
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
			case 0:
				data->transformMode = SP_TRANSFORMMODE_NORMAL;
				break;
			case 1:
				data->transformMode = SP_TRANSFORMMODE_ONLYTRANSLATION;
				break;
			case 2:
				data->transformMode = SP_TRANSFORMMODE_NOROTATIONORREFLECTION;
				break;
			case 3:
				data->transformMode = SP_TRANSFORMMODE_NOSCALE;
				break;
			case 4:
				data->transformMode = SP_TRANSFORMMODE_NOSCALEORREFLECTION;
				break;
		}
		data->skinRequired = readBoolean(input);
		if (nonessential) {
			readColor(input, &data->color.r, &data->color.g, &data->color.b, &data->color.a);
		}
		skeletonData->bones[i] = data;
	}

	/* Slots. */
	skeletonData->slotsCount = readVarint(input, 1);
	skeletonData->slots = MALLOC(sp41SlotData *, skeletonData->slotsCount);
	for (i = 0; i < skeletonData->slotsCount; ++i) {
		int r, g, b, a;
		const char *attachmentName;
		const char *slotName = readString(input);
		sp41BoneData *boneData = skeletonData->bones[readVarint(input, 1)];
		/* TODO Avoid copying of slotName */
		sp41SlotData *slotData = sp41SlotData_create(i, slotName, boneData);
		FREE(slotName);
		readColor(input, &slotData->color.r, &slotData->color.g, &slotData->color.b, &slotData->color.a);
		a = readByte(input);
		r = readByte(input);
		g = readByte(input);
		b = readByte(input);
		if (!(r == 0xff && g == 0xff && b == 0xff && a == 0xff)) {
			slotData->darkColor = sp41Color_create();
			sp41Color_setFromFloats(slotData->darkColor, r / 255.0f, g / 255.0f, b / 255.0f, 1);
		}
		attachmentName = readStringRef(input, skeletonData);
		if (attachmentName) MALLOC_STR(slotData->attachmentName, attachmentName);
		else
			slotData->attachmentName = 0;
		slotData->blendMode = (sp41BlendMode) readVarint(input, 1);
		skeletonData->slots[i] = slotData;
	}

	/* IK constraints. */
	skeletonData->ikConstraintsCount = readVarint(input, 1);
	skeletonData->ikConstraints = MALLOC(sp41IkConstraintData *, skeletonData->ikConstraintsCount);
	for (i = 0; i < skeletonData->ikConstraintsCount; ++i) {
		const char *name = readString(input);
		/* TODO Avoid copying of name */
		sp41IkConstraintData *data = sp41IkConstraintData_create(name);
		data->order = readVarint(input, 1);
		data->skinRequired = readBoolean(input);
		FREE(name);
		data->bonesCount = readVarint(input, 1);
		data->bones = MALLOC(sp41BoneData *, data->bonesCount);
		for (ii = 0; ii < data->bonesCount; ++ii)
			data->bones[ii] = skeletonData->bones[readVarint(input, 1)];
		data->target = skeletonData->bones[readVarint(input, 1)];
		data->mix = readFloat(input);
		data->softness = readFloat(input);
		data->bendDirection = readSByte(input);
		data->compress = readBoolean(input);
		data->stretch = readBoolean(input);
		data->uniform = readBoolean(input);
		skeletonData->ikConstraints[i] = data;
	}

	/* Transform constraints. */
	skeletonData->transformConstraintsCount = readVarint(input, 1);
	skeletonData->transformConstraints = MALLOC(
			sp41TransformConstraintData *, skeletonData->transformConstraintsCount);
	for (i = 0; i < skeletonData->transformConstraintsCount; ++i) {
		const char *name = readString(input);
		/* TODO Avoid copying of name */
		sp41TransformConstraintData *data = sp41TransformConstraintData_create(name);
		data->order = readVarint(input, 1);
		data->skinRequired = readBoolean(input);
		FREE(name);
		data->bonesCount = readVarint(input, 1);
		CONST_CAST(sp41BoneData **, data->bones) = MALLOC(sp41BoneData *, data->bonesCount);
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
		data->mixRotate = readFloat(input);
		data->mixX = readFloat(input);
		data->mixY = readFloat(input);
		data->mixScaleX = readFloat(input);
		data->mixScaleY = readFloat(input);
		data->mixShearY = readFloat(input);
		skeletonData->transformConstraints[i] = data;
	}

	/* Path constraints */
	skeletonData->pathConstraintsCount = readVarint(input, 1);
	skeletonData->pathConstraints = MALLOC(sp41PathConstraintData *, skeletonData->pathConstraintsCount);
	for (i = 0; i < skeletonData->pathConstraintsCount; ++i) {
		const char *name = readString(input);
		/* TODO Avoid copying of name */
		sp41PathConstraintData *data = sp41PathConstraintData_create(name);
		data->order = readVarint(input, 1);
		data->skinRequired = readBoolean(input);
		FREE(name);
		data->bonesCount = readVarint(input, 1);
		CONST_CAST(sp41BoneData **, data->bones) = MALLOC(sp41BoneData *, data->bonesCount);
		for (ii = 0; ii < data->bonesCount; ++ii)
			data->bones[ii] = skeletonData->bones[readVarint(input, 1)];
		data->target = skeletonData->slots[readVarint(input, 1)];
		data->positionMode = (sp41PositionMode) readVarint(input, 1);
		data->spacingMode = (sp41SpacingMode) readVarint(input, 1);
		data->rotateMode = (sp41RotateMode) readVarint(input, 1);
		data->offsetRotation = readFloat(input);
		data->position = readFloat(input);
		if (data->positionMode == SP_POSITION_MODE_FIXED) data->position *= self->scale;
		data->spacing = readFloat(input);
		if (data->spacingMode == SP_SPACING_MODE_LENGTH || data->spacingMode == SP_SPACING_MODE_FIXED)
			data->spacing *= self->scale;
		data->mixRotate = readFloat(input);
		data->mixX = readFloat(input);
		data->mixY = readFloat(input);
		skeletonData->pathConstraints[i] = data;
	}

	/* Default skin. */
	skeletonData->defaultSkin = sp41SkeletonBinary_readSkin(self, input, -1, skeletonData, nonessential);
	skeletonData->skinsCount = readVarint(input, 1);

	if (skeletonData->defaultSkin)
		++skeletonData->skinsCount;

	skeletonData->skins = MALLOC(sp41Skin *, skeletonData->skinsCount);

	if (skeletonData->defaultSkin)
		skeletonData->skins[0] = skeletonData->defaultSkin;

	/* Skins. */
	for (i = skeletonData->defaultSkin ? 1 : 0; i < skeletonData->skinsCount; ++i) {
		skeletonData->skins[i] = sp41SkeletonBinary_readSkin(self, input, 0, skeletonData, nonessential);
	}

	/* Linked meshes. */
	for (i = 0; i < internal->linkedMeshCount; ++i) {
		_sp41LinkedMesh *linkedMesh = internal->linkedMeshes + i;
		sp41Skin *skin = !linkedMesh->skin ? skeletonData->defaultSkin : sp41SkeletonData_findSkin(skeletonData, linkedMesh->skin);
		sp41Attachment *parent;
		if (!skin) {
			FREE(input);
			sp41SkeletonData_dispose(skeletonData);
			_sp41SkeletonBinary_setError(self, "Skin not found: ", linkedMesh->skin);
			return NULL;
		}
		parent = sp41Skin_getAttachment(skin, linkedMesh->slotIndex, linkedMesh->parent);
		if (!parent) {
			FREE(input);
			sp41SkeletonData_dispose(skeletonData);
			_sp41SkeletonBinary_setError(self, "Parent mesh not found: ", linkedMesh->parent);
			return NULL;
		}
		linkedMesh->mesh->super.timelineAttachment = linkedMesh->inheritTimeline ? parent
																				 : SUPER(SUPER(linkedMesh->mesh));
		sp41MeshAttachment_setParentMesh(linkedMesh->mesh, SUB_CAST(sp41MeshAttachment, parent));
		if (linkedMesh->mesh->region) sp41MeshAttachment_updateRegion(linkedMesh->mesh);
		sp41AttachmentLoader_configureAttachment(self->attachmentLoader, SUPER(SUPER(linkedMesh->mesh)));
	}

	/* Events. */
	skeletonData->eventsCount = readVarint(input, 1);
	skeletonData->events = MALLOC(sp41EventData *, skeletonData->eventsCount);
	for (i = 0; i < skeletonData->eventsCount; ++i) {
		const char *name = readStringRef(input, skeletonData);
		sp41EventData *eventData = sp41EventData_create(name);
		eventData->intValue = readVarint(input, 0);
		eventData->floatValue = readFloat(input);
		eventData->stringValue = readString(input);
		eventData->audioPath = readString(input);
		if (eventData->audioPath) {
			eventData->volume = readFloat(input);
			eventData->balance = readFloat(input);
		}
		skeletonData->events[i] = eventData;
	}

	/* Animations. */
	skeletonData->animationsCount = readVarint(input, 1);
	skeletonData->animations = MALLOC(sp41Animation *, skeletonData->animationsCount);
	for (i = 0; i < skeletonData->animationsCount; ++i) {
		const char *name = readString(input);
		sp41Animation *animation = _sp41SkeletonBinary_readAnimation(self, name, input, skeletonData);
		FREE(name);
		if (!animation) {
			FREE(input);
			sp41SkeletonData_dispose(skeletonData);
			return NULL;
		}
		skeletonData->animations[i] = animation;
	}

	FREE(input);
	return skeletonData;
}

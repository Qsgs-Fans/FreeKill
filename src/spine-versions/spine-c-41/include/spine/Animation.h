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

#ifndef SPINE_ANIMATION_H_
#define SPINE_ANIMATION_H_

#include <spine/dll.h>
#include <spine/Event.h>
#include <spine/Attachment.h>
#include <spine/VertexAttachment.h>
#include <spine/Sequence.h>
#include <spine/Array.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp41Timeline sp41Timeline;
struct sp41Skeleton;
typedef uint64_t sp41PropertyId;

_SP_ARRAY_DECLARE_TYPE(sp41PropertyIdArray, sp41PropertyId)

_SP_ARRAY_DECLARE_TYPE(sp41TimelineArray, sp41Timeline*)

typedef struct sp41Animation {
	const char *const name;
	float duration;

	sp41TimelineArray *timelines;
	sp41PropertyIdArray *timelineIds;
} sp41Animation;

typedef enum {
	SP_MIX_BLEND_SETUP,
	SP_MIX_BLEND_FIRST,
	SP_MIX_BLEND_REPLACE,
	SP_MIX_BLEND_ADD
} sp41MixBlend;

typedef enum {
	SP_MIX_DIRECTION_IN,
	SP_MIX_DIRECTION_OUT
} sp41MixDirection;

SP_API sp41Animation *sp41Animation_create(const char *name, sp41TimelineArray *timelines, float duration);

SP_API void sp41Animation_dispose(sp41Animation *self);

SP_API int /*bool*/ sp41Animation_hasTimeline(sp41Animation *self, sp41PropertyId *ids, int idsCount);

/** Poses the skeleton at the specified time for this animation.
 * @param lastTime The last time the animation was applied.
 * @param events Any triggered events are added. May be null.*/
SP_API void
sp41Animation_apply(const sp41Animation *self, struct sp41Skeleton *skeleton, float lastTime, float time, int loop,
				  sp41Event **events, int *eventsCount, float alpha, sp41MixBlend blend, sp41MixDirection direction);

/**/
typedef enum {
	SP_TIMELINE_ATTACHMENT,
	SP_TIMELINE_ALPHA,
	SP_TIMELINE_PATHCONSTRAINTPOSITION,
	SP_TIMELINE_PATHCONSTRAINTSPACING,
	SP_TIMELINE_ROTATE,
	SP_TIMELINE_SCALEX,
	SP_TIMELINE_SCALEY,
	SP_TIMELINE_SHEARX,
	SP_TIMELINE_SHEARY,
	SP_TIMELINE_TRANSLATEX,
	SP_TIMELINE_TRANSLATEY,
	SP_TIMELINE_SCALE,
	SP_TIMELINE_SHEAR,
	SP_TIMELINE_TRANSLATE,
	SP_TIMELINE_DEFORM,
	SP_TIMELINE_SEQUENCE,
	SP_TIMELINE_IKCONSTRAINT,
	SP_TIMELINE_PATHCONSTRAINTMIX,
	SP_TIMELINE_RGB2,
	SP_TIMELINE_RGBA2,
	SP_TIMELINE_RGBA,
	SP_TIMELINE_RGB,
	SP_TIMELINE_TRANSFORMCONSTRAINT,
	SP_TIMELINE_DRAWORDER,
	SP_TIMELINE_EVENT
} sp41TimelineType;

/**/

typedef enum {
	SP_PROPERTY_ROTATE = 1 << 0,
	SP_PROPERTY_X = 1 << 1,
	SP_PROPERTY_Y = 1 << 2,
	SP_PROPERTY_SCALEX = 1 << 3,
	SP_PROPERTY_SCALEY = 1 << 4,
	SP_PROPERTY_SHEARX = 1 << 5,
	SP_PROPERTY_SHEARY = 1 << 6,
	SP_PROPERTY_RGB = 1 << 7,
	SP_PROPERTY_ALPHA = 1 << 8,
	SP_PROPERTY_RGB2 = 1 << 9,
	SP_PROPERTY_ATTACHMENT = 1 << 10,
	SP_PROPERTY_DEFORM = 1 << 11,
	SP_PROPERTY_EVENT = 1 << 12,
	SP_PROPERTY_DRAWORDER = 1 << 13,
	SP_PROPERTY_IKCONSTRAINT = 1 << 14,
	SP_PROPERTY_TRANSFORMCONSTRAINT = 1 << 15,
	SP_PROPERTY_PATHCONSTRAINT_POSITION = 1 << 16,
	SP_PROPERTY_PATHCONSTRAINT_SPACING = 1 << 17,
	SP_PROPERTY_PATHCONSTRAINT_MIX = 1 << 18,
	SP_PROPERTY_SEQUENCE = 1 << 19
} sp41Property;

#define SP_MAX_PROPERTY_IDS 3

typedef struct _sp41TimelineVtable {
	void (*apply)(sp41Timeline *self, struct sp41Skeleton *skeleton, float lastTime, float time, sp41Event **firedEvents,
				  int *eventsCount, float alpha, sp41MixBlend blend, sp41MixDirection direction);

	void (*dispose)(sp41Timeline *self);

	void
	(*setBezier)(sp41Timeline *self, int bezier, int frame, float value, float time1, float value1, float cx1, float cy1,
				 float cx2, float cy2, float time2, float value2);
} _sp41TimelineVtable;

struct sp41Timeline {
	_sp41TimelineVtable vtable;
	sp41PropertyId propertyIds[SP_MAX_PROPERTY_IDS];
	int propertyIdsCount;
	sp41FloatArray *frames;
	int frameCount;
	int frameEntries;
	sp41TimelineType type;
};

SP_API void sp41Timeline_dispose(sp41Timeline *self);

SP_API void
sp41Timeline_apply(sp41Timeline *self, struct sp41Skeleton *skeleton, float lastTime, float time, sp41Event **firedEvents,
				 int *eventsCount, float alpha, sp41MixBlend blend, sp41MixDirection direction);

SP_API void
sp41Timeline_setBezier(sp41Timeline *self, int bezier, int frame, float value, float time1, float value1, float cx1,
					 float cy1, float cx2, float cy2, float time2, float value2);

SP_API float sp41Timeline_getDuration(const sp41Timeline *self);

/**/

typedef struct sp41CurveTimeline {
	sp41Timeline super;
	sp41FloatArray *curves; /* type, x, y, ... */
} sp41CurveTimeline;

SP_API void sp41CurveTimeline_setLinear(sp41CurveTimeline *self, int frameIndex);

SP_API void sp41CurveTimeline_setStepped(sp41CurveTimeline *self, int frameIndex);

/* Sets the control handle positions for an interpolation bezier curve used to transition from this keyframe to the next.
 * cx1 and cx2 are from 0 to 1, representing the percent of time between the two keyframes. cy1 and cy2 are the percent of
 * the difference between the keyframe's values. */
SP_API void sp41CurveTimeline_setCurve(sp41CurveTimeline *self, int frameIndex, float cx1, float cy1, float cx2, float cy2);

SP_API float sp41CurveTimeline_getCurvePercent(const sp41CurveTimeline *self, int frameIndex, float percent);

typedef struct sp41CurveTimeline sp41CurveTimeline1;

SP_API void sp41CurveTimeline1_setFrame(sp41CurveTimeline1 *self, int frame, float time, float value);

SP_API float sp41CurveTimeline1_getCurveValue(sp41CurveTimeline1 *self, float time);

typedef struct sp41CurveTimeline sp41CurveTimeline2;

SP_API void sp41CurveTimeline2_setFrame(sp41CurveTimeline1 *self, int frame, float time, float value1, float value2);

/**/

typedef struct sp41RotateTimeline {
	sp41CurveTimeline1 super;
	int boneIndex;
} sp41RotateTimeline;

SP_API sp41RotateTimeline *sp41RotateTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp41RotateTimeline_setFrame(sp41RotateTimeline *self, int frameIndex, float time, float angle);

/**/

typedef struct sp41TranslateTimeline {
	sp41CurveTimeline2 super;
	int boneIndex;
} sp41TranslateTimeline;

SP_API sp41TranslateTimeline *sp41TranslateTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp41TranslateTimeline_setFrame(sp41TranslateTimeline *self, int frameIndex, float time, float x, float y);

/**/

typedef struct sp41TranslateXTimeline {
	sp41CurveTimeline1 super;
	int boneIndex;
} sp41TranslateXTimeline;

SP_API sp41TranslateXTimeline *sp41TranslateXTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp41TranslateXTimeline_setFrame(sp41TranslateXTimeline *self, int frame, float time, float x);

/**/

typedef struct sp41TranslateYTimeline {
	sp41CurveTimeline1 super;
	int boneIndex;
} sp41TranslateYTimeline;

SP_API sp41TranslateYTimeline *sp41TranslateYTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp41TranslateYTimeline_setFrame(sp41TranslateYTimeline *self, int frame, float time, float y);

/**/

typedef struct sp41ScaleTimeline {
	sp41CurveTimeline2 super;
	int boneIndex;
} sp41ScaleTimeline;

SP_API sp41ScaleTimeline *sp41ScaleTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp41ScaleTimeline_setFrame(sp41ScaleTimeline *self, int frameIndex, float time, float x, float y);

/**/

typedef struct sp41ScaleXTimeline {
	sp41CurveTimeline1 super;
	int boneIndex;
} sp41ScaleXTimeline;

SP_API sp41ScaleXTimeline *sp41ScaleXTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp41ScaleXTimeline_setFrame(sp41ScaleXTimeline *self, int frame, float time, float x);

/**/

typedef struct sp41ScaleYTimeline {
	sp41CurveTimeline1 super;
	int boneIndex;
} sp41ScaleYTimeline;

SP_API sp41ScaleYTimeline *sp41ScaleYTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp41ScaleYTimeline_setFrame(sp41ScaleYTimeline *self, int frame, float time, float y);

/**/

typedef struct sp41ShearTimeline {
	sp41CurveTimeline2 super;
	int boneIndex;
} sp41ShearTimeline;

SP_API sp41ShearTimeline *sp41ShearTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp41ShearTimeline_setFrame(sp41ShearTimeline *self, int frameIndex, float time, float x, float y);

/**/

typedef struct sp41ShearXTimeline {
	sp41CurveTimeline1 super;
	int boneIndex;
} sp41ShearXTimeline;

SP_API sp41ShearXTimeline *sp41ShearXTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp41ShearXTimeline_setFrame(sp41ShearXTimeline *self, int frame, float time, float x);

/**/

typedef struct sp41ShearYTimeline {
	sp41CurveTimeline1 super;
	int boneIndex;
} sp41ShearYTimeline;

SP_API sp41ShearYTimeline *sp41ShearYTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp41ShearYTimeline_setFrame(sp41ShearYTimeline *self, int frame, float time, float x);

/**/

typedef struct sp41RGBATimeline {
	sp41CurveTimeline2 super;
	int slotIndex;
} sp41RGBATimeline;

SP_API sp41RGBATimeline *sp41RGBATimeline_create(int framesCount, int bezierCount, int slotIndex);

SP_API void
sp41RGBATimeline_setFrame(sp41RGBATimeline *self, int frameIndex, float time, float r, float g, float b, float a);

/**/

typedef struct sp41RGBTimeline {
	sp41CurveTimeline2 super;
	int slotIndex;
} sp41RGBTimeline;

SP_API sp41RGBTimeline *sp41RGBTimeline_create(int framesCount, int bezierCount, int slotIndex);

SP_API void sp41RGBTimeline_setFrame(sp41RGBTimeline *self, int frameIndex, float time, float r, float g, float b);

/**/

typedef struct sp41AlphaTimeline {
	sp41CurveTimeline1 super;
	int slotIndex;
} sp41AlphaTimeline;

SP_API sp41AlphaTimeline *sp41AlphaTimeline_create(int frameCount, int bezierCount, int slotIndex);

SP_API void sp41AlphaTimeline_setFrame(sp41AlphaTimeline *self, int frame, float time, float x);

/**/

typedef struct sp41RGBA2Timeline {
	sp41CurveTimeline super;
	int slotIndex;
} sp41RGBA2Timeline;

SP_API sp41RGBA2Timeline *sp41RGBA2Timeline_create(int framesCount, int bezierCount, int slotIndex);

SP_API void
sp41RGBA2Timeline_setFrame(sp41RGBA2Timeline *self, int frameIndex, float time, float r, float g, float b, float a,
						 float r2, float g2, float b2);

/**/

typedef struct sp41RGB2Timeline {
	sp41CurveTimeline super;
	int slotIndex;
} sp41RGB2Timeline;

SP_API sp41RGB2Timeline *sp41RGB2Timeline_create(int framesCount, int bezierCount, int slotIndex);

SP_API void
sp41RGB2Timeline_setFrame(sp41RGB2Timeline *self, int frameIndex, float time, float r, float g, float b, float r2, float g2,
						float b2);

/**/

typedef struct sp41AttachmentTimeline {
	sp41Timeline super;
	int slotIndex;
	const char **const attachmentNames;
} sp41AttachmentTimeline;

SP_API sp41AttachmentTimeline *sp41AttachmentTimeline_create(int framesCount, int SlotIndex);

/* @param attachmentName May be 0. */
SP_API void
sp41AttachmentTimeline_setFrame(sp41AttachmentTimeline *self, int frameIndex, float time, const char *attachmentName);

/**/

typedef struct sp41DeformTimeline {
	sp41CurveTimeline super;
	int const frameVerticesCount;
	const float **const frameVertices;
	int slotIndex;
	sp41Attachment *attachment;
} sp41DeformTimeline;

SP_API sp41DeformTimeline *
sp41DeformTimeline_create(int framesCount, int frameVerticesCount, int bezierCount, int slotIndex,
						sp41VertexAttachment *attachment);

SP_API void sp41DeformTimeline_setFrame(sp41DeformTimeline *self, int frameIndex, float time, float *vertices);

/**/

typedef struct sp41SequenceTimeline {
	sp41Timeline super;
	int slotIndex;
	sp41Attachment *attachment;
} sp41SequenceTimeline;

SP_API sp41SequenceTimeline *sp41SequenceTimeline_create(int framesCount, int slotIndex, sp41Attachment *attachment);

SP_API void sp41SequenceTimeline_setFrame(sp41SequenceTimeline *self, int frameIndex, float time, int mode, int index, float delay);

/**/

/**/

typedef struct sp41EventTimeline {
	sp41Timeline super;
	sp41Event **const events;
} sp41EventTimeline;

SP_API sp41EventTimeline *sp41EventTimeline_create(int framesCount);

SP_API void sp41EventTimeline_setFrame(sp41EventTimeline *self, int frameIndex, sp41Event *event);

/**/

typedef struct sp41DrawOrderTimeline {
	sp41Timeline super;
	const int **const drawOrders;
	int const slotsCount;
} sp41DrawOrderTimeline;

SP_API sp41DrawOrderTimeline *sp41DrawOrderTimeline_create(int framesCount, int slotsCount);

SP_API void sp41DrawOrderTimeline_setFrame(sp41DrawOrderTimeline *self, int frameIndex, float time, const int *drawOrder);

/**/

typedef struct sp41IkConstraintTimeline {
	sp41CurveTimeline super;
	int ikConstraintIndex;
} sp41IkConstraintTimeline;

SP_API sp41IkConstraintTimeline *
sp41IkConstraintTimeline_create(int framesCount, int bezierCount, int transformConstraintIndex);

SP_API void
sp41IkConstraintTimeline_setFrame(sp41IkConstraintTimeline *self, int frameIndex, float time, float mix, float softness,
								int bendDirection, int /*boolean*/ compress, int /**boolean**/ stretch);

/**/

typedef struct sp41TransformConstraintTimeline {
	sp41CurveTimeline super;
	int transformConstraintIndex;
} sp41TransformConstraintTimeline;

SP_API sp41TransformConstraintTimeline *
sp41TransformConstraintTimeline_create(int framesCount, int bezierCount, int transformConstraintIndex);

SP_API void
sp41TransformConstraintTimeline_setFrame(sp41TransformConstraintTimeline *self, int frameIndex, float time, float mixRotate,
									   float mixX, float mixY, float mixScaleX, float mixScaleY, float mixShearY);

/**/

typedef struct sp41PathConstraintPositionTimeline {
	sp41CurveTimeline super;
	int pathConstraintIndex;
} sp41PathConstraintPositionTimeline;

SP_API sp41PathConstraintPositionTimeline *
sp41PathConstraintPositionTimeline_create(int framesCount, int bezierCount, int pathConstraintIndex);

SP_API void
sp41PathConstraintPositionTimeline_setFrame(sp41PathConstraintPositionTimeline *self, int frameIndex, float time,
										  float value);

/**/

typedef struct sp41PathConstraintSpacingTimeline {
	sp41CurveTimeline super;
	int pathConstraintIndex;
} sp41PathConstraintSpacingTimeline;

SP_API sp41PathConstraintSpacingTimeline *
sp41PathConstraintSpacingTimeline_create(int framesCount, int bezierCount, int pathConstraintIndex);

SP_API void sp41PathConstraintSpacingTimeline_setFrame(sp41PathConstraintSpacingTimeline *self, int frameIndex, float time,
													 float value);

/**/

typedef struct sp41PathConstraintMixTimeline {
	sp41CurveTimeline super;
	int pathConstraintIndex;
} sp41PathConstraintMixTimeline;

SP_API sp41PathConstraintMixTimeline *
sp41PathConstraintMixTimeline_create(int framesCount, int bezierCount, int pathConstraintIndex);

SP_API void
sp41PathConstraintMixTimeline_setFrame(sp41PathConstraintMixTimeline *self, int frameIndex, float time, float mixRotate,
									 float mixX, float mixY);

/**/

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATION_H_ */

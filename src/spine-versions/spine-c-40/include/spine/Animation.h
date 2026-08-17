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

#ifndef SPINE_ANIMATION_H_
#define SPINE_ANIMATION_H_

#include <spine/dll.h>
#include <spine/Event.h>
#include <spine/Attachment.h>
#include <spine/VertexAttachment.h>
#include <spine/Array.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp40Timeline sp40Timeline;
struct sp40Skeleton;
typedef uint64_t sp40PropertyId;

_SP_ARRAY_DECLARE_TYPE(sp40PropertyIdArray, sp40PropertyId)

_SP_ARRAY_DECLARE_TYPE(sp40TimelineArray, sp40Timeline*)

typedef struct sp40Animation {
	const char *const name;
	float duration;

	sp40TimelineArray *timelines;
	sp40PropertyIdArray *timelineIds;
} sp40Animation;

typedef enum {
	SP_MIX_BLEND_SETUP,
	SP_MIX_BLEND_FIRST,
	SP_MIX_BLEND_REPLACE,
	SP_MIX_BLEND_ADD
} sp40MixBlend;

typedef enum {
	SP_MIX_DIRECTION_IN,
	SP_MIX_DIRECTION_OUT
} sp40MixDirection;

SP_API sp40Animation *sp40Animation_create(const char *name, sp40TimelineArray *timelines, float duration);

SP_API void sp40Animation_dispose(sp40Animation *self);

SP_API int /*bool*/ sp40Animation_hasTimeline(sp40Animation *self, sp40PropertyId *ids, int idsCount);

/** Poses the skeleton at the specified time for this animation.
 * @param lastTime The last time the animation was applied.
 * @param events Any triggered events are added. May be null.*/
SP_API void
sp40Animation_apply(const sp40Animation *self, struct sp40Skeleton *skeleton, float lastTime, float time, int loop,
				  sp40Event **events, int *eventsCount, float alpha, sp40MixBlend blend, sp40MixDirection direction);

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
	SP_TIMELINE_IKCONSTRAINT,
	SP_TIMELINE_PATHCONSTRAINTMIX,
	SP_TIMELINE_RGB2,
	SP_TIMELINE_RGBA2,
	SP_TIMELINE_RGBA,
	SP_TIMELINE_RGB,
	SP_TIMELINE_TRANSFORMCONSTRAINT,
	SP_TIMELINE_DRAWORDER,
	SP_TIMELINE_EVENT
} sp40TimelineType;

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
	SP_PROPERTY_PATHCONSTRAINT_MIX = 1 << 18
} sp40Property;

#define SP_MAX_PROPERTY_IDS 3

typedef struct _sp40TimelineVtable {
	void (*apply)(sp40Timeline *self, struct sp40Skeleton *skeleton, float lastTime, float time, sp40Event **firedEvents,
				  int *eventsCount, float alpha, sp40MixBlend blend, sp40MixDirection direction);

	void (*dispose)(sp40Timeline *self);

	void
	(*setBezier)(sp40Timeline *self, int bezier, int frame, float value, float time1, float value1, float cx1, float cy1,
				 float cx2, float cy2, float time2, float value2);
} _sp40TimelineVtable;

struct sp40Timeline {
	_sp40TimelineVtable vtable;
	sp40PropertyId propertyIds[SP_MAX_PROPERTY_IDS];
	int propertyIdsCount;
	sp40FloatArray *frames;
	int frameCount;
	int frameEntries;
	sp40TimelineType type;
};

SP_API void sp40Timeline_dispose(sp40Timeline *self);

SP_API void
sp40Timeline_apply(sp40Timeline *self, struct sp40Skeleton *skeleton, float lastTime, float time, sp40Event **firedEvents,
				 int *eventsCount, float alpha, sp40MixBlend blend, sp40MixDirection direction);

SP_API void
sp40Timeline_setBezier(sp40Timeline *self, int bezier, int frame, float value, float time1, float value1, float cx1,
					 float cy1, float cx2, float cy2, float time2, float value2);

SP_API float sp40Timeline_getDuration(const sp40Timeline *self);

/**/

typedef struct sp40CurveTimeline {
	sp40Timeline super;
	sp40FloatArray *curves; /* type, x, y, ... */
} sp40CurveTimeline;

SP_API void sp40CurveTimeline_setLinear(sp40CurveTimeline *self, int frameIndex);

SP_API void sp40CurveTimeline_setStepped(sp40CurveTimeline *self, int frameIndex);

/* Sets the control handle positions for an interpolation bezier curve used to transition from this keyframe to the next.
 * cx1 and cx2 are from 0 to 1, representing the percent of time between the two keyframes. cy1 and cy2 are the percent of
 * the difference between the keyframe's values. */
SP_API void sp40CurveTimeline_setCurve(sp40CurveTimeline *self, int frameIndex, float cx1, float cy1, float cx2, float cy2);

SP_API float sp40CurveTimeline_getCurvePercent(const sp40CurveTimeline *self, int frameIndex, float percent);

typedef struct sp40CurveTimeline sp40CurveTimeline1;

SP_API void sp40CurveTimeline1_setFrame(sp40CurveTimeline1 *self, int frame, float time, float value);

SP_API float sp40CurveTimeline1_getCurveValue(sp40CurveTimeline1 *self, float time);

typedef struct sp40CurveTimeline sp40CurveTimeline2;

SP_API void sp40CurveTimeline2_setFrame(sp40CurveTimeline1 *self, int frame, float time, float value1, float value2);

/**/

typedef struct sp40RotateTimeline {
	sp40CurveTimeline1 super;
	int boneIndex;
} sp40RotateTimeline;

SP_API sp40RotateTimeline *sp40RotateTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp40RotateTimeline_setFrame(sp40RotateTimeline *self, int frameIndex, float time, float angle);

/**/

typedef struct sp40TranslateTimeline {
	sp40CurveTimeline2 super;
	int boneIndex;
} sp40TranslateTimeline;

SP_API sp40TranslateTimeline *sp40TranslateTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp40TranslateTimeline_setFrame(sp40TranslateTimeline *self, int frameIndex, float time, float x, float y);

/**/

typedef struct sp40TranslateXTimeline {
	sp40CurveTimeline1 super;
	int boneIndex;
} sp40TranslateXTimeline;

SP_API sp40TranslateXTimeline *sp40TranslateXTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp40TranslateXTimeline_setFrame(sp40TranslateXTimeline *self, int frame, float time, float x);

/**/

typedef struct sp40TranslateYTimeline {
	sp40CurveTimeline1 super;
	int boneIndex;
} sp40TranslateYTimeline;

SP_API sp40TranslateYTimeline *sp40TranslateYTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp40TranslateYTimeline_setFrame(sp40TranslateYTimeline *self, int frame, float time, float y);

/**/

typedef struct sp40ScaleTimeline {
	sp40CurveTimeline2 super;
	int boneIndex;
} sp40ScaleTimeline;

SP_API sp40ScaleTimeline *sp40ScaleTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp40ScaleTimeline_setFrame(sp40ScaleTimeline *self, int frameIndex, float time, float x, float y);

/**/

typedef struct sp40ScaleXTimeline {
	sp40CurveTimeline1 super;
	int boneIndex;
} sp40ScaleXTimeline;

SP_API sp40ScaleXTimeline *sp40ScaleXTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp40ScaleXTimeline_setFrame(sp40ScaleXTimeline *self, int frame, float time, float x);

/**/

typedef struct sp40ScaleYTimeline {
	sp40CurveTimeline1 super;
	int boneIndex;
} sp40ScaleYTimeline;

SP_API sp40ScaleYTimeline *sp40ScaleYTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp40ScaleYTimeline_setFrame(sp40ScaleYTimeline *self, int frame, float time, float y);

/**/

typedef struct sp40ShearTimeline {
	sp40CurveTimeline2 super;
	int boneIndex;
} sp40ShearTimeline;

SP_API sp40ShearTimeline *sp40ShearTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp40ShearTimeline_setFrame(sp40ShearTimeline *self, int frameIndex, float time, float x, float y);

/**/

typedef struct sp40ShearXTimeline {
	sp40CurveTimeline1 super;
	int boneIndex;
} sp40ShearXTimeline;

SP_API sp40ShearXTimeline *sp40ShearXTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp40ShearXTimeline_setFrame(sp40ShearXTimeline *self, int frame, float time, float x);

/**/

typedef struct sp40ShearYTimeline {
	sp40CurveTimeline1 super;
	int boneIndex;
} sp40ShearYTimeline;

SP_API sp40ShearYTimeline *sp40ShearYTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp40ShearYTimeline_setFrame(sp40ShearYTimeline *self, int frame, float time, float x);

/**/

typedef struct sp40RGBATimeline {
	sp40CurveTimeline2 super;
	int slotIndex;
} sp40RGBATimeline;

SP_API sp40RGBATimeline *sp40RGBATimeline_create(int framesCount, int bezierCount, int slotIndex);

SP_API void
sp40RGBATimeline_setFrame(sp40RGBATimeline *self, int frameIndex, float time, float r, float g, float b, float a);

/**/

typedef struct sp40RGBTimeline {
	sp40CurveTimeline2 super;
	int slotIndex;
} sp40RGBTimeline;

SP_API sp40RGBTimeline *sp40RGBTimeline_create(int framesCount, int bezierCount, int slotIndex);

SP_API void sp40RGBTimeline_setFrame(sp40RGBTimeline *self, int frameIndex, float time, float r, float g, float b);

/**/

typedef struct sp40AlphaTimeline {
	sp40CurveTimeline1 super;
	int slotIndex;
} sp40AlphaTimeline;

SP_API sp40AlphaTimeline *sp40AlphaTimeline_create(int frameCount, int bezierCount, int slotIndex);

SP_API void sp40AlphaTimeline_setFrame(sp40AlphaTimeline *self, int frame, float time, float x);

/**/

typedef struct sp40RGBA2Timeline {
	sp40CurveTimeline super;
	int slotIndex;
} sp40RGBA2Timeline;

SP_API sp40RGBA2Timeline *sp40RGBA2Timeline_create(int framesCount, int bezierCount, int slotIndex);

SP_API void
sp40RGBA2Timeline_setFrame(sp40RGBA2Timeline *self, int frameIndex, float time, float r, float g, float b, float a,
						 float r2, float g2, float b2);

/**/

typedef struct sp40RGB2Timeline {
	sp40CurveTimeline super;
	int slotIndex;
} sp40RGB2Timeline;

SP_API sp40RGB2Timeline *sp40RGB2Timeline_create(int framesCount, int bezierCount, int slotIndex);

SP_API void
sp40RGB2Timeline_setFrame(sp40RGB2Timeline *self, int frameIndex, float time, float r, float g, float b, float r2, float g2,
						float b2);

/**/

typedef struct sp40AttachmentTimeline {
	sp40Timeline super;
	int slotIndex;
	const char **const attachmentNames;
} sp40AttachmentTimeline;

SP_API sp40AttachmentTimeline *sp40AttachmentTimeline_create(int framesCount, int SlotIndex);

/* @param attachmentName May be 0. */
SP_API void
sp40AttachmentTimeline_setFrame(sp40AttachmentTimeline *self, int frameIndex, float time, const char *attachmentName);

/**/

typedef struct sp40DeformTimeline {
	sp40CurveTimeline super;
	int const frameVerticesCount;
	const float **const frameVertices;
	int slotIndex;
	sp40Attachment *attachment;
} sp40DeformTimeline;

SP_API sp40DeformTimeline *
sp40DeformTimeline_create(int framesCount, int frameVerticesCount, int bezierCount, int slotIndex,
						sp40VertexAttachment *attachment);

SP_API void sp40DeformTimeline_setFrame(sp40DeformTimeline *self, int frameIndex, float time, float *vertices);

/**/

typedef struct sp40EventTimeline {
	sp40Timeline super;
	sp40Event **const events;
} sp40EventTimeline;

SP_API sp40EventTimeline *sp40EventTimeline_create(int framesCount);

SP_API void sp40EventTimeline_setFrame(sp40EventTimeline *self, int frameIndex, sp40Event *event);

/**/

typedef struct sp40DrawOrderTimeline {
	sp40Timeline super;
	const int **const drawOrders;
	int const slotsCount;
} sp40DrawOrderTimeline;

SP_API sp40DrawOrderTimeline *sp40DrawOrderTimeline_create(int framesCount, int slotsCount);

SP_API void sp40DrawOrderTimeline_setFrame(sp40DrawOrderTimeline *self, int frameIndex, float time, const int *drawOrder);

/**/

typedef struct sp40IkConstraintTimeline {
	sp40CurveTimeline super;
	int ikConstraintIndex;
} sp40IkConstraintTimeline;

SP_API sp40IkConstraintTimeline *
sp40IkConstraintTimeline_create(int framesCount, int bezierCount, int transformConstraintIndex);

SP_API void
sp40IkConstraintTimeline_setFrame(sp40IkConstraintTimeline *self, int frameIndex, float time, float mix, float softness,
								int bendDirection, int /*boolean*/ compress, int /**boolean**/ stretch);

/**/

typedef struct sp40TransformConstraintTimeline {
	sp40CurveTimeline super;
	int transformConstraintIndex;
} sp40TransformConstraintTimeline;

SP_API sp40TransformConstraintTimeline *
sp40TransformConstraintTimeline_create(int framesCount, int bezierCount, int transformConstraintIndex);

SP_API void
sp40TransformConstraintTimeline_setFrame(sp40TransformConstraintTimeline *self, int frameIndex, float time, float mixRotate,
									   float mixX, float mixY, float mixScaleX, float mixScaleY, float mixShearY);

/**/

typedef struct sp40PathConstraintPositionTimeline {
	sp40CurveTimeline super;
	int pathConstraintIndex;
} sp40PathConstraintPositionTimeline;

SP_API sp40PathConstraintPositionTimeline *
sp40PathConstraintPositionTimeline_create(int framesCount, int bezierCount, int pathConstraintIndex);

SP_API void
sp40PathConstraintPositionTimeline_setFrame(sp40PathConstraintPositionTimeline *self, int frameIndex, float time,
										  float value);

/**/

typedef struct sp40PathConstraintSpacingTimeline {
	sp40CurveTimeline super;
	int pathConstraintIndex;
} sp40PathConstraintSpacingTimeline;

SP_API sp40PathConstraintSpacingTimeline *
sp40PathConstraintSpacingTimeline_create(int framesCount, int bezierCount, int pathConstraintIndex);

SP_API void sp40PathConstraintSpacingTimeline_setFrame(sp40PathConstraintSpacingTimeline *self, int frameIndex, float time,
													 float value);

/**/

typedef struct sp40PathConstraintMixTimeline {
	sp40CurveTimeline super;
	int pathConstraintIndex;
} sp40PathConstraintMixTimeline;

SP_API sp40PathConstraintMixTimeline *
sp40PathConstraintMixTimeline_create(int framesCount, int bezierCount, int pathConstraintIndex);

SP_API void
sp40PathConstraintMixTimeline_setFrame(sp40PathConstraintMixTimeline *self, int frameIndex, float time, float mixRotate,
									 float mixX, float mixY);

/**/

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATION_H_ */

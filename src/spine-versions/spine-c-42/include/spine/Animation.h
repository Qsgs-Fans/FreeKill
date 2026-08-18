/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated July 28, 2023. Replaces all prior versions.
 *
 * Copyright (c) 2013-2023, Esoteric Software LLC
 *
 * Integration of the Spine Runtimes into software or otherwise creating
 * derivative works of the Spine Runtimes is permitted under the terms and
 * conditions of Section 2 of the Spine Editor License Agreement:
 * http://esotericsoftware.com/spine-editor-license
 *
 * Otherwise, it is permitted to integrate the Spine Runtimes into software or
 * otherwise create derivative works of the Spine Runtimes (collectively,
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
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE
 * SPINE RUNTIMES, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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

typedef struct sp42Timeline sp42Timeline;
struct sp42Skeleton;
typedef uint64_t sp42PropertyId;

_SP_ARRAY_DECLARE_TYPE(sp42PropertyIdArray, sp42PropertyId)

_SP_ARRAY_DECLARE_TYPE(sp42TimelineArray, sp42Timeline*)

typedef struct sp42Animation {
	char *name;
	float duration;

	sp42TimelineArray *timelines;
	sp42PropertyIdArray *timelineIds;
} sp42Animation;

typedef enum {
	SP_MIX_BLEND_SETUP,
	SP_MIX_BLEND_FIRST,
	SP_MIX_BLEND_REPLACE,
	SP_MIX_BLEND_ADD
} sp42MixBlend;

typedef enum {
	SP_MIX_DIRECTION_IN,
	SP_MIX_DIRECTION_OUT
} sp42MixDirection;

SP_API sp42Animation *sp42Animation_create(const char *name, sp42TimelineArray *timelines, float duration);

SP_API void sp42Animation_dispose(sp42Animation *self);

SP_API int /*bool*/ sp42Animation_hasTimeline(sp42Animation *self, sp42PropertyId *ids, int idsCount);

/** Poses the skeleton at the specified time for this animation.
 * @param lastTime The last time the animation was applied.
 * @param events Any triggered events are added. May be null.*/
SP_API void
sp42Animation_apply(const sp42Animation *self, struct sp42Skeleton *skeleton, float lastTime, float time, int loop,
				  sp42Event **events, int *eventsCount, float alpha, sp42MixBlend blend, sp42MixDirection direction);

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
    SP_TIMELINE_INHERIT,
	SP_TIMELINE_IKCONSTRAINT,
	SP_TIMELINE_PATHCONSTRAINTMIX,
    SP_TIMELINE_PHYSICSCONSTRAINT_INERTIA,
    SP_TIMELINE_PHYSICSCONSTRAINT_STRENGTH,
    SP_TIMELINE_PHYSICSCONSTRAINT_DAMPING,
    SP_TIMELINE_PHYSICSCONSTRAINT_MASS,
    SP_TIMELINE_PHYSICSCONSTRAINT_WIND,
    SP_TIMELINE_PHYSICSCONSTRAINT_GRAVITY,
    SP_TIMELINE_PHYSICSCONSTRAINT_MIX,
    SP_TIMELINE_PHYSICSCONSTRAINT_RESET,
	SP_TIMELINE_RGB2,
	SP_TIMELINE_RGBA2,
	SP_TIMELINE_RGBA,
	SP_TIMELINE_RGB,
	SP_TIMELINE_TRANSFORMCONSTRAINT,
	SP_TIMELINE_DRAWORDER,
	SP_TIMELINE_EVENT
} sp42TimelineType;

/**/

typedef enum {
	SP_PROPERTY_ROTATE = 1 << 0,
	SP_PROPERTY_X = 1 << 1,
	SP_PROPERTY_Y = 1 << 2,
	SP_PROPERTY_SCALEX = 1 << 3,
	SP_PROPERTY_SCALEY = 1 << 4,
	SP_PROPERTY_SHEARX = 1 << 5,
	SP_PROPERTY_SHEARY = 1 << 6,
    SP_PROPERTY_INHERIT = 1 << 7,
	SP_PROPERTY_RGB = 1 << 8,
	SP_PROPERTY_ALPHA = 1 << 9,
	SP_PROPERTY_RGB2 = 1 << 10,
	SP_PROPERTY_ATTACHMENT = 1 << 11,
	SP_PROPERTY_DEFORM = 1 << 12,
	SP_PROPERTY_EVENT = 1 << 13,
	SP_PROPERTY_DRAWORDER = 1 << 14,
	SP_PROPERTY_IKCONSTRAINT = 1 << 15,
	SP_PROPERTY_TRANSFORMCONSTRAINT = 1 << 16,
	SP_PROPERTY_PATHCONSTRAINT_POSITION = 1 << 17,
	SP_PROPERTY_PATHCONSTRAINT_SPACING = 1 << 18,
	SP_PROPERTY_PATHCONSTRAINT_MIX = 1 << 19,
    SP_PROPERTY_PHYSICSCONSTRAINT_INERTIA = 1 << 20,
    SP_PROPERTY_PHYSICSCONSTRAINT_STRENGTH = 1 << 21,
    SP_PROPERTY_PHYSICSCONSTRAINT_DAMPING = 1 << 22,
    SP_PROPERTY_PHYSICSCONSTRAINT_MASS = 1 << 23,
    SP_PROPERTY_PHYSICSCONSTRAINT_WIND = 1 << 24,
    SP_PROPERTY_PHYSICSCONSTRAINT_GRAVITY = 1 << 25,
    SP_PROPERTY_PHYSICSCONSTRAINT_MIX = 1 << 26,
    SP_PROPERTY_PHYSICSCONSTRAINT_RESET = 1 << 27,
	SP_PROPERTY_SEQUENCE = 1 << 28
} sp42Property;

#define SP_MAX_PROPERTY_IDS 3

typedef struct _sp42TimelineVtable {
	void (*apply)(sp42Timeline *self, struct sp42Skeleton *skeleton, float lastTime, float time, sp42Event **firedEvents,
				  int *eventsCount, float alpha, sp42MixBlend blend, sp42MixDirection direction);

	void (*dispose)(sp42Timeline *self);

	void
	(*setBezier)(sp42Timeline *self, int bezier, int frame, float value, float time1, float value1, float cx1, float cy1,
				 float cx2, float cy2, float time2, float value2);
} _sp42TimelineVtable;

struct sp42Timeline {
	_sp42TimelineVtable vtable;
	sp42PropertyId propertyIds[SP_MAX_PROPERTY_IDS];
	int propertyIdsCount;
	sp42FloatArray *frames;
	int frameCount;
	int frameEntries;
	sp42TimelineType type;
};

SP_API void sp42Timeline_dispose(sp42Timeline *self);

SP_API void
sp42Timeline_apply(sp42Timeline *self, struct sp42Skeleton *skeleton, float lastTime, float time, sp42Event **firedEvents,
				 int *eventsCount, float alpha, sp42MixBlend blend, sp42MixDirection direction);

SP_API void
sp42Timeline_setBezier(sp42Timeline *self, int bezier, int frame, float value, float time1, float value1, float cx1,
					 float cy1, float cx2, float cy2, float time2, float value2);

SP_API float sp42Timeline_getDuration(const sp42Timeline *self);

/**/

typedef struct sp42CurveTimeline {
	sp42Timeline super;
	sp42FloatArray *curves; /* type, x, y, ... */
} sp42CurveTimeline;

SP_API void sp42CurveTimeline_setLinear(sp42CurveTimeline *self, int frameIndex);

SP_API void sp42CurveTimeline_setStepped(sp42CurveTimeline *self, int frameIndex);

/* Sets the control handle positions for an interpolation bezier curve used to transition from this keyframe to the next.
 * cx1 and cx2 are from 0 to 1, representing the percent of time between the two keyframes. cy1 and cy2 are the percent of
 * the difference between the keyframe's values. */
SP_API void sp42CurveTimeline_setCurve(sp42CurveTimeline *self, int frameIndex, float cx1, float cy1, float cx2, float cy2);

SP_API float sp42CurveTimeline_getCurvePercent(const sp42CurveTimeline *self, int frameIndex, float percent);

typedef struct sp42CurveTimeline sp42CurveTimeline1;

SP_API void sp42CurveTimeline1_setFrame(sp42CurveTimeline1 *self, int frame, float time, float value);

SP_API float sp42CurveTimeline1_getCurveValue(sp42CurveTimeline1 *self, float time);

SP_API float sp42CurveTimeline1_getRelativeValue(sp42CurveTimeline1 *timeline, float time, float alpha, sp42MixBlend blend, float current, float setup);

SP_API float sp42CurveTimeline1_getAbsoluteValue(sp42CurveTimeline1 *timeline, float time, float alpha, sp42MixBlend blend, float current, float setup);

SP_API float sp42CurveTimeline1_getAbsoluteValue2(sp42CurveTimeline1 *timeline, float time, float alpha, sp42MixBlend blend, float current, float setup, float value);

SP_API float sp42CurveTimeline1_getScaleValue (sp42CurveTimeline1 *timeline, float time, float alpha, sp42MixBlend blend, sp42MixDirection direction, float current, float setup);

typedef struct sp42CurveTimeline sp42CurveTimeline2;

SP_API void sp42CurveTimeline2_setFrame(sp42CurveTimeline1 *self, int frame, float time, float value1, float value2);

/**/

typedef struct sp42RotateTimeline {
	sp42CurveTimeline1 super;
	int boneIndex;
} sp42RotateTimeline;

SP_API sp42RotateTimeline *sp42RotateTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp42RotateTimeline_setFrame(sp42RotateTimeline *self, int frameIndex, float time, float angle);

/**/

typedef struct sp42TranslateTimeline {
	sp42CurveTimeline2 super;
	int boneIndex;
} sp42TranslateTimeline;

SP_API sp42TranslateTimeline *sp42TranslateTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp42TranslateTimeline_setFrame(sp42TranslateTimeline *self, int frameIndex, float time, float x, float y);

/**/

typedef struct sp42TranslateXTimeline {
	sp42CurveTimeline1 super;
	int boneIndex;
} sp42TranslateXTimeline;

SP_API sp42TranslateXTimeline *sp42TranslateXTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp42TranslateXTimeline_setFrame(sp42TranslateXTimeline *self, int frame, float time, float x);

/**/

typedef struct sp42TranslateYTimeline {
	sp42CurveTimeline1 super;
	int boneIndex;
} sp42TranslateYTimeline;

SP_API sp42TranslateYTimeline *sp42TranslateYTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp42TranslateYTimeline_setFrame(sp42TranslateYTimeline *self, int frame, float time, float y);

/**/

typedef struct sp42ScaleTimeline {
	sp42CurveTimeline2 super;
	int boneIndex;
} sp42ScaleTimeline;

SP_API sp42ScaleTimeline *sp42ScaleTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp42ScaleTimeline_setFrame(sp42ScaleTimeline *self, int frameIndex, float time, float x, float y);

/**/

typedef struct sp42ScaleXTimeline {
	sp42CurveTimeline1 super;
	int boneIndex;
} sp42ScaleXTimeline;

SP_API sp42ScaleXTimeline *sp42ScaleXTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp42ScaleXTimeline_setFrame(sp42ScaleXTimeline *self, int frame, float time, float x);

/**/

typedef struct sp42ScaleYTimeline {
	sp42CurveTimeline1 super;
	int boneIndex;
} sp42ScaleYTimeline;

SP_API sp42ScaleYTimeline *sp42ScaleYTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp42ScaleYTimeline_setFrame(sp42ScaleYTimeline *self, int frame, float time, float y);

/**/

typedef struct sp42ShearTimeline {
	sp42CurveTimeline2 super;
	int boneIndex;
} sp42ShearTimeline;

SP_API sp42ShearTimeline *sp42ShearTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp42ShearTimeline_setFrame(sp42ShearTimeline *self, int frameIndex, float time, float x, float y);

/**/

typedef struct sp42ShearXTimeline {
	sp42CurveTimeline1 super;
	int boneIndex;
} sp42ShearXTimeline;

SP_API sp42ShearXTimeline *sp42ShearXTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp42ShearXTimeline_setFrame(sp42ShearXTimeline *self, int frame, float time, float x);

/**/

typedef struct sp42ShearYTimeline {
	sp42CurveTimeline1 super;
	int boneIndex;
} sp42ShearYTimeline;

SP_API sp42ShearYTimeline *sp42ShearYTimeline_create(int frameCount, int bezierCount, int boneIndex);

SP_API void sp42ShearYTimeline_setFrame(sp42ShearYTimeline *self, int frame, float time, float x);

/**/

typedef struct sp42RGBATimeline {
	sp42CurveTimeline2 super;
	int slotIndex;
} sp42RGBATimeline;

SP_API sp42RGBATimeline *sp42RGBATimeline_create(int framesCount, int bezierCount, int slotIndex);

SP_API void
sp42RGBATimeline_setFrame(sp42RGBATimeline *self, int frameIndex, float time, float r, float g, float b, float a);

/**/

typedef struct sp42RGBTimeline {
	sp42CurveTimeline2 super;
	int slotIndex;
} sp42RGBTimeline;

SP_API sp42RGBTimeline *sp42RGBTimeline_create(int framesCount, int bezierCount, int slotIndex);

SP_API void sp42RGBTimeline_setFrame(sp42RGBTimeline *self, int frameIndex, float time, float r, float g, float b);

/**/

typedef struct sp42AlphaTimeline {
	sp42CurveTimeline1 super;
	int slotIndex;
} sp42AlphaTimeline;

SP_API sp42AlphaTimeline *sp42AlphaTimeline_create(int frameCount, int bezierCount, int slotIndex);

SP_API void sp42AlphaTimeline_setFrame(sp42AlphaTimeline *self, int frame, float time, float x);

/**/

typedef struct sp42RGBA2Timeline {
	sp42CurveTimeline super;
	int slotIndex;
} sp42RGBA2Timeline;

SP_API sp42RGBA2Timeline *sp42RGBA2Timeline_create(int framesCount, int bezierCount, int slotIndex);

SP_API void
sp42RGBA2Timeline_setFrame(sp42RGBA2Timeline *self, int frameIndex, float time, float r, float g, float b, float a,
						 float r2, float g2, float b2);

/**/

typedef struct sp42RGB2Timeline {
	sp42CurveTimeline super;
	int slotIndex;
} sp42RGB2Timeline;

SP_API sp42RGB2Timeline *sp42RGB2Timeline_create(int framesCount, int bezierCount, int slotIndex);

SP_API void
sp42RGB2Timeline_setFrame(sp42RGB2Timeline *self, int frameIndex, float time, float r, float g, float b, float r2, float g2,
						float b2);

/**/

typedef struct sp42AttachmentTimeline {
	sp42Timeline super;
	int slotIndex;
	char **attachmentNames;
} sp42AttachmentTimeline;

SP_API sp42AttachmentTimeline *sp42AttachmentTimeline_create(int framesCount, int SlotIndex);

/* @param attachmentName May be 0. */
SP_API void
sp42AttachmentTimeline_setFrame(sp42AttachmentTimeline *self, int frameIndex, float time, const char *attachmentName);

/**/

typedef struct sp42DeformTimeline {
	sp42CurveTimeline super;
	int frameVerticesCount;
	float **frameVertices;
	int slotIndex;
	sp42Attachment *attachment;
} sp42DeformTimeline;

SP_API sp42DeformTimeline *
sp42DeformTimeline_create(int framesCount, int frameVerticesCount, int bezierCount, int slotIndex,
						sp42VertexAttachment *attachment);

SP_API void sp42DeformTimeline_setFrame(sp42DeformTimeline *self, int frameIndex, float time, float *vertices);

/**/

typedef struct sp42SequenceTimeline {
	sp42Timeline super;
	int slotIndex;
	sp42Attachment *attachment;
} sp42SequenceTimeline;

SP_API sp42SequenceTimeline *sp42SequenceTimeline_create(int framesCount, int slotIndex, sp42Attachment *attachment);

SP_API void sp42SequenceTimeline_setFrame(sp42SequenceTimeline *self, int frameIndex, float time, int mode, int index, float delay);

/**/

/**/

typedef struct sp42EventTimeline {
	sp42Timeline super;
	sp42Event **events;
} sp42EventTimeline;

SP_API sp42EventTimeline *sp42EventTimeline_create(int framesCount);

SP_API void sp42EventTimeline_setFrame(sp42EventTimeline *self, int frameIndex, sp42Event *event);

/**/

typedef struct sp42DrawOrderTimeline {
	sp42Timeline super;
	int **drawOrders;
	int slotsCount;
} sp42DrawOrderTimeline;

SP_API sp42DrawOrderTimeline *sp42DrawOrderTimeline_create(int framesCount, int slotsCount);

SP_API void sp42DrawOrderTimeline_setFrame(sp42DrawOrderTimeline *self, int frameIndex, float time, const int *drawOrder);

/**/

typedef struct sp42InheritTimeline {
    sp42Timeline super;
    int boneIndex;
} sp42InheritTimeline;

SP_API sp42InheritTimeline *sp42InheritTimeline_create(int framesCount, int boneIndex);

SP_API void sp42InheritTimeline_setFrame(sp42InheritTimeline *self, int frameIndex, float time, sp42Inherit inherit);


/**/

typedef struct sp42IkConstraintTimeline {
	sp42CurveTimeline super;
	int ikConstraintIndex;
} sp42IkConstraintTimeline;

SP_API sp42IkConstraintTimeline *
sp42IkConstraintTimeline_create(int framesCount, int bezierCount, int transformConstraintIndex);

SP_API void
sp42IkConstraintTimeline_setFrame(sp42IkConstraintTimeline *self, int frameIndex, float time, float mix, float softness,
								int bendDirection, int /*boolean*/ compress, int /**boolean**/ stretch);

/**/

typedef struct sp42TransformConstraintTimeline {
	sp42CurveTimeline super;
	int transformConstraintIndex;
} sp42TransformConstraintTimeline;

SP_API sp42TransformConstraintTimeline *
sp42TransformConstraintTimeline_create(int framesCount, int bezierCount, int transformConstraintIndex);

SP_API void
sp42TransformConstraintTimeline_setFrame(sp42TransformConstraintTimeline *self, int frameIndex, float time, float mixRotate,
									   float mixX, float mixY, float mixScaleX, float mixScaleY, float mixShearY);

/**/

typedef struct sp42PathConstraintPositionTimeline {
	sp42CurveTimeline super;
	int pathConstraintIndex;
} sp42PathConstraintPositionTimeline;

SP_API sp42PathConstraintPositionTimeline *
sp42PathConstraintPositionTimeline_create(int framesCount, int bezierCount, int pathConstraintIndex);

SP_API void
sp42PathConstraintPositionTimeline_setFrame(sp42PathConstraintPositionTimeline *self, int frameIndex, float time,
										  float value);

/**/

typedef struct sp42PathConstraintSpacingTimeline {
	sp42CurveTimeline super;
	int pathConstraintIndex;
} sp42PathConstraintSpacingTimeline;

SP_API sp42PathConstraintSpacingTimeline *
sp42PathConstraintSpacingTimeline_create(int framesCount, int bezierCount, int pathConstraintIndex);

SP_API void sp42PathConstraintSpacingTimeline_setFrame(sp42PathConstraintSpacingTimeline *self, int frameIndex, float time,
													 float value);

/**/

typedef struct sp42PathConstraintMixTimeline {
	sp42CurveTimeline super;
	int pathConstraintIndex;
} sp42PathConstraintMixTimeline;

SP_API sp42PathConstraintMixTimeline *
sp42PathConstraintMixTimeline_create(int framesCount, int bezierCount, int pathConstraintIndex);

SP_API void
sp42PathConstraintMixTimeline_setFrame(sp42PathConstraintMixTimeline *self, int frameIndex, float time, float mixRotate,
									 float mixX, float mixY);

/**/

typedef struct sp42PhysicsConstraintTimeline {
    sp42CurveTimeline super;
    int physicsConstraintIndex;
} sp42PhysicsConstraintTimeline;

SP_API sp42PhysicsConstraintTimeline *
sp42PhysicsConstraintTimeline_create(int framesCount, int bezierCount, int physicsConstraintIndex, sp42TimelineType type);

SP_API void sp42PhysicsConstraintTimeline_setFrame(sp42PhysicsConstraintTimeline *self, int frame, float time, float value);

/**/

typedef struct sp42PhysicsConstraintResetTimeline {
    sp42Timeline super;
    int physicsConstraintIndex;
} sp42PhysicsConstraintResetTimeline;

SP_API sp42PhysicsConstraintResetTimeline *sp42PhysicsConstraintResetTimeline_create(int framesCount, int boneIndex);

SP_API void sp42PhysicsConstraintResetTimeline_setFrame(sp42PhysicsConstraintResetTimeline *self, int frameIndex, float time);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATION_H_ */

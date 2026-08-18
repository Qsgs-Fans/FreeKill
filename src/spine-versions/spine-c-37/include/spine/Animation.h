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

#ifndef SPINE_ANIMATION_H_
#define SPINE_ANIMATION_H_

#include <spine/dll.h>
#include <spine/Event.h>
#include <spine/Attachment.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp37Timeline sp37Timeline;
struct sp37Skeleton;

typedef struct sp37Animation {
	const char* const name;
	float duration;

	int timelinesCount;
	sp37Timeline** timelines;

#ifdef __cplusplus
	sp37Animation() :
		name(0),
		duration(0),
		timelinesCount(0),
		timelines(0) {
	}
#endif
} sp37Animation;

typedef enum {
	SP_MIX_BLEND_SETUP,
	SP_MIX_BLEND_FIRST,
	SP_MIX_BLEND_REPLACE,
	SP_MIX_BLEND_ADD
} sp37MixBlend;

typedef enum {
	SP_MIX_DIRECTION_IN,
	SP_MIX_DIRECTION_OUT
} sp37MixDirection;

SP_API sp37Animation* sp37Animation_create (const char* name, int timelinesCount);
SP_API void sp37Animation_dispose (sp37Animation* self);

/** Poses the skeleton at the specified time for this animation.
 * @param lastTime The last time the animation was applied.
 * @param events Any triggered events are added. May be null.*/
SP_API void sp37Animation_apply (const sp37Animation* self, struct sp37Skeleton* skeleton, float lastTime, float time, int loop,
		sp37Event** events, int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction);

#ifdef SPINE_SHORT_NAMES
typedef sp37Animation Animation;
#define Animation_create(...) sp37Animation_create(__VA_ARGS__)
#define Animation_dispose(...) sp37Animation_dispose(__VA_ARGS__)
#define Animation_apply(...) sp37Animation_apply(__VA_ARGS__)
#endif

/**/

typedef enum {
	SP_TIMELINE_ROTATE,
	SP_TIMELINE_TRANSLATE,
	SP_TIMELINE_SCALE,
	SP_TIMELINE_SHEAR,
	SP_TIMELINE_ATTACHMENT,
	SP_TIMELINE_COLOR,
	SP_TIMELINE_DEFORM,
	SP_TIMELINE_EVENT,
	SP_TIMELINE_DRAWORDER,
	SP_TIMELINE_IKCONSTRAINT,
	SP_TIMELINE_TRANSFORMCONSTRAINT,
	SP_TIMELINE_PATHCONSTRAINTPOSITION,
	SP_TIMELINE_PATHCONSTRAINTSPACING,
	SP_TIMELINE_PATHCONSTRAINTMIX,
	SP_TIMELINE_TWOCOLOR
} sp37TimelineType;

struct sp37Timeline {
	const sp37TimelineType type;
	const void* const vtable;

#ifdef __cplusplus
	sp37Timeline() :
		type(SP_TIMELINE_SCALE),
		vtable(0) {
	}
#endif
};

SP_API void sp37Timeline_dispose (sp37Timeline* self);
SP_API void sp37Timeline_apply (const sp37Timeline* self, struct sp37Skeleton* skeleton, float lastTime, float time, sp37Event** firedEvents,
		int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction);
SP_API int sp37Timeline_getPropertyId (const sp37Timeline* self);

#ifdef SPINE_SHORT_NAMES
typedef sp37Timeline Timeline;
#define TIMELINE_SCALE SP_TIMELINE_SCALE
#define TIMELINE_ROTATE SP_TIMELINE_ROTATE
#define TIMELINE_TRANSLATE SP_TIMELINE_TRANSLATE
#define TIMELINE_COLOR SP_TIMELINE_COLOR
#define TIMELINE_ATTACHMENT SP_TIMELINE_ATTACHMENT
#define TIMELINE_EVENT SP_TIMELINE_EVENT
#define TIMELINE_DRAWORDER SP_TIMELINE_DRAWORDER
#define Timeline_dispose(...) sp37Timeline_dispose(__VA_ARGS__)
#define Timeline_apply(...) sp37Timeline_apply(__VA_ARGS__)
#endif

/**/

typedef struct sp37CurveTimeline {
	sp37Timeline super;
	float* curves; /* type, x, y, ... */

#ifdef __cplusplus
	sp37CurveTimeline() :
		super(),
		curves(0) {
	}
#endif
} sp37CurveTimeline;

SP_API void sp37CurveTimeline_setLinear (sp37CurveTimeline* self, int frameIndex);
SP_API void sp37CurveTimeline_setStepped (sp37CurveTimeline* self, int frameIndex);

/* Sets the control handle positions for an interpolation bezier curve used to transition from this keyframe to the next.
 * cx1 and cx2 are from 0 to 1, representing the percent of time between the two keyframes. cy1 and cy2 are the percent of
 * the difference between the keyframe's values. */
SP_API void sp37CurveTimeline_setCurve (sp37CurveTimeline* self, int frameIndex, float cx1, float cy1, float cx2, float cy2);
SP_API float sp37CurveTimeline_getCurvePercent (const sp37CurveTimeline* self, int frameIndex, float percent);

#ifdef SPINE_SHORT_NAMES
typedef sp37CurveTimeline CurveTimeline;
#define CurveTimeline_setLinear(...) sp37CurveTimeline_setLinear(__VA_ARGS__)
#define CurveTimeline_setStepped(...) sp37CurveTimeline_setStepped(__VA_ARGS__)
#define CurveTimeline_setCurve(...) sp37CurveTimeline_setCurve(__VA_ARGS__)
#define CurveTimeline_getCurvePercent(...) sp37CurveTimeline_getCurvePercent(__VA_ARGS__)
#endif

/**/

typedef struct sp37BaseTimeline {
	sp37CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, angle, ... for rotate. time, x, y, ... for translate and scale. */
	int boneIndex;

#ifdef __cplusplus
	sp37BaseTimeline() :
		super(),
		framesCount(0),
		frames(0),
		boneIndex(0) {
	}
#endif
} sp37BaseTimeline;

/**/

static const int ROTATE_PREV_TIME = -2, ROTATE_PREV_ROTATION = -1;
static const int ROTATE_ROTATION = 1;
static const int ROTATE_ENTRIES = 2;

typedef struct sp37BaseTimeline sp37RotateTimeline;

SP_API sp37RotateTimeline* sp37RotateTimeline_create (int framesCount);

SP_API void sp37RotateTimeline_setFrame (sp37RotateTimeline* self, int frameIndex, float time, float angle);

#ifdef SPINE_SHORT_NAMES
typedef sp37RotateTimeline RotateTimeline;
#define RotateTimeline_create(...) sp37RotateTimeline_create(__VA_ARGS__)
#define RotateTimeline_setFrame(...) sp37RotateTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int TRANSLATE_ENTRIES = 3;

typedef struct sp37BaseTimeline sp37TranslateTimeline;

SP_API sp37TranslateTimeline* sp37TranslateTimeline_create (int framesCount);

SP_API void sp37TranslateTimeline_setFrame (sp37TranslateTimeline* self, int frameIndex, float time, float x, float y);

#ifdef SPINE_SHORT_NAMES
typedef sp37TranslateTimeline TranslateTimeline;
#define TranslateTimeline_create(...) sp37TranslateTimeline_create(__VA_ARGS__)
#define TranslateTimeline_setFrame(...) sp37TranslateTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp37BaseTimeline sp37ScaleTimeline;

SP_API sp37ScaleTimeline* sp37ScaleTimeline_create (int framesCount);

SP_API void sp37ScaleTimeline_setFrame (sp37ScaleTimeline* self, int frameIndex, float time, float x, float y);

#ifdef SPINE_SHORT_NAMES
typedef sp37ScaleTimeline ScaleTimeline;
#define ScaleTimeline_create(...) sp37ScaleTimeline_create(__VA_ARGS__)
#define ScaleTimeline_setFrame(...) sp37ScaleTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp37BaseTimeline sp37ShearTimeline;

SP_API sp37ShearTimeline* sp37ShearTimeline_create (int framesCount);

SP_API void sp37ShearTimeline_setFrame (sp37ShearTimeline* self, int frameIndex, float time, float x, float y);

#ifdef SPINE_SHORT_NAMES
typedef sp37ShearTimeline ShearTimeline;
#define ShearTimeline_create(...) sp37ShearTimeline_create(__VA_ARGS__)
#define ShearTimeline_setFrame(...) sp37ShearTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int COLOR_ENTRIES = 5;

typedef struct sp37ColorTimeline {
	sp37CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, r, g, b, a, ... */
	int slotIndex;

#ifdef __cplusplus
	sp37ColorTimeline() :
		super(),
		framesCount(0),
		frames(0),
		slotIndex(0) {
	}
#endif
} sp37ColorTimeline;

SP_API sp37ColorTimeline* sp37ColorTimeline_create (int framesCount);

SP_API void sp37ColorTimeline_setFrame (sp37ColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a);

#ifdef SPINE_SHORT_NAMES
typedef sp37ColorTimeline ColorTimeline;
#define ColorTimeline_create(...) sp37ColorTimeline_create(__VA_ARGS__)
#define ColorTimeline_setFrame(...) sp37ColorTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int TWOCOLOR_ENTRIES = 8;

typedef struct sp37TwoColorTimeline {
	sp37CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, r, g, b, a, ... */
	int slotIndex;

#ifdef __cplusplus
	sp37TwoColorTimeline() :
		super(),
		framesCount(0),
		frames(0),
		slotIndex(0) {
	}
#endif
} sp37TwoColorTimeline;

SP_API sp37TwoColorTimeline* sp37TwoColorTimeline_create (int framesCount);

SP_API void sp37TwoColorTimeline_setFrame (sp37TwoColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a, float r2, float g2, float b2);

#ifdef SPINE_SHORT_NAMES
typedef sp37TwoColorTimeline TwoColorTimeline;
#define TwoColorTimeline_create(...) sp37TwoColorTimeline_create(__VA_ARGS__)
#define TwoColorTimeline_setFrame(...) sp37TwoColorTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp37AttachmentTimeline {
	sp37Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	int slotIndex;
	const char** const attachmentNames;

#ifdef __cplusplus
	sp37AttachmentTimeline() :
		super(),
		framesCount(0),
		frames(0),
		slotIndex(0),
		attachmentNames(0) {
	}
#endif
} sp37AttachmentTimeline;

SP_API sp37AttachmentTimeline* sp37AttachmentTimeline_create (int framesCount);

/* @param attachmentName May be 0. */
SP_API void sp37AttachmentTimeline_setFrame (sp37AttachmentTimeline* self, int frameIndex, float time, const char* attachmentName);

#ifdef SPINE_SHORT_NAMES
typedef sp37AttachmentTimeline AttachmentTimeline;
#define AttachmentTimeline_create(...) sp37AttachmentTimeline_create(__VA_ARGS__)
#define AttachmentTimeline_setFrame(...) sp37AttachmentTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp37EventTimeline {
	sp37Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	sp37Event** const events;

#ifdef __cplusplus
	sp37EventTimeline() :
		super(),
		framesCount(0),
		frames(0),
		events(0) {
	}
#endif
} sp37EventTimeline;

SP_API sp37EventTimeline* sp37EventTimeline_create (int framesCount);

SP_API void sp37EventTimeline_setFrame (sp37EventTimeline* self, int frameIndex, sp37Event* event);

#ifdef SPINE_SHORT_NAMES
typedef sp37EventTimeline EventTimeline;
#define EventTimeline_create(...) sp37EventTimeline_create(__VA_ARGS__)
#define EventTimeline_setFrame(...) sp37EventTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp37DrawOrderTimeline {
	sp37Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	const int** const drawOrders;
	int const slotsCount;

#ifdef __cplusplus
	sp37DrawOrderTimeline() :
		super(),
		framesCount(0),
		frames(0),
		drawOrders(0),
		slotsCount(0) {
	}
#endif
} sp37DrawOrderTimeline;

SP_API sp37DrawOrderTimeline* sp37DrawOrderTimeline_create (int framesCount, int slotsCount);

SP_API void sp37DrawOrderTimeline_setFrame (sp37DrawOrderTimeline* self, int frameIndex, float time, const int* drawOrder);

#ifdef SPINE_SHORT_NAMES
typedef sp37DrawOrderTimeline DrawOrderTimeline;
#define DrawOrderTimeline_create(...) sp37DrawOrderTimeline_create(__VA_ARGS__)
#define DrawOrderTimeline_setFrame(...) sp37DrawOrderTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp37DeformTimeline {
	sp37CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	int const frameVerticesCount;
	const float** const frameVertices;
	int slotIndex;
	sp37Attachment* attachment;

#ifdef __cplusplus
	sp37DeformTimeline() :
		super(),
		framesCount(0),
		frames(0),
		frameVerticesCount(0),
		frameVertices(0),
		slotIndex(0) {
	}
#endif
} sp37DeformTimeline;

SP_API sp37DeformTimeline* sp37DeformTimeline_create (int framesCount, int frameVerticesCount);

SP_API void sp37DeformTimeline_setFrame (sp37DeformTimeline* self, int frameIndex, float time, float* vertices);

#ifdef SPINE_SHORT_NAMES
typedef sp37DeformTimeline DeformTimeline;
#define DeformTimeline_create(...) sp37DeformTimeline_create(__VA_ARGS__)
#define DeformTimeline_setFrame(...) sp37DeformTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int IKCONSTRAINT_ENTRIES = 5;

typedef struct sp37IkConstraintTimeline {
	sp37CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, mix, bendDirection, ... */
	int ikConstraintIndex;

#ifdef __cplusplus
	sp37IkConstraintTimeline() :
		super(),
		framesCount(0),
		frames(0),
		ikConstraintIndex(0) {
	}
#endif
} sp37IkConstraintTimeline;

SP_API sp37IkConstraintTimeline* sp37IkConstraintTimeline_create (int framesCount);

SP_API void sp37IkConstraintTimeline_setFrame (sp37IkConstraintTimeline* self, int frameIndex, float time, float mix, int bendDirection, int /*boolean*/ compress, int /**boolean**/ stretch);

#ifdef SPINE_SHORT_NAMES
typedef sp37IkConstraintTimeline IkConstraintTimeline;
#define IkConstraintTimeline_create(...) sp37IkConstraintTimeline_create(__VA_ARGS__)
#define IkConstraintTimeline_setFrame(...) sp37IkConstraintTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int TRANSFORMCONSTRAINT_ENTRIES = 5;

typedef struct sp37TransformConstraintTimeline {
	sp37CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int transformConstraintIndex;

#ifdef __cplusplus
	sp37TransformConstraintTimeline() :
		super(),
		framesCount(0),
		frames(0),
		transformConstraintIndex(0) {
	}
#endif
} sp37TransformConstraintTimeline;

SP_API sp37TransformConstraintTimeline* sp37TransformConstraintTimeline_create (int framesCount);

SP_API void sp37TransformConstraintTimeline_setFrame (sp37TransformConstraintTimeline* self, int frameIndex, float time, float rotateMix, float translateMix, float scaleMix, float shearMix);

#ifdef SPINE_SHORT_NAMES
typedef sp37TransformConstraintTimeline TransformConstraintTimeline;
#define TransformConstraintTimeline_create(...) sp37TransformConstraintTimeline_create(__VA_ARGS__)
#define TransformConstraintTimeline_setFrame(...) sp37TransformConstraintTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int PATHCONSTRAINTPOSITION_ENTRIES = 2;

typedef struct sp37PathConstraintPositionTimeline {
	sp37CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int pathConstraintIndex;

#ifdef __cplusplus
	sp37PathConstraintPositionTimeline() :
		super(),
		framesCount(0),
		frames(0),
		pathConstraintIndex(0) {
	}
#endif
} sp37PathConstraintPositionTimeline;

SP_API sp37PathConstraintPositionTimeline* sp37PathConstraintPositionTimeline_create (int framesCount);

SP_API void sp37PathConstraintPositionTimeline_setFrame (sp37PathConstraintPositionTimeline* self, int frameIndex, float time, float value);

#ifdef SPINE_SHORT_NAMES
typedef sp37PathConstraintPositionTimeline PathConstraintPositionTimeline;
#define PathConstraintPositionTimeline_create(...) sp37PathConstraintPositionTimeline_create(__VA_ARGS__)
#define PathConstraintPositionTimeline_setFrame(...) sp37PathConstraintPositionTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int PATHCONSTRAINTSPACING_ENTRIES = 2;

typedef struct sp37PathConstraintSpacingTimeline {
	sp37CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int pathConstraintIndex;

#ifdef __cplusplus
	sp37PathConstraintSpacingTimeline() :
		super(),
		framesCount(0),
		frames(0),
		pathConstraintIndex(0) {
	}
#endif
} sp37PathConstraintSpacingTimeline;

SP_API sp37PathConstraintSpacingTimeline* sp37PathConstraintSpacingTimeline_create (int framesCount);

SP_API void sp37PathConstraintSpacingTimeline_setFrame (sp37PathConstraintSpacingTimeline* self, int frameIndex, float time, float value);

#ifdef SPINE_SHORT_NAMES
typedef sp37PathConstraintSpacingTimeline PathConstraintSpacingTimeline;
#define PathConstraintSpacingTimeline_create(...) sp37PathConstraintSpacingTimeline_create(__VA_ARGS__)
#define PathConstraintSpacingTimeline_setFrame(...) sp37PathConstraintSpacingTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int PATHCONSTRAINTMIX_ENTRIES = 3;

typedef struct sp37PathConstraintMixTimeline {
	sp37CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int pathConstraintIndex;

#ifdef __cplusplus
	sp37PathConstraintMixTimeline() :
		super(),
		framesCount(0),
		frames(0),
		pathConstraintIndex(0) {
	}
#endif
} sp37PathConstraintMixTimeline;

SP_API sp37PathConstraintMixTimeline* sp37PathConstraintMixTimeline_create (int framesCount);

SP_API void sp37PathConstraintMixTimeline_setFrame (sp37PathConstraintMixTimeline* self, int frameIndex, float time, float rotateMix, float translateMix);

#ifdef SPINE_SHORT_NAMES
typedef sp37PathConstraintMixTimeline PathConstraintMixTimeline;
#define PathConstraintMixTimeline_create(...) sp37PathConstraintMixTimeline_create(__VA_ARGS__)
#define PathConstraintMixTimeline_setFrame(...) sp37PathConstraintMixTimeline_setFrame(__VA_ARGS__)
#endif

/**/

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATION_H_ */

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

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp38Timeline sp38Timeline;
struct sp38Skeleton;

typedef struct sp38Animation {
	const char* const name;
	float duration;

	int timelinesCount;
	sp38Timeline** timelines;

#ifdef __cplusplus
	sp38Animation() :
		name(0),
		duration(0),
		timelinesCount(0),
		timelines(0) {
	}
#endif
} sp38Animation;

typedef enum {
	SP_MIX_BLEND_SETUP,
	SP_MIX_BLEND_FIRST,
	SP_MIX_BLEND_REPLACE,
	SP_MIX_BLEND_ADD
} sp38MixBlend;

typedef enum {
	SP_MIX_DIRECTION_IN,
	SP_MIX_DIRECTION_OUT
} sp38MixDirection;

SP_API sp38Animation* sp38Animation_create (const char* name, int timelinesCount);
SP_API void sp38Animation_dispose (sp38Animation* self);

/** Poses the skeleton at the specified time for this animation.
 * @param lastTime The last time the animation was applied.
 * @param events Any triggered events are added. May be null.*/
SP_API void sp38Animation_apply (const sp38Animation* self, struct sp38Skeleton* skeleton, float lastTime, float time, int loop,
		sp38Event** events, int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction);

#ifdef SPINE_SHORT_NAMES
typedef sp38Animation Animation;
#define Animation_create(...) sp38Animation_create(__VA_ARGS__)
#define Animation_dispose(...) sp38Animation_dispose(__VA_ARGS__)
#define Animation_apply(...) sp38Animation_apply(__VA_ARGS__)
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
} sp38TimelineType;

struct sp38Timeline {
	const sp38TimelineType type;
	const void* const vtable;

#ifdef __cplusplus
	sp38Timeline() :
		type(SP_TIMELINE_SCALE),
		vtable(0) {
	}
#endif
};

SP_API void sp38Timeline_dispose (sp38Timeline* self);
SP_API void sp38Timeline_apply (const sp38Timeline* self, struct sp38Skeleton* skeleton, float lastTime, float time, sp38Event** firedEvents,
		int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction);
SP_API int sp38Timeline_getPropertyId (const sp38Timeline* self);

#ifdef SPINE_SHORT_NAMES
typedef sp38Timeline Timeline;
#define TIMELINE_SCALE SP_TIMELINE_SCALE
#define TIMELINE_ROTATE SP_TIMELINE_ROTATE
#define TIMELINE_TRANSLATE SP_TIMELINE_TRANSLATE
#define TIMELINE_COLOR SP_TIMELINE_COLOR
#define TIMELINE_ATTACHMENT SP_TIMELINE_ATTACHMENT
#define TIMELINE_EVENT SP_TIMELINE_EVENT
#define TIMELINE_DRAWORDER SP_TIMELINE_DRAWORDER
#define Timeline_dispose(...) sp38Timeline_dispose(__VA_ARGS__)
#define Timeline_apply(...) sp38Timeline_apply(__VA_ARGS__)
#endif

/**/

typedef struct sp38CurveTimeline {
	sp38Timeline super;
	float* curves; /* type, x, y, ... */

#ifdef __cplusplus
	sp38CurveTimeline() :
		super(),
		curves(0) {
	}
#endif
} sp38CurveTimeline;

SP_API void sp38CurveTimeline_setLinear (sp38CurveTimeline* self, int frameIndex);
SP_API void sp38CurveTimeline_setStepped (sp38CurveTimeline* self, int frameIndex);

/* Sets the control handle positions for an interpolation bezier curve used to transition from this keyframe to the next.
 * cx1 and cx2 are from 0 to 1, representing the percent of time between the two keyframes. cy1 and cy2 are the percent of
 * the difference between the keyframe's values. */
SP_API void sp38CurveTimeline_setCurve (sp38CurveTimeline* self, int frameIndex, float cx1, float cy1, float cx2, float cy2);
SP_API float sp38CurveTimeline_getCurvePercent (const sp38CurveTimeline* self, int frameIndex, float percent);

#ifdef SPINE_SHORT_NAMES
typedef sp38CurveTimeline CurveTimeline;
#define CurveTimeline_setLinear(...) sp38CurveTimeline_setLinear(__VA_ARGS__)
#define CurveTimeline_setStepped(...) sp38CurveTimeline_setStepped(__VA_ARGS__)
#define CurveTimeline_setCurve(...) sp38CurveTimeline_setCurve(__VA_ARGS__)
#define CurveTimeline_getCurvePercent(...) sp38CurveTimeline_getCurvePercent(__VA_ARGS__)
#endif

/**/

typedef struct sp38BaseTimeline {
	sp38CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, angle, ... for rotate. time, x, y, ... for translate and scale. */
	int boneIndex;

#ifdef __cplusplus
	sp38BaseTimeline() :
		super(),
		framesCount(0),
		frames(0),
		boneIndex(0) {
	}
#endif
} sp38BaseTimeline;

/**/

static const int ROTATE_PREV_TIME = -2, ROTATE_PREV_ROTATION = -1;
static const int ROTATE_ROTATION = 1;
static const int ROTATE_ENTRIES = 2;

typedef struct sp38BaseTimeline sp38RotateTimeline;

SP_API sp38RotateTimeline* sp38RotateTimeline_create (int framesCount);

SP_API void sp38RotateTimeline_setFrame (sp38RotateTimeline* self, int frameIndex, float time, float angle);

#ifdef SPINE_SHORT_NAMES
typedef sp38RotateTimeline RotateTimeline;
#define RotateTimeline_create(...) sp38RotateTimeline_create(__VA_ARGS__)
#define RotateTimeline_setFrame(...) sp38RotateTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int TRANSLATE_ENTRIES = 3;

typedef struct sp38BaseTimeline sp38TranslateTimeline;

SP_API sp38TranslateTimeline* sp38TranslateTimeline_create (int framesCount);

SP_API void sp38TranslateTimeline_setFrame (sp38TranslateTimeline* self, int frameIndex, float time, float x, float y);

#ifdef SPINE_SHORT_NAMES
typedef sp38TranslateTimeline TranslateTimeline;
#define TranslateTimeline_create(...) sp38TranslateTimeline_create(__VA_ARGS__)
#define TranslateTimeline_setFrame(...) sp38TranslateTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp38BaseTimeline sp38ScaleTimeline;

SP_API sp38ScaleTimeline* sp38ScaleTimeline_create (int framesCount);

SP_API void sp38ScaleTimeline_setFrame (sp38ScaleTimeline* self, int frameIndex, float time, float x, float y);

#ifdef SPINE_SHORT_NAMES
typedef sp38ScaleTimeline ScaleTimeline;
#define ScaleTimeline_create(...) sp38ScaleTimeline_create(__VA_ARGS__)
#define ScaleTimeline_setFrame(...) sp38ScaleTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp38BaseTimeline sp38ShearTimeline;

SP_API sp38ShearTimeline* sp38ShearTimeline_create (int framesCount);

SP_API void sp38ShearTimeline_setFrame (sp38ShearTimeline* self, int frameIndex, float time, float x, float y);

#ifdef SPINE_SHORT_NAMES
typedef sp38ShearTimeline ShearTimeline;
#define ShearTimeline_create(...) sp38ShearTimeline_create(__VA_ARGS__)
#define ShearTimeline_setFrame(...) sp38ShearTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int COLOR_ENTRIES = 5;

typedef struct sp38ColorTimeline {
	sp38CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, r, g, b, a, ... */
	int slotIndex;

#ifdef __cplusplus
	sp38ColorTimeline() :
		super(),
		framesCount(0),
		frames(0),
		slotIndex(0) {
	}
#endif
} sp38ColorTimeline;

SP_API sp38ColorTimeline* sp38ColorTimeline_create (int framesCount);

SP_API void sp38ColorTimeline_setFrame (sp38ColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a);

#ifdef SPINE_SHORT_NAMES
typedef sp38ColorTimeline ColorTimeline;
#define ColorTimeline_create(...) sp38ColorTimeline_create(__VA_ARGS__)
#define ColorTimeline_setFrame(...) sp38ColorTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int TWOCOLOR_ENTRIES = 8;

typedef struct sp38TwoColorTimeline {
	sp38CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, r, g, b, a, ... */
	int slotIndex;

#ifdef __cplusplus
	sp38TwoColorTimeline() :
		super(),
		framesCount(0),
		frames(0),
		slotIndex(0) {
	}
#endif
} sp38TwoColorTimeline;

SP_API sp38TwoColorTimeline* sp38TwoColorTimeline_create (int framesCount);

SP_API void sp38TwoColorTimeline_setFrame (sp38TwoColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a, float r2, float g2, float b2);

#ifdef SPINE_SHORT_NAMES
typedef sp38TwoColorTimeline TwoColorTimeline;
#define TwoColorTimeline_create(...) sp38TwoColorTimeline_create(__VA_ARGS__)
#define TwoColorTimeline_setFrame(...) sp38TwoColorTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp38AttachmentTimeline {
	sp38Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	int slotIndex;
	const char** const attachmentNames;

#ifdef __cplusplus
	sp38AttachmentTimeline() :
		super(),
		framesCount(0),
		frames(0),
		slotIndex(0),
		attachmentNames(0) {
	}
#endif
} sp38AttachmentTimeline;

SP_API sp38AttachmentTimeline* sp38AttachmentTimeline_create (int framesCount);

/* @param attachmentName May be 0. */
SP_API void sp38AttachmentTimeline_setFrame (sp38AttachmentTimeline* self, int frameIndex, float time, const char* attachmentName);

#ifdef SPINE_SHORT_NAMES
typedef sp38AttachmentTimeline AttachmentTimeline;
#define AttachmentTimeline_create(...) sp38AttachmentTimeline_create(__VA_ARGS__)
#define AttachmentTimeline_setFrame(...) sp38AttachmentTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp38EventTimeline {
	sp38Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	sp38Event** const events;

#ifdef __cplusplus
	sp38EventTimeline() :
		super(),
		framesCount(0),
		frames(0),
		events(0) {
	}
#endif
} sp38EventTimeline;

SP_API sp38EventTimeline* sp38EventTimeline_create (int framesCount);

SP_API void sp38EventTimeline_setFrame (sp38EventTimeline* self, int frameIndex, sp38Event* event);

#ifdef SPINE_SHORT_NAMES
typedef sp38EventTimeline EventTimeline;
#define EventTimeline_create(...) sp38EventTimeline_create(__VA_ARGS__)
#define EventTimeline_setFrame(...) sp38EventTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp38DrawOrderTimeline {
	sp38Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	const int** const drawOrders;
	int const slotsCount;

#ifdef __cplusplus
	sp38DrawOrderTimeline() :
		super(),
		framesCount(0),
		frames(0),
		drawOrders(0),
		slotsCount(0) {
	}
#endif
} sp38DrawOrderTimeline;

SP_API sp38DrawOrderTimeline* sp38DrawOrderTimeline_create (int framesCount, int slotsCount);

SP_API void sp38DrawOrderTimeline_setFrame (sp38DrawOrderTimeline* self, int frameIndex, float time, const int* drawOrder);

#ifdef SPINE_SHORT_NAMES
typedef sp38DrawOrderTimeline DrawOrderTimeline;
#define DrawOrderTimeline_create(...) sp38DrawOrderTimeline_create(__VA_ARGS__)
#define DrawOrderTimeline_setFrame(...) sp38DrawOrderTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp38DeformTimeline {
	sp38CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	int const frameVerticesCount;
	const float** const frameVertices;
	int slotIndex;
	sp38Attachment* attachment;

#ifdef __cplusplus
	sp38DeformTimeline() :
		super(),
		framesCount(0),
		frames(0),
		frameVerticesCount(0),
		frameVertices(0),
		slotIndex(0) {
	}
#endif
} sp38DeformTimeline;

SP_API sp38DeformTimeline* sp38DeformTimeline_create (int framesCount, int frameVerticesCount);

SP_API void sp38DeformTimeline_setFrame (sp38DeformTimeline* self, int frameIndex, float time, float* vertices);

#ifdef SPINE_SHORT_NAMES
typedef sp38DeformTimeline DeformTimeline;
#define DeformTimeline_create(...) sp38DeformTimeline_create(__VA_ARGS__)
#define DeformTimeline_setFrame(...) sp38DeformTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int IKCONSTRAINT_ENTRIES = 6;

typedef struct sp38IkConstraintTimeline {
	sp38CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, mix, bendDirection, ... */
	int ikConstraintIndex;

#ifdef __cplusplus
	sp38IkConstraintTimeline() :
		super(),
		framesCount(0),
		frames(0),
		ikConstraintIndex(0) {
	}
#endif
} sp38IkConstraintTimeline;

SP_API sp38IkConstraintTimeline* sp38IkConstraintTimeline_create (int framesCount);

SP_API void sp38IkConstraintTimeline_setFrame (sp38IkConstraintTimeline* self, int frameIndex, float time, float mix, float softness, int bendDirection, int /*boolean*/ compress, int /**boolean**/ stretch);

#ifdef SPINE_SHORT_NAMES
typedef sp38IkConstraintTimeline IkConstraintTimeline;
#define IkConstraintTimeline_create(...) sp38IkConstraintTimeline_create(__VA_ARGS__)
#define IkConstraintTimeline_setFrame(...) sp38IkConstraintTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int TRANSFORMCONSTRAINT_ENTRIES = 5;

typedef struct sp38TransformConstraintTimeline {
	sp38CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int transformConstraintIndex;

#ifdef __cplusplus
	sp38TransformConstraintTimeline() :
		super(),
		framesCount(0),
		frames(0),
		transformConstraintIndex(0) {
	}
#endif
} sp38TransformConstraintTimeline;

SP_API sp38TransformConstraintTimeline* sp38TransformConstraintTimeline_create (int framesCount);

SP_API void sp38TransformConstraintTimeline_setFrame (sp38TransformConstraintTimeline* self, int frameIndex, float time, float rotateMix, float translateMix, float scaleMix, float shearMix);

#ifdef SPINE_SHORT_NAMES
typedef sp38TransformConstraintTimeline TransformConstraintTimeline;
#define TransformConstraintTimeline_create(...) sp38TransformConstraintTimeline_create(__VA_ARGS__)
#define TransformConstraintTimeline_setFrame(...) sp38TransformConstraintTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int PATHCONSTRAINTPOSITION_ENTRIES = 2;

typedef struct sp38PathConstraintPositionTimeline {
	sp38CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int pathConstraintIndex;

#ifdef __cplusplus
	sp38PathConstraintPositionTimeline() :
		super(),
		framesCount(0),
		frames(0),
		pathConstraintIndex(0) {
	}
#endif
} sp38PathConstraintPositionTimeline;

SP_API sp38PathConstraintPositionTimeline* sp38PathConstraintPositionTimeline_create (int framesCount);

SP_API void sp38PathConstraintPositionTimeline_setFrame (sp38PathConstraintPositionTimeline* self, int frameIndex, float time, float value);

#ifdef SPINE_SHORT_NAMES
typedef sp38PathConstraintPositionTimeline PathConstraintPositionTimeline;
#define PathConstraintPositionTimeline_create(...) sp38PathConstraintPositionTimeline_create(__VA_ARGS__)
#define PathConstraintPositionTimeline_setFrame(...) sp38PathConstraintPositionTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int PATHCONSTRAINTSPACING_ENTRIES = 2;

typedef struct sp38PathConstraintSpacingTimeline {
	sp38CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int pathConstraintIndex;

#ifdef __cplusplus
	sp38PathConstraintSpacingTimeline() :
		super(),
		framesCount(0),
		frames(0),
		pathConstraintIndex(0) {
	}
#endif
} sp38PathConstraintSpacingTimeline;

SP_API sp38PathConstraintSpacingTimeline* sp38PathConstraintSpacingTimeline_create (int framesCount);

SP_API void sp38PathConstraintSpacingTimeline_setFrame (sp38PathConstraintSpacingTimeline* self, int frameIndex, float time, float value);

#ifdef SPINE_SHORT_NAMES
typedef sp38PathConstraintSpacingTimeline PathConstraintSpacingTimeline;
#define PathConstraintSpacingTimeline_create(...) sp38PathConstraintSpacingTimeline_create(__VA_ARGS__)
#define PathConstraintSpacingTimeline_setFrame(...) sp38PathConstraintSpacingTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int PATHCONSTRAINTMIX_ENTRIES = 3;

typedef struct sp38PathConstraintMixTimeline {
	sp38CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int pathConstraintIndex;

#ifdef __cplusplus
	sp38PathConstraintMixTimeline() :
		super(),
		framesCount(0),
		frames(0),
		pathConstraintIndex(0) {
	}
#endif
} sp38PathConstraintMixTimeline;

SP_API sp38PathConstraintMixTimeline* sp38PathConstraintMixTimeline_create (int framesCount);

SP_API void sp38PathConstraintMixTimeline_setFrame (sp38PathConstraintMixTimeline* self, int frameIndex, float time, float rotateMix, float translateMix);

#ifdef SPINE_SHORT_NAMES
typedef sp38PathConstraintMixTimeline PathConstraintMixTimeline;
#define PathConstraintMixTimeline_create(...) sp38PathConstraintMixTimeline_create(__VA_ARGS__)
#define PathConstraintMixTimeline_setFrame(...) sp38PathConstraintMixTimeline_setFrame(__VA_ARGS__)
#endif

/**/

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATION_H_ */

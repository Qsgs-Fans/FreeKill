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

#ifndef SPINE_ANIMATION_H_
#define SPINE_ANIMATION_H_

#include <spine/Event.h>
#include <spine/Attachment.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp35Timeline sp35Timeline;
struct sp35Skeleton;

typedef struct sp35Animation {
	const char* const name;
	float duration;

	int timelinesCount;
	sp35Timeline** timelines;

#ifdef __cplusplus
	sp35Animation() :
		name(0),
		duration(0),
		timelinesCount(0),
		timelines(0) {
	}
#endif
} sp35Animation;

sp35Animation* sp35Animation_create (const char* name, int timelinesCount);
void sp35Animation_dispose (sp35Animation* self);

/** Poses the skeleton at the specified time for this animation.
 * @param lastTime The last time the animation was applied.
 * @param events Any triggered events are added. May be null.*/
void sp35Animation_apply (const sp35Animation* self, struct sp35Skeleton* skeleton, float lastTime, float time, int loop,
		sp35Event** events, int* eventsCount, float alpha, int /*boolean*/ setupPose, int /*boolean*/ mixingOut);

#ifdef SPINE_SHORT_NAMES
typedef sp35Animation Animation;
#define Animation_create(...) sp35Animation_create(__VA_ARGS__)
#define Animation_dispose(...) sp35Animation_dispose(__VA_ARGS__)
#define Animation_apply(...) sp35Animation_apply(__VA_ARGS__)
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
	SP_TIMELINE_PATHCONSTRAINTMIX
} sp35TimelineType;

struct sp35Timeline {
	const sp35TimelineType type;
	const void* const vtable;

#ifdef __cplusplus
	sp35Timeline() :
		type(SP_TIMELINE_SCALE),
		vtable(0) {
	}
#endif
};

void sp35Timeline_dispose (sp35Timeline* self);
void sp35Timeline_apply (const sp35Timeline* self, struct sp35Skeleton* skeleton, float lastTime, float time, sp35Event** firedEvents,
		int* eventsCount, float alpha, int /*boolean*/ setupPose, int /*boolean*/ mixingOut);
int sp35Timeline_getPropertyId (const sp35Timeline* self);

#ifdef SPINE_SHORT_NAMES
typedef sp35Timeline Timeline;
#define TIMELINE_SCALE SP_TIMELINE_SCALE
#define TIMELINE_ROTATE SP_TIMELINE_ROTATE
#define TIMELINE_TRANSLATE SP_TIMELINE_TRANSLATE
#define TIMELINE_COLOR SP_TIMELINE_COLOR
#define TIMELINE_ATTACHMENT SP_TIMELINE_ATTACHMENT
#define TIMELINE_EVENT SP_TIMELINE_EVENT
#define TIMELINE_DRAWORDER SP_TIMELINE_DRAWORDER
#define Timeline_dispose(...) sp35Timeline_dispose(__VA_ARGS__)
#define Timeline_apply(...) sp35Timeline_apply(__VA_ARGS__)
#endif

/**/

typedef struct sp35CurveTimeline {
	sp35Timeline super;
	float* curves; /* type, x, y, ... */

#ifdef __cplusplus
	sp35CurveTimeline() :
		super(),
		curves(0) {
	}
#endif
} sp35CurveTimeline;

void sp35CurveTimeline_setLinear (sp35CurveTimeline* self, int frameIndex);
void sp35CurveTimeline_setStepped (sp35CurveTimeline* self, int frameIndex);

/* Sets the control handle positions for an interpolation bezier curve used to transition from this keyframe to the next.
 * cx1 and cx2 are from 0 to 1, representing the percent of time between the two keyframes. cy1 and cy2 are the percent of
 * the difference between the keyframe's values. */
void sp35CurveTimeline_setCurve (sp35CurveTimeline* self, int frameIndex, float cx1, float cy1, float cx2, float cy2);
float sp35CurveTimeline_getCurvePercent (const sp35CurveTimeline* self, int frameIndex, float percent);

#ifdef SPINE_SHORT_NAMES
typedef sp35CurveTimeline CurveTimeline;
#define CurveTimeline_setLinear(...) sp35CurveTimeline_setLinear(__VA_ARGS__)
#define CurveTimeline_setStepped(...) sp35CurveTimeline_setStepped(__VA_ARGS__)
#define CurveTimeline_setCurve(...) sp35CurveTimeline_setCurve(__VA_ARGS__)
#define CurveTimeline_getCurvePercent(...) sp35CurveTimeline_getCurvePercent(__VA_ARGS__)
#endif

/**/

typedef struct sp35BaseTimeline {
	sp35CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, angle, ... for rotate. time, x, y, ... for translate and scale. */
	int boneIndex;

#ifdef __cplusplus
	sp35BaseTimeline() :
		super(),
		framesCount(0),
		frames(0),
		boneIndex(0) {
	}
#endif
} sp35BaseTimeline;

/**/

static const int ROTATE_PREV_TIME = -2, ROTATE_PREV_ROTATION = -1;
static const int ROTATE_ROTATION = 1;
static const int ROTATE_ENTRIES = 2;

typedef struct sp35BaseTimeline sp35RotateTimeline;

sp35RotateTimeline* sp35RotateTimeline_create (int framesCount);

void sp35RotateTimeline_setFrame (sp35RotateTimeline* self, int frameIndex, float time, float angle);

#ifdef SPINE_SHORT_NAMES
typedef sp35RotateTimeline RotateTimeline;
#define RotateTimeline_create(...) sp35RotateTimeline_create(__VA_ARGS__)
#define RotateTimeline_setFrame(...) sp35RotateTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int TRANSLATE_ENTRIES = 3;

typedef struct sp35BaseTimeline sp35TranslateTimeline;

sp35TranslateTimeline* sp35TranslateTimeline_create (int framesCount);

void sp35TranslateTimeline_setFrame (sp35TranslateTimeline* self, int frameIndex, float time, float x, float y);

#ifdef SPINE_SHORT_NAMES
typedef sp35TranslateTimeline TranslateTimeline;
#define TranslateTimeline_create(...) sp35TranslateTimeline_create(__VA_ARGS__)
#define TranslateTimeline_setFrame(...) sp35TranslateTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp35BaseTimeline sp35ScaleTimeline;

sp35ScaleTimeline* sp35ScaleTimeline_create (int framesCount);

void sp35ScaleTimeline_setFrame (sp35ScaleTimeline* self, int frameIndex, float time, float x, float y);

#ifdef SPINE_SHORT_NAMES
typedef sp35ScaleTimeline ScaleTimeline;
#define ScaleTimeline_create(...) sp35ScaleTimeline_create(__VA_ARGS__)
#define ScaleTimeline_setFrame(...) sp35ScaleTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp35BaseTimeline sp35ShearTimeline;

sp35ShearTimeline* sp35ShearTimeline_create (int framesCount);

void sp35ShearTimeline_setFrame (sp35ShearTimeline* self, int frameIndex, float time, float x, float y);

#ifdef SPINE_SHORT_NAMES
typedef sp35ShearTimeline ShearTimeline;
#define ShearTimeline_create(...) sp35ShearTimeline_create(__VA_ARGS__)
#define ShearTimeline_setFrame(...) sp35ShearTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int COLOR_ENTRIES = 5;

typedef struct sp35ColorTimeline {
	sp35CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, r, g, b, a, ... */
	int slotIndex;

#ifdef __cplusplus
	sp35ColorTimeline() :
		super(),
		framesCount(0),
		frames(0),
		slotIndex(0) {
	}
#endif
} sp35ColorTimeline;

sp35ColorTimeline* sp35ColorTimeline_create (int framesCount);

void sp35ColorTimeline_setFrame (sp35ColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a);

#ifdef SPINE_SHORT_NAMES
typedef sp35ColorTimeline ColorTimeline;
#define ColorTimeline_create(...) sp35ColorTimeline_create(__VA_ARGS__)
#define ColorTimeline_setFrame(...) sp35ColorTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp35AttachmentTimeline {
	sp35Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	int slotIndex;
	const char** const attachmentNames;

#ifdef __cplusplus
	sp35AttachmentTimeline() :
		super(),
		framesCount(0),
		frames(0),
		slotIndex(0),
		attachmentNames(0) {
	}
#endif
} sp35AttachmentTimeline;

sp35AttachmentTimeline* sp35AttachmentTimeline_create (int framesCount);

/* @param attachmentName May be 0. */
void sp35AttachmentTimeline_setFrame (sp35AttachmentTimeline* self, int frameIndex, float time, const char* attachmentName);

#ifdef SPINE_SHORT_NAMES
typedef sp35AttachmentTimeline AttachmentTimeline;
#define AttachmentTimeline_create(...) sp35AttachmentTimeline_create(__VA_ARGS__)
#define AttachmentTimeline_setFrame(...) sp35AttachmentTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp35EventTimeline {
	sp35Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	sp35Event** const events;

#ifdef __cplusplus
	sp35EventTimeline() :
		super(),
		framesCount(0),
		frames(0),
		events(0) {
	}
#endif
} sp35EventTimeline;

sp35EventTimeline* sp35EventTimeline_create (int framesCount);

void sp35EventTimeline_setFrame (sp35EventTimeline* self, int frameIndex, sp35Event* event);

#ifdef SPINE_SHORT_NAMES
typedef sp35EventTimeline EventTimeline;
#define EventTimeline_create(...) sp35EventTimeline_create(__VA_ARGS__)
#define EventTimeline_setFrame(...) sp35EventTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp35DrawOrderTimeline {
	sp35Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	const int** const drawOrders;
	int const slotsCount;

#ifdef __cplusplus
	sp35DrawOrderTimeline() :
		super(),
		framesCount(0),
		frames(0),
		drawOrders(0),
		slotsCount(0) {
	}
#endif
} sp35DrawOrderTimeline;

sp35DrawOrderTimeline* sp35DrawOrderTimeline_create (int framesCount, int slotsCount);

void sp35DrawOrderTimeline_setFrame (sp35DrawOrderTimeline* self, int frameIndex, float time, const int* drawOrder);

#ifdef SPINE_SHORT_NAMES
typedef sp35DrawOrderTimeline DrawOrderTimeline;
#define DrawOrderTimeline_create(...) sp35DrawOrderTimeline_create(__VA_ARGS__)
#define DrawOrderTimeline_setFrame(...) sp35DrawOrderTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp35DeformTimeline {
	sp35CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	int const frameVerticesCount;
	const float** const frameVertices;
	int slotIndex;
	sp35Attachment* attachment;

#ifdef __cplusplus
	sp35DeformTimeline() :
		super(),
		framesCount(0),
		frames(0),
		frameVerticesCount(0),
		frameVertices(0),
		slotIndex(0) {
	}
#endif
} sp35DeformTimeline;

sp35DeformTimeline* sp35DeformTimeline_create (int framesCount, int frameVerticesCount);

void sp35DeformTimeline_setFrame (sp35DeformTimeline* self, int frameIndex, float time, float* vertices);

#ifdef SPINE_SHORT_NAMES
typedef sp35DeformTimeline DeformTimeline;
#define DeformTimeline_create(...) sp35DeformTimeline_create(__VA_ARGS__)
#define DeformTimeline_setFrame(...) sp35DeformTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int IKCONSTRAINT_ENTRIES = 3;

typedef struct sp35IkConstraintTimeline {
	sp35CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, mix, bendDirection, ... */
	int ikConstraintIndex;

#ifdef __cplusplus
	sp35IkConstraintTimeline() :
		super(),
		framesCount(0),
		frames(0),
		ikConstraintIndex(0) {
	}
#endif
} sp35IkConstraintTimeline;

sp35IkConstraintTimeline* sp35IkConstraintTimeline_create (int framesCount);

void sp35IkConstraintTimeline_setFrame (sp35IkConstraintTimeline* self, int frameIndex, float time, float mix, int bendDirection);

#ifdef SPINE_SHORT_NAMES
typedef sp35IkConstraintTimeline IkConstraintTimeline;
#define IkConstraintTimeline_create(...) sp35IkConstraintTimeline_create(__VA_ARGS__)
#define IkConstraintTimeline_setFrame(...) sp35IkConstraintTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int TRANSFORMCONSTRAINT_ENTRIES = 5;

typedef struct sp35TransformConstraintTimeline {
	sp35CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int transformConstraintIndex;

#ifdef __cplusplus
	sp35TransformConstraintTimeline() :
		super(),
		framesCount(0),
		frames(0),
		transformConstraintIndex(0) {
	}
#endif
} sp35TransformConstraintTimeline;

sp35TransformConstraintTimeline* sp35TransformConstraintTimeline_create (int framesCount);

void sp35TransformConstraintTimeline_setFrame (sp35TransformConstraintTimeline* self, int frameIndex, float time, float rotateMix, float translateMix, float scaleMix, float shearMix);

#ifdef SPINE_SHORT_NAMES
typedef sp35TransformConstraintTimeline TransformConstraintTimeline;
#define TransformConstraintTimeline_create(...) sp35TransformConstraintTimeline_create(__VA_ARGS__)
#define TransformConstraintTimeline_setFrame(...) sp35TransformConstraintTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int PATHCONSTRAINTPOSITION_ENTRIES = 2;

typedef struct sp35PathConstraintPositionTimeline {
	sp35CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int pathConstraintIndex;

#ifdef __cplusplus
	sp35PathConstraintPositionTimeline() :
		super(),
		framesCount(0),
		frames(0),
		pathConstraintIndex(0) {
	}
#endif
} sp35PathConstraintPositionTimeline;

sp35PathConstraintPositionTimeline* sp35PathConstraintPositionTimeline_create (int framesCount);

void sp35PathConstraintPositionTimeline_setFrame (sp35PathConstraintPositionTimeline* self, int frameIndex, float time, float value);

#ifdef SPINE_SHORT_NAMES
typedef sp35PathConstraintPositionTimeline PathConstraintPositionTimeline;
#define PathConstraintPositionTimeline_create(...) sp35PathConstraintPositionTimeline_create(__VA_ARGS__)
#define PathConstraintPositionTimeline_setFrame(...) sp35PathConstraintPositionTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int PATHCONSTRAINTSPACING_ENTRIES = 2;

typedef struct sp35PathConstraintSpacingTimeline {
	sp35CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int pathConstraintIndex;

#ifdef __cplusplus
	sp35PathConstraintSpacingTimeline() :
		super(),
		framesCount(0),
		frames(0),
		pathConstraintIndex(0) {
	}
#endif
} sp35PathConstraintSpacingTimeline;

sp35PathConstraintSpacingTimeline* sp35PathConstraintSpacingTimeline_create (int framesCount);

void sp35PathConstraintSpacingTimeline_setFrame (sp35PathConstraintSpacingTimeline* self, int frameIndex, float time, float value);

#ifdef SPINE_SHORT_NAMES
typedef sp35PathConstraintSpacingTimeline PathConstraintSpacingTimeline;
#define PathConstraintSpacingTimeline_create(...) sp35PathConstraintSpacingTimeline_create(__VA_ARGS__)
#define PathConstraintSpacingTimeline_setFrame(...) sp35PathConstraintSpacingTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int PATHCONSTRAINTMIX_ENTRIES = 3;

typedef struct sp35PathConstraintMixTimeline {
	sp35CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int pathConstraintIndex;

#ifdef __cplusplus
	sp35PathConstraintMixTimeline() :
		super(),
		framesCount(0),
		frames(0),
		pathConstraintIndex(0) {
	}
#endif
} sp35PathConstraintMixTimeline;

sp35PathConstraintMixTimeline* sp35PathConstraintMixTimeline_create (int framesCount);

void sp35PathConstraintMixTimeline_setFrame (sp35PathConstraintMixTimeline* self, int frameIndex, float time, float rotateMix, float translateMix);

#ifdef SPINE_SHORT_NAMES
typedef sp35PathConstraintMixTimeline PathConstraintMixTimeline;
#define PathConstraintMixTimeline_create(...) sp35PathConstraintMixTimeline_create(__VA_ARGS__)
#define PathConstraintMixTimeline_setFrame(...) sp35PathConstraintMixTimeline_setFrame(__VA_ARGS__)
#endif

/**/

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATION_H_ */

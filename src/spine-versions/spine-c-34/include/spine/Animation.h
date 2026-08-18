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

typedef struct sp34Timeline sp34Timeline;
struct sp34Skeleton;

typedef struct sp34Animation {
	const char* const name;
	float duration;

	int timelinesCount;
	sp34Timeline** timelines;

#ifdef __cplusplus
	sp34Animation() :
		name(0),
		duration(0),
		timelinesCount(0),
		timelines(0) {
	}
#endif
} sp34Animation;

sp34Animation* sp34Animation_create (const char* name, int timelinesCount);
void sp34Animation_dispose (sp34Animation* self);

/** Poses the skeleton at the specified time for this animation.
 * @param lastTime The last time the animation was applied.
 * @param events Any triggered events are added. May be null.*/
void sp34Animation_apply (const sp34Animation* self, struct sp34Skeleton* skeleton, float lastTime, float time, int loop,
		sp34Event** events, int* eventsCount);

/** Poses the skeleton at the specified time for this animation mixed with the current pose.
 * @param lastTime The last time the animation was applied.
 * @param events Any triggered events are added. May be null.
 * @param alpha The amount of this animation that affects the current pose. */
void sp34Animation_mix (const sp34Animation* self, struct sp34Skeleton* skeleton, float lastTime, float time, int loop,
		sp34Event** events, int* eventsCount, float alpha);

#ifdef SPINE_SHORT_NAMES
typedef sp34Animation Animation;
#define Animation_create(...) sp34Animation_create(__VA_ARGS__)
#define Animation_dispose(...) sp34Animation_dispose(__VA_ARGS__)
#define Animation_apply(...) sp34Animation_apply(__VA_ARGS__)
#define Animation_mix(...) sp34Animation_mix(__VA_ARGS__)
#endif

/**/

typedef enum {
	SP_TIMELINE_SCALE,
	SP_TIMELINE_ROTATE,
	SP_TIMELINE_TRANSLATE,
	SP_TIMELINE_SHEAR,
	SP_TIMELINE_COLOR,
	SP_TIMELINE_ATTACHMENT,
	SP_TIMELINE_EVENT,
	SP_TIMELINE_DRAWORDER,
	SP_TIMELINE_DEFORM,
	SP_TIMELINE_IKCONSTRAINT,
	SP_TIMELINE_TRANSFORMCONSTRAINT,
	SP_TIMELINE_PATHCONSTRAINTPOSITION,
	SP_TIMELINE_PATHCONSTRAINTSPACING,
	SP_TIMELINE_PATHCONSTRAINTMIX
} sp34TimelineType;

struct sp34Timeline {
	const sp34TimelineType type;
	const void* const vtable;

#ifdef __cplusplus
	sp34Timeline() :
		type(SP_TIMELINE_SCALE),
		vtable(0) {
	}
#endif
};

void sp34Timeline_dispose (sp34Timeline* self);
void sp34Timeline_apply (const sp34Timeline* self, struct sp34Skeleton* skeleton, float lastTime, float time, sp34Event** firedEvents,
		int* eventsCount, float alpha);

#ifdef SPINE_SHORT_NAMES
typedef sp34Timeline Timeline;
#define TIMELINE_SCALE SP_TIMELINE_SCALE
#define TIMELINE_ROTATE SP_TIMELINE_ROTATE
#define TIMELINE_TRANSLATE SP_TIMELINE_TRANSLATE
#define TIMELINE_COLOR SP_TIMELINE_COLOR
#define TIMELINE_ATTACHMENT SP_TIMELINE_ATTACHMENT
#define TIMELINE_EVENT SP_TIMELINE_EVENT
#define TIMELINE_DRAWORDER SP_TIMELINE_DRAWORDER
#define Timeline_dispose(...) sp34Timeline_dispose(__VA_ARGS__)
#define Timeline_apply(...) sp34Timeline_apply(__VA_ARGS__)
#endif

/**/

typedef struct sp34CurveTimeline {
	sp34Timeline super;
	float* curves; /* type, x, y, ... */

#ifdef __cplusplus
	sp34CurveTimeline() :
		super(),
		curves(0) {
	}
#endif
} sp34CurveTimeline;

void sp34CurveTimeline_setLinear (sp34CurveTimeline* self, int frameIndex);
void sp34CurveTimeline_setStepped (sp34CurveTimeline* self, int frameIndex);

/* Sets the control handle positions for an interpolation bezier curve used to transition from this keyframe to the next.
 * cx1 and cx2 are from 0 to 1, representing the percent of time between the two keyframes. cy1 and cy2 are the percent of
 * the difference between the keyframe's values. */
void sp34CurveTimeline_setCurve (sp34CurveTimeline* self, int frameIndex, float cx1, float cy1, float cx2, float cy2);
float sp34CurveTimeline_getCurvePercent (const sp34CurveTimeline* self, int frameIndex, float percent);

#ifdef SPINE_SHORT_NAMES
typedef sp34CurveTimeline CurveTimeline;
#define CurveTimeline_setLinear(...) sp34CurveTimeline_setLinear(__VA_ARGS__)
#define CurveTimeline_setStepped(...) sp34CurveTimeline_setStepped(__VA_ARGS__)
#define CurveTimeline_setCurve(...) sp34CurveTimeline_setCurve(__VA_ARGS__)
#define CurveTimeline_getCurvePercent(...) sp34CurveTimeline_getCurvePercent(__VA_ARGS__)
#endif

/**/

typedef struct sp34BaseTimeline {
	sp34CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, angle, ... for rotate. time, x, y, ... for translate and scale. */
	int boneIndex;

#ifdef __cplusplus
	sp34BaseTimeline() :
		super(),
		framesCount(0),
		frames(0),
		boneIndex(0) {
	}
#endif
} sp34BaseTimeline;

/**/

static const int ROTATE_ENTRIES = 2;

typedef struct sp34BaseTimeline sp34RotateTimeline;

sp34RotateTimeline* sp34RotateTimeline_create (int framesCount);

void sp34RotateTimeline_setFrame (sp34RotateTimeline* self, int frameIndex, float time, float angle);

#ifdef SPINE_SHORT_NAMES
typedef sp34RotateTimeline RotateTimeline;
#define RotateTimeline_create(...) sp34RotateTimeline_create(__VA_ARGS__)
#define RotateTimeline_setFrame(...) sp34RotateTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int TRANSLATE_ENTRIES = 3;

typedef struct sp34BaseTimeline sp34TranslateTimeline;

sp34TranslateTimeline* sp34TranslateTimeline_create (int framesCount);

void sp34TranslateTimeline_setFrame (sp34TranslateTimeline* self, int frameIndex, float time, float x, float y);

#ifdef SPINE_SHORT_NAMES
typedef sp34TranslateTimeline TranslateTimeline;
#define TranslateTimeline_create(...) sp34TranslateTimeline_create(__VA_ARGS__)
#define TranslateTimeline_setFrame(...) sp34TranslateTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp34BaseTimeline sp34ScaleTimeline;

sp34ScaleTimeline* sp34ScaleTimeline_create (int framesCount);

void sp34ScaleTimeline_setFrame (sp34ScaleTimeline* self, int frameIndex, float time, float x, float y);

#ifdef SPINE_SHORT_NAMES
typedef sp34ScaleTimeline ScaleTimeline;
#define ScaleTimeline_create(...) sp34ScaleTimeline_create(__VA_ARGS__)
#define ScaleTimeline_setFrame(...) sp34ScaleTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp34BaseTimeline sp34ShearTimeline;

sp34ShearTimeline* sp34ShearTimeline_create (int framesCount);

void sp34ShearTimeline_setFrame (sp34ShearTimeline* self, int frameIndex, float time, float x, float y);

#ifdef SPINE_SHORT_NAMES
typedef sp34ShearTimeline ShearTimeline;
#define ShearTimeline_create(...) sp34ShearTimeline_create(__VA_ARGS__)
#define ShearTimeline_setFrame(...) sp34ShearTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int COLOR_ENTRIES = 5;

typedef struct sp34ColorTimeline {
	sp34CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, r, g, b, a, ... */
	int slotIndex;

#ifdef __cplusplus
	sp34ColorTimeline() :
		super(),
		framesCount(0),
		frames(0),
		slotIndex(0) {
	}
#endif
} sp34ColorTimeline;

sp34ColorTimeline* sp34ColorTimeline_create (int framesCount);

void sp34ColorTimeline_setFrame (sp34ColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a);

#ifdef SPINE_SHORT_NAMES
typedef sp34ColorTimeline ColorTimeline;
#define ColorTimeline_create(...) sp34ColorTimeline_create(__VA_ARGS__)
#define ColorTimeline_setFrame(...) sp34ColorTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp34AttachmentTimeline {
	sp34Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	int slotIndex;
	const char** const attachmentNames;

#ifdef __cplusplus
	sp34AttachmentTimeline() :
		super(),
		framesCount(0),
		frames(0),
		slotIndex(0),
		attachmentNames(0) {
	}
#endif
} sp34AttachmentTimeline;

sp34AttachmentTimeline* sp34AttachmentTimeline_create (int framesCount);

/* @param attachmentName May be 0. */
void sp34AttachmentTimeline_setFrame (sp34AttachmentTimeline* self, int frameIndex, float time, const char* attachmentName);

#ifdef SPINE_SHORT_NAMES
typedef sp34AttachmentTimeline AttachmentTimeline;
#define AttachmentTimeline_create(...) sp34AttachmentTimeline_create(__VA_ARGS__)
#define AttachmentTimeline_setFrame(...) sp34AttachmentTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp34EventTimeline {
	sp34Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	sp34Event** const events;

#ifdef __cplusplus
	sp34EventTimeline() :
		super(),
		framesCount(0),
		frames(0),
		events(0) {
	}
#endif
} sp34EventTimeline;

sp34EventTimeline* sp34EventTimeline_create (int framesCount);

void sp34EventTimeline_setFrame (sp34EventTimeline* self, int frameIndex, sp34Event* event);

#ifdef SPINE_SHORT_NAMES
typedef sp34EventTimeline EventTimeline;
#define EventTimeline_create(...) sp34EventTimeline_create(__VA_ARGS__)
#define EventTimeline_setFrame(...) sp34EventTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp34DrawOrderTimeline {
	sp34Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	const int** const drawOrders;
	int const slotsCount;

#ifdef __cplusplus
	sp34DrawOrderTimeline() :
		super(),
		framesCount(0),
		frames(0),
		drawOrders(0),
		slotsCount(0) {
	}
#endif
} sp34DrawOrderTimeline;

sp34DrawOrderTimeline* sp34DrawOrderTimeline_create (int framesCount, int slotsCount);

void sp34DrawOrderTimeline_setFrame (sp34DrawOrderTimeline* self, int frameIndex, float time, const int* drawOrder);

#ifdef SPINE_SHORT_NAMES
typedef sp34DrawOrderTimeline DrawOrderTimeline;
#define DrawOrderTimeline_create(...) sp34DrawOrderTimeline_create(__VA_ARGS__)
#define DrawOrderTimeline_setFrame(...) sp34DrawOrderTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp34DeformTimeline {
	sp34CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	int const frameVerticesCount;
	const float** const frameVertices;
	int slotIndex;
	sp34Attachment* attachment;

#ifdef __cplusplus
	sp34DeformTimeline() :
		super(),
		framesCount(0),
		frames(0),
		frameVerticesCount(0),
		frameVertices(0),
		slotIndex(0) {
	}
#endif
} sp34DeformTimeline;

sp34DeformTimeline* sp34DeformTimeline_create (int framesCount, int frameVerticesCount);

void sp34DeformTimeline_setFrame (sp34DeformTimeline* self, int frameIndex, float time, float* vertices);

#ifdef SPINE_SHORT_NAMES
typedef sp34DeformTimeline DeformTimeline;
#define DeformTimeline_create(...) sp34DeformTimeline_create(__VA_ARGS__)
#define DeformTimeline_setFrame(...) sp34DeformTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int IKCONSTRAINT_ENTRIES = 3;

typedef struct sp34IkConstraintTimeline {
	sp34CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, mix, bendDirection, ... */
	int ikConstraintIndex;

#ifdef __cplusplus
	sp34IkConstraintTimeline() :
		super(),
		framesCount(0),
		frames(0),
		ikConstraintIndex(0) {
	}
#endif
} sp34IkConstraintTimeline;

sp34IkConstraintTimeline* sp34IkConstraintTimeline_create (int framesCount);

void sp34IkConstraintTimeline_setFrame (sp34IkConstraintTimeline* self, int frameIndex, float time, float mix, int bendDirection);

#ifdef SPINE_SHORT_NAMES
typedef sp34IkConstraintTimeline IkConstraintTimeline;
#define IkConstraintTimeline_create(...) sp34IkConstraintTimeline_create(__VA_ARGS__)
#define IkConstraintTimeline_setFrame(...) sp34IkConstraintTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int TRANSFORMCONSTRAINT_ENTRIES = 5;

typedef struct sp34TransformConstraintTimeline {
	sp34CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int transformConstraintIndex;

#ifdef __cplusplus
	sp34TransformConstraintTimeline() :
		super(),
		framesCount(0),
		frames(0),
		transformConstraintIndex(0) {
	}
#endif
} sp34TransformConstraintTimeline;

sp34TransformConstraintTimeline* sp34TransformConstraintTimeline_create (int framesCount);

void sp34TransformConstraintTimeline_setFrame (sp34TransformConstraintTimeline* self, int frameIndex, float time, float rotateMix, float translateMix, float scaleMix, float shearMix);

#ifdef SPINE_SHORT_NAMES
typedef sp34TransformConstraintTimeline TransformConstraintTimeline;
#define TransformConstraintTimeline_create(...) sp34TransformConstraintTimeline_create(__VA_ARGS__)
#define TransformConstraintTimeline_setFrame(...) sp34TransformConstraintTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int PATHCONSTRAINTPOSITION_ENTRIES = 2;

typedef struct sp34PathConstraintPositionTimeline {
	sp34CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int pathConstraintIndex;

#ifdef __cplusplus
	sp34PathConstraintPositionTimeline() :
		super(),
		framesCount(0),
		frames(0),
		pathConstraintIndex(0) {
	}
#endif
} sp34PathConstraintPositionTimeline;

sp34PathConstraintPositionTimeline* sp34PathConstraintPositionTimeline_create (int framesCount);

void sp34PathConstraintPositionTimeline_setFrame (sp34PathConstraintPositionTimeline* self, int frameIndex, float time, float value);

#ifdef SPINE_SHORT_NAMES
typedef sp34PathConstraintPositionTimeline PathConstraintPositionTimeline;
#define PathConstraintPositionTimeline_create(...) sp34PathConstraintPositionTimeline_create(__VA_ARGS__)
#define PathConstraintPositionTimeline_setFrame(...) sp34PathConstraintPositionTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int PATHCONSTRAINTSPACING_ENTRIES = 2;

typedef struct sp34PathConstraintSpacingTimeline {
	sp34CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int pathConstraintIndex;

#ifdef __cplusplus
	sp34PathConstraintSpacingTimeline() :
		super(),
		framesCount(0),
		frames(0),
		pathConstraintIndex(0) {
	}
#endif
} sp34PathConstraintSpacingTimeline;

sp34PathConstraintSpacingTimeline* sp34PathConstraintSpacingTimeline_create (int framesCount);

void sp34PathConstraintSpacingTimeline_setFrame (sp34PathConstraintSpacingTimeline* self, int frameIndex, float time, float value);

#ifdef SPINE_SHORT_NAMES
typedef sp34PathConstraintSpacingTimeline PathConstraintSpacingTimeline;
#define PathConstraintSpacingTimeline_create(...) sp34PathConstraintSpacingTimeline_create(__VA_ARGS__)
#define PathConstraintSpacingTimeline_setFrame(...) sp34PathConstraintSpacingTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int PATHCONSTRAINTMIX_ENTRIES = 3;

typedef struct sp34PathConstraintMixTimeline {
	sp34CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int pathConstraintIndex;

#ifdef __cplusplus
	sp34PathConstraintMixTimeline() :
		super(),
		framesCount(0),
		frames(0),
		pathConstraintIndex(0) {
	}
#endif
} sp34PathConstraintMixTimeline;

sp34PathConstraintMixTimeline* sp34PathConstraintMixTimeline_create (int framesCount);

void sp34PathConstraintMixTimeline_setFrame (sp34PathConstraintMixTimeline* self, int frameIndex, float time, float rotateMix, float translateMix);

#ifdef SPINE_SHORT_NAMES
typedef sp34PathConstraintMixTimeline PathConstraintMixTimeline;
#define PathConstraintMixTimeline_create(...) sp34PathConstraintMixTimeline_create(__VA_ARGS__)
#define PathConstraintMixTimeline_setFrame(...) sp34PathConstraintMixTimeline_setFrame(__VA_ARGS__)
#endif

/**/

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATION_H_ */

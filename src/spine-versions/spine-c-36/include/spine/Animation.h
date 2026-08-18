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

#include <spine/dll.h>
#include <spine/Event.h>
#include <spine/Attachment.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp36Timeline sp36Timeline;
struct sp36Skeleton;

typedef struct sp36Animation {
	const char* const name;
	float duration;

	int timelinesCount;
	sp36Timeline** timelines;

#ifdef __cplusplus
	sp36Animation() :
		name(0),
		duration(0),
		timelinesCount(0),
		timelines(0) {
	}
#endif
} sp36Animation;

typedef enum {
	SP_MIX_POSE_SETUP,
	SP_MIX_POSE_CURRENT,
	SP_MIX_POSE_CURRENT_LAYERED
} sp36MixPose;

typedef enum {
	SP_MIX_DIRECTION_IN,
	SP_MIX_DIRECTION_OUT
} sp36MixDirection;

SP_API sp36Animation* sp36Animation_create (const char* name, int timelinesCount);
SP_API void sp36Animation_dispose (sp36Animation* self);

/** Poses the skeleton at the specified time for this animation.
 * @param lastTime The last time the animation was applied.
 * @param events Any triggered events are added. May be null.*/
SP_API void sp36Animation_apply (const sp36Animation* self, struct sp36Skeleton* skeleton, float lastTime, float time, int loop,
		sp36Event** events, int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction);

#ifdef SPINE_SHORT_NAMES
typedef sp36Animation Animation;
#define Animation_create(...) sp36Animation_create(__VA_ARGS__)
#define Animation_dispose(...) sp36Animation_dispose(__VA_ARGS__)
#define Animation_apply(...) sp36Animation_apply(__VA_ARGS__)
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
} sp36TimelineType;

struct sp36Timeline {
	const sp36TimelineType type;
	const void* const vtable;

#ifdef __cplusplus
	sp36Timeline() :
		type(SP_TIMELINE_SCALE),
		vtable(0) {
	}
#endif
};

SP_API void sp36Timeline_dispose (sp36Timeline* self);
SP_API void sp36Timeline_apply (const sp36Timeline* self, struct sp36Skeleton* skeleton, float lastTime, float time, sp36Event** firedEvents,
		int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction);
SP_API int sp36Timeline_getPropertyId (const sp36Timeline* self);

#ifdef SPINE_SHORT_NAMES
typedef sp36Timeline Timeline;
#define TIMELINE_SCALE SP_TIMELINE_SCALE
#define TIMELINE_ROTATE SP_TIMELINE_ROTATE
#define TIMELINE_TRANSLATE SP_TIMELINE_TRANSLATE
#define TIMELINE_COLOR SP_TIMELINE_COLOR
#define TIMELINE_ATTACHMENT SP_TIMELINE_ATTACHMENT
#define TIMELINE_EVENT SP_TIMELINE_EVENT
#define TIMELINE_DRAWORDER SP_TIMELINE_DRAWORDER
#define Timeline_dispose(...) sp36Timeline_dispose(__VA_ARGS__)
#define Timeline_apply(...) sp36Timeline_apply(__VA_ARGS__)
#endif

/**/

typedef struct sp36CurveTimeline {
	sp36Timeline super;
	float* curves; /* type, x, y, ... */

#ifdef __cplusplus
	sp36CurveTimeline() :
		super(),
		curves(0) {
	}
#endif
} sp36CurveTimeline;

SP_API void sp36CurveTimeline_setLinear (sp36CurveTimeline* self, int frameIndex);
SP_API void sp36CurveTimeline_setStepped (sp36CurveTimeline* self, int frameIndex);

/* Sets the control handle positions for an interpolation bezier curve used to transition from this keyframe to the next.
 * cx1 and cx2 are from 0 to 1, representing the percent of time between the two keyframes. cy1 and cy2 are the percent of
 * the difference between the keyframe's values. */
SP_API void sp36CurveTimeline_setCurve (sp36CurveTimeline* self, int frameIndex, float cx1, float cy1, float cx2, float cy2);
SP_API float sp36CurveTimeline_getCurvePercent (const sp36CurveTimeline* self, int frameIndex, float percent);

#ifdef SPINE_SHORT_NAMES
typedef sp36CurveTimeline CurveTimeline;
#define CurveTimeline_setLinear(...) sp36CurveTimeline_setLinear(__VA_ARGS__)
#define CurveTimeline_setStepped(...) sp36CurveTimeline_setStepped(__VA_ARGS__)
#define CurveTimeline_setCurve(...) sp36CurveTimeline_setCurve(__VA_ARGS__)
#define CurveTimeline_getCurvePercent(...) sp36CurveTimeline_getCurvePercent(__VA_ARGS__)
#endif

/**/

typedef struct sp36BaseTimeline {
	sp36CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, angle, ... for rotate. time, x, y, ... for translate and scale. */
	int boneIndex;

#ifdef __cplusplus
	sp36BaseTimeline() :
		super(),
		framesCount(0),
		frames(0),
		boneIndex(0) {
	}
#endif
} sp36BaseTimeline;

/**/

static const int ROTATE_PREV_TIME = -2, ROTATE_PREV_ROTATION = -1;
static const int ROTATE_ROTATION = 1;
static const int ROTATE_ENTRIES = 2;

typedef struct sp36BaseTimeline sp36RotateTimeline;

SP_API sp36RotateTimeline* sp36RotateTimeline_create (int framesCount);

SP_API void sp36RotateTimeline_setFrame (sp36RotateTimeline* self, int frameIndex, float time, float angle);

#ifdef SPINE_SHORT_NAMES
typedef sp36RotateTimeline RotateTimeline;
#define RotateTimeline_create(...) sp36RotateTimeline_create(__VA_ARGS__)
#define RotateTimeline_setFrame(...) sp36RotateTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int TRANSLATE_ENTRIES = 3;

typedef struct sp36BaseTimeline sp36TranslateTimeline;

SP_API sp36TranslateTimeline* sp36TranslateTimeline_create (int framesCount);

SP_API void sp36TranslateTimeline_setFrame (sp36TranslateTimeline* self, int frameIndex, float time, float x, float y);

#ifdef SPINE_SHORT_NAMES
typedef sp36TranslateTimeline TranslateTimeline;
#define TranslateTimeline_create(...) sp36TranslateTimeline_create(__VA_ARGS__)
#define TranslateTimeline_setFrame(...) sp36TranslateTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp36BaseTimeline sp36ScaleTimeline;

SP_API sp36ScaleTimeline* sp36ScaleTimeline_create (int framesCount);

SP_API void sp36ScaleTimeline_setFrame (sp36ScaleTimeline* self, int frameIndex, float time, float x, float y);

#ifdef SPINE_SHORT_NAMES
typedef sp36ScaleTimeline ScaleTimeline;
#define ScaleTimeline_create(...) sp36ScaleTimeline_create(__VA_ARGS__)
#define ScaleTimeline_setFrame(...) sp36ScaleTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp36BaseTimeline sp36ShearTimeline;

SP_API sp36ShearTimeline* sp36ShearTimeline_create (int framesCount);

SP_API void sp36ShearTimeline_setFrame (sp36ShearTimeline* self, int frameIndex, float time, float x, float y);

#ifdef SPINE_SHORT_NAMES
typedef sp36ShearTimeline ShearTimeline;
#define ShearTimeline_create(...) sp36ShearTimeline_create(__VA_ARGS__)
#define ShearTimeline_setFrame(...) sp36ShearTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int COLOR_ENTRIES = 5;

typedef struct sp36ColorTimeline {
	sp36CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, r, g, b, a, ... */
	int slotIndex;

#ifdef __cplusplus
	sp36ColorTimeline() :
		super(),
		framesCount(0),
		frames(0),
		slotIndex(0) {
	}
#endif
} sp36ColorTimeline;

SP_API sp36ColorTimeline* sp36ColorTimeline_create (int framesCount);

SP_API void sp36ColorTimeline_setFrame (sp36ColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a);

#ifdef SPINE_SHORT_NAMES
typedef sp36ColorTimeline ColorTimeline;
#define ColorTimeline_create(...) sp36ColorTimeline_create(__VA_ARGS__)
#define ColorTimeline_setFrame(...) sp36ColorTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int TWOCOLOR_ENTRIES = 8;

typedef struct sp36TwoColorTimeline {
	sp36CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, r, g, b, a, ... */
	int slotIndex;

#ifdef __cplusplus
	sp36TwoColorTimeline() :
		super(),
		framesCount(0),
		frames(0),
		slotIndex(0) {
	}
#endif
} sp36TwoColorTimeline;

SP_API sp36TwoColorTimeline* sp36TwoColorTimeline_create (int framesCount);

SP_API void sp36TwoColorTimeline_setFrame (sp36TwoColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a, float r2, float g2, float b2);

#ifdef SPINE_SHORT_NAMES
typedef sp36TwoColorTimeline TwoColorTimeline;
#define TwoColorTimeline_create(...) sp36TwoColorTimeline_create(__VA_ARGS__)
#define TwoColorTimeline_setFrame(...) sp36TwoColorTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp36AttachmentTimeline {
	sp36Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	int slotIndex;
	const char** const attachmentNames;

#ifdef __cplusplus
	sp36AttachmentTimeline() :
		super(),
		framesCount(0),
		frames(0),
		slotIndex(0),
		attachmentNames(0) {
	}
#endif
} sp36AttachmentTimeline;

SP_API sp36AttachmentTimeline* sp36AttachmentTimeline_create (int framesCount);

/* @param attachmentName May be 0. */
SP_API void sp36AttachmentTimeline_setFrame (sp36AttachmentTimeline* self, int frameIndex, float time, const char* attachmentName);

#ifdef SPINE_SHORT_NAMES
typedef sp36AttachmentTimeline AttachmentTimeline;
#define AttachmentTimeline_create(...) sp36AttachmentTimeline_create(__VA_ARGS__)
#define AttachmentTimeline_setFrame(...) sp36AttachmentTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp36EventTimeline {
	sp36Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	sp36Event** const events;

#ifdef __cplusplus
	sp36EventTimeline() :
		super(),
		framesCount(0),
		frames(0),
		events(0) {
	}
#endif
} sp36EventTimeline;

SP_API sp36EventTimeline* sp36EventTimeline_create (int framesCount);

SP_API void sp36EventTimeline_setFrame (sp36EventTimeline* self, int frameIndex, sp36Event* event);

#ifdef SPINE_SHORT_NAMES
typedef sp36EventTimeline EventTimeline;
#define EventTimeline_create(...) sp36EventTimeline_create(__VA_ARGS__)
#define EventTimeline_setFrame(...) sp36EventTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp36DrawOrderTimeline {
	sp36Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	const int** const drawOrders;
	int const slotsCount;

#ifdef __cplusplus
	sp36DrawOrderTimeline() :
		super(),
		framesCount(0),
		frames(0),
		drawOrders(0),
		slotsCount(0) {
	}
#endif
} sp36DrawOrderTimeline;

SP_API sp36DrawOrderTimeline* sp36DrawOrderTimeline_create (int framesCount, int slotsCount);

SP_API void sp36DrawOrderTimeline_setFrame (sp36DrawOrderTimeline* self, int frameIndex, float time, const int* drawOrder);

#ifdef SPINE_SHORT_NAMES
typedef sp36DrawOrderTimeline DrawOrderTimeline;
#define DrawOrderTimeline_create(...) sp36DrawOrderTimeline_create(__VA_ARGS__)
#define DrawOrderTimeline_setFrame(...) sp36DrawOrderTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp36DeformTimeline {
	sp36CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	int const frameVerticesCount;
	const float** const frameVertices;
	int slotIndex;
	sp36Attachment* attachment;

#ifdef __cplusplus
	sp36DeformTimeline() :
		super(),
		framesCount(0),
		frames(0),
		frameVerticesCount(0),
		frameVertices(0),
		slotIndex(0) {
	}
#endif
} sp36DeformTimeline;

SP_API sp36DeformTimeline* sp36DeformTimeline_create (int framesCount, int frameVerticesCount);

SP_API void sp36DeformTimeline_setFrame (sp36DeformTimeline* self, int frameIndex, float time, float* vertices);

#ifdef SPINE_SHORT_NAMES
typedef sp36DeformTimeline DeformTimeline;
#define DeformTimeline_create(...) sp36DeformTimeline_create(__VA_ARGS__)
#define DeformTimeline_setFrame(...) sp36DeformTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int IKCONSTRAINT_ENTRIES = 3;

typedef struct sp36IkConstraintTimeline {
	sp36CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, mix, bendDirection, ... */
	int ikConstraintIndex;

#ifdef __cplusplus
	sp36IkConstraintTimeline() :
		super(),
		framesCount(0),
		frames(0),
		ikConstraintIndex(0) {
	}
#endif
} sp36IkConstraintTimeline;

SP_API sp36IkConstraintTimeline* sp36IkConstraintTimeline_create (int framesCount);

SP_API void sp36IkConstraintTimeline_setFrame (sp36IkConstraintTimeline* self, int frameIndex, float time, float mix, int bendDirection);

#ifdef SPINE_SHORT_NAMES
typedef sp36IkConstraintTimeline IkConstraintTimeline;
#define IkConstraintTimeline_create(...) sp36IkConstraintTimeline_create(__VA_ARGS__)
#define IkConstraintTimeline_setFrame(...) sp36IkConstraintTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int TRANSFORMCONSTRAINT_ENTRIES = 5;

typedef struct sp36TransformConstraintTimeline {
	sp36CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int transformConstraintIndex;

#ifdef __cplusplus
	sp36TransformConstraintTimeline() :
		super(),
		framesCount(0),
		frames(0),
		transformConstraintIndex(0) {
	}
#endif
} sp36TransformConstraintTimeline;

SP_API sp36TransformConstraintTimeline* sp36TransformConstraintTimeline_create (int framesCount);

SP_API void sp36TransformConstraintTimeline_setFrame (sp36TransformConstraintTimeline* self, int frameIndex, float time, float rotateMix, float translateMix, float scaleMix, float shearMix);

#ifdef SPINE_SHORT_NAMES
typedef sp36TransformConstraintTimeline TransformConstraintTimeline;
#define TransformConstraintTimeline_create(...) sp36TransformConstraintTimeline_create(__VA_ARGS__)
#define TransformConstraintTimeline_setFrame(...) sp36TransformConstraintTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int PATHCONSTRAINTPOSITION_ENTRIES = 2;

typedef struct sp36PathConstraintPositionTimeline {
	sp36CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int pathConstraintIndex;

#ifdef __cplusplus
	sp36PathConstraintPositionTimeline() :
		super(),
		framesCount(0),
		frames(0),
		pathConstraintIndex(0) {
	}
#endif
} sp36PathConstraintPositionTimeline;

SP_API sp36PathConstraintPositionTimeline* sp36PathConstraintPositionTimeline_create (int framesCount);

SP_API void sp36PathConstraintPositionTimeline_setFrame (sp36PathConstraintPositionTimeline* self, int frameIndex, float time, float value);

#ifdef SPINE_SHORT_NAMES
typedef sp36PathConstraintPositionTimeline PathConstraintPositionTimeline;
#define PathConstraintPositionTimeline_create(...) sp36PathConstraintPositionTimeline_create(__VA_ARGS__)
#define PathConstraintPositionTimeline_setFrame(...) sp36PathConstraintPositionTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int PATHCONSTRAINTSPACING_ENTRIES = 2;

typedef struct sp36PathConstraintSpacingTimeline {
	sp36CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int pathConstraintIndex;

#ifdef __cplusplus
	sp36PathConstraintSpacingTimeline() :
		super(),
		framesCount(0),
		frames(0),
		pathConstraintIndex(0) {
	}
#endif
} sp36PathConstraintSpacingTimeline;

SP_API sp36PathConstraintSpacingTimeline* sp36PathConstraintSpacingTimeline_create (int framesCount);

SP_API void sp36PathConstraintSpacingTimeline_setFrame (sp36PathConstraintSpacingTimeline* self, int frameIndex, float time, float value);

#ifdef SPINE_SHORT_NAMES
typedef sp36PathConstraintSpacingTimeline PathConstraintSpacingTimeline;
#define PathConstraintSpacingTimeline_create(...) sp36PathConstraintSpacingTimeline_create(__VA_ARGS__)
#define PathConstraintSpacingTimeline_setFrame(...) sp36PathConstraintSpacingTimeline_setFrame(__VA_ARGS__)
#endif

/**/

static const int PATHCONSTRAINTMIX_ENTRIES = 3;

typedef struct sp36PathConstraintMixTimeline {
	sp36CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, rotate mix, translate mix, scale mix, shear mix, ... */
	int pathConstraintIndex;

#ifdef __cplusplus
	sp36PathConstraintMixTimeline() :
		super(),
		framesCount(0),
		frames(0),
		pathConstraintIndex(0) {
	}
#endif
} sp36PathConstraintMixTimeline;

SP_API sp36PathConstraintMixTimeline* sp36PathConstraintMixTimeline_create (int framesCount);

SP_API void sp36PathConstraintMixTimeline_setFrame (sp36PathConstraintMixTimeline* self, int frameIndex, float time, float rotateMix, float translateMix);

#ifdef SPINE_SHORT_NAMES
typedef sp36PathConstraintMixTimeline PathConstraintMixTimeline;
#define PathConstraintMixTimeline_create(...) sp36PathConstraintMixTimeline_create(__VA_ARGS__)
#define PathConstraintMixTimeline_setFrame(...) sp36PathConstraintMixTimeline_setFrame(__VA_ARGS__)
#endif

/**/

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATION_H_ */

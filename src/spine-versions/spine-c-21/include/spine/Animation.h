/******************************************************************************
 * Spine Runtimes Software License
 * Version 2.1
 * 
 * Copyright (c) 2013, Esoteric Software
 * All rights reserved.
 * 
 * You are granted a perpetual, non-exclusive, non-sublicensable and
 * non-transferable license to install, execute and perform the Spine Runtimes
 * Software (the "Software") solely for internal use. Without the written
 * permission of Esoteric Software (typically granted by licensing Spine), you
 * may not (a) modify, translate, adapt or otherwise create derivative works,
 * improvements of the Software or develop new applications using the Software
 * or (b) remove, delete, alter or obscure any trademarks or any copyright,
 * trademark, patent or other intellectual property or proprietary rights
 * notices on or in the Software, including any copy thereof. Redistributions
 * in binary or source form must include this license and terms.
 * 
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#ifndef SPINE_ANIMATION_H_
#define SPINE_ANIMATION_H_

#include <spine/Event.h>
#include <spine/Attachment.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp21Timeline sp21Timeline;
struct sp21Skeleton;

typedef struct sp21Animation {
	const char* const name;
	float duration;

	int timelinesCount;
	sp21Timeline** timelines;

#ifdef __cplusplus
	sp21Animation() :
		name(0),
		duration(0),
		timelinesCount(0),
		timelines(0) {
	}
#endif
} sp21Animation;

sp21Animation* sp21Animation_create (const char* name, int timelinesCount);
void sp21Animation_dispose (sp21Animation* self);

/** Poses the skeleton at the specified time for this animation.
 * @param lastTime The last time the animation was applied.
 * @param events Any triggered events are added. */
void sp21Animation_apply (const sp21Animation* self, struct sp21Skeleton* skeleton, float lastTime, float time, int loop,
		sp21Event** events, int* eventsCount);

/** Poses the skeleton at the specified time for this animation mixed with the current pose.
 * @param lastTime The last time the animation was applied.
 * @param events Any triggered events are added.
 * @param alpha The amount of this animation that affects the current pose. */
void sp21Animation_mix (const sp21Animation* self, struct sp21Skeleton* skeleton, float lastTime, float time, int loop,
		sp21Event** events, int* eventsCount, float alpha);

#ifdef SPINE_SHORT_NAMES
typedef sp21Animation Animation;
#define Animation_create(...) sp21Animation_create(__VA_ARGS__)
#define Animation_dispose(...) sp21Animation_dispose(__VA_ARGS__)
#define Animation_apply(...) sp21Animation_apply(__VA_ARGS__)
#define Animation_mix(...) sp21Animation_mix(__VA_ARGS__)
#endif

/**/

typedef enum {
	SP_TIMELINE_SCALE,
	SP_TIMELINE_ROTATE,
	SP_TIMELINE_TRANSLATE,
	SP_TIMELINE_COLOR,
	SP_TIMELINE_ATTACHMENT,
	SP_TIMELINE_EVENT,
	SP_TIMELINE_DRAWORDER,
	SP_TIMELINE_FFD,
	SP_TIMELINE_IKCONSTRAINT,
	SP_TIMELINE_FLIPX,
	SP_TIMELINE_FLIPY
} sp21TimelineType;

struct sp21Timeline {
	const sp21TimelineType type;
	const void* const vtable;

#ifdef __cplusplus
	sp21Timeline() :
		type(SP_TIMELINE_SCALE),
		vtable(0) {
	}
#endif
};

void sp21Timeline_dispose (sp21Timeline* self);
void sp21Timeline_apply (const sp21Timeline* self, struct sp21Skeleton* skeleton, float lastTime, float time, sp21Event** firedEvents,
		int* eventsCount, float alpha);

#ifdef SPINE_SHORT_NAMES
typedef sp21Timeline Timeline;
#define TIMELINE_SCALE SP_TIMELINE_SCALE
#define TIMELINE_ROTATE SP_TIMELINE_ROTATE
#define TIMELINE_TRANSLATE SP_TIMELINE_TRANSLATE
#define TIMELINE_COLOR SP_TIMELINE_COLOR
#define TIMELINE_ATTACHMENT SP_TIMELINE_ATTACHMENT
#define TIMELINE_EVENT SP_TIMELINE_EVENT
#define TIMELINE_DRAWORDER SP_TIMELINE_DRAWORDER
#define Timeline_dispose(...) sp21Timeline_dispose(__VA_ARGS__)
#define Timeline_apply(...) sp21Timeline_apply(__VA_ARGS__)
#endif

/**/

typedef struct sp21CurveTimeline {
	sp21Timeline super;
	float* curves; /* type, x, y, ... */

#ifdef __cplusplus
	sp21CurveTimeline() :
		super(),
		curves(0) {
	}
#endif
} sp21CurveTimeline;

void sp21CurveTimeline_setLinear (sp21CurveTimeline* self, int frameIndex);
void sp21CurveTimeline_setStepped (sp21CurveTimeline* self, int frameIndex);

/* Sets the control handle positions for an interpolation bezier curve used to transition from this keyframe to the next.
 * cx1 and cx2 are from 0 to 1, representing the percent of time between the two keyframes. cy1 and cy2 are the percent of
 * the difference between the keyframe's values. */
void sp21CurveTimeline_setCurve (sp21CurveTimeline* self, int frameIndex, float cx1, float cy1, float cx2, float cy2);
float sp21CurveTimeline_getCurvePercent (const sp21CurveTimeline* self, int frameIndex, float percent);

#ifdef SPINE_SHORT_NAMES
typedef sp21CurveTimeline CurveTimeline;
#define CurveTimeline_setLinear(...) sp21CurveTimeline_setLinear(__VA_ARGS__)
#define CurveTimeline_setStepped(...) sp21CurveTimeline_setStepped(__VA_ARGS__)
#define CurveTimeline_setCurve(...) sp21CurveTimeline_setCurve(__VA_ARGS__)
#define CurveTimeline_getCurvePercent(...) sp21CurveTimeline_getCurvePercent(__VA_ARGS__)
#endif

/**/

typedef struct sp21BaseTimeline {
	sp21CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, angle, ... for rotate. time, x, y, ... for translate and scale. */
	int boneIndex;

#ifdef __cplusplus
	sp21BaseTimeline() :
		super(),
		framesCount(0),
		frames(0),
		boneIndex(0) {
	}
#endif
} sp21BaseTimeline;

/**/

typedef struct sp21BaseTimeline sp21RotateTimeline;

sp21RotateTimeline* sp21RotateTimeline_create (int framesCount);

void sp21RotateTimeline_setFrame (sp21RotateTimeline* self, int frameIndex, float time, float angle);

#ifdef SPINE_SHORT_NAMES
typedef sp21RotateTimeline RotateTimeline;
#define RotateTimeline_create(...) sp21RotateTimeline_create(__VA_ARGS__)
#define RotateTimeline_setFrame(...) sp21RotateTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp21BaseTimeline sp21TranslateTimeline;

sp21TranslateTimeline* sp21TranslateTimeline_create (int framesCount);

void sp21TranslateTimeline_setFrame (sp21TranslateTimeline* self, int frameIndex, float time, float x, float y);

#ifdef SPINE_SHORT_NAMES
typedef sp21TranslateTimeline TranslateTimeline;
#define TranslateTimeline_create(...) sp21TranslateTimeline_create(__VA_ARGS__)
#define TranslateTimeline_setFrame(...) sp21TranslateTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp21BaseTimeline sp21ScaleTimeline;

sp21ScaleTimeline* sp21ScaleTimeline_create (int framesCount);

void sp21ScaleTimeline_setFrame (sp21ScaleTimeline* self, int frameIndex, float time, float x, float y);

#ifdef SPINE_SHORT_NAMES
typedef sp21ScaleTimeline ScaleTimeline;
#define ScaleTimeline_create(...) sp21ScaleTimeline_create(__VA_ARGS__)
#define ScaleTimeline_setFrame(...) sp21ScaleTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp21ColorTimeline {
	sp21CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, r, g, b, a, ... */
	int slotIndex;

#ifdef __cplusplus
	sp21ColorTimeline() :
		super(),
		framesCount(0),
		frames(0),
		slotIndex(0) {
	}
#endif
} sp21ColorTimeline;

sp21ColorTimeline* sp21ColorTimeline_create (int framesCount);

void sp21ColorTimeline_setFrame (sp21ColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a);

#ifdef SPINE_SHORT_NAMES
typedef sp21ColorTimeline ColorTimeline;
#define ColorTimeline_create(...) sp21ColorTimeline_create(__VA_ARGS__)
#define ColorTimeline_setFrame(...) sp21ColorTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp21AttachmentTimeline {
	sp21Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	int slotIndex;
	const char** const attachmentNames;

#ifdef __cplusplus
	sp21AttachmentTimeline() :
		super(),
		framesCount(0),
		frames(0),
		slotIndex(0),
		attachmentNames(0) {
	}
#endif
} sp21AttachmentTimeline;

sp21AttachmentTimeline* sp21AttachmentTimeline_create (int framesCount);

/* @param attachmentName May be 0. */
void sp21AttachmentTimeline_setFrame (sp21AttachmentTimeline* self, int frameIndex, float time, const char* attachmentName);

#ifdef SPINE_SHORT_NAMES
typedef sp21AttachmentTimeline AttachmentTimeline;
#define AttachmentTimeline_create(...) sp21AttachmentTimeline_create(__VA_ARGS__)
#define AttachmentTimeline_setFrame(...) sp21AttachmentTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp21EventTimeline {
	sp21Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	sp21Event** const events;

#ifdef __cplusplus
	sp21EventTimeline() :
		super(),
		framesCount(0),
		frames(0),
		events(0) {
	}
#endif
} sp21EventTimeline;

sp21EventTimeline* sp21EventTimeline_create (int framesCount);

void sp21EventTimeline_setFrame (sp21EventTimeline* self, int frameIndex, float time, sp21Event* event);

#ifdef SPINE_SHORT_NAMES
typedef sp21EventTimeline EventTimeline;
#define EventTimeline_create(...) sp21EventTimeline_create(__VA_ARGS__)
#define EventTimeline_setFrame(...) sp21EventTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp21DrawOrderTimeline {
	sp21Timeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	const int** const drawOrders;
	int const slotsCount;

#ifdef __cplusplus
	sp21DrawOrderTimeline() :
		super(),
		framesCount(0),
		frames(0),
		drawOrders(0),
		slotsCount(0) {
	}
#endif
} sp21DrawOrderTimeline;

sp21DrawOrderTimeline* sp21DrawOrderTimeline_create (int framesCount, int slotsCount);

void sp21DrawOrderTimeline_setFrame (sp21DrawOrderTimeline* self, int frameIndex, float time, const int* drawOrder);

#ifdef SPINE_SHORT_NAMES
typedef sp21DrawOrderTimeline DrawOrderTimeline;
#define DrawOrderTimeline_create(...) sp21DrawOrderTimeline_create(__VA_ARGS__)
#define DrawOrderTimeline_setFrame(...) sp21DrawOrderTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp21FFDTimeline {
	sp21CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, ... */
	int const frameVerticesCount;
	const float** const frameVertices;
	int slotIndex;
	sp21Attachment* attachment;

#ifdef __cplusplus
	sp21FFDTimeline() :
		super(),
		framesCount(0),
		frames(0),
		frameVerticesCount(0),
		frameVertices(0),
		slotIndex(0) {
	}
#endif
} sp21FFDTimeline;

sp21FFDTimeline* sp21FFDTimeline_create (int framesCount, int frameVerticesCount);

void sp21FFDTimeline_setFrame (sp21FFDTimeline* self, int frameIndex, float time, float* vertices);

#ifdef SPINE_SHORT_NAMES
typedef sp21FFDTimeline FFDTimeline;
#define FFDTimeline_create(...) sp21FFDTimeline_create(__VA_ARGS__)
#define FFDTimeline_setFrame(...) sp21FFDTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp21IkConstraintTimeline {
	sp21CurveTimeline super;
	int const framesCount;
	float* const frames; /* time, mix, bendDirection, ... */
	int ikConstraintIndex;

#ifdef __cplusplus
	sp21IkConstraintTimeline() :
		super(),
		framesCount(0),
		frames(0),
		ikConstraintIndex(0) {
	}
#endif
} sp21IkConstraintTimeline;

sp21IkConstraintTimeline* sp21IkConstraintTimeline_create (int framesCount);

/* @param attachmentName May be 0. */
void sp21IkConstraintTimeline_setFrame (sp21IkConstraintTimeline* self, int frameIndex, float time, float mix, int bendDirection);

#ifdef SPINE_SHORT_NAMES
typedef sp21IkConstraintTimeline IkConstraintTimeline;
#define IkConstraintTimeline_create(...) sp21IkConstraintTimeline_create(__VA_ARGS__)
#define IkConstraintTimeline_setFrame(...) sp21IkConstraintTimeline_setFrame(__VA_ARGS__)
#endif

/**/

typedef struct sp21FlipTimeline {
	sp21Timeline super;
	int const x;
	int const framesCount;
	float* const frames; /* time, flip, ... */
	int boneIndex;

#ifdef __cplusplus
	sp21FlipTimeline() :
		super(),
		x(0),
		framesCount(0),
		frames(0),
		boneIndex(0) {
	}
#endif
} sp21FlipTimeline;

sp21FlipTimeline* sp21FlipTimeline_create (int framesCount, int/*bool*/x);

void sp21FlipTimeline_setFrame (sp21FlipTimeline* self, int frameIndex, float time, int/*bool*/flip);

#ifdef SPINE_SHORT_NAMES
typedef sp21FlipTimeline FlipTimeline;
#define FlipTimeline_create(...) sp21FlipTimeline_create(__VA_ARGS__)
#define FlipTimeline_setFrame(...) sp21FlipTimeline_setFrame(__VA_ARGS__)
#endif

/**/

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATION_H_ */

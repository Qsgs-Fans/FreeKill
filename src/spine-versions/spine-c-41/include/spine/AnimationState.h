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

#ifndef SPINE_ANIMATIONSTATE_H_
#define SPINE_ANIMATIONSTATE_H_

#include <spine/dll.h>
#include <spine/Animation.h>
#include <spine/AnimationStateData.h>
#include <spine/Event.h>
#include <spine/Array.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
	SP_ANIMATION_START,
	SP_ANIMATION_INTERRUPT,
	SP_ANIMATION_END,
	SP_ANIMATION_COMPLETE,
	SP_ANIMATION_DISPOSE,
	SP_ANIMATION_EVENT
} sp41EventType;

typedef struct sp41AnimationState sp41AnimationState;
typedef struct sp41TrackEntry sp41TrackEntry;

typedef void (*sp41AnimationStateListener)(sp41AnimationState *state, sp41EventType type, sp41TrackEntry *entry,
										 sp41Event *event);

_SP_ARRAY_DECLARE_TYPE(sp41TrackEntryArray, sp41TrackEntry*)

struct sp41TrackEntry {
	sp41Animation *animation;
	sp41TrackEntry *previous;
	sp41TrackEntry *next;
	sp41TrackEntry *mixingFrom;
	sp41TrackEntry *mixingTo;
	sp41AnimationStateListener listener;
	int trackIndex;
	int /*boolean*/ loop;
	int /*boolean*/ holdPrevious;
	int /*boolean*/ reverse;
	int /*boolean*/ shortestRotation;
	float eventThreshold, attachmentThreshold, drawOrderThreshold;
	float animationStart, animationEnd, animationLast, nextAnimationLast;
	float delay, trackTime, trackLast, nextTrackLast, trackEnd, timeScale;
	float alpha, mixTime, mixDuration, interruptAlpha, totalAlpha;
	sp41MixBlend mixBlend;
	sp41IntArray *timelineMode;
	sp41TrackEntryArray *timelineHoldMix;
	float *timelinesRotation;
	int timelinesRotationCount;
	void *rendererObject;
	void *userData;
};

struct sp41AnimationState {
	sp41AnimationStateData *const data;

	int tracksCount;
	sp41TrackEntry **tracks;

	sp41AnimationStateListener listener;

	float timeScale;

	void *rendererObject;
	void *userData;

	int unkeyedState;
};

/* @param data May be 0 for no mixing. */
SP_API sp41AnimationState *sp41AnimationState_create(sp41AnimationStateData *data);

SP_API void sp41AnimationState_dispose(sp41AnimationState *self);

SP_API void sp41AnimationState_update(sp41AnimationState *self, float delta);

SP_API int /**bool**/ sp41AnimationState_apply(sp41AnimationState *self, struct sp41Skeleton *skeleton);

SP_API void sp41AnimationState_clearTracks(sp41AnimationState *self);

SP_API void sp41AnimationState_clearTrack(sp41AnimationState *self, int trackIndex);

/** Set the current animation. Any queued animations are cleared. */
SP_API sp41TrackEntry *
sp41AnimationState_setAnimationByName(sp41AnimationState *self, int trackIndex, const char *animationName,
									int/*bool*/loop);

SP_API sp41TrackEntry *
sp41AnimationState_setAnimation(sp41AnimationState *self, int trackIndex, sp41Animation *animation, int/*bool*/loop);

/** Adds an animation to be played delay seconds after the current or last queued animation, taking into account any mix
 * duration. */
SP_API sp41TrackEntry *
sp41AnimationState_addAnimationByName(sp41AnimationState *self, int trackIndex, const char *animationName,
									int/*bool*/loop, float delay);

SP_API sp41TrackEntry *
sp41AnimationState_addAnimation(sp41AnimationState *self, int trackIndex, sp41Animation *animation, int/*bool*/loop,
							  float delay);

SP_API sp41TrackEntry *sp41AnimationState_setEmptyAnimation(sp41AnimationState *self, int trackIndex, float mixDuration);

SP_API sp41TrackEntry *
sp41AnimationState_addEmptyAnimation(sp41AnimationState *self, int trackIndex, float mixDuration, float delay);

SP_API void sp41AnimationState_setEmptyAnimations(sp41AnimationState *self, float mixDuration);

SP_API sp41TrackEntry *sp41AnimationState_getCurrent(sp41AnimationState *self, int trackIndex);

SP_API void sp41AnimationState_clearListenerNotifications(sp41AnimationState *self);

SP_API float sp41TrackEntry_getAnimationTime(sp41TrackEntry *entry);

SP_API float sp41TrackEntry_getTrackComplete(sp41TrackEntry *entry);

SP_API void sp41AnimationState_clearNext(sp41AnimationState *self, sp41TrackEntry *entry);

/** Use this to dispose static memory before your app exits to appease your memory leak detector*/
SP_API void sp41AnimationState_disposeStatics();

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATIONSTATE_H_ */

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
} sp40EventType;

typedef struct sp40AnimationState sp40AnimationState;
typedef struct sp40TrackEntry sp40TrackEntry;

typedef void (*sp40AnimationStateListener)(sp40AnimationState *state, sp40EventType type, sp40TrackEntry *entry,
										 sp40Event *event);

_SP_ARRAY_DECLARE_TYPE(sp40TrackEntryArray, sp40TrackEntry*)

struct sp40TrackEntry {
	sp40Animation *animation;
	sp40TrackEntry *previous;
	sp40TrackEntry *next;
	sp40TrackEntry *mixingFrom;
	sp40TrackEntry *mixingTo;
	sp40AnimationStateListener listener;
	int trackIndex;
	int /*boolean*/ loop;
	int /*boolean*/ holdPrevious;
	int /*boolean*/ reverse;
	float eventThreshold, attachmentThreshold, drawOrderThreshold;
	float animationStart, animationEnd, animationLast, nextAnimationLast;
	float delay, trackTime, trackLast, nextTrackLast, trackEnd, timeScale;
	float alpha, mixTime, mixDuration, interruptAlpha, totalAlpha;
	sp40MixBlend mixBlend;
	sp40IntArray *timelineMode;
	sp40TrackEntryArray *timelineHoldMix;
	float *timelinesRotation;
	int timelinesRotationCount;
	void *rendererObject;
	void *userData;
};

struct sp40AnimationState {
	sp40AnimationStateData *const data;

	int tracksCount;
	sp40TrackEntry **tracks;

	sp40AnimationStateListener listener;

	float timeScale;

	void *rendererObject;
	void *userData;

	int unkeyedState;
};

/* @param data May be 0 for no mixing. */
SP_API sp40AnimationState *sp40AnimationState_create(sp40AnimationStateData *data);

SP_API void sp40AnimationState_dispose(sp40AnimationState *self);

SP_API void sp40AnimationState_update(sp40AnimationState *self, float delta);

SP_API int /**bool**/ sp40AnimationState_apply(sp40AnimationState *self, struct sp40Skeleton *skeleton);

SP_API void sp40AnimationState_clearTracks(sp40AnimationState *self);

SP_API void sp40AnimationState_clearTrack(sp40AnimationState *self, int trackIndex);

/** Set the current animation. Any queued animations are cleared. */
SP_API sp40TrackEntry *
sp40AnimationState_setAnimationByName(sp40AnimationState *self, int trackIndex, const char *animationName,
									int/*bool*/loop);

SP_API sp40TrackEntry *
sp40AnimationState_setAnimation(sp40AnimationState *self, int trackIndex, sp40Animation *animation, int/*bool*/loop);

/** Adds an animation to be played delay seconds after the current or last queued animation, taking into account any mix
 * duration. */
SP_API sp40TrackEntry *
sp40AnimationState_addAnimationByName(sp40AnimationState *self, int trackIndex, const char *animationName,
									int/*bool*/loop, float delay);

SP_API sp40TrackEntry *
sp40AnimationState_addAnimation(sp40AnimationState *self, int trackIndex, sp40Animation *animation, int/*bool*/loop,
							  float delay);

SP_API sp40TrackEntry *sp40AnimationState_setEmptyAnimation(sp40AnimationState *self, int trackIndex, float mixDuration);

SP_API sp40TrackEntry *
sp40AnimationState_addEmptyAnimation(sp40AnimationState *self, int trackIndex, float mixDuration, float delay);

SP_API void sp40AnimationState_setEmptyAnimations(sp40AnimationState *self, float mixDuration);

SP_API sp40TrackEntry *sp40AnimationState_getCurrent(sp40AnimationState *self, int trackIndex);

SP_API void sp40AnimationState_clearListenerNotifications(sp40AnimationState *self);

SP_API float sp40TrackEntry_getAnimationTime(sp40TrackEntry *entry);

SP_API float sp40TrackEntry_getTrackComplete(sp40TrackEntry *entry);

SP_API void sp40AnimationState_clearNext(sp40AnimationState *self, sp40TrackEntry *entry);

/** Use this to dispose static memory before your app exits to appease your memory leak detector*/
SP_API void sp40AnimationState_disposeStatics();

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATIONSTATE_H_ */

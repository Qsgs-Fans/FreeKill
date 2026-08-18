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
	SP_ANIMATION_START, SP_ANIMATION_INTERRUPT, SP_ANIMATION_END, SP_ANIMATION_COMPLETE, SP_ANIMATION_DISPOSE, SP_ANIMATION_EVENT
} sp36EventType;

typedef struct sp36AnimationState sp36AnimationState;
typedef struct sp36TrackEntry sp36TrackEntry;

typedef void (*sp36AnimationStateListener) (sp36AnimationState* state, sp36EventType type, sp36TrackEntry* entry, sp36Event* event);

_SP_ARRAY_DECLARE_TYPE(sp36TrackEntryArray, sp36TrackEntry*)

struct sp36TrackEntry {
	sp36Animation* animation;
	sp36TrackEntry* next;
	sp36TrackEntry* mixingFrom;
	sp36AnimationStateListener listener;
	int trackIndex;
	int /*boolean*/ loop;
	float eventThreshold, attachmentThreshold, drawOrderThreshold;
	float animationStart, animationEnd, animationLast, nextAnimationLast;
	float delay, trackTime, trackLast, nextTrackLast, trackEnd, timeScale;
	float alpha, mixTime, mixDuration, interruptAlpha, totalAlpha;
	sp36IntArray* timelineData;
	sp36TrackEntryArray* timelineDipMix;
	float* timelinesRotation;
	int timelinesRotationCount;
	void* rendererObject;
	void* userData;

#ifdef __cplusplus
	sp36TrackEntry() :
		animation(0),
		next(0), mixingFrom(0),
		listener(0),
		trackIndex(0),
		loop(0),
		eventThreshold(0), attachmentThreshold(0), drawOrderThreshold(0),
		animationStart(0), animationEnd(0), animationLast(0), nextAnimationLast(0),
		delay(0), trackTime(0), trackLast(0), nextTrackLast(0), trackEnd(0), timeScale(0),
		alpha(0), mixTime(0), mixDuration(0), interruptAlpha(0), totalAlpha(0),
		timelineData(0),
		timelineDipMix(0),
		timelinesRotation(0),
		timelinesRotationCount(0),
		rendererObject(0), userData(0) {
	}
#endif
};

struct sp36AnimationState {
	sp36AnimationStateData* const data;

	int tracksCount;
	sp36TrackEntry** tracks;

	sp36AnimationStateListener listener;

	float timeScale;

	sp36TrackEntryArray* mixingTo;

	void* rendererObject;
	void* userData;

#ifdef __cplusplus
	sp36AnimationState() :
		data(0),
		tracksCount(0),
		tracks(0),
		listener(0),
		timeScale(0),
		mixingTo(0),
		rendererObject(0),
		userData(0) {
	}
#endif
};

/* @param data May be 0 for no mixing. */
SP_API sp36AnimationState* sp36AnimationState_create (sp36AnimationStateData* data);
SP_API void sp36AnimationState_dispose (sp36AnimationState* self);

SP_API void sp36AnimationState_update (sp36AnimationState* self, float delta);
SP_API int /**bool**/ sp36AnimationState_apply (sp36AnimationState* self, struct sp36Skeleton* skeleton);

SP_API void sp36AnimationState_clearTracks (sp36AnimationState* self);
SP_API void sp36AnimationState_clearTrack (sp36AnimationState* self, int trackIndex);

/** Set the current animation. Any queued animations are cleared. */
SP_API sp36TrackEntry* sp36AnimationState_setAnimationByName (sp36AnimationState* self, int trackIndex, const char* animationName,
		int/*bool*/loop);
SP_API sp36TrackEntry* sp36AnimationState_setAnimation (sp36AnimationState* self, int trackIndex, sp36Animation* animation, int/*bool*/loop);

/** Adds an animation to be played delay seconds after the current or last queued animation, taking into account any mix
 * duration. */
SP_API sp36TrackEntry* sp36AnimationState_addAnimationByName (sp36AnimationState* self, int trackIndex, const char* animationName,
		int/*bool*/loop, float delay);
SP_API sp36TrackEntry* sp36AnimationState_addAnimation (sp36AnimationState* self, int trackIndex, sp36Animation* animation, int/*bool*/loop,
		float delay);
SP_API sp36TrackEntry* sp36AnimationState_setEmptyAnimation(sp36AnimationState* self, int trackIndex, float mixDuration);
SP_API sp36TrackEntry* sp36AnimationState_addEmptyAnimation(sp36AnimationState* self, int trackIndex, float mixDuration, float delay);
SP_API void sp36AnimationState_setEmptyAnimations(sp36AnimationState* self, float mixDuration);

SP_API sp36TrackEntry* sp36AnimationState_getCurrent (sp36AnimationState* self, int trackIndex);

SP_API void sp36AnimationState_clearListenerNotifications(sp36AnimationState* self);

SP_API float sp36TrackEntry_getAnimationTime (sp36TrackEntry* entry);

/** Use this to dispose static memory before your app exits to appease your memory leak detector*/
SP_API void sp36AnimationState_disposeStatics ();

#ifdef SPINE_SHORT_NAMES
typedef sp36EventType EventType;
#define ANIMATION_START SP_ANIMATION_START
#define ANIMATION_INTERRUPT SP_ANIMATION_INTERRUPT
#define ANIMATION_END SP_ANIMATION_END
#define ANIMATION_COMPLETE SP_ANIMATION_COMPLETE
#define ANIMATION_DISPOSE SP_ANIMATION_DISPOSE
#define ANIMATION_EVENT SP_ANIMATION_EVENT
typedef sp36AnimationStateListener AnimationStateListener;
typedef sp36TrackEntry TrackEntry;
typedef sp36AnimationState AnimationState;
#define AnimationState_create(...) sp36AnimationState_create(__VA_ARGS__)
#define AnimationState_dispose(...) sp36AnimationState_dispose(__VA_ARGS__)
#define AnimationState_update(...) sp36AnimationState_update(__VA_ARGS__)
#define AnimationState_apply(...) sp36AnimationState_apply(__VA_ARGS__)
#define AnimationState_clearTracks(...) sp36AnimationState_clearTracks(__VA_ARGS__)
#define AnimationState_clearTrack(...) sp36AnimationState_clearTrack(__VA_ARGS__)
#define AnimationState_setAnimationByName(...) sp36AnimationState_setAnimationByName(__VA_ARGS__)
#define AnimationState_setAnimation(...) sp36AnimationState_setAnimation(__VA_ARGS__)
#define AnimationState_addAnimationByName(...) sp36AnimationState_addAnimationByName(__VA_ARGS__)
#define AnimationState_addAnimation(...) sp36AnimationState_addAnimation(__VA_ARGS__)
#define AnimationState_setEmptyAnimation(...) sp36AnimatinState_setEmptyAnimation(__VA_ARGS__)
#define AnimationState_addEmptyAnimation(...) sp36AnimatinState_addEmptyAnimation(__VA_ARGS__)
#define AnimationState_setEmptyAnimations(...) sp36AnimatinState_setEmptyAnimations(__VA_ARGS__)
#define AnimationState_getCurrent(...) sp36AnimationState_getCurrent(__VA_ARGS__)
#define AnimationState_clearListenerNotifications(...) sp36AnimatinState_clearListenerNotifications(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATIONSTATE_H_ */

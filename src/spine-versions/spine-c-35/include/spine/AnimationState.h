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

#include <spine/Animation.h>
#include <spine/AnimationStateData.h>
#include <spine/Event.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
	SP_ANIMATION_START, SP_ANIMATION_INTERRUPT, SP_ANIMATION_END, SP_ANIMATION_COMPLETE, SP_ANIMATION_DISPOSE, SP_ANIMATION_EVENT
} sp35EventType;

typedef struct sp35AnimationState sp35AnimationState;
typedef struct sp35TrackEntry sp35TrackEntry;

typedef void (*sp35AnimationStateListener) (sp35AnimationState* state, sp35EventType type, sp35TrackEntry* entry, sp35Event* event);

struct sp35TrackEntry {
	sp35Animation* animation;
	sp35TrackEntry* next;
	sp35TrackEntry* mixingFrom;
	sp35AnimationStateListener listener;
	int trackIndex;
	int /*boolean*/ loop;
	float eventThreshold, attachmentThreshold, drawOrderThreshold;
	float animationStart, animationEnd, animationLast, nextAnimationLast;
	float delay, trackTime, trackLast, nextTrackLast, trackEnd, timeScale;
	float alpha, mixTime, mixDuration, mixAlpha;
	int* /*boolean*/ timelinesFirst;
	int timelinesFirstCount;
	float* timelinesRotation;
	int timelinesRotationCount;
	void* rendererObject;
	void* userData;

#ifdef __cplusplus
	sp35TrackEntry() :
		animation(0),
		next(0), mixingFrom(0),
		listener(0),
		trackIndex(0),
		loop(0),
		eventThreshold(0), attachmentThreshold(0), drawOrderThreshold(0),
		animationStart(0), animationEnd(0), animationLast(0), nextAnimationLast(0),
		delay(0), trackTime(0), trackLast(0), nextTrackLast(0), trackEnd(0), timeScale(0),
		alpha(0), mixTime(0), mixDuration(0), mixAlpha(0),
		timelinesFirst(0),
		timelinesFirstCount(0),
		timelinesRotation(0),
		timelinesRotationCount(0) {
	}
#endif
};

struct sp35AnimationState {
	sp35AnimationStateData* const data;

	int tracksCount;
	sp35TrackEntry** tracks;

	sp35AnimationStateListener listener;

	float timeScale;

	void* rendererObject;

#ifdef __cplusplus
	sp35AnimationState() :
		data(0),
		tracksCount(0),
		tracks(0),
		listener(0),
		timeScale(0) {
	}
#endif
};

/* @param data May be 0 for no mixing. */
sp35AnimationState* sp35AnimationState_create (sp35AnimationStateData* data);
void sp35AnimationState_dispose (sp35AnimationState* self);

void sp35AnimationState_update (sp35AnimationState* self, float delta);
void sp35AnimationState_apply (sp35AnimationState* self, struct sp35Skeleton* skeleton);

void sp35AnimationState_clearTracks (sp35AnimationState* self);
void sp35AnimationState_clearTrack (sp35AnimationState* self, int trackIndex);

/** Set the current animation. Any queued animations are cleared. */
sp35TrackEntry* sp35AnimationState_setAnimationByName (sp35AnimationState* self, int trackIndex, const char* animationName,
		int/*bool*/loop);
sp35TrackEntry* sp35AnimationState_setAnimation (sp35AnimationState* self, int trackIndex, sp35Animation* animation, int/*bool*/loop);

/** Adds an animation to be played delay seconds after the current or last queued animation, taking into account any mix
 * duration. */
sp35TrackEntry* sp35AnimationState_addAnimationByName (sp35AnimationState* self, int trackIndex, const char* animationName,
		int/*bool*/loop, float delay);
sp35TrackEntry* sp35AnimationState_addAnimation (sp35AnimationState* self, int trackIndex, sp35Animation* animation, int/*bool*/loop,
		float delay);
sp35TrackEntry* sp35AnimationState_setEmptyAnimation(sp35AnimationState* self, int trackIndex, float mixDuration);
sp35TrackEntry* sp35AnimationState_addEmptyAnimation(sp35AnimationState* self, int trackIndex, float mixDuration, float delay);
void sp35AnimationState_setEmptyAnimations(sp35AnimationState* self, float mixDuration);

sp35TrackEntry* sp35AnimationState_getCurrent (sp35AnimationState* self, int trackIndex);

void sp35AnimationState_clearListenerNotifications(sp35AnimationState* self);

float sp35TrackEntry_getAnimationTime (sp35TrackEntry* entry);

/** Use this to dispose static memory before your app exits to appease your memory leak detector*/
void sp35AnimationState_disposeStatics ();

#ifdef SPINE_SHORT_NAMES
typedef sp35EventType EventType;
#define ANIMATION_START SP_ANIMATION_START
#define ANIMATION_INTERRUPT SP_ANIMATION_INTERRUPT
#define ANIMATION_END SP_ANIMATION_END
#define ANIMATION_COMPLETE SP_ANIMATION_COMPLETE
#define ANIMATION_DISPOSE SP_ANIMATION_DISPOSE
#define ANIMATION_EVENT SP_ANIMATION_EVENT
typedef sp35AnimationStateListener AnimationStateListener;
typedef sp35TrackEntry TrackEntry;
typedef sp35AnimationState AnimationState;
#define AnimationState_create(...) sp35AnimationState_create(__VA_ARGS__)
#define AnimationState_dispose(...) sp35AnimationState_dispose(__VA_ARGS__)
#define AnimationState_update(...) sp35AnimationState_update(__VA_ARGS__)
#define AnimationState_apply(...) sp35AnimationState_apply(__VA_ARGS__)
#define AnimationState_clearTracks(...) sp35AnimationState_clearTracks(__VA_ARGS__)
#define AnimationState_clearTrack(...) sp35AnimationState_clearTrack(__VA_ARGS__)
#define AnimationState_setAnimationByName(...) sp35AnimationState_setAnimationByName(__VA_ARGS__)
#define AnimationState_setAnimation(...) sp35AnimationState_setAnimation(__VA_ARGS__)
#define AnimationState_addAnimationByName(...) sp35AnimationState_addAnimationByName(__VA_ARGS__)
#define AnimationState_addAnimation(...) sp35AnimationState_addAnimation(__VA_ARGS__)
#define AnimationState_setEmptyAnimation(...) sp35AnimatinState_setEmptyAnimation(__VA_ARGS__)
#define AnimationState_addEmptyAnimation(...) sp35AnimatinState_addEmptyAnimation(__VA_ARGS__)
#define AnimationState_setEmptyAnimations(...) sp35AnimatinState_setEmptyAnimations(__VA_ARGS__)
#define AnimationState_getCurrent(...) sp35AnimationState_getCurrent(__VA_ARGS__)
#define AnimationState_clearListenerNotifications(...) sp35AnimatinState_clearListenerNotifications(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATIONSTATE_H_ */

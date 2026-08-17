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
} sp37EventType;

typedef struct sp37AnimationState sp37AnimationState;
typedef struct sp37TrackEntry sp37TrackEntry;

typedef void (*sp37AnimationStateListener) (sp37AnimationState* state, sp37EventType type, sp37TrackEntry* entry, sp37Event* event);

_SP_ARRAY_DECLARE_TYPE(sp37TrackEntryArray, sp37TrackEntry*)

struct sp37TrackEntry {
	sp37Animation* animation;
	sp37TrackEntry* next;
	sp37TrackEntry* mixingFrom;
	sp37TrackEntry* mixingTo;
	sp37AnimationStateListener listener;
	int trackIndex;
	int /*boolean*/ loop;
	int /*boolean*/ holdPrevious;
	float eventThreshold, attachmentThreshold, drawOrderThreshold;
	float animationStart, animationEnd, animationLast, nextAnimationLast;
	float delay, trackTime, trackLast, nextTrackLast, trackEnd, timeScale;
	float alpha, mixTime, mixDuration, interruptAlpha, totalAlpha;
	sp37MixBlend mixBlend;
	sp37IntArray* timelineMode;
	sp37TrackEntryArray* timelineHoldMix;
	float* timelinesRotation;
	int timelinesRotationCount;
	void* rendererObject;
	void* userData;

#ifdef __cplusplus
	sp37TrackEntry() :
		animation(0),
		next(0), mixingFrom(0), mixingTo(0),
		listener(0),
		trackIndex(0),
		loop(0),
		holdPrevious(0),
		eventThreshold(0), attachmentThreshold(0), drawOrderThreshold(0),
		animationStart(0), animationEnd(0), animationLast(0), nextAnimationLast(0),
		delay(0), trackTime(0), trackLast(0), nextTrackLast(0), trackEnd(0), timeScale(0),
		alpha(0), mixTime(0), mixDuration(0), interruptAlpha(0), totalAlpha(0),
		mixBlend(SP_MIX_BLEND_REPLACE),
		timelineMode(0),
		timelineHoldMix(0),
		timelinesRotation(0),
		timelinesRotationCount(0),
		rendererObject(0), userData(0) {
	}
#endif
};

struct sp37AnimationState {
	sp37AnimationStateData* const data;

	int tracksCount;
	sp37TrackEntry** tracks;

	sp37AnimationStateListener listener;

	float timeScale;

	void* rendererObject;
	void* userData;

#ifdef __cplusplus
	sp37AnimationState() :
		data(0),
		tracksCount(0),
		tracks(0),
		listener(0),
		timeScale(0),
		rendererObject(0),
		userData(0) {
	}
#endif
};

/* @param data May be 0 for no mixing. */
SP_API sp37AnimationState* sp37AnimationState_create (sp37AnimationStateData* data);
SP_API void sp37AnimationState_dispose (sp37AnimationState* self);

SP_API void sp37AnimationState_update (sp37AnimationState* self, float delta);
SP_API int /**bool**/ sp37AnimationState_apply (sp37AnimationState* self, struct sp37Skeleton* skeleton);

SP_API void sp37AnimationState_clearTracks (sp37AnimationState* self);
SP_API void sp37AnimationState_clearTrack (sp37AnimationState* self, int trackIndex);

/** Set the current animation. Any queued animations are cleared. */
SP_API sp37TrackEntry* sp37AnimationState_setAnimationByName (sp37AnimationState* self, int trackIndex, const char* animationName,
		int/*bool*/loop);
SP_API sp37TrackEntry* sp37AnimationState_setAnimation (sp37AnimationState* self, int trackIndex, sp37Animation* animation, int/*bool*/loop);

/** Adds an animation to be played delay seconds after the current or last queued animation, taking into account any mix
 * duration. */
SP_API sp37TrackEntry* sp37AnimationState_addAnimationByName (sp37AnimationState* self, int trackIndex, const char* animationName,
		int/*bool*/loop, float delay);
SP_API sp37TrackEntry* sp37AnimationState_addAnimation (sp37AnimationState* self, int trackIndex, sp37Animation* animation, int/*bool*/loop,
		float delay);
SP_API sp37TrackEntry* sp37AnimationState_setEmptyAnimation(sp37AnimationState* self, int trackIndex, float mixDuration);
SP_API sp37TrackEntry* sp37AnimationState_addEmptyAnimation(sp37AnimationState* self, int trackIndex, float mixDuration, float delay);
SP_API void sp37AnimationState_setEmptyAnimations(sp37AnimationState* self, float mixDuration);

SP_API sp37TrackEntry* sp37AnimationState_getCurrent (sp37AnimationState* self, int trackIndex);

SP_API void sp37AnimationState_clearListenerNotifications(sp37AnimationState* self);

SP_API float sp37TrackEntry_getAnimationTime (sp37TrackEntry* entry);

/** Use this to dispose static memory before your app exits to appease your memory leak detector*/
SP_API void sp37AnimationState_disposeStatics ();

#ifdef SPINE_SHORT_NAMES
typedef sp37EventType EventType;
#define ANIMATION_START SP_ANIMATION_START
#define ANIMATION_INTERRUPT SP_ANIMATION_INTERRUPT
#define ANIMATION_END SP_ANIMATION_END
#define ANIMATION_COMPLETE SP_ANIMATION_COMPLETE
#define ANIMATION_DISPOSE SP_ANIMATION_DISPOSE
#define ANIMATION_EVENT SP_ANIMATION_EVENT
typedef sp37AnimationStateListener AnimationStateListener;
typedef sp37TrackEntry TrackEntry;
typedef sp37AnimationState AnimationState;
#define AnimationState_create(...) sp37AnimationState_create(__VA_ARGS__)
#define AnimationState_dispose(...) sp37AnimationState_dispose(__VA_ARGS__)
#define AnimationState_update(...) sp37AnimationState_update(__VA_ARGS__)
#define AnimationState_apply(...) sp37AnimationState_apply(__VA_ARGS__)
#define AnimationState_clearTracks(...) sp37AnimationState_clearTracks(__VA_ARGS__)
#define AnimationState_clearTrack(...) sp37AnimationState_clearTrack(__VA_ARGS__)
#define AnimationState_setAnimationByName(...) sp37AnimationState_setAnimationByName(__VA_ARGS__)
#define AnimationState_setAnimation(...) sp37AnimationState_setAnimation(__VA_ARGS__)
#define AnimationState_addAnimationByName(...) sp37AnimationState_addAnimationByName(__VA_ARGS__)
#define AnimationState_addAnimation(...) sp37AnimationState_addAnimation(__VA_ARGS__)
#define AnimationState_setEmptyAnimation(...) sp37AnimationState_setEmptyAnimation(__VA_ARGS__)
#define AnimationState_addEmptyAnimation(...) sp37AnimationState_addEmptyAnimation(__VA_ARGS__)
#define AnimationState_setEmptyAnimations(...) sp37AnimationState_setEmptyAnimations(__VA_ARGS__)
#define AnimationState_getCurrent(...) sp37AnimationState_getCurrent(__VA_ARGS__)
#define AnimationState_clearListenerNotifications(...) sp37AnimationState_clearListenerNotifications(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATIONSTATE_H_ */

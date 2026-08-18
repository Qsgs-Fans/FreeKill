/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated July 28, 2023. Replaces all prior versions.
 *
 * Copyright (c) 2013-2023, Esoteric Software LLC
 *
 * Integration of the Spine Runtimes into software or otherwise creating
 * derivative works of the Spine Runtimes is permitted under the terms and
 * conditions of Section 2 of the Spine Editor License Agreement:
 * http://esotericsoftware.com/spine-editor-license
 *
 * Otherwise, it is permitted to integrate the Spine Runtimes into software or
 * otherwise create derivative works of the Spine Runtimes (collectively,
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
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE
 * SPINE RUNTIMES, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
} sp42EventType;

typedef struct sp42AnimationState sp42AnimationState;
typedef struct sp42TrackEntry sp42TrackEntry;

typedef void (*sp42AnimationStateListener)(sp42AnimationState *state, sp42EventType type, sp42TrackEntry *entry,
										 sp42Event *event);

_SP_ARRAY_DECLARE_TYPE(sp42TrackEntryArray, sp42TrackEntry*)

struct sp42TrackEntry {
	sp42Animation *animation;
	sp42TrackEntry *previous;
	sp42TrackEntry *next;
	sp42TrackEntry *mixingFrom;
	sp42TrackEntry *mixingTo;
	sp42AnimationStateListener listener;
	int trackIndex;
	int /*boolean*/ loop;
	int /*boolean*/ holdPrevious;
	int /*boolean*/ reverse;
	int /*boolean*/ shortestRotation;
	float eventThreshold, mixAttachmentThreshold, alphaAttachmentThreshold, mixDrawOrderThreshold;
	float animationStart, animationEnd, animationLast, nextAnimationLast;
	float delay, trackTime, trackLast, nextTrackLast, trackEnd, timeScale;
	float alpha, mixTime, mixDuration, interruptAlpha, totalAlpha;
	sp42MixBlend mixBlend;
	sp42IntArray *timelineMode;
	sp42TrackEntryArray *timelineHoldMix;
	float *timelinesRotation;
	int timelinesRotationCount;
	void *rendererObject;
	void *userData;
};

struct sp42AnimationState {
	sp42AnimationStateData *data;

	int tracksCount;
	sp42TrackEntry **tracks;

	sp42AnimationStateListener listener;

	float timeScale;

	void *rendererObject;
	void *userData;

	int unkeyedState;
};

/* @param data May be 0 for no mixing. */
SP_API sp42AnimationState *sp42AnimationState_create(sp42AnimationStateData *data);

SP_API void sp42AnimationState_dispose(sp42AnimationState *self);

SP_API void sp42AnimationState_update(sp42AnimationState *self, float delta);

SP_API int /**bool**/ sp42AnimationState_apply(sp42AnimationState *self, struct sp42Skeleton *skeleton);

SP_API void sp42AnimationState_clearTracks(sp42AnimationState *self);

SP_API void sp42AnimationState_clearTrack(sp42AnimationState *self, int trackIndex);

/** Set the current animation. Any queued animations are cleared. */
SP_API sp42TrackEntry *
sp42AnimationState_setAnimationByName(sp42AnimationState *self, int trackIndex, const char *animationName,
									int/*bool*/loop);

SP_API sp42TrackEntry *
sp42AnimationState_setAnimation(sp42AnimationState *self, int trackIndex, sp42Animation *animation, int/*bool*/loop);

/** Adds an animation to be played delay seconds after the current or last queued animation, taking into account any mix
 * duration. */
SP_API sp42TrackEntry *
sp42AnimationState_addAnimationByName(sp42AnimationState *self, int trackIndex, const char *animationName,
									int/*bool*/loop, float delay);

SP_API sp42TrackEntry *
sp42AnimationState_addAnimation(sp42AnimationState *self, int trackIndex, sp42Animation *animation, int/*bool*/loop,
							  float delay);

SP_API sp42TrackEntry *sp42AnimationState_setEmptyAnimation(sp42AnimationState *self, int trackIndex, float mixDuration);

SP_API sp42TrackEntry *
sp42AnimationState_addEmptyAnimation(sp42AnimationState *self, int trackIndex, float mixDuration, float delay);

SP_API void sp42AnimationState_setEmptyAnimations(sp42AnimationState *self, float mixDuration);

SP_API sp42TrackEntry *sp42AnimationState_getCurrent(sp42AnimationState *self, int trackIndex);

SP_API void sp42AnimationState_clearListenerNotifications(sp42AnimationState *self);

SP_API float sp42TrackEntry_getAnimationTime(sp42TrackEntry *entry);

SP_API void sp42TrackEntry_resetRotationDirections(sp42TrackEntry *entry);

SP_API float sp42TrackEntry_getTrackComplete(sp42TrackEntry *entry);

SP_API void sp42TrackEntry_setMixDuration(sp42TrackEntry *entry, float mixDuration, float delay);

SP_API int/*bool*/ sp42TrackEntry_wasApplied(sp42TrackEntry *entry);

SP_API int/*bool*/ sp42TrackEntry_isNextReady(sp42TrackEntry *entry);

SP_API void sp42AnimationState_clearNext(sp42AnimationState *self, sp42TrackEntry *entry);

/** Use this to dispose static memory before your app exits to appease your memory leak detector*/
SP_API void sp42AnimationState_disposeStatics(void);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATIONSTATE_H_ */

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
	SP_ANIMATION_START, SP_ANIMATION_END, SP_ANIMATION_COMPLETE, SP_ANIMATION_EVENT
} sp34EventType;

typedef struct sp34AnimationState sp34AnimationState;

typedef void (*sp34AnimationStateListener) (sp34AnimationState* state, int trackIndex, sp34EventType type, sp34Event* event,
		int loopCount);

typedef struct sp34TrackEntry sp34TrackEntry;
struct sp34TrackEntry {
	sp34AnimationState* const state;
	sp34TrackEntry* next;
	sp34TrackEntry* previous;
	sp34Animation* animation;
	int/*bool*/loop;
	float delay, time, lastTime, endTime, timeScale;
	sp34AnimationStateListener listener;
	float mixTime, mixDuration, mix;

	void* rendererObject;

#ifdef __cplusplus
	sp34TrackEntry() :
		state(0),
		next(0),
		previous(0),
		animation(0),
		loop(0),
		delay(0), time(0), lastTime(0), endTime(0), timeScale(0),
		listener(0),
		mixTime(0), mixDuration(0), mix(0),
		rendererObject(0) {
	}
#endif
};

struct sp34AnimationState {
	sp34AnimationStateData* const data;
	float timeScale;
	sp34AnimationStateListener listener;

	int tracksCount;
	sp34TrackEntry** tracks;

	void* rendererObject;

#ifdef __cplusplus
	sp34AnimationState() :
		data(0),
		timeScale(0),
		listener(0),
		tracksCount(0),
		tracks(0),
		rendererObject(0) {
	}
#endif
};

/* @param data May be 0 for no mixing. */
sp34AnimationState* sp34AnimationState_create (sp34AnimationStateData* data);
void sp34AnimationState_dispose (sp34AnimationState* self);

void sp34AnimationState_update (sp34AnimationState* self, float delta);
void sp34AnimationState_apply (sp34AnimationState* self, struct sp34Skeleton* skeleton);

void sp34AnimationState_clearTracks (sp34AnimationState* self);
void sp34AnimationState_clearTrack (sp34AnimationState* self, int trackIndex);

/** Set the current animation. Any queued animations are cleared. */
sp34TrackEntry* sp34AnimationState_setAnimationByName (sp34AnimationState* self, int trackIndex, const char* animationName,
		int/*bool*/loop);
sp34TrackEntry* sp34AnimationState_setAnimation (sp34AnimationState* self, int trackIndex, sp34Animation* animation, int/*bool*/loop);

/** Adds an animation to be played delay seconds after the current or last queued animation, taking into account any mix
 * duration. */
sp34TrackEntry* sp34AnimationState_addAnimationByName (sp34AnimationState* self, int trackIndex, const char* animationName,
		int/*bool*/loop, float delay);
sp34TrackEntry* sp34AnimationState_addAnimation (sp34AnimationState* self, int trackIndex, sp34Animation* animation, int/*bool*/loop,
		float delay);

sp34TrackEntry* sp34AnimationState_getCurrent (sp34AnimationState* self, int trackIndex);

#ifdef SPINE_SHORT_NAMES
typedef sp34EventType EventType;
#define ANIMATION_START SP_ANIMATION_START
#define ANIMATION_END SP_ANIMATION_END
#define ANIMATION_COMPLETE SP_ANIMATION_COMPLETE
#define ANIMATION_EVENT SP_ANIMATION_EVENT
typedef sp34AnimationStateListener AnimationStateListener;
typedef sp34TrackEntry TrackEntry;
typedef sp34AnimationState AnimationState;
#define AnimationState_create(...) sp34AnimationState_create(__VA_ARGS__)
#define AnimationState_dispose(...) sp34AnimationState_dispose(__VA_ARGS__)
#define AnimationState_update(...) sp34AnimationState_update(__VA_ARGS__)
#define AnimationState_apply(...) sp34AnimationState_apply(__VA_ARGS__)
#define AnimationState_clearTracks(...) sp34AnimationState_clearTracks(__VA_ARGS__)
#define AnimationState_clearTrack(...) sp34AnimationState_clearTrack(__VA_ARGS__)
#define AnimationState_setAnimationByName(...) sp34AnimationState_setAnimationByName(__VA_ARGS__)
#define AnimationState_setAnimation(...) sp34AnimationState_setAnimation(__VA_ARGS__)
#define AnimationState_addAnimationByName(...) sp34AnimationState_addAnimationByName(__VA_ARGS__)
#define AnimationState_addAnimation(...) sp34AnimationState_addAnimation(__VA_ARGS__)
#define AnimationState_getCurrent(...) sp34AnimationState_getCurrent(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATIONSTATE_H_ */

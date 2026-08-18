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
} sp21EventType;

typedef struct sp21AnimationState sp21AnimationState;

typedef void (*sp21AnimationStateListener) (sp21AnimationState* state, int trackIndex, sp21EventType type, sp21Event* event,
		int loopCount);

typedef struct sp21TrackEntry sp21TrackEntry;
struct sp21TrackEntry {
	sp21AnimationState* const state;
	sp21TrackEntry* next;
	sp21TrackEntry* previous;
	sp21Animation* animation;
	int/*bool*/loop;
	float delay, time, lastTime, endTime, timeScale;
	sp21AnimationStateListener listener;
	float mixTime, mixDuration, mix;

	void* rendererObject;

#ifdef __cplusplus
	sp21TrackEntry() :
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

struct sp21AnimationState {
	sp21AnimationStateData* const data;
	float timeScale;
	sp21AnimationStateListener listener;

	int tracksCount;
	sp21TrackEntry** tracks;

	void* rendererObject;

#ifdef __cplusplus
	sp21AnimationState() :
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
sp21AnimationState* sp21AnimationState_create (sp21AnimationStateData* data);
void sp21AnimationState_dispose (sp21AnimationState* self);

void sp21AnimationState_update (sp21AnimationState* self, float delta);
void sp21AnimationState_apply (sp21AnimationState* self, struct sp21Skeleton* skeleton);

void sp21AnimationState_clearTracks (sp21AnimationState* self);
void sp21AnimationState_clearTrack (sp21AnimationState* self, int trackIndex);

/** Set the current animation. Any queued animations are cleared. */
sp21TrackEntry* sp21AnimationState_setAnimationByName (sp21AnimationState* self, int trackIndex, const char* animationName,
		int/*bool*/loop);
sp21TrackEntry* sp21AnimationState_setAnimation (sp21AnimationState* self, int trackIndex, sp21Animation* animation, int/*bool*/loop);

/** Adds an animation to be played delay seconds after the current or last queued animation, taking into account any mix
 * duration. */
sp21TrackEntry* sp21AnimationState_addAnimationByName (sp21AnimationState* self, int trackIndex, const char* animationName,
		int/*bool*/loop, float delay);
sp21TrackEntry* sp21AnimationState_addAnimation (sp21AnimationState* self, int trackIndex, sp21Animation* animation, int/*bool*/loop,
		float delay);

sp21TrackEntry* sp21AnimationState_getCurrent (sp21AnimationState* self, int trackIndex);

#ifdef SPINE_SHORT_NAMES
typedef sp21EventType EventType;
#define ANIMATION_START SP_ANIMATION_START
#define ANIMATION_END SP_ANIMATION_END
#define ANIMATION_COMPLETE SP_ANIMATION_COMPLETE
#define ANIMATION_EVENT SP_ANIMATION_EVENT
typedef sp21AnimationStateListener AnimationStateListener;
typedef sp21TrackEntry TrackEntry;
typedef sp21AnimationState AnimationState;
#define AnimationState_create(...) sp21AnimationState_create(__VA_ARGS__)
#define AnimationState_dispose(...) sp21AnimationState_dispose(__VA_ARGS__)
#define AnimationState_update(...) sp21AnimationState_update(__VA_ARGS__)
#define AnimationState_apply(...) sp21AnimationState_apply(__VA_ARGS__)
#define AnimationState_clearTracks(...) sp21AnimationState_clearTracks(__VA_ARGS__)
#define AnimationState_clearTrack(...) sp21AnimationState_clearTrack(__VA_ARGS__)
#define AnimationState_setAnimationByName(...) sp21AnimationState_setAnimationByName(__VA_ARGS__)
#define AnimationState_setAnimation(...) sp21AnimationState_setAnimation(__VA_ARGS__)
#define AnimationState_addAnimationByName(...) sp21AnimationState_addAnimationByName(__VA_ARGS__)
#define AnimationState_addAnimation(...) sp21AnimationState_addAnimation(__VA_ARGS__)
#define AnimationState_getCurrent(...) sp21AnimationState_getCurrent(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ANIMATIONSTATE_H_ */

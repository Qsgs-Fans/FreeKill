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

#include <spine/AnimationState.h>
#include <spine/extension.h>
#include <string.h>

sp21TrackEntry* _sp21TrackEntry_create (sp21AnimationState* state) {
	sp21TrackEntry* self = NEW(sp21TrackEntry);
	CONST_CAST(sp21AnimationState*, self->state) = state;
	self->timeScale = 1;
	self->lastTime = -1;
	self->mix = 1;
	return self;
}

void _sp21TrackEntry_dispose (sp21TrackEntry* self) {
	if (self->previous) SUB_CAST(_sp21AnimationState, self->state)->disposeTrackEntry(self->previous);
	FREE(self);
}

/**/

sp21TrackEntry* _sp21AnimationState_createTrackEntry (sp21AnimationState* self) {
	return _sp21TrackEntry_create(self);
}

void _sp21AnimationState_disposeTrackEntry (sp21TrackEntry* entry) {
	_sp21TrackEntry_dispose(entry);
}

sp21AnimationState* sp21AnimationState_create (sp21AnimationStateData* data) {
	_sp21AnimationState* internal = NEW(_sp21AnimationState);
	sp21AnimationState* self = SUPER(internal);
	internal->events = MALLOC(sp21Event*, 64);
	self->timeScale = 1;
	CONST_CAST(sp21AnimationStateData*, self->data) = data;
	internal->createTrackEntry = _sp21AnimationState_createTrackEntry;
	internal->disposeTrackEntry = _sp21AnimationState_disposeTrackEntry;
	return self;
}

void _sp21AnimationState_disposeAllEntries (sp21AnimationState* self, sp21TrackEntry* entry) {
	_sp21AnimationState* internal = SUB_CAST(_sp21AnimationState, self);
	while (entry) {
		sp21TrackEntry* next = entry->next;
		internal->disposeTrackEntry(entry);
		entry = next;
	}
}

void sp21AnimationState_dispose (sp21AnimationState* self) {
	int i;
	_sp21AnimationState* internal = SUB_CAST(_sp21AnimationState, self);
	FREE(internal->events);
	for (i = 0; i < self->tracksCount; ++i)
		_sp21AnimationState_disposeAllEntries(self, self->tracks[i]);
	FREE(self->tracks);
	FREE(self);
}

void _sp21AnimationState_setCurrent (sp21AnimationState* self, int index, sp21TrackEntry* entry);

void sp21AnimationState_update (sp21AnimationState* self, float delta) {
	int i;
	float previousDelta;
	delta *= self->timeScale;
	for (i = 0; i < self->tracksCount; ++i) {
		sp21TrackEntry* current = self->tracks[i];
		if (!current) continue;

		current->time += delta * current->timeScale;
		if (current->previous) {
			previousDelta = delta * current->previous->timeScale;
			current->previous->time += previousDelta;
			current->mixTime += previousDelta;
		}

		if (current->next) {
			current->next->time = current->lastTime - current->next->delay;
			if (current->next->time >= 0) _sp21AnimationState_setCurrent(self, i, current->next);
		} else {
			/* End non-looping animation when it reaches its end time and there is no next entry. */
			if (!current->loop && current->lastTime >= current->endTime) sp21AnimationState_clearTrack(self, i);
		}
	}
}

void sp21AnimationState_apply (sp21AnimationState* self, sp21Skeleton* skeleton) {
	_sp21AnimationState* internal = SUB_CAST(_sp21AnimationState, self);

	int i, ii;
	int eventsCount;
	int entryChanged;
	float time;
	sp21TrackEntry* previous;
	for (i = 0; i < self->tracksCount; ++i) {
		sp21TrackEntry* current = self->tracks[i];
		if (!current) continue;

		eventsCount = 0;

		time = current->time;
		if (!current->loop && time > current->endTime) time = current->endTime;

		previous = current->previous;
		if (!previous) {
			if (current->mix == 1) {
				sp21Animation_apply(current->animation, skeleton, current->lastTime, time,
					current->loop, internal->events, &eventsCount);
			} else {
				sp21Animation_mix(current->animation, skeleton, current->lastTime, time,
					current->loop, internal->events, &eventsCount, current->mix);
			}
		} else {
			float alpha = current->mixTime / current->mixDuration * current->mix;

			float previousTime = previous->time;
			if (!previous->loop && previousTime > previous->endTime) previousTime = previous->endTime;
			sp21Animation_apply(previous->animation, skeleton, previousTime, previousTime, previous->loop, 0, 0);

			if (alpha >= 1) {
				alpha = 1;
				internal->disposeTrackEntry(current->previous);
				current->previous = 0;
			}
			sp21Animation_mix(current->animation, skeleton, current->lastTime, time,
				current->loop, internal->events, &eventsCount, alpha);
		}

		entryChanged = 0;
		for (ii = 0; ii < eventsCount; ++ii) {
			sp21Event* event = internal->events[ii];
			if (current->listener) {
				current->listener(self, i, SP_ANIMATION_EVENT, event, 0);
				if (self->tracks[i] != current) {
					entryChanged = 1;
					break;
				}
			}
			if (self->listener) {
				self->listener(self, i, SP_ANIMATION_EVENT, event, 0);
				if (self->tracks[i] != current) {
					entryChanged = 1;
					break;
				}
			}
		}
		if (entryChanged) continue;

		/* Check if completed the animation or a loop iteration. */
		if (current->loop ? (FMOD(current->lastTime, current->endTime) > FMOD(time, current->endTime))
				: (current->lastTime < current->endTime && time >= current->endTime)) {
			int count = (int)(time / current->endTime);
			if (current->listener) {
				current->listener(self, i, SP_ANIMATION_COMPLETE, 0, count);
				if (self->tracks[i] != current) continue;
			}
			if (self->listener) {
				self->listener(self, i, SP_ANIMATION_COMPLETE, 0, count);
				if (self->tracks[i] != current) continue;
			}
		}

		current->lastTime = current->time;
	}
}

void sp21AnimationState_clearTracks (sp21AnimationState* self) {
	int i;
	for (i = 0; i < self->tracksCount; ++i)
		sp21AnimationState_clearTrack(self, i);
	self->tracksCount = 0;
}

void sp21AnimationState_clearTrack (sp21AnimationState* self, int trackIndex) {
	sp21TrackEntry* current;
	if (trackIndex >= self->tracksCount) return;
	current = self->tracks[trackIndex];
	if (!current) return;

	if (current->listener) current->listener(self, trackIndex, SP_ANIMATION_END, 0, 0);
	if (self->listener) self->listener(self, trackIndex, SP_ANIMATION_END, 0, 0);

	self->tracks[trackIndex] = 0;

	_sp21AnimationState_disposeAllEntries(self, current);
}

sp21TrackEntry* _sp21AnimationState_expandToIndex (sp21AnimationState* self, int index) {
	sp21TrackEntry** newTracks;
	if (index < self->tracksCount) return self->tracks[index];
	newTracks = CALLOC(sp21TrackEntry*, index + 1);
	memcpy(newTracks, self->tracks, self->tracksCount * sizeof(sp21TrackEntry*));
	FREE(self->tracks);
	self->tracks = newTracks;
	self->tracksCount = index + 1;
	return 0;
}

void _sp21AnimationState_setCurrent (sp21AnimationState* self, int index, sp21TrackEntry* entry) {
	_sp21AnimationState* internal = SUB_CAST(_sp21AnimationState, self);

	sp21TrackEntry* current = _sp21AnimationState_expandToIndex(self, index);
	if (current) {
		sp21TrackEntry* previous = current->previous;
		current->previous = 0;

		if (current->listener) current->listener(self, index, SP_ANIMATION_END, 0, 0);
		if (self->listener) self->listener(self, index, SP_ANIMATION_END, 0, 0);

		entry->mixDuration = sp21AnimationStateData_getMix(self->data, current->animation, entry->animation);
		if (entry->mixDuration > 0) {
			entry->mixTime = 0;
			/* If a mix is in progress, mix from the closest animation. */
			if (previous && current->mixTime / current->mixDuration < 0.5f) {
				entry->previous = previous;
				previous = current;
			} else
				entry->previous = current;
		} else
			internal->disposeTrackEntry(current);

		if (previous) internal->disposeTrackEntry(previous);
	}

	self->tracks[index] = entry;

	if (entry->listener) {
		entry->listener(self, index, SP_ANIMATION_START, 0, 0);
		if (self->tracks[index] != entry) return;
	}
	if (self->listener) self->listener(self, index, SP_ANIMATION_START, 0, 0);
}

sp21TrackEntry* sp21AnimationState_setAnimationByName (sp21AnimationState* self, int trackIndex, const char* animationName,
		int/*bool*/loop) {
	sp21Animation* animation = sp21SkeletonData_findAnimation(self->data->skeletonData, animationName);
	return sp21AnimationState_setAnimation(self, trackIndex, animation, loop);
}

sp21TrackEntry* sp21AnimationState_setAnimation (sp21AnimationState* self, int trackIndex, sp21Animation* animation, int/*bool*/loop) {
	_sp21AnimationState* internal = SUB_CAST(_sp21AnimationState, self);

	sp21TrackEntry* entry;
	sp21TrackEntry* current = _sp21AnimationState_expandToIndex(self, trackIndex);
	if (current) _sp21AnimationState_disposeAllEntries(self, current->next);

	entry = internal->createTrackEntry(self);
	entry->animation = animation;
	entry->loop = loop;
	entry->endTime = animation->duration;
	_sp21AnimationState_setCurrent(self, trackIndex, entry);
	return entry;
}

sp21TrackEntry* sp21AnimationState_addAnimationByName (sp21AnimationState* self, int trackIndex, const char* animationName,
		int/*bool*/loop, float delay) {
	sp21Animation* animation = sp21SkeletonData_findAnimation(self->data->skeletonData, animationName);
	return sp21AnimationState_addAnimation(self, trackIndex, animation, loop, delay);
}

sp21TrackEntry* sp21AnimationState_addAnimation (sp21AnimationState* self, int trackIndex, sp21Animation* animation, int/*bool*/loop,
		float delay) {
	_sp21AnimationState* internal = SUB_CAST(_sp21AnimationState, self);
	sp21TrackEntry* last;

	sp21TrackEntry* entry = internal->createTrackEntry(self);
	entry->animation = animation;
	entry->loop = loop;
	entry->endTime = animation->duration;

	last = _sp21AnimationState_expandToIndex(self, trackIndex);
	if (last) {
		while (last->next)
			last = last->next;
		last->next = entry;
	} else
		self->tracks[trackIndex] = entry;

	if (delay <= 0) {
		if (last)
			delay += last->endTime - sp21AnimationStateData_getMix(self->data, last->animation, animation);
		else
			delay = 0;
	}
	entry->delay = delay;

	return entry;
}

sp21TrackEntry* sp21AnimationState_getCurrent (sp21AnimationState* self, int trackIndex) {
	if (trackIndex >= self->tracksCount) return 0;
	return self->tracks[trackIndex];
}

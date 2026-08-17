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

#include <spine/AnimationState.h>
#include <spine/extension.h>
#include <string.h>

sp34TrackEntry* _sp34TrackEntry_create (sp34AnimationState* state) {
	sp34TrackEntry* self = NEW(sp34TrackEntry);
	CONST_CAST(sp34AnimationState*, self->state) = state;
	self->timeScale = 1;
	self->lastTime = -1;
	self->mix = 1;
	return self;
}

void _sp34TrackEntry_dispose (sp34TrackEntry* self) {
	if (self->previous) SUB_CAST(_sp34AnimationState, self->state)->disposeTrackEntry(self->previous);
	FREE(self);
}

/**/

sp34TrackEntry* _sp34AnimationState_createTrackEntry (sp34AnimationState* self) {
	return _sp34TrackEntry_create(self);
}

void _sp34AnimationState_disposeTrackEntry (sp34TrackEntry* entry) {
	_sp34TrackEntry_dispose(entry);
}

sp34AnimationState* sp34AnimationState_create (sp34AnimationStateData* data) {
	_sp34AnimationState* internal = NEW(_sp34AnimationState);
	sp34AnimationState* self = SUPER(internal);
	internal->events = MALLOC(sp34Event*, 64);
	self->timeScale = 1;
	CONST_CAST(sp34AnimationStateData*, self->data) = data;
	internal->createTrackEntry = _sp34AnimationState_createTrackEntry;
	internal->disposeTrackEntry = _sp34AnimationState_disposeTrackEntry;
	return self;
}

void _sp34AnimationState_disposeAllEntries (sp34AnimationState* self, sp34TrackEntry* entry) {
	_sp34AnimationState* internal = SUB_CAST(_sp34AnimationState, self);
	while (entry) {
		sp34TrackEntry* next = entry->next;
		internal->disposeTrackEntry(entry);
		entry = next;
	}
}

void sp34AnimationState_dispose (sp34AnimationState* self) {
	int i;
	_sp34AnimationState* internal = SUB_CAST(_sp34AnimationState, self);
	FREE(internal->events);
	for (i = 0; i < self->tracksCount; ++i)
		_sp34AnimationState_disposeAllEntries(self, self->tracks[i]);
	FREE(self->tracks);
	FREE(self);
}

void _sp34AnimationState_setCurrent (sp34AnimationState* self, int index, sp34TrackEntry* entry);

void sp34AnimationState_update (sp34AnimationState* self, float delta) {
	int i;
	float previousDelta;
	delta *= self->timeScale;
	for (i = 0; i < self->tracksCount; ++i) {
		sp34TrackEntry* current = self->tracks[i];
		if (!current) continue;

		current->time += delta * current->timeScale;
		if (current->previous) {
			previousDelta = delta * current->previous->timeScale;
			current->previous->time += previousDelta;
			current->mixTime += previousDelta;
		}

		if (current->next) {
			current->next->time = current->lastTime - current->next->delay;
			if (current->next->time >= 0) _sp34AnimationState_setCurrent(self, i, current->next);
		} else {
			/* End non-looping animation when it reaches its end time and there is no next entry. */
			if (!current->loop && current->lastTime >= current->endTime) sp34AnimationState_clearTrack(self, i);
		}
	}
}

void sp34AnimationState_apply (sp34AnimationState* self, sp34Skeleton* skeleton) {
	_sp34AnimationState* internal = SUB_CAST(_sp34AnimationState, self);

	int i, ii;
	int eventsCount;
	int entryChanged;
	float time;
	sp34TrackEntry* previous;
	for (i = 0; i < self->tracksCount; ++i) {
		sp34TrackEntry* current = self->tracks[i];
		if (!current) continue;

		eventsCount = 0;

		time = current->time;
		if (!current->loop && time > current->endTime) time = current->endTime;

		previous = current->previous;
		if (!previous) {
			if (current->mix == 1) {
				sp34Animation_apply(current->animation, skeleton, current->lastTime, time,
					current->loop, internal->events, &eventsCount);
			} else {
				sp34Animation_mix(current->animation, skeleton, current->lastTime, time,
					current->loop, internal->events, &eventsCount, current->mix);
			}
		} else {
			float alpha = current->mixTime / current->mixDuration * current->mix;

			float previousTime = previous->time;
			if (!previous->loop && previousTime > previous->endTime) previousTime = previous->endTime;
			sp34Animation_apply(previous->animation, skeleton, previousTime, previousTime, previous->loop, 0, 0);

			if (alpha >= 1) {
				alpha = 1;
				internal->disposeTrackEntry(current->previous);
				current->previous = 0;
			}
			sp34Animation_mix(current->animation, skeleton, current->lastTime, time,
				current->loop, internal->events, &eventsCount, alpha);
		}

		entryChanged = 0;
		for (ii = 0; ii < eventsCount; ++ii) {
			sp34Event* event = internal->events[ii];
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

void sp34AnimationState_clearTracks (sp34AnimationState* self) {
	int i;
	for (i = 0; i < self->tracksCount; ++i)
		sp34AnimationState_clearTrack(self, i);
	self->tracksCount = 0;
}

void sp34AnimationState_clearTrack (sp34AnimationState* self, int trackIndex) {
	sp34TrackEntry* current;
	if (trackIndex >= self->tracksCount) return;
	current = self->tracks[trackIndex];
	if (!current) return;

	if (current->listener) current->listener(self, trackIndex, SP_ANIMATION_END, 0, 0);
	if (self->listener) self->listener(self, trackIndex, SP_ANIMATION_END, 0, 0);

	self->tracks[trackIndex] = 0;

	_sp34AnimationState_disposeAllEntries(self, current);
}

sp34TrackEntry* _sp34AnimationState_expandToIndex (sp34AnimationState* self, int index) {
	sp34TrackEntry** newTracks;
	if (index < self->tracksCount) return self->tracks[index];
	newTracks = CALLOC(sp34TrackEntry*, index + 1);
	memcpy(newTracks, self->tracks, self->tracksCount * sizeof(sp34TrackEntry*));
	FREE(self->tracks);
	self->tracks = newTracks;
	self->tracksCount = index + 1;
	return 0;
}

void _sp34AnimationState_setCurrent (sp34AnimationState* self, int index, sp34TrackEntry* entry) {
	_sp34AnimationState* internal = SUB_CAST(_sp34AnimationState, self);

	sp34TrackEntry* current = _sp34AnimationState_expandToIndex(self, index);
	if (current) {
		sp34TrackEntry* previous = current->previous;
		current->previous = 0;

		if (current->listener) current->listener(self, index, SP_ANIMATION_END, 0, 0);
		if (self->listener) self->listener(self, index, SP_ANIMATION_END, 0, 0);

		entry->mixDuration = sp34AnimationStateData_getMix(self->data, current->animation, entry->animation);
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

sp34TrackEntry* sp34AnimationState_setAnimationByName (sp34AnimationState* self, int trackIndex, const char* animationName,
		int/*bool*/loop) {
	sp34Animation* animation = sp34SkeletonData_findAnimation(self->data->skeletonData, animationName);
	return sp34AnimationState_setAnimation(self, trackIndex, animation, loop);
}

sp34TrackEntry* sp34AnimationState_setAnimation (sp34AnimationState* self, int trackIndex, sp34Animation* animation, int/*bool*/loop) {
	_sp34AnimationState* internal = SUB_CAST(_sp34AnimationState, self);

	sp34TrackEntry* entry;
	sp34TrackEntry* current = _sp34AnimationState_expandToIndex(self, trackIndex);
	if (current) _sp34AnimationState_disposeAllEntries(self, current->next);

	entry = internal->createTrackEntry(self);
	entry->animation = animation;
	entry->loop = loop;
	entry->endTime = animation->duration;
	_sp34AnimationState_setCurrent(self, trackIndex, entry);
	return entry;
}

sp34TrackEntry* sp34AnimationState_addAnimationByName (sp34AnimationState* self, int trackIndex, const char* animationName,
		int/*bool*/loop, float delay) {
	sp34Animation* animation = sp34SkeletonData_findAnimation(self->data->skeletonData, animationName);
	return sp34AnimationState_addAnimation(self, trackIndex, animation, loop, delay);
}

sp34TrackEntry* sp34AnimationState_addAnimation (sp34AnimationState* self, int trackIndex, sp34Animation* animation, int/*bool*/loop,
		float delay) {
	_sp34AnimationState* internal = SUB_CAST(_sp34AnimationState, self);
	sp34TrackEntry* last;

	sp34TrackEntry* entry = internal->createTrackEntry(self);
	entry->animation = animation;
	entry->loop = loop;
	entry->endTime = animation->duration;

	last = _sp34AnimationState_expandToIndex(self, trackIndex);
	if (last) {
		while (last->next)
			last = last->next;
		last->next = entry;
	} else
		self->tracks[trackIndex] = entry;

	if (delay <= 0) {
		if (last)
			delay += last->endTime - sp34AnimationStateData_getMix(self->data, last->animation, animation);
		else
			delay = 0;
	}
	entry->delay = delay;

	return entry;
}

sp34TrackEntry* sp34AnimationState_getCurrent (sp34AnimationState* self, int trackIndex) {
	if (trackIndex >= self->tracksCount) return 0;
	return self->tracks[trackIndex];
}

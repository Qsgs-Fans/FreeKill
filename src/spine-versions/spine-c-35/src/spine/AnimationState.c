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
#include <limits.h>

static sp35Animation* SP_EMPTY_ANIMATION = 0;
void sp35AnimationState_disposeStatics () {
	if (SP_EMPTY_ANIMATION) sp35Animation_dispose(SP_EMPTY_ANIMATION);
	SP_EMPTY_ANIMATION = 0;
}

/* Forward declaration of some "private" functions so we can keep
   the same function order in C as we have method order in Java */
void _sp35AnimationState_disposeTrackEntry (sp35TrackEntry* entry);
void _sp35AnimationState_disposeTrackEntries (sp35AnimationState* state, sp35TrackEntry* entry);
void _sp35AnimationState_updateMixingFrom (sp35AnimationState* self, sp35TrackEntry* entry, float delta);
float _sp35AnimationState_applyMixingFrom (sp35AnimationState* self, sp35TrackEntry* entry, sp35Skeleton* skeleton);
void _sp35AnimationState_applyRotateTimeline (sp35AnimationState* self, sp35Timeline* timeline, sp35Skeleton* skeleton, float time, float alpha, int /*boolean*/ setupPose, float* timelinesRotation, int i, int /*boolean*/ firstFrame);
void _sp35AnimationState_queueEvents (sp35AnimationState* self, sp35TrackEntry* entry, float animationTime);
void _sp35AnimationState_setCurrent (sp35AnimationState* self, int index, sp35TrackEntry* current, int /*boolean*/ interrupt);
sp35TrackEntry* _sp35AnimationState_expandToIndex (sp35AnimationState* self, int index);
sp35TrackEntry* _sp35AnimationState_trackEntry (sp35AnimationState* self, int trackIndex, sp35Animation* animation, int /*boolean*/ loop, sp35TrackEntry* last);
void _sp35AnimationState_disposeNext (sp35AnimationState* self, sp35TrackEntry* entry);
void _sp35AnimationState_animationsChanged (sp35AnimationState* self);
float* _sp35AnimationState_resizeTimelinesRotation(sp35TrackEntry* entry, int newSize);
int* _sp35AnimationState_resizeTimelinesFirst(sp35TrackEntry* entry, int newSize);
void _sp35AnimationState_ensureCapacityPropertyIDs(sp35AnimationState* self, int capacity);
int _sp35AnimationState_addPropertyID(sp35AnimationState* self, int id);
void _sp35AnimationState_setTimelinesFirst (sp35AnimationState* self, sp35TrackEntry* entry);
void _sp35AnimationState_checkTimelinesFirst (sp35AnimationState* self, sp35TrackEntry* entry);
void _sp35AnimationState_checkTimelinesUsage (sp35AnimationState* self, sp35TrackEntry* entry);

_sp35EventQueue* _sp35EventQueue_create (_sp35AnimationState* state) {
	_sp35EventQueue *self = CALLOC(_sp35EventQueue, 1);
	self->state = state;
	self->objectsCount = 0;
	self->objectsCapacity = 16;
	self->objects = CALLOC(_sp35EventQueueItem, self->objectsCapacity);
	self->drainDisabled = 0;
	return self;
}

void _sp35EventQueue_free (_sp35EventQueue* self) {
	FREE(self->objects);
    FREE(self);
}

void _sp35EventQueue_ensureCapacity (_sp35EventQueue* self, int newElements) {
	if (self->objectsCount + newElements > self->objectsCapacity) {
		_sp35EventQueueItem* newObjects;
		self->objectsCapacity <<= 1;
		newObjects = CALLOC(_sp35EventQueueItem, self->objectsCapacity);
		memcpy(newObjects, self->objects, sizeof(_sp35EventQueueItem) * self->objectsCount);
		FREE(self->objects);
		self->objects = newObjects;
	}
}

void _sp35EventQueue_addType (_sp35EventQueue* self, sp35EventType type) {
	_sp35EventQueue_ensureCapacity(self, 1);
	self->objects[self->objectsCount++].type = type;
}

void _sp35EventQueue_addEntry (_sp35EventQueue* self, sp35TrackEntry* entry) {
	_sp35EventQueue_ensureCapacity(self, 1);
	self->objects[self->objectsCount++].entry = entry;
}

void _sp35EventQueue_addEvent (_sp35EventQueue* self, sp35Event* event) {
	_sp35EventQueue_ensureCapacity(self, 1);
	self->objects[self->objectsCount++].event = event;
}

void _sp35EventQueue_start (_sp35EventQueue* self, sp35TrackEntry* entry) {
	_sp35EventQueue_addType(self, SP_ANIMATION_START);
	_sp35EventQueue_addEntry(self, entry);
	self->state->animationsChanged = 1;
}

void _sp35EventQueue_interrupt (_sp35EventQueue* self, sp35TrackEntry* entry) {
	_sp35EventQueue_addType(self, SP_ANIMATION_INTERRUPT);
	_sp35EventQueue_addEntry(self, entry);
}

void _sp35EventQueue_end (_sp35EventQueue* self, sp35TrackEntry* entry) {
	_sp35EventQueue_addType(self, SP_ANIMATION_END);
	_sp35EventQueue_addEntry(self, entry);
	self->state->animationsChanged = 1;
}

void _sp35EventQueue_dispose (_sp35EventQueue* self, sp35TrackEntry* entry) {
	_sp35EventQueue_addType(self, SP_ANIMATION_DISPOSE);
	_sp35EventQueue_addEntry(self, entry);
}

void _sp35EventQueue_complete (_sp35EventQueue* self, sp35TrackEntry* entry) {
	_sp35EventQueue_addType(self, SP_ANIMATION_COMPLETE);
	_sp35EventQueue_addEntry(self, entry);
}

void _sp35EventQueue_event (_sp35EventQueue* self, sp35TrackEntry* entry, sp35Event* event) {
	_sp35EventQueue_addType(self, SP_ANIMATION_EVENT);
	_sp35EventQueue_addEntry(self, entry);
	_sp35EventQueue_addEvent(self, event);
}

void _sp35EventQueue_clear (_sp35EventQueue* self) {
	self->objectsCount = 0;
}

void _sp35EventQueue_drain (_sp35EventQueue* self) {
	int i;
	if (self->drainDisabled) return;
	self->drainDisabled = 1;
	for (i = 0; i < self->objectsCount; i += 2) {
		sp35EventType type = (sp35EventType)self->objects[i].type;
		sp35TrackEntry* entry = self->objects[i+1].entry;
		sp35Event* event;
		switch (type) {
			case SP_ANIMATION_START:
			case SP_ANIMATION_INTERRUPT:
			case SP_ANIMATION_COMPLETE:
				if (entry->listener) entry->listener(SUPER(self->state), type, entry, 0);
				if (self->state->super.listener) self->state->super.listener(SUPER(self->state), type, entry, 0);
				break;
			case SP_ANIMATION_END:
				if (entry->listener) entry->listener(SUPER(self->state), type, entry, 0);
				if (self->state->super.listener) self->state->super.listener(SUPER(self->state), type, entry, 0);
				/* Fall through. */
			case SP_ANIMATION_DISPOSE:
				if (entry->listener) entry->listener(SUPER(self->state), SP_ANIMATION_DISPOSE, entry, 0);
				if (self->state->super.listener) self->state->super.listener(SUPER(self->state), SP_ANIMATION_DISPOSE, entry, 0);
				_sp35AnimationState_disposeTrackEntry(entry);
				break;
			case SP_ANIMATION_EVENT:
				event = self->objects[i+2].event;
				if (entry->listener) entry->listener(SUPER(self->state), type, entry, event);
				if (self->state->super.listener) self->state->super.listener(SUPER(self->state), type, entry, event);
				i++;
				break;
		}
	}
	_sp35EventQueue_clear(self);

	self->drainDisabled = 0;
}

void _sp35AnimationState_disposeTrackEntry (sp35TrackEntry* entry) {
	FREE(entry->timelinesFirst);
	FREE(entry->timelinesRotation);
	FREE(entry);
}

void _sp35AnimationState_disposeTrackEntries (sp35AnimationState* state, sp35TrackEntry* entry) {
	while (entry) {
		sp35TrackEntry* next = entry->next;
		sp35TrackEntry* from = entry->mixingFrom;
		while (from) {
			sp35TrackEntry* nextFrom = from->mixingFrom;
			_sp35AnimationState_disposeTrackEntry(from);
			from = nextFrom;
		}
		_sp35AnimationState_disposeTrackEntry(entry);
		entry = next;
	}
}

sp35AnimationState* sp35AnimationState_create (sp35AnimationStateData* data) {
	_sp35AnimationState* internal;
	sp35AnimationState* self;

	if (!SP_EMPTY_ANIMATION) {
		SP_EMPTY_ANIMATION = (sp35Animation*)1; /* dirty trick so we can recursively call sp35Animation_create */
		SP_EMPTY_ANIMATION = sp35Animation_create("<empty>", 0);
	}

	internal = NEW(_sp35AnimationState);
	self = SUPER(internal);

	CONST_CAST(sp35AnimationStateData*, self->data) = data;
	self->timeScale = 1;

	internal->queue = _sp35EventQueue_create(internal);
	internal->events = CALLOC(sp35Event*, 128);

	internal->propertyIDs = CALLOC(int, 128);
	internal->propertyIDsCapacity = 128;

	return self;
}

void sp35AnimationState_dispose (sp35AnimationState* self) {
	int i;
	_sp35AnimationState* internal = SUB_CAST(_sp35AnimationState, self);
	for (i = 0; i < self->tracksCount; i++)
		_sp35AnimationState_disposeTrackEntries(self, self->tracks[i]);
	FREE(self->tracks);
	_sp35EventQueue_free(internal->queue);
	FREE(internal->events);
	FREE(internal->propertyIDs);
    FREE(internal);
}

void sp35AnimationState_update (sp35AnimationState* self, float delta) {
	int i, n;
	_sp35AnimationState* internal = SUB_CAST(_sp35AnimationState, self);
	delta *= self->timeScale;
	for (i = 0, n = self->tracksCount; i < n; i++) {
		float currentDelta;
		sp35TrackEntry* current = self->tracks[i];
		sp35TrackEntry* next;
		if (!current) continue;

		current->animationLast = current->nextAnimationLast;
		current->trackLast = current->nextTrackLast;

		currentDelta = delta * current->timeScale;

		if (current->delay > 0) {
			current->delay -= currentDelta;
			if (current->delay > 0) continue;
			currentDelta = -current->delay;
			current->delay = 0;
		}

		next = current->next;
		if (next) {
			/* When the next entry's delay is passed, change to the next entry, preserving leftover time. */
			float nextTime = current->trackLast - next->delay;
			if (nextTime >= 0) {
				next->delay = 0;
				next->trackTime = nextTime + delta * next->timeScale;
				current->trackTime += currentDelta;
				_sp35AnimationState_setCurrent(self, i, next, 1);
				while (next->mixingFrom) {
					next->mixTime += currentDelta;
					next = next->mixingFrom;
				}
				continue;
			}
		} else {
			/* Clear the track when there is no next entry, the track end time is reached, and there is no mixingFrom. */
			if (current->trackLast >= current->trackEnd && current->mixingFrom == 0) {
				self->tracks[i] = 0;
				_sp35EventQueue_end(internal->queue, current);
				_sp35AnimationState_disposeNext(self, current);
				continue;
			}
		}
        _sp35AnimationState_updateMixingFrom(self, current, delta);

		current->trackTime += currentDelta;
	}

	_sp35EventQueue_drain(internal->queue);
}

void _sp35AnimationState_updateMixingFrom (sp35AnimationState* self, sp35TrackEntry* entry, float delta) {
	sp35TrackEntry* from = entry->mixingFrom;		
	_sp35AnimationState* internal = SUB_CAST(_sp35AnimationState, self);
	if (!from) return;
    
    _sp35AnimationState_updateMixingFrom(self, from, delta);

	if (entry->mixTime >= entry->mixDuration && from->mixingFrom == 0 && entry->mixTime > 0) {
        entry->mixingFrom = 0;
		_sp35EventQueue_end(internal->queue, from);
        return;
	}

	from->animationLast = from->nextAnimationLast;
	from->trackLast = from->nextTrackLast;
	from->trackTime += delta * from->timeScale;
	entry->mixTime += delta * entry->timeScale;
}

void sp35AnimationState_apply (sp35AnimationState* self, sp35Skeleton* skeleton) {
	_sp35AnimationState* internal = SUB_CAST(_sp35AnimationState, self);
	sp35TrackEntry* current;
	int i, ii, n;
	float animationLast, animationTime;
	int timelineCount;
	sp35Timeline** timelines;
	int /*boolean*/ firstFrame;
	float* timelinesRotation;
	int* timelinesFirst;
	sp35Timeline* timeline;

	if (internal->animationsChanged) _sp35AnimationState_animationsChanged(self);

	for (i = 0, n = self->tracksCount; i < n; i++) {
		float mix;
		current = self->tracks[i];
		if (!current || current->delay > 0) continue;

		/* Apply mixing from entries first. */
		mix = current->alpha;
		if (current->mixingFrom)
            mix *= _sp35AnimationState_applyMixingFrom(self, current, skeleton);
        else if (current->trackTime >= current->trackEnd)
            mix = 0;

		/* Apply current entry. */
		animationLast = current->animationLast; animationTime = sp35TrackEntry_getAnimationTime(current);
		timelineCount = current->animation->timelinesCount;
		timelines = current->animation->timelines;
		if (mix == 1) {
			for (ii = 0; ii < timelineCount; ii++)
				sp35Timeline_apply(timelines[ii], skeleton, animationLast, animationTime, internal->events, &internal->eventsCount, 1, 1, 0);
		} else {
			firstFrame = current->timelinesRotationCount == 0;
			if (firstFrame) _sp35AnimationState_resizeTimelinesRotation(current, timelineCount << 1);
			timelinesRotation = current->timelinesRotation;

			timelinesFirst = current->timelinesFirst;
			for (ii = 0; ii < timelineCount; ii++) {
				timeline = timelines[ii];
				if (timeline->type == SP_TIMELINE_ROTATE)
					_sp35AnimationState_applyRotateTimeline(self, timeline, skeleton, animationTime, mix, timelinesFirst[ii], timelinesRotation, ii << 1, firstFrame);
				else
					sp35Timeline_apply(timeline, skeleton, animationLast, animationTime, internal->events, &internal->eventsCount, mix, timelinesFirst[ii], 0);
			}
		}
		_sp35AnimationState_queueEvents(self, current, animationTime);
		internal->eventsCount = 0;
		current->nextAnimationLast = animationTime;
		current->nextTrackLast = current->trackTime;
	}

	_sp35EventQueue_drain(internal->queue);
}

float _sp35AnimationState_applyMixingFrom (sp35AnimationState* self, sp35TrackEntry* entry, sp35Skeleton* skeleton) {
	_sp35AnimationState* internal = SUB_CAST(_sp35AnimationState, self);
	float mix;
	sp35Event** events;
	int /*boolean*/ attachments;
	int /*boolean*/ drawOrder;
	float animationLast;
	float animationTime;
	int timelineCount;
	sp35Timeline** timelines;
	int* timelinesFirst;
	float alpha;
	int /*boolean*/ firstFrame;
	float* timelinesRotation;
	sp35Timeline* timeline;
	int /*boolean*/ setupPose;
	int i;

	sp35TrackEntry* from = entry->mixingFrom;
	if (from->mixingFrom) _sp35AnimationState_applyMixingFrom(self, from, skeleton);

	if (entry->mixDuration == 0) /* Single frame mix to undo mixingFrom changes. */
		mix = 1;
	else {
		mix = entry->mixTime / entry->mixDuration;
		if (mix > 1) mix = 1;
	}

	events = mix < from->eventThreshold ? internal->events : 0;
	attachments = mix < from->attachmentThreshold;
	drawOrder = mix < from->drawOrderThreshold;
	animationLast = from->animationLast;
	animationTime = sp35TrackEntry_getAnimationTime(from);
	timelineCount = from->animation->timelinesCount;
	timelines = from->animation->timelines;
	timelinesFirst = from->timelinesFirst;
	alpha = from->alpha * entry->mixAlpha * (1 - mix);

	firstFrame = from->timelinesRotationCount == 0;
	if (firstFrame) _sp35AnimationState_resizeTimelinesRotation(from, timelineCount << 1);
	timelinesRotation = from->timelinesRotation;

	for (i = 0; i < timelineCount; i++) {
		timeline = timelines[i];
		setupPose = timelinesFirst[i];
		if (timeline->type == SP_TIMELINE_ROTATE)
			_sp35AnimationState_applyRotateTimeline(self, timeline, skeleton, animationTime, alpha, setupPose, timelinesRotation, i << 1, firstFrame);
		else {
			if (!setupPose) {
				if (!attachments && timeline->type == SP_TIMELINE_ATTACHMENT) continue;
				if (!drawOrder && timeline->type == SP_TIMELINE_DRAWORDER) continue;
			}
			sp35Timeline_apply(timeline, skeleton, animationLast, animationTime, events, &internal->eventsCount, alpha, setupPose, 1);
		}
	}

	if (entry->mixDuration > 0) _sp35AnimationState_queueEvents(self, from, animationTime);
	internal->eventsCount = 0;
	from->nextAnimationLast = animationTime;
	from->nextTrackLast = from->trackTime;

	return mix;
}

void _sp35AnimationState_applyRotateTimeline (sp35AnimationState* self, sp35Timeline* timeline, sp35Skeleton* skeleton, float time, float alpha, int /*boolean*/ setupPose, float* timelinesRotation, int i, int /*boolean*/ firstFrame) {
	sp35RotateTimeline *rotateTimeline;
	float *frames;
	sp35Bone* bone;
	float r1, r2;
	int frame;
	float prevRotation;
	float frameTime;
	float percent;
	float total, diff;
	int /*boolean*/ current, dir;

	if (firstFrame) timelinesRotation[i] = 0;

	if (alpha == 1) {
		sp35Timeline_apply(timeline, skeleton, 0, time, 0, 0, 1, setupPose, 0);
		return;
	}

	rotateTimeline = SUB_CAST(sp35RotateTimeline, timeline);
	frames = rotateTimeline->frames;
	bone = skeleton->bones[rotateTimeline->boneIndex];
	if (time < frames[0]) {
		if (setupPose) {
			bone->rotation = bone->data->rotation;
		}
		return; /* Time is before first frame. */
	}

	if (time >= frames[rotateTimeline->framesCount - ROTATE_ENTRIES]) /* Time is after last frame. */
		r2 = bone->data->rotation + frames[rotateTimeline->framesCount + ROTATE_PREV_ROTATION];
	else {
		/* Interpolate between the previous frame and the current frame. */
		frame = _sp35CurveTimeline_binarySearch(frames, rotateTimeline->framesCount, time, ROTATE_ENTRIES);
		prevRotation = frames[frame + ROTATE_PREV_ROTATION];
		frameTime = frames[frame];
		percent = sp35CurveTimeline_getCurvePercent(SUPER(rotateTimeline), (frame >> 1) - 1,
													   1 - (time - frameTime) / (frames[frame + ROTATE_PREV_TIME] - frameTime));

		r2 = frames[frame + ROTATE_ROTATION] - prevRotation;
		r2 -= (16384 - (int)(16384.499999999996 - r2 / 360)) * 360;
		r2 = prevRotation + r2 * percent + bone->data->rotation;
		r2 -= (16384 - (int)(16384.499999999996 - r2 / 360)) * 360;
	}

	/* Mix between rotations using the direction of the shortest route on the first frame while detecting crosses. */
	r1 = setupPose ? bone->data->rotation : bone->rotation;
	diff = r2 - r1;
	if (diff == 0) {
		total = timelinesRotation[i];
	} else {
		float lastTotal, lastDiff;
		diff -= (16384 - (int)(16384.499999999996 - diff / 360)) * 360;
		if (firstFrame) {
			lastTotal = 0;
			lastDiff = diff;
		} else {
			lastTotal = timelinesRotation[i]; /* Angle and direction of mix, including loops. */
			lastDiff = timelinesRotation[i + 1]; /* Difference between bones. */
		}
		current = diff > 0;
		dir = lastTotal >= 0;
		/* Detect cross at 0 (not 180). */
		if (SIGNUM(lastDiff) != SIGNUM(diff) && ABS(lastDiff) <= 90) {
			/* A cross after a 360 rotation is a loop. */
			if (ABS(lastTotal) > 180) lastTotal += 360 * SIGNUM(lastTotal);
			dir = current;
		}
		total = diff + lastTotal - FMOD(lastTotal, 360); /* Store loops as part of lastTotal. */
		if (dir != current) total += 360 * SIGNUM(lastTotal);
		timelinesRotation[i] = total;
	}
	timelinesRotation[i + 1] = diff;
	r1 += total * alpha;
	bone->rotation = r1 - (16384 - (int)(16384.499999999996 - r1 / 360)) * 360;
}

void _sp35AnimationState_queueEvents (sp35AnimationState* self, sp35TrackEntry* entry, float animationTime) {
	sp35Event** events;
	sp35Event* event;
	_sp35AnimationState* internal = SUB_CAST(_sp35AnimationState, self);
	int i, n;
	float animationStart = entry->animationStart, animationEnd = entry->animationEnd;
	float duration = animationEnd - animationStart;
	float trackLastWrapped = FMOD(entry->trackLast, duration);

	/* Queue events before complete. */
	events = internal->events;
	for (i = 0, n = internal->eventsCount; i < n; i++) {
		event = events[i];
		if (event->time < trackLastWrapped) break;
		if (event->time > animationEnd) continue; /* Discard events outside animation start/end. */
		_sp35EventQueue_event(internal->queue, entry, event);
	}

	/* Queue complete if completed a loop iteration or the animation. */
	if (entry->loop ? (trackLastWrapped > FMOD(entry->trackTime, duration))
				   : (animationTime >= animationEnd && entry->animationLast < animationEnd)) {
		_sp35EventQueue_complete(internal->queue, entry);
	}

	/* Queue events after complete. */
	for (; i < n; i++) {
		event = events[i];
		if (event->time < animationStart) continue; /* Discard events outside animation start/end. */
		_sp35EventQueue_event(internal->queue, entry, event);
	}
}

void sp35AnimationState_clearTracks (sp35AnimationState* self) {
	_sp35AnimationState* internal = SUB_CAST(_sp35AnimationState, self);
	int i, n, oldDrainDisabled;
	oldDrainDisabled = internal->queue->drainDisabled;
	internal->queue->drainDisabled = 1;
	for (i = 0, n = self->tracksCount; i < n; i++)
		sp35AnimationState_clearTrack(self, i);
	self->tracksCount = 0;
	internal->queue->drainDisabled = oldDrainDisabled;
	_sp35EventQueue_drain(internal->queue);
}

void sp35AnimationState_clearTrack (sp35AnimationState* self, int trackIndex) {
	sp35TrackEntry* current;
	sp35TrackEntry* entry;
	sp35TrackEntry* from;
	_sp35AnimationState* internal = SUB_CAST(_sp35AnimationState, self);

	if (trackIndex >= self->tracksCount) return;
	current = self->tracks[trackIndex];
	if (!current) return;

	_sp35EventQueue_end(internal->queue, current);

	_sp35AnimationState_disposeNext(self, current);

	entry = current;
	while (1) {
		from = entry->mixingFrom;
		if (!from) break;
		_sp35EventQueue_end(internal->queue, from);
		entry->mixingFrom = 0;
		entry = from;
	}

	self->tracks[current->trackIndex] = 0;
	_sp35EventQueue_drain(internal->queue);
}

void _sp35AnimationState_setCurrent (sp35AnimationState* self, int index, sp35TrackEntry* current, int /*boolean*/ interrupt) {
	_sp35AnimationState* internal = SUB_CAST(_sp35AnimationState, self);
	sp35TrackEntry* from = _sp35AnimationState_expandToIndex(self, index);
	self->tracks[index] = current;

	if (from) {
		if (interrupt) _sp35EventQueue_interrupt(internal->queue, from);
		current->mixingFrom = from;
		current->mixTime = 0;

		from->timelinesRotationCount = 0;

		/* If not completely mixed in, set mixAlpha so mixing out happens from current mix to zero. */
		if (from->mixingFrom && from->mixDuration > 0) current->mixAlpha *= MIN(from->mixTime / from->mixDuration, 1);
	}

	_sp35EventQueue_start(internal->queue, current);
}

/** Set the current animation. Any queued animations are cleared. */
sp35TrackEntry* sp35AnimationState_setAnimationByName (sp35AnimationState* self, int trackIndex, const char* animationName,
												   int/*bool*/loop) {
	sp35Animation* animation = sp35SkeletonData_findAnimation(self->data->skeletonData, animationName);
	return sp35AnimationState_setAnimation(self, trackIndex, animation, loop);
}

sp35TrackEntry* sp35AnimationState_setAnimation (sp35AnimationState* self, int trackIndex, sp35Animation* animation, int/*bool*/loop) {
	sp35TrackEntry* entry;
	_sp35AnimationState* internal = SUB_CAST(_sp35AnimationState, self);
	int interrupt = 1;
	sp35TrackEntry* current = _sp35AnimationState_expandToIndex(self, trackIndex);
	if (current) {
		if (current->nextTrackLast == -1) {
			/* Don't mix from an entry that was never applied. */
			self->tracks[trackIndex] = current->mixingFrom;
			_sp35EventQueue_interrupt(internal->queue, current);
			_sp35EventQueue_end(internal->queue, current);
			_sp35AnimationState_disposeNext(self, current);
			current = current->mixingFrom;
			interrupt = 0;
		} else
			_sp35AnimationState_disposeNext(self, current);
	}
	entry = _sp35AnimationState_trackEntry(self, trackIndex, animation, loop, current);
	_sp35AnimationState_setCurrent(self, trackIndex, entry, interrupt);
	_sp35EventQueue_drain(internal->queue);
	return entry;
}

/** Adds an animation to be played delay seconds after the current or last queued animation, taking into account any mix
 * duration. */
sp35TrackEntry* sp35AnimationState_addAnimationByName (sp35AnimationState* self, int trackIndex, const char* animationName,
												   int/*bool*/loop, float delay) {
	sp35Animation* animation = sp35SkeletonData_findAnimation(self->data->skeletonData, animationName);
	return sp35AnimationState_addAnimation(self, trackIndex, animation, loop, delay);
}

sp35TrackEntry* sp35AnimationState_addAnimation (sp35AnimationState* self, int trackIndex, sp35Animation* animation, int/*bool*/loop,
											 float delay) {
	sp35TrackEntry* entry;
	_sp35AnimationState* internal = SUB_CAST(_sp35AnimationState, self);
	sp35TrackEntry* last = _sp35AnimationState_expandToIndex(self, trackIndex);
	if (last) {
		while (last->next)
			last = last->next;
	}

	entry = _sp35AnimationState_trackEntry(self, trackIndex, animation, loop, last);

	if (!last) {
		_sp35AnimationState_setCurrent(self, trackIndex, entry, 1);
		_sp35EventQueue_drain(internal->queue);
	} else {
		last->next = entry;
		if (delay <= 0) {
			float duration = last->animationEnd - last->animationStart;
			if (duration != 0)
				delay += duration * (1 + (int)(last->trackTime / duration)) - sp35AnimationStateData_getMix(self->data, last->animation, animation);
			else
				delay = 0;
		}
	}

	entry->delay = delay;
	return entry;
}

sp35TrackEntry* sp35AnimationState_setEmptyAnimation(sp35AnimationState* self, int trackIndex, float mixDuration) {
	sp35TrackEntry* entry = sp35AnimationState_setAnimation(self, trackIndex, SP_EMPTY_ANIMATION, 0);
	entry->mixDuration = mixDuration;
	entry->trackEnd = mixDuration;
	return entry;
}

sp35TrackEntry* sp35AnimationState_addEmptyAnimation(sp35AnimationState* self, int trackIndex, float mixDuration, float delay) {
	sp35TrackEntry* entry;
	if (delay <= 0) delay -= mixDuration;
	entry = sp35AnimationState_addAnimation(self, trackIndex, SP_EMPTY_ANIMATION, 0, delay);
	entry->mixDuration = mixDuration;
	entry->trackEnd = mixDuration;
	return entry;
}

void sp35AnimationState_setEmptyAnimations(sp35AnimationState* self, float mixDuration) {
	int i, n, oldDrainDisabled;
	sp35TrackEntry* current;
	_sp35AnimationState* internal = SUB_CAST(_sp35AnimationState, self);
	oldDrainDisabled = internal->queue->drainDisabled;
	internal->queue->drainDisabled = 1;
	for (i = 0, n = self->tracksCount; i < n; i++) {
		current = self->tracks[i];
		if (current) sp35AnimationState_setEmptyAnimation(self, current->trackIndex, mixDuration);
	}
	internal->queue->drainDisabled = oldDrainDisabled;
	_sp35EventQueue_drain(internal->queue);
}

sp35TrackEntry* _sp35AnimationState_expandToIndex (sp35AnimationState* self, int index) {
	sp35TrackEntry** newTracks;
	if (index < self->tracksCount) return self->tracks[index];
	newTracks = CALLOC(sp35TrackEntry*, index + 1);
	memcpy(newTracks, self->tracks, self->tracksCount * sizeof(sp35TrackEntry*));
	FREE(self->tracks);
	self->tracks = newTracks;
	self->tracksCount = index + 1;
	return 0;
}

sp35TrackEntry* _sp35AnimationState_trackEntry (sp35AnimationState* self, int trackIndex, sp35Animation* animation, int /*boolean*/ loop, sp35TrackEntry* last) {
	sp35TrackEntry* entry = NEW(sp35TrackEntry);
	entry->trackIndex = trackIndex;
	entry->animation = animation;
	entry->loop = loop;

	entry->eventThreshold = 0;
	entry->attachmentThreshold = 0;
	entry->drawOrderThreshold = 0;

	entry->animationStart = 0;
	entry->animationEnd = animation->duration;
	entry->animationLast = -1;
	entry->nextAnimationLast = -1;

	entry->delay = 0;
	entry->trackTime = 0;
	entry->trackLast = -1;
	entry->nextTrackLast = -1;
	entry->trackEnd = (float)INT_MAX;
	entry->timeScale = 1;

	entry->alpha = 1;
	entry->mixAlpha = 1;
	entry->mixTime = 0;
	entry->mixDuration = !last ? 0 : sp35AnimationStateData_getMix(self->data, last->animation, animation);
	return entry;
}

void _sp35AnimationState_disposeNext (sp35AnimationState* self, sp35TrackEntry* entry) {
	_sp35AnimationState* internal = SUB_CAST(_sp35AnimationState, self);
	sp35TrackEntry* next = entry->next;
	while (next) {
		_sp35EventQueue_dispose(internal->queue, next);
		next = next->next;
	}
	entry->next = 0;
}

void _sp35AnimationState_animationsChanged (sp35AnimationState* self) {
	_sp35AnimationState* internal = SUB_CAST(_sp35AnimationState, self);
	int i, n;
	sp35TrackEntry* entry;
	internal->animationsChanged = 0;

	i = 0; n = self->tracksCount;
	internal->propertyIDsCount = 0;

	for (; i < n; i++) {
		entry = self->tracks[i];
		if (!entry) continue;
		_sp35AnimationState_setTimelinesFirst(self, entry);
		i++;
		break;
	}
	for (; i < n; i++) {
		entry = self->tracks[i];
		if (entry) _sp35AnimationState_checkTimelinesFirst(self, entry);
	}
}

float* _sp35AnimationState_resizeTimelinesRotation(sp35TrackEntry* entry, int newSize) {
	if (entry->timelinesRotationCount != newSize) {
		float* newTimelinesRotation = CALLOC(float, newSize);
		FREE(entry->timelinesRotation);
		entry->timelinesRotation = newTimelinesRotation;
		entry->timelinesRotationCount = newSize;
	}
	return entry->timelinesRotation;
}

int* _sp35AnimationState_resizeTimelinesFirst(sp35TrackEntry* entry, int newSize) {
	if (entry->timelinesFirstCount != newSize) {
		int* newTimelinesFirst = CALLOC(int, newSize);
		FREE(entry->timelinesFirst);
		entry->timelinesFirst = newTimelinesFirst;
		entry->timelinesFirstCount = newSize;
	}

	return entry->timelinesFirst;
}

void _sp35AnimationState_ensureCapacityPropertyIDs(sp35AnimationState* self, int capacity) {
	_sp35AnimationState* internal = SUB_CAST(_sp35AnimationState, self);
	if (internal->propertyIDsCapacity < capacity) {
		int *newPropertyIDs = CALLOC(int, capacity << 1);
		memcpy(newPropertyIDs, internal->propertyIDs, sizeof(int) * internal->propertyIDsCount);
		FREE(internal->propertyIDs);
		internal->propertyIDs = newPropertyIDs;
		internal->propertyIDsCapacity = capacity << 1;
	}
}

int _sp35AnimationState_addPropertyID(sp35AnimationState* self, int id) {
	int i, n;
	_sp35AnimationState* internal = SUB_CAST(_sp35AnimationState, self);

	for (i = 0, n = internal->propertyIDsCount; i < n; i++) {
		if (internal->propertyIDs[i] == id) return 0;
	}

	_sp35AnimationState_ensureCapacityPropertyIDs(self, internal->propertyIDsCount + 1);
	internal->propertyIDs[internal->propertyIDsCount] = id;
	internal->propertyIDsCount++;
	return 1;
}

void _sp35AnimationState_setTimelinesFirst (sp35AnimationState* self, sp35TrackEntry* entry) {
	int i, n;
	int* usage;
	sp35Timeline** timelines;

	if (entry->mixingFrom) {
		_sp35AnimationState_setTimelinesFirst(self, entry->mixingFrom);
		_sp35AnimationState_checkTimelinesUsage(self, entry);
		return;
	}

	n = entry->animation->timelinesCount;
	timelines = entry->animation->timelines;
	usage = _sp35AnimationState_resizeTimelinesFirst(entry, n);
	for (i = 0; i < n; i++) {
		_sp35AnimationState_addPropertyID(self, sp35Timeline_getPropertyId(timelines[i]));
		usage[i] = 1;
	}
}

void _sp35AnimationState_checkTimelinesFirst (sp35AnimationState* self, sp35TrackEntry* entry) {
	if (entry->mixingFrom) _sp35AnimationState_checkTimelinesFirst(self, entry->mixingFrom);
	_sp35AnimationState_checkTimelinesUsage(self, entry);
}

void _sp35AnimationState_checkTimelinesUsage (sp35AnimationState* self, sp35TrackEntry* entry) {
	int i, n;
	int* usage;
	sp35Timeline** timelines;
	n = entry->animation->timelinesCount;
	timelines = entry->animation->timelines;
	usage = _sp35AnimationState_resizeTimelinesFirst(entry, n);
	for (i = 0; i < n; i++)
		usage[i] = _sp35AnimationState_addPropertyID(self, sp35Timeline_getPropertyId(timelines[i]));
}

sp35TrackEntry* sp35AnimationState_getCurrent (sp35AnimationState* self, int trackIndex) {
	if (trackIndex >= self->tracksCount) return 0;
	return self->tracks[trackIndex];
}

void sp35AnimationState_clearListenerNotifications(sp35AnimationState* self) {
	_sp35AnimationState* internal = SUB_CAST(_sp35AnimationState, self);
	_sp35EventQueue_clear(internal->queue);
}

float sp35TrackEntry_getAnimationTime (sp35TrackEntry* entry) {
	if (entry->loop) {
		float duration = entry->animationEnd - entry->animationStart;
		if (duration == 0) return entry->animationStart;
		return FMOD(entry->trackTime, duration) + entry->animationStart;
	}
	return MIN(entry->trackTime + entry->animationStart, entry->animationEnd);
}

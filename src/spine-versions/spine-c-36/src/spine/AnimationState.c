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

#define SUBSEQUENT 0
#define FIRST 1
#define DIP 2
#define DIP_MIX 3

_SP_ARRAY_IMPLEMENT_TYPE(sp36TrackEntryArray, sp36TrackEntry*)

static sp36Animation* SP_EMPTY_ANIMATION = 0;
void sp36AnimationState_disposeStatics () {
	if (SP_EMPTY_ANIMATION) sp36Animation_dispose(SP_EMPTY_ANIMATION);
	SP_EMPTY_ANIMATION = 0;
}

/* Forward declaration of some "private" functions so we can keep
   the same function order in C as we have method order in Java */
void _sp36AnimationState_disposeTrackEntry (sp36TrackEntry* entry);
void _sp36AnimationState_disposeTrackEntries (sp36AnimationState* state, sp36TrackEntry* entry);
int /*boolean*/ _sp36AnimationState_updateMixingFrom (sp36AnimationState* self, sp36TrackEntry* entry, float delta);
float _sp36AnimationState_applyMixingFrom (sp36AnimationState* self, sp36TrackEntry* entry, sp36Skeleton* skeleton, sp36MixPose currentPose);
void _sp36AnimationState_applyRotateTimeline (sp36AnimationState* self, sp36Timeline* timeline, sp36Skeleton* skeleton, float time, float alpha, sp36MixPose pose, float* timelinesRotation, int i, int /*boolean*/ firstFrame);
void _sp36AnimationState_queueEvents (sp36AnimationState* self, sp36TrackEntry* entry, float animationTime);
void _sp36AnimationState_setCurrent (sp36AnimationState* self, int index, sp36TrackEntry* current, int /*boolean*/ interrupt);
sp36TrackEntry* _sp36AnimationState_expandToIndex (sp36AnimationState* self, int index);
sp36TrackEntry* _sp36AnimationState_trackEntry (sp36AnimationState* self, int trackIndex, sp36Animation* animation, int /*boolean*/ loop, sp36TrackEntry* last);
void _sp36AnimationState_disposeNext (sp36AnimationState* self, sp36TrackEntry* entry);
void _sp36AnimationState_animationsChanged (sp36AnimationState* self);
float* _sp36AnimationState_resizeTimelinesRotation(sp36TrackEntry* entry, int newSize);
int* _sp36AnimationState_resizeTimelinesFirst(sp36TrackEntry* entry, int newSize);
void _sp36AnimationState_ensureCapacityPropertyIDs(sp36AnimationState* self, int capacity);
int _sp36AnimationState_addPropertyID(sp36AnimationState* self, int id);
sp36TrackEntry* _sp36TrackEntry_setTimelineData(sp36TrackEntry* self, sp36TrackEntry* to, sp36TrackEntryArray* mixingToArray, sp36AnimationState* state);


_sp36EventQueue* _sp36EventQueue_create (_sp36AnimationState* state) {
	_sp36EventQueue *self = CALLOC(_sp36EventQueue, 1);
	self->state = state;
	self->objectsCount = 0;
	self->objectsCapacity = 16;
	self->objects = CALLOC(_sp36EventQueueItem, self->objectsCapacity);
	self->drainDisabled = 0;
	return self;
}

void _sp36EventQueue_free (_sp36EventQueue* self) {
	FREE(self->objects);
    FREE(self);
}

void _sp36EventQueue_ensureCapacity (_sp36EventQueue* self, int newElements) {
	if (self->objectsCount + newElements > self->objectsCapacity) {
		_sp36EventQueueItem* newObjects;
		self->objectsCapacity <<= 1;
		newObjects = CALLOC(_sp36EventQueueItem, self->objectsCapacity);
		memcpy(newObjects, self->objects, sizeof(_sp36EventQueueItem) * self->objectsCount);
		FREE(self->objects);
		self->objects = newObjects;
	}
}

void _sp36EventQueue_addType (_sp36EventQueue* self, sp36EventType type) {
	_sp36EventQueue_ensureCapacity(self, 1);
	self->objects[self->objectsCount++].type = type;
}

void _sp36EventQueue_addEntry (_sp36EventQueue* self, sp36TrackEntry* entry) {
	_sp36EventQueue_ensureCapacity(self, 1);
	self->objects[self->objectsCount++].entry = entry;
}

void _sp36EventQueue_addEvent (_sp36EventQueue* self, sp36Event* event) {
	_sp36EventQueue_ensureCapacity(self, 1);
	self->objects[self->objectsCount++].event = event;
}

void _sp36EventQueue_start (_sp36EventQueue* self, sp36TrackEntry* entry) {
	_sp36EventQueue_addType(self, SP_ANIMATION_START);
	_sp36EventQueue_addEntry(self, entry);
	self->state->animationsChanged = 1;
}

void _sp36EventQueue_interrupt (_sp36EventQueue* self, sp36TrackEntry* entry) {
	_sp36EventQueue_addType(self, SP_ANIMATION_INTERRUPT);
	_sp36EventQueue_addEntry(self, entry);
}

void _sp36EventQueue_end (_sp36EventQueue* self, sp36TrackEntry* entry) {
	_sp36EventQueue_addType(self, SP_ANIMATION_END);
	_sp36EventQueue_addEntry(self, entry);
	self->state->animationsChanged = 1;
}

void _sp36EventQueue_dispose (_sp36EventQueue* self, sp36TrackEntry* entry) {
	_sp36EventQueue_addType(self, SP_ANIMATION_DISPOSE);
	_sp36EventQueue_addEntry(self, entry);
}

void _sp36EventQueue_complete (_sp36EventQueue* self, sp36TrackEntry* entry) {
	_sp36EventQueue_addType(self, SP_ANIMATION_COMPLETE);
	_sp36EventQueue_addEntry(self, entry);
}

void _sp36EventQueue_event (_sp36EventQueue* self, sp36TrackEntry* entry, sp36Event* event) {
	_sp36EventQueue_addType(self, SP_ANIMATION_EVENT);
	_sp36EventQueue_addEntry(self, entry);
	_sp36EventQueue_addEvent(self, event);
}

void _sp36EventQueue_clear (_sp36EventQueue* self) {
	self->objectsCount = 0;
}

void _sp36EventQueue_drain (_sp36EventQueue* self) {
	int i;
	if (self->drainDisabled) return;
	self->drainDisabled = 1;
	for (i = 0; i < self->objectsCount; i += 2) {
		sp36EventType type = (sp36EventType)self->objects[i].type;
		sp36TrackEntry* entry = self->objects[i+1].entry;
		sp36Event* event;
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
				_sp36AnimationState_disposeTrackEntry(entry);
				break;
			case SP_ANIMATION_EVENT:
				event = self->objects[i+2].event;
				if (entry->listener) entry->listener(SUPER(self->state), type, entry, event);
				if (self->state->super.listener) self->state->super.listener(SUPER(self->state), type, entry, event);
				i++;
				break;
		}
	}
	_sp36EventQueue_clear(self);

	self->drainDisabled = 0;
}

/* These two functions are needed in the UE4 runtime, see #1037 */
void _sp36AnimationState_enableQueue(sp36AnimationState* self) {
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);
	internal->queue->drainDisabled = 0;
}

void _sp36AnimationState_disableQueue(sp36AnimationState* self) {
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);
	internal->queue->drainDisabled = 1;
}

void _sp36AnimationState_disposeTrackEntry (sp36TrackEntry* entry) {
	sp36IntArray_dispose(entry->timelineData);
	sp36TrackEntryArray_dispose(entry->timelineDipMix);
	FREE(entry->timelinesRotation);
	FREE(entry);
}

void _sp36AnimationState_disposeTrackEntries (sp36AnimationState* state, sp36TrackEntry* entry) {
	while (entry) {
		sp36TrackEntry* next = entry->next;
		sp36TrackEntry* from = entry->mixingFrom;
		while (from) {
			sp36TrackEntry* nextFrom = from->mixingFrom;
			if (entry->listener) entry->listener(state, SP_ANIMATION_DISPOSE, from, 0);
			if (state->listener) state->listener(state, SP_ANIMATION_DISPOSE, from, 0);
			_sp36AnimationState_disposeTrackEntry(from);
			from = nextFrom;
		}
		if (entry->listener) entry->listener(state, SP_ANIMATION_DISPOSE, entry, 0);
		if (state->listener) state->listener(state, SP_ANIMATION_DISPOSE, entry, 0);
		_sp36AnimationState_disposeTrackEntry(entry);
		entry = next;
	}
}

sp36AnimationState* sp36AnimationState_create (sp36AnimationStateData* data) {
	_sp36AnimationState* internal;
	sp36AnimationState* self;

	if (!SP_EMPTY_ANIMATION) {
		SP_EMPTY_ANIMATION = (sp36Animation*)1; /* dirty trick so we can recursively call sp36Animation_create */
		SP_EMPTY_ANIMATION = sp36Animation_create("<empty>", 0);
	}

	internal = NEW(_sp36AnimationState);
	self = SUPER(internal);

	CONST_CAST(sp36AnimationStateData*, self->data) = data;
	self->timeScale = 1;

	internal->queue = _sp36EventQueue_create(internal);
	internal->events = CALLOC(sp36Event*, 128);

	internal->propertyIDs = CALLOC(int, 128);
	internal->propertyIDsCapacity = 128;

	self->mixingTo = sp36TrackEntryArray_create(16);

	return self;
}

void sp36AnimationState_dispose (sp36AnimationState* self) {
	int i;
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);
	for (i = 0; i < self->tracksCount; i++)
		_sp36AnimationState_disposeTrackEntries(self, self->tracks[i]);
	FREE(self->tracks);
	_sp36EventQueue_free(internal->queue);
	FREE(internal->events);
	FREE(internal->propertyIDs);
	sp36TrackEntryArray_dispose(self->mixingTo);
    FREE(internal);
}

void sp36AnimationState_update (sp36AnimationState* self, float delta) {
	int i, n;
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);
	delta *= self->timeScale;
	for (i = 0, n = self->tracksCount; i < n; i++) {
		float currentDelta;
		sp36TrackEntry* current = self->tracks[i];
		sp36TrackEntry* next;
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
				_sp36AnimationState_setCurrent(self, i, next, 1);
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
				_sp36EventQueue_end(internal->queue, current);
				_sp36AnimationState_disposeNext(self, current);
				continue;
			}
		}
		if (current->mixingFrom != 0 && _sp36AnimationState_updateMixingFrom(self, current, delta)) {
			/* End mixing from entries once all have completed. */
			sp36TrackEntry* from = current->mixingFrom;
			current->mixingFrom = 0;
			while (from != 0) {
				_sp36EventQueue_end(internal->queue, from);
				from = from->mixingFrom;
			}
		}

		current->trackTime += currentDelta;
	}

	_sp36EventQueue_drain(internal->queue);
}

int /*boolean*/ _sp36AnimationState_updateMixingFrom (sp36AnimationState* self, sp36TrackEntry* to, float delta) {
	sp36TrackEntry* from = to->mixingFrom;
	int finished;
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);
	if (!from) return -1;

	finished = _sp36AnimationState_updateMixingFrom(self, from, delta);

	from->animationLast = from->nextAnimationLast;
	from->trackLast = from->nextTrackLast;

	/* Require mixTime > 0 to ensure the mixing from entry was applied at least once. */
	if (to->mixTime > 0 && (to->mixTime >= to->mixDuration || to->timeScale == 0)) {
		/* Require totalAlpha == 0 to ensure mixing is complete, unless mixDuration == 0 (the transition is a single frame). */
		if (from->totalAlpha == 0 || to->mixDuration == 0) {
			to->mixingFrom = from->mixingFrom;
			to->interruptAlpha = from->interruptAlpha;
			_sp36EventQueue_end(internal->queue, from);
		}
		return finished;
	}

	from->trackTime += delta * from->timeScale;
	to->mixTime += delta * to->timeScale;
	return 0;
}

int sp36AnimationState_apply (sp36AnimationState* self, sp36Skeleton* skeleton) {
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);
	sp36TrackEntry* current;
	int i, ii, n;
	float animationLast, animationTime;
	int timelineCount;
	sp36Timeline** timelines;
	int /*boolean*/ firstFrame;
	float* timelinesRotation;
	sp36Timeline* timeline;
	int applied = 0;
	sp36MixPose currentPose;
	sp36MixPose pose;

	if (internal->animationsChanged) _sp36AnimationState_animationsChanged(self);

	for (i = 0, n = self->tracksCount; i < n; i++) {
		float mix;
		current = self->tracks[i];
		if (!current || current->delay > 0) continue;
		applied = -1;
		currentPose = i == 0 ? SP_MIX_POSE_CURRENT : SP_MIX_POSE_CURRENT_LAYERED;

		/* Apply mixing from entries first. */
		mix = current->alpha;
		if (current->mixingFrom)
            mix *= _sp36AnimationState_applyMixingFrom(self, current, skeleton, currentPose);
        else if (current->trackTime >= current->trackEnd && current->next == 0)
            mix = 0;

		/* Apply current entry. */
		animationLast = current->animationLast; animationTime = sp36TrackEntry_getAnimationTime(current);
		timelineCount = current->animation->timelinesCount;
		timelines = current->animation->timelines;
		if (mix == 1) {
			for (ii = 0; ii < timelineCount; ii++)
				sp36Timeline_apply(timelines[ii], skeleton, animationLast, animationTime, internal->events, &internal->eventsCount, 1, SP_MIX_POSE_SETUP, SP_MIX_DIRECTION_IN);
		} else {
			sp36IntArray* timelineData = current->timelineData;

			firstFrame = current->timelinesRotationCount == 0;
			if (firstFrame) _sp36AnimationState_resizeTimelinesRotation(current, timelineCount << 1);
			timelinesRotation = current->timelinesRotation;

			for (ii = 0; ii < timelineCount; ii++) {
				timeline = timelines[ii];
				pose = timelineData->items[ii] >= FIRST ? SP_MIX_POSE_SETUP : currentPose;
				if (timeline->type == SP_TIMELINE_ROTATE)
					_sp36AnimationState_applyRotateTimeline(self, timeline, skeleton, animationTime, mix, pose, timelinesRotation, ii << 1, firstFrame);
				else
					sp36Timeline_apply(timeline, skeleton, animationLast, animationTime, internal->events, &internal->eventsCount, mix, pose, SP_MIX_DIRECTION_IN);
			}
		}
		_sp36AnimationState_queueEvents(self, current, animationTime);
		internal->eventsCount = 0;
		current->nextAnimationLast = animationTime;
		current->nextTrackLast = current->trackTime;
	}

	_sp36EventQueue_drain(internal->queue);
	return applied;
}

float _sp36AnimationState_applyMixingFrom (sp36AnimationState* self, sp36TrackEntry* to, sp36Skeleton* skeleton, sp36MixPose currentPose) {
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);
	float mix;
	sp36Event** events;
	int /*boolean*/ attachments;
	int /*boolean*/ drawOrder;
	float animationLast;
	float animationTime;
	int timelineCount;
	sp36Timeline** timelines;
	sp36IntArray* timelineData;
	sp36TrackEntryArray* timelineDipMix;
	float alphaDip;
	float alphaMix;
	float alpha;
	int /*boolean*/ firstFrame;
	float* timelinesRotation;
	sp36MixPose pose;
	int i;
	sp36TrackEntry* dipMix;

	sp36TrackEntry* from = to->mixingFrom;
	if (from->mixingFrom) _sp36AnimationState_applyMixingFrom(self, from, skeleton, currentPose);

	if (to->mixDuration == 0) { /* Single frame mix to undo mixingFrom changes. */
		mix = 1;
		currentPose = SP_MIX_POSE_SETUP;
	} else {
		mix = to->mixTime / to->mixDuration;
		if (mix > 1) mix = 1;
	}

	events = mix < from->eventThreshold ? internal->events : 0;
	attachments = mix < from->attachmentThreshold;
	drawOrder = mix < from->drawOrderThreshold;
	animationLast = from->animationLast;
	animationTime = sp36TrackEntry_getAnimationTime(from);
	timelineCount = from->animation->timelinesCount;
	timelines = from->animation->timelines;
	timelineData = from->timelineData;
	timelineDipMix = from->timelineDipMix;

	firstFrame = from->timelinesRotationCount == 0;
	if (firstFrame) _sp36AnimationState_resizeTimelinesRotation(from, timelineCount << 1);
	timelinesRotation = from->timelinesRotation;

	alphaDip = from->alpha * to->interruptAlpha; alphaMix = alphaDip * (1 - mix);
	from->totalAlpha = 0;
	for (i = 0; i < timelineCount; i++) {
		sp36Timeline* timeline = timelines[i];
		switch (timelineData->items[i]) {
			case SUBSEQUENT:
				if (!attachments && timeline->type == SP_TIMELINE_ATTACHMENT) continue;
				if (!drawOrder && timeline->type == SP_TIMELINE_DRAWORDER) continue;
				pose = currentPose;
				alpha = alphaMix;
				break;
			case FIRST:
				pose = SP_MIX_POSE_SETUP;
				alpha = alphaMix;
				break;
			case DIP:
				pose = SP_MIX_POSE_SETUP;
				alpha = alphaDip;
				break;
			default:
				pose = SP_MIX_POSE_SETUP;
				alpha = alphaDip;
				dipMix = timelineDipMix->items[i];
				alpha *= MAX(0, 1 - dipMix->mixTime / dipMix->mixDuration);
				break;
		}
		from->totalAlpha += alpha;
		if (timeline->type == SP_TIMELINE_ROTATE)
			_sp36AnimationState_applyRotateTimeline(self, timeline, skeleton, animationTime, alpha, pose, timelinesRotation, i << 1, firstFrame);
		else {
			sp36Timeline_apply(timeline, skeleton, animationLast, animationTime, events, &internal->eventsCount, alpha, pose, SP_MIX_DIRECTION_OUT);
		}
	}


	if (to->mixDuration > 0) _sp36AnimationState_queueEvents(self, from, animationTime);
	internal->eventsCount = 0;
	from->nextAnimationLast = animationTime;
	from->nextTrackLast = from->trackTime;

	return mix;
}

void _sp36AnimationState_applyRotateTimeline (sp36AnimationState* self, sp36Timeline* timeline, sp36Skeleton* skeleton, float time, float alpha, sp36MixPose pose, float* timelinesRotation, int i, int /*boolean*/ firstFrame) {
	sp36RotateTimeline *rotateTimeline;
	float *frames;
	sp36Bone* bone;
	float r1, r2;
	int frame;
	float prevRotation;
	float frameTime;
	float percent;
	float total, diff;
	int /*boolean*/ current, dir;

	if (firstFrame) timelinesRotation[i] = 0;

	if (alpha == 1) {
		sp36Timeline_apply(timeline, skeleton, 0, time, 0, 0, 1, pose, SP_MIX_DIRECTION_IN);
		return;
	}

	rotateTimeline = SUB_CAST(sp36RotateTimeline, timeline);
	frames = rotateTimeline->frames;
	bone = skeleton->bones[rotateTimeline->boneIndex];
	if (time < frames[0]) {
		if (pose == SP_MIX_POSE_SETUP) {
			bone->rotation = bone->data->rotation;
		}
		return; /* Time is before first frame. */
	}

	if (time >= frames[rotateTimeline->framesCount - ROTATE_ENTRIES]) /* Time is after last frame. */
		r2 = bone->data->rotation + frames[rotateTimeline->framesCount + ROTATE_PREV_ROTATION];
	else {
		/* Interpolate between the previous frame and the current frame. */
		frame = _sp36CurveTimeline_binarySearch(frames, rotateTimeline->framesCount, time, ROTATE_ENTRIES);
		prevRotation = frames[frame + ROTATE_PREV_ROTATION];
		frameTime = frames[frame];
		percent = sp36CurveTimeline_getCurvePercent(SUPER(rotateTimeline), (frame >> 1) - 1,
													   1 - (time - frameTime) / (frames[frame + ROTATE_PREV_TIME] - frameTime));

		r2 = frames[frame + ROTATE_ROTATION] - prevRotation;
		r2 -= (16384 - (int)(16384.499999999996 - r2 / 360)) * 360;
		r2 = prevRotation + r2 * percent + bone->data->rotation;
		r2 -= (16384 - (int)(16384.499999999996 - r2 / 360)) * 360;
	}

	/* Mix between rotations using the direction of the shortest route on the first frame while detecting crosses. */
	r1 = pose == SP_MIX_POSE_SETUP ? bone->data->rotation : bone->rotation;
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

void _sp36AnimationState_queueEvents (sp36AnimationState* self, sp36TrackEntry* entry, float animationTime) {
	sp36Event** events;
	sp36Event* event;
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);
	int i, n, complete;
	float animationStart = entry->animationStart, animationEnd = entry->animationEnd;
	float duration = animationEnd - animationStart;
	float trackLastWrapped = FMOD(entry->trackLast, duration);

	/* Queue events before complete. */
	events = internal->events;
	for (i = 0, n = internal->eventsCount; i < n; i++) {
		event = events[i];
		if (event->time < trackLastWrapped) break;
		if (event->time > animationEnd) continue; /* Discard events outside animation start/end. */
		_sp36EventQueue_event(internal->queue, entry, event);
	}

	/* Queue complete if completed a loop iteration or the animation. */
	if (entry->loop)
		complete = duration == 0 || (trackLastWrapped > FMOD(entry->trackTime, duration));
	else
		complete = (animationTime >= animationEnd && entry->animationLast < animationEnd);
	if (complete) _sp36EventQueue_complete(internal->queue, entry);

	/* Queue events after complete. */
	for (; i < n; i++) {
		event = events[i];
		if (event->time < animationStart) continue; /* Discard events outside animation start/end. */
		_sp36EventQueue_event(internal->queue, entry, event);
	}
}

void sp36AnimationState_clearTracks (sp36AnimationState* self) {
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);
	int i, n, oldDrainDisabled;
	oldDrainDisabled = internal->queue->drainDisabled;
	internal->queue->drainDisabled = 1;
	for (i = 0, n = self->tracksCount; i < n; i++)
		sp36AnimationState_clearTrack(self, i);
	self->tracksCount = 0;
	internal->queue->drainDisabled = oldDrainDisabled;
	_sp36EventQueue_drain(internal->queue);
}

void sp36AnimationState_clearTrack (sp36AnimationState* self, int trackIndex) {
	sp36TrackEntry* current;
	sp36TrackEntry* entry;
	sp36TrackEntry* from;
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);

	if (trackIndex >= self->tracksCount) return;
	current = self->tracks[trackIndex];
	if (!current) return;

	_sp36EventQueue_end(internal->queue, current);

	_sp36AnimationState_disposeNext(self, current);

	entry = current;
	while (1) {
		from = entry->mixingFrom;
		if (!from) break;
		_sp36EventQueue_end(internal->queue, from);
		entry->mixingFrom = 0;
		entry = from;
	}

	self->tracks[current->trackIndex] = 0;
	_sp36EventQueue_drain(internal->queue);
}

void _sp36AnimationState_setCurrent (sp36AnimationState* self, int index, sp36TrackEntry* current, int /*boolean*/ interrupt) {
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);
	sp36TrackEntry* from = _sp36AnimationState_expandToIndex(self, index);
	self->tracks[index] = current;

	if (from) {
		if (interrupt) _sp36EventQueue_interrupt(internal->queue, from);
		current->mixingFrom = from;
		current->mixTime = 0;

		/* Store the interrupted mix percentage. */
		if (from->mixingFrom != 0 && from->mixDuration > 0)
			current->interruptAlpha *= MIN(1, from->mixTime / from->mixDuration);

		from->timelinesRotationCount = 0;
	}

	_sp36EventQueue_start(internal->queue, current);
}

/** Set the current animation. Any queued animations are cleared. */
sp36TrackEntry* sp36AnimationState_setAnimationByName (sp36AnimationState* self, int trackIndex, const char* animationName,
												   int/*bool*/loop) {
	sp36Animation* animation = sp36SkeletonData_findAnimation(self->data->skeletonData, animationName);
	return sp36AnimationState_setAnimation(self, trackIndex, animation, loop);
}

sp36TrackEntry* sp36AnimationState_setAnimation (sp36AnimationState* self, int trackIndex, sp36Animation* animation, int/*bool*/loop) {
	sp36TrackEntry* entry;
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);
	int interrupt = 1;
	sp36TrackEntry* current = _sp36AnimationState_expandToIndex(self, trackIndex);
	if (current) {
		if (current->nextTrackLast == -1) {
			/* Don't mix from an entry that was never applied. */
			self->tracks[trackIndex] = current->mixingFrom;
			_sp36EventQueue_interrupt(internal->queue, current);
			_sp36EventQueue_end(internal->queue, current);
			_sp36AnimationState_disposeNext(self, current);
			current = current->mixingFrom;
			interrupt = 0;
		} else
			_sp36AnimationState_disposeNext(self, current);
	}
	entry = _sp36AnimationState_trackEntry(self, trackIndex, animation, loop, current);
	_sp36AnimationState_setCurrent(self, trackIndex, entry, interrupt);
	_sp36EventQueue_drain(internal->queue);
	return entry;
}

/** Adds an animation to be played delay seconds after the current or last queued animation, taking into account any mix
 * duration. */
sp36TrackEntry* sp36AnimationState_addAnimationByName (sp36AnimationState* self, int trackIndex, const char* animationName,
												   int/*bool*/loop, float delay) {
	sp36Animation* animation = sp36SkeletonData_findAnimation(self->data->skeletonData, animationName);
	return sp36AnimationState_addAnimation(self, trackIndex, animation, loop, delay);
}

sp36TrackEntry* sp36AnimationState_addAnimation (sp36AnimationState* self, int trackIndex, sp36Animation* animation, int/*bool*/loop,
											 float delay) {
	sp36TrackEntry* entry;
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);
	sp36TrackEntry* last = _sp36AnimationState_expandToIndex(self, trackIndex);
	if (last) {
		while (last->next)
			last = last->next;
	}

	entry = _sp36AnimationState_trackEntry(self, trackIndex, animation, loop, last);

	if (!last) {
		_sp36AnimationState_setCurrent(self, trackIndex, entry, 1);
		_sp36EventQueue_drain(internal->queue);
	} else {
		last->next = entry;
		if (delay <= 0) {
			float duration = last->animationEnd - last->animationStart;
			if (duration != 0) {
				if (last->loop) {
					delay += duration * (1 + (int) (last->trackTime / duration));
				} else {
					delay += duration;
				}
				delay -= sp36AnimationStateData_getMix(self->data, last->animation, animation);
			} else
				delay = 0;
		}
	}

	entry->delay = delay;
	return entry;
}

sp36TrackEntry* sp36AnimationState_setEmptyAnimation(sp36AnimationState* self, int trackIndex, float mixDuration) {
	sp36TrackEntry* entry = sp36AnimationState_setAnimation(self, trackIndex, SP_EMPTY_ANIMATION, 0);
	entry->mixDuration = mixDuration;
	entry->trackEnd = mixDuration;
	return entry;
}

sp36TrackEntry* sp36AnimationState_addEmptyAnimation(sp36AnimationState* self, int trackIndex, float mixDuration, float delay) {
	sp36TrackEntry* entry;
	if (delay <= 0) delay -= mixDuration;
	entry = sp36AnimationState_addAnimation(self, trackIndex, SP_EMPTY_ANIMATION, 0, delay);
	entry->mixDuration = mixDuration;
	entry->trackEnd = mixDuration;
	return entry;
}

void sp36AnimationState_setEmptyAnimations(sp36AnimationState* self, float mixDuration) {
	int i, n, oldDrainDisabled;
	sp36TrackEntry* current;
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);
	oldDrainDisabled = internal->queue->drainDisabled;
	internal->queue->drainDisabled = 1;
	for (i = 0, n = self->tracksCount; i < n; i++) {
		current = self->tracks[i];
		if (current) sp36AnimationState_setEmptyAnimation(self, current->trackIndex, mixDuration);
	}
	internal->queue->drainDisabled = oldDrainDisabled;
	_sp36EventQueue_drain(internal->queue);
}

sp36TrackEntry* _sp36AnimationState_expandToIndex (sp36AnimationState* self, int index) {
	sp36TrackEntry** newTracks;
	if (index < self->tracksCount) return self->tracks[index];
	newTracks = CALLOC(sp36TrackEntry*, index + 1);
	memcpy(newTracks, self->tracks, self->tracksCount * sizeof(sp36TrackEntry*));
	FREE(self->tracks);
	self->tracks = newTracks;
	self->tracksCount = index + 1;
	return 0;
}

sp36TrackEntry* _sp36AnimationState_trackEntry (sp36AnimationState* self, int trackIndex, sp36Animation* animation, int /*boolean*/ loop, sp36TrackEntry* last) {
	sp36TrackEntry* entry = NEW(sp36TrackEntry);
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
	entry->interruptAlpha = 1;
	entry->mixTime = 0;
	entry->mixDuration = !last ? 0 : sp36AnimationStateData_getMix(self->data, last->animation, animation);

	entry->timelineData = sp36IntArray_create(16);
	entry->timelineDipMix = sp36TrackEntryArray_create(16);
	return entry;
}

void _sp36AnimationState_disposeNext (sp36AnimationState* self, sp36TrackEntry* entry) {
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);
	sp36TrackEntry* next = entry->next;
	while (next) {
		_sp36EventQueue_dispose(internal->queue, next);
		next = next->next;
	}
	entry->next = 0;
}

void _sp36AnimationState_animationsChanged (sp36AnimationState* self) {
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);
	int i, n;
	sp36TrackEntry* entry;
	sp36TrackEntryArray* mixingTo;
	internal->animationsChanged = 0;

	internal->propertyIDsCount = 0;
	i = 0; n = self->tracksCount;

	mixingTo = self->mixingTo;

	for (;i < n; i++) {
		entry = self->tracks[i];
		if (entry != 0) _sp36TrackEntry_setTimelineData(entry, 0, mixingTo, self);
	}
}

float* _sp36AnimationState_resizeTimelinesRotation(sp36TrackEntry* entry, int newSize) {
	if (entry->timelinesRotationCount != newSize) {
		float* newTimelinesRotation = CALLOC(float, newSize);
		FREE(entry->timelinesRotation);
		entry->timelinesRotation = newTimelinesRotation;
		entry->timelinesRotationCount = newSize;
	}
	return entry->timelinesRotation;
}

void _sp36AnimationState_ensureCapacityPropertyIDs(sp36AnimationState* self, int capacity) {
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);
	if (internal->propertyIDsCapacity < capacity) {
		int *newPropertyIDs = CALLOC(int, capacity << 1);
		memcpy(newPropertyIDs, internal->propertyIDs, sizeof(int) * internal->propertyIDsCount);
		FREE(internal->propertyIDs);
		internal->propertyIDs = newPropertyIDs;
		internal->propertyIDsCapacity = capacity << 1;
	}
}

int _sp36AnimationState_addPropertyID(sp36AnimationState* self, int id) {
	int i, n;
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);

	for (i = 0, n = internal->propertyIDsCount; i < n; i++) {
		if (internal->propertyIDs[i] == id) return 0;
	}

	_sp36AnimationState_ensureCapacityPropertyIDs(self, internal->propertyIDsCount + 1);
	internal->propertyIDs[internal->propertyIDsCount] = id;
	internal->propertyIDsCount++;
	return 1;
}

sp36TrackEntry* sp36AnimationState_getCurrent (sp36AnimationState* self, int trackIndex) {
	if (trackIndex >= self->tracksCount) return 0;
	return self->tracks[trackIndex];
}

void sp36AnimationState_clearListenerNotifications(sp36AnimationState* self) {
	_sp36AnimationState* internal = SUB_CAST(_sp36AnimationState, self);
	_sp36EventQueue_clear(internal->queue);
}

float sp36TrackEntry_getAnimationTime (sp36TrackEntry* entry) {
	if (entry->loop) {
		float duration = entry->animationEnd - entry->animationStart;
		if (duration == 0) return entry->animationStart;
		return FMOD(entry->trackTime, duration) + entry->animationStart;
	}
	return MIN(entry->trackTime + entry->animationStart, entry->animationEnd);
}

int /*boolean*/ _sp36TrackEntry_hasTimeline(sp36TrackEntry* self, int id) {
	sp36Timeline** timelines = self->animation->timelines;
	int i, n;
	for (i = 0, n = self->animation->timelinesCount; i < n; i++)
		if (sp36Timeline_getPropertyId(timelines[i]) == id) return 1;
	return 0;
}

sp36TrackEntry* _sp36TrackEntry_setTimelineData(sp36TrackEntry* self, sp36TrackEntry* to, sp36TrackEntryArray* mixingToArray, sp36AnimationState* state) {
	sp36TrackEntry* lastEntry;
	sp36TrackEntry** mixingTo;
	int mixingToLast;
	sp36Timeline** timelines;
	int timelinesCount;
	int* timelineData;
	sp36TrackEntry** timelineDipMix;
	int i, ii;

	if (to != 0) sp36TrackEntryArray_add(mixingToArray, to);
	lastEntry = self->mixingFrom != 0 ? _sp36TrackEntry_setTimelineData(self->mixingFrom, self, mixingToArray, state) : self;
	if (to != 0) sp36TrackEntryArray_pop(mixingToArray);

	mixingTo = mixingToArray->items;
	mixingToLast = mixingToArray->size - 1;
	timelines = self->animation->timelines;
	timelinesCount = self->animation->timelinesCount;
	timelineData = sp36IntArray_setSize(self->timelineData, timelinesCount)->items;
	sp36TrackEntryArray_clear(self->timelineDipMix);
	timelineDipMix = sp36TrackEntryArray_setSize(self->timelineDipMix, timelinesCount)->items;

	i = 0;
	continue_outer:
	for (; i < timelinesCount; i++) {
		int id = sp36Timeline_getPropertyId(timelines[i]);
		if (!_sp36AnimationState_addPropertyID(state, id))
			timelineData[i] = SUBSEQUENT;
		else if (to == 0 || !_sp36TrackEntry_hasTimeline(to, id))
			timelineData[i] = FIRST;
		else {
			for (ii = mixingToLast; ii >= 0; ii--) {
				sp36TrackEntry* entry = mixingTo[ii];
				if (!_sp36TrackEntry_hasTimeline(entry, id)) {
					if (entry->mixDuration > 0) {
						timelineData[i] = DIP_MIX;
						timelineDipMix[i] = entry;
						i++;
						goto continue_outer;
					}
				}
				break;
			}
			timelineData[i] = DIP;
		}
	}
	return lastEntry;
}

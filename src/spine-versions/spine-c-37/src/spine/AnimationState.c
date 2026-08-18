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

#include <spine/AnimationState.h>
#include <spine/extension.h>
#include <limits.h>

#define SUBSEQUENT 0
#define FIRST 1
#define HOLD 2
#define HOLD_MIX 3

_SP_ARRAY_IMPLEMENT_TYPE(sp37TrackEntryArray, sp37TrackEntry*)

static sp37Animation* SP_EMPTY_ANIMATION = 0;
void sp37AnimationState_disposeStatics () {
	if (SP_EMPTY_ANIMATION) sp37Animation_dispose(SP_EMPTY_ANIMATION);
	SP_EMPTY_ANIMATION = 0;
}

/* Forward declaration of some "private" functions so we can keep
   the same function order in C as we have method order in Java */
void _sp37AnimationState_disposeTrackEntry (sp37TrackEntry* entry);
void _sp37AnimationState_disposeTrackEntries (sp37AnimationState* state, sp37TrackEntry* entry);
int /*boolean*/ _sp37AnimationState_updateMixingFrom (sp37AnimationState* self, sp37TrackEntry* entry, float delta);
float _sp37AnimationState_applyMixingFrom (sp37AnimationState* self, sp37TrackEntry* entry, sp37Skeleton* skeleton, sp37MixBlend currentBlend);
void _sp37AnimationState_applyRotateTimeline (sp37AnimationState* self, sp37Timeline* timeline, sp37Skeleton* skeleton, float time, float alpha, sp37MixBlend blend, float* timelinesRotation, int i, int /*boolean*/ firstFrame);
void _sp37AnimationState_queueEvents (sp37AnimationState* self, sp37TrackEntry* entry, float animationTime);
void _sp37AnimationState_setCurrent (sp37AnimationState* self, int index, sp37TrackEntry* current, int /*boolean*/ interrupt);
sp37TrackEntry* _sp37AnimationState_expandToIndex (sp37AnimationState* self, int index);
sp37TrackEntry* _sp37AnimationState_trackEntry (sp37AnimationState* self, int trackIndex, sp37Animation* animation, int /*boolean*/ loop, sp37TrackEntry* last);
void _sp37AnimationState_disposeNext (sp37AnimationState* self, sp37TrackEntry* entry);
void _sp37AnimationState_animationsChanged (sp37AnimationState* self);
float* _sp37AnimationState_resizeTimelinesRotation(sp37TrackEntry* entry, int newSize);
int* _sp37AnimationState_resizeTimelinesFirst(sp37TrackEntry* entry, int newSize);
void _sp37AnimationState_ensureCapacityPropertyIDs(sp37AnimationState* self, int capacity);
int _sp37AnimationState_addPropertyID(sp37AnimationState* self, int id);
void _sp37TrackEntry_setTimelineData(sp37TrackEntry* self, sp37AnimationState* state);


_sp37EventQueue* _sp37EventQueue_create (_sp37AnimationState* state) {
	_sp37EventQueue *self = CALLOC(_sp37EventQueue, 1);
	self->state = state;
	self->objectsCount = 0;
	self->objectsCapacity = 16;
	self->objects = CALLOC(_sp37EventQueueItem, self->objectsCapacity);
	self->drainDisabled = 0;
	return self;
}

void _sp37EventQueue_free (_sp37EventQueue* self) {
	FREE(self->objects);
    FREE(self);
}

void _sp37EventQueue_ensureCapacity (_sp37EventQueue* self, int newElements) {
	if (self->objectsCount + newElements > self->objectsCapacity) {
		_sp37EventQueueItem* newObjects;
		self->objectsCapacity <<= 1;
		newObjects = CALLOC(_sp37EventQueueItem, self->objectsCapacity);
		memcpy(newObjects, self->objects, sizeof(_sp37EventQueueItem) * self->objectsCount);
		FREE(self->objects);
		self->objects = newObjects;
	}
}

void _sp37EventQueue_addType (_sp37EventQueue* self, sp37EventType type) {
	_sp37EventQueue_ensureCapacity(self, 1);
	self->objects[self->objectsCount++].type = type;
}

void _sp37EventQueue_addEntry (_sp37EventQueue* self, sp37TrackEntry* entry) {
	_sp37EventQueue_ensureCapacity(self, 1);
	self->objects[self->objectsCount++].entry = entry;
}

void _sp37EventQueue_addEvent (_sp37EventQueue* self, sp37Event* event) {
	_sp37EventQueue_ensureCapacity(self, 1);
	self->objects[self->objectsCount++].event = event;
}

void _sp37EventQueue_start (_sp37EventQueue* self, sp37TrackEntry* entry) {
	_sp37EventQueue_addType(self, SP_ANIMATION_START);
	_sp37EventQueue_addEntry(self, entry);
	self->state->animationsChanged = 1;
}

void _sp37EventQueue_interrupt (_sp37EventQueue* self, sp37TrackEntry* entry) {
	_sp37EventQueue_addType(self, SP_ANIMATION_INTERRUPT);
	_sp37EventQueue_addEntry(self, entry);
}

void _sp37EventQueue_end (_sp37EventQueue* self, sp37TrackEntry* entry) {
	_sp37EventQueue_addType(self, SP_ANIMATION_END);
	_sp37EventQueue_addEntry(self, entry);
	self->state->animationsChanged = 1;
}

void _sp37EventQueue_dispose (_sp37EventQueue* self, sp37TrackEntry* entry) {
	_sp37EventQueue_addType(self, SP_ANIMATION_DISPOSE);
	_sp37EventQueue_addEntry(self, entry);
}

void _sp37EventQueue_complete (_sp37EventQueue* self, sp37TrackEntry* entry) {
	_sp37EventQueue_addType(self, SP_ANIMATION_COMPLETE);
	_sp37EventQueue_addEntry(self, entry);
}

void _sp37EventQueue_event (_sp37EventQueue* self, sp37TrackEntry* entry, sp37Event* event) {
	_sp37EventQueue_addType(self, SP_ANIMATION_EVENT);
	_sp37EventQueue_addEntry(self, entry);
	_sp37EventQueue_addEvent(self, event);
}

void _sp37EventQueue_clear (_sp37EventQueue* self) {
	self->objectsCount = 0;
}

void _sp37EventQueue_drain (_sp37EventQueue* self) {
	int i;
	if (self->drainDisabled) return;
	self->drainDisabled = 1;
	for (i = 0; i < self->objectsCount; i += 2) {
		sp37EventType type = (sp37EventType)self->objects[i].type;
		sp37TrackEntry* entry = self->objects[i+1].entry;
		sp37Event* event;
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
				_sp37AnimationState_disposeTrackEntry(entry);
				break;
			case SP_ANIMATION_EVENT:
				event = self->objects[i+2].event;
				if (entry->listener) entry->listener(SUPER(self->state), type, entry, event);
				if (self->state->super.listener) self->state->super.listener(SUPER(self->state), type, entry, event);
				i++;
				break;
		}
	}
	_sp37EventQueue_clear(self);

	self->drainDisabled = 0;
}

/* These two functions are needed in the UE4 runtime, see #1037 */
void _sp37AnimationState_enableQueue(sp37AnimationState* self) {
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);
	internal->queue->drainDisabled = 0;
}

void _sp37AnimationState_disableQueue(sp37AnimationState* self) {
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);
	internal->queue->drainDisabled = 1;
}

void _sp37AnimationState_disposeTrackEntry (sp37TrackEntry* entry) {
	sp37IntArray_dispose(entry->timelineMode);
	sp37TrackEntryArray_dispose(entry->timelineHoldMix);
	FREE(entry->timelinesRotation);
	FREE(entry);
}

void _sp37AnimationState_disposeTrackEntries (sp37AnimationState* state, sp37TrackEntry* entry) {
	while (entry) {
		sp37TrackEntry* next = entry->next;
		sp37TrackEntry* from = entry->mixingFrom;
		while (from) {
			sp37TrackEntry* nextFrom = from->mixingFrom;
			if (entry->listener) entry->listener(state, SP_ANIMATION_DISPOSE, from, 0);
			if (state->listener) state->listener(state, SP_ANIMATION_DISPOSE, from, 0);
			_sp37AnimationState_disposeTrackEntry(from);
			from = nextFrom;
		}
		if (entry->listener) entry->listener(state, SP_ANIMATION_DISPOSE, entry, 0);
		if (state->listener) state->listener(state, SP_ANIMATION_DISPOSE, entry, 0);
		_sp37AnimationState_disposeTrackEntry(entry);
		entry = next;
	}
}

sp37AnimationState* sp37AnimationState_create (sp37AnimationStateData* data) {
	_sp37AnimationState* internal;
	sp37AnimationState* self;

	if (!SP_EMPTY_ANIMATION) {
		SP_EMPTY_ANIMATION = (sp37Animation*)1; /* dirty trick so we can recursively call sp37Animation_create */
		SP_EMPTY_ANIMATION = sp37Animation_create("<empty>", 0);
	}

	internal = NEW(_sp37AnimationState);
	self = SUPER(internal);

	CONST_CAST(sp37AnimationStateData*, self->data) = data;
	self->timeScale = 1;

	internal->queue = _sp37EventQueue_create(internal);
	internal->events = CALLOC(sp37Event*, 128);

	internal->propertyIDs = CALLOC(int, 128);
	internal->propertyIDsCapacity = 128;

	return self;
}

void sp37AnimationState_dispose (sp37AnimationState* self) {
	int i;
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);
	for (i = 0; i < self->tracksCount; i++)
		_sp37AnimationState_disposeTrackEntries(self, self->tracks[i]);
	FREE(self->tracks);
	_sp37EventQueue_free(internal->queue);
	FREE(internal->events);
	FREE(internal->propertyIDs);
    FREE(internal);
}

void sp37AnimationState_update (sp37AnimationState* self, float delta) {
	int i, n;
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);
	delta *= self->timeScale;
	for (i = 0, n = self->tracksCount; i < n; i++) {
		float currentDelta;
		sp37TrackEntry* current = self->tracks[i];
		sp37TrackEntry* next;
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
				next->trackTime = current->timeScale == 0 ? 0 : (nextTime / current->timeScale + delta) * next->timeScale;
				current->trackTime += currentDelta;
				_sp37AnimationState_setCurrent(self, i, next, 1);
				while (next->mixingFrom) {
					next->mixTime += delta;
					next = next->mixingFrom;
				}
				continue;
			}
		} else {
			/* Clear the track when there is no next entry, the track end time is reached, and there is no mixingFrom. */
			if (current->trackLast >= current->trackEnd && current->mixingFrom == 0) {
				self->tracks[i] = 0;
				_sp37EventQueue_end(internal->queue, current);
				_sp37AnimationState_disposeNext(self, current);
				continue;
			}
		}
		if (current->mixingFrom != 0 && _sp37AnimationState_updateMixingFrom(self, current, delta)) {
			/* End mixing from entries once all have completed. */
			sp37TrackEntry* from = current->mixingFrom;
			current->mixingFrom = 0;
			if (from != 0) from->mixingTo = 0;
			while (from != 0) {
				_sp37EventQueue_end(internal->queue, from);
				from = from->mixingFrom;
			}
		}

		current->trackTime += currentDelta;
	}

	_sp37EventQueue_drain(internal->queue);
}

int /*boolean*/ _sp37AnimationState_updateMixingFrom (sp37AnimationState* self, sp37TrackEntry* to, float delta) {
	sp37TrackEntry* from = to->mixingFrom;
	int finished;
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);
	if (!from) return -1;

	finished = _sp37AnimationState_updateMixingFrom(self, from, delta);

	from->animationLast = from->nextAnimationLast;
	from->trackLast = from->nextTrackLast;

	/* Require mixTime > 0 to ensure the mixing from entry was applied at least once. */
	if (to->mixTime > 0 && to->mixTime >= to->mixDuration) {
		/* Require totalAlpha == 0 to ensure mixing is complete, unless mixDuration == 0 (the transition is a single frame). */
		if (from->totalAlpha == 0 || to->mixDuration == 0) {
			to->mixingFrom = from->mixingFrom;
			if (from->mixingFrom != 0) from->mixingFrom->mixingTo = to;
			to->interruptAlpha = from->interruptAlpha;
			_sp37EventQueue_end(internal->queue, from);
		}
		return finished;
	}

	from->trackTime += delta * from->timeScale;
	to->mixTime += delta;
	return 0;
}

int sp37AnimationState_apply (sp37AnimationState* self, sp37Skeleton* skeleton) {
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);
	sp37TrackEntry* current;
	int i, ii, n;
	float animationLast, animationTime;
	int timelineCount;
	sp37Timeline** timelines;
	int /*boolean*/ firstFrame;
	float* timelinesRotation;
	sp37Timeline* timeline;
	int applied = 0;
	sp37MixBlend blend;
	sp37MixBlend timelineBlend;

	if (internal->animationsChanged) _sp37AnimationState_animationsChanged(self);

	for (i = 0, n = self->tracksCount; i < n; i++) {
		float mix;
		current = self->tracks[i];
		if (!current || current->delay > 0) continue;
		applied = -1;
		blend = i == 0 ? SP_MIX_BLEND_FIRST : current->mixBlend;

		/* Apply mixing from entries first. */
		mix = current->alpha;
		if (current->mixingFrom)
            mix *= _sp37AnimationState_applyMixingFrom(self, current, skeleton, blend);
        else if (current->trackTime >= current->trackEnd && current->next == 0)
            mix = 0;

		/* Apply current entry. */
		animationLast = current->animationLast; animationTime = sp37TrackEntry_getAnimationTime(current);
		timelineCount = current->animation->timelinesCount;
		timelines = current->animation->timelines;
		if ((i == 0 && mix == 1) || blend == SP_MIX_BLEND_ADD) {
			for (ii = 0; ii < timelineCount; ii++)
				sp37Timeline_apply(timelines[ii], skeleton, animationLast, animationTime, internal->events, &internal->eventsCount, mix, blend, SP_MIX_DIRECTION_IN);
		} else {
			sp37IntArray* timelineMode = current->timelineMode;

			firstFrame = current->timelinesRotationCount == 0;
			if (firstFrame) _sp37AnimationState_resizeTimelinesRotation(current, timelineCount << 1);
			timelinesRotation = current->timelinesRotation;

			for (ii = 0; ii < timelineCount; ii++) {
				timeline = timelines[ii];
				timelineBlend = timelineMode->items[ii] == SUBSEQUENT ? blend : SP_MIX_BLEND_SETUP;
				if (timeline->type == SP_TIMELINE_ROTATE)
					_sp37AnimationState_applyRotateTimeline(self, timeline, skeleton, animationTime, mix, timelineBlend, timelinesRotation, ii << 1, firstFrame);
				else
					sp37Timeline_apply(timeline, skeleton, animationLast, animationTime, internal->events, &internal->eventsCount, mix, timelineBlend, SP_MIX_DIRECTION_IN);
			}
		}
		_sp37AnimationState_queueEvents(self, current, animationTime);
		internal->eventsCount = 0;
		current->nextAnimationLast = animationTime;
		current->nextTrackLast = current->trackTime;
	}

	_sp37EventQueue_drain(internal->queue);
	return applied;
}

float _sp37AnimationState_applyMixingFrom (sp37AnimationState* self, sp37TrackEntry* to, sp37Skeleton* skeleton, sp37MixBlend blend) {
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);
	float mix;
	sp37Event** events;
	int /*boolean*/ attachments;
	int /*boolean*/ drawOrder;
	float animationLast;
	float animationTime;
	int timelineCount;
	sp37Timeline** timelines;
	sp37IntArray* timelineMode;
	sp37TrackEntryArray* timelineHoldMix;
	sp37MixBlend timelineBlend;
	float alphaHold;
	float alphaMix;
	float alpha;
	int /*boolean*/ firstFrame;
	float* timelinesRotation;
	int i;
	sp37TrackEntry* holdMix;

	sp37TrackEntry* from = to->mixingFrom;
	if (from->mixingFrom) _sp37AnimationState_applyMixingFrom(self, from, skeleton, blend);

	if (to->mixDuration == 0) { /* Single frame mix to undo mixingFrom changes. */
		mix = 1;
		if (blend == SP_MIX_BLEND_FIRST) blend = SP_MIX_BLEND_SETUP;
	} else {
		mix = to->mixTime / to->mixDuration;
		if (mix > 1) mix = 1;
		if (blend != SP_MIX_BLEND_FIRST) blend = from->mixBlend;
	}

	events = mix < from->eventThreshold ? internal->events : 0;
	attachments = mix < from->attachmentThreshold;
	drawOrder = mix < from->drawOrderThreshold;
	animationLast = from->animationLast;
	animationTime = sp37TrackEntry_getAnimationTime(from);
	timelineCount = from->animation->timelinesCount;
	timelines = from->animation->timelines;
	alphaHold = from->alpha * to->interruptAlpha; alphaMix = alphaHold * (1 - mix);
	if (blend == SP_MIX_BLEND_ADD) {
		for (i = 0; i < timelineCount; i++) {
			sp37Timeline *timeline = timelines[i];
			sp37Timeline_apply(timeline, skeleton, animationLast, animationTime, events, &internal->eventsCount, alphaMix, blend, SP_MIX_DIRECTION_OUT);
		}
	} else {
		timelineMode = from->timelineMode;
		timelineHoldMix = from->timelineHoldMix;

		firstFrame = from->timelinesRotationCount == 0;
		if (firstFrame) _sp37AnimationState_resizeTimelinesRotation(from, timelineCount << 1);
		timelinesRotation = from->timelinesRotation;

		from->totalAlpha = 0;
		for (i = 0; i < timelineCount; i++) {
			sp37MixDirection direction = SP_MIX_DIRECTION_OUT;
			sp37Timeline *timeline = timelines[i];

			switch (timelineMode->items[i]) {
				case SUBSEQUENT:
					if (!attachments && timeline->type == SP_TIMELINE_ATTACHMENT) continue;
					if (!drawOrder && timeline->type == SP_TIMELINE_DRAWORDER) continue;
					timelineBlend = blend;
					alpha = alphaMix;
					break;
				case FIRST:
					timelineBlend = SP_MIX_BLEND_SETUP;
					alpha = alphaMix;
					break;
				case HOLD:
					timelineBlend = SP_MIX_BLEND_SETUP;
					alpha = alphaHold;
					break;
				default:
					timelineBlend = SP_MIX_BLEND_SETUP;
					holdMix = timelineHoldMix->items[i];
					alpha = alphaHold * MAX(0, 1 - holdMix->mixTime / holdMix->mixDuration);
					break;
			}
			from->totalAlpha += alpha;
			if (timeline->type == SP_TIMELINE_ROTATE)
				_sp37AnimationState_applyRotateTimeline(self, timeline, skeleton, animationTime, alpha, timelineBlend,
													  timelinesRotation, i << 1, firstFrame);
			else {
				if (timelineBlend == SP_MIX_BLEND_SETUP) {
					if (timeline->type == SP_TIMELINE_ATTACHMENT) {
						if (attachments) direction = SP_MIX_DIRECTION_IN;
					} else if (timeline->type == SP_TIMELINE_DRAWORDER) {
						if (drawOrder) direction = SP_MIX_DIRECTION_IN;
					}
				}

				sp37Timeline_apply(timeline, skeleton, animationLast, animationTime, events, &internal->eventsCount,
								 alpha, timelineBlend, direction);
			}
		}
	}


	if (to->mixDuration > 0) _sp37AnimationState_queueEvents(self, from, animationTime);
	internal->eventsCount = 0;
	from->nextAnimationLast = animationTime;
	from->nextTrackLast = from->trackTime;

	return mix;
}

void _sp37AnimationState_applyRotateTimeline (sp37AnimationState* self, sp37Timeline* timeline, sp37Skeleton* skeleton, float time, float alpha, sp37MixBlend blend, float* timelinesRotation, int i, int /*boolean*/ firstFrame) {
	sp37RotateTimeline *rotateTimeline;
	float *frames;
	sp37Bone* bone;
	float r1, r2;
	int frame;
	float prevRotation;
	float frameTime;
	float percent;
	float total, diff;
	int /*boolean*/ current, dir;
	UNUSED(self);

	if (firstFrame) timelinesRotation[i] = 0;

	if (alpha == 1) {
		sp37Timeline_apply(timeline, skeleton, 0, time, 0, 0, 1, blend, SP_MIX_DIRECTION_IN);
		return;
	}

	rotateTimeline = SUB_CAST(sp37RotateTimeline, timeline);
	frames = rotateTimeline->frames;
	bone = skeleton->bones[rotateTimeline->boneIndex];
	if (time < frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				bone->rotation = bone->data->rotation;
			default:
				return;
			case SP_MIX_BLEND_FIRST:
				r1 = bone->rotation;
				r2 = bone->data->rotation;
		}
	} else {
		r1 = blend == SP_MIX_BLEND_SETUP ? bone->data->rotation : bone->rotation;
		if (time >= frames[rotateTimeline->framesCount - ROTATE_ENTRIES]) /* Time is after last frame. */
			r2 = bone->data->rotation + frames[rotateTimeline->framesCount + ROTATE_PREV_ROTATION];
		else {
			/* Interpolate between the previous frame and the current frame. */
			frame = _sp37CurveTimeline_binarySearch(frames, rotateTimeline->framesCount, time, ROTATE_ENTRIES);
			prevRotation = frames[frame + ROTATE_PREV_ROTATION];
			frameTime = frames[frame];
			percent = sp37CurveTimeline_getCurvePercent(SUPER(rotateTimeline), (frame >> 1) - 1,
													  1 - (time - frameTime) /
														  (frames[frame + ROTATE_PREV_TIME] - frameTime));

			r2 = frames[frame + ROTATE_ROTATION] - prevRotation;
			r2 -= (16384 - (int) (16384.499999999996 - r2 / 360)) * 360;
			r2 = prevRotation + r2 * percent + bone->data->rotation;
			r2 -= (16384 - (int) (16384.499999999996 - r2 / 360)) * 360;
		}
	}

	/* Mix between rotations using the direction of the shortest route on the first frame while detecting crosses. */
	diff = r2 - r1;
	diff -= (16384 - (int)(16384.499999999996 - diff / 360)) * 360;
	if (diff == 0) {
		total = timelinesRotation[i];
	} else {
		float lastTotal, lastDiff;
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

void _sp37AnimationState_queueEvents (sp37AnimationState* self, sp37TrackEntry* entry, float animationTime) {
	sp37Event** events;
	sp37Event* event;
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);
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
		_sp37EventQueue_event(internal->queue, entry, event);
	}

	/* Queue complete if completed a loop iteration or the animation. */
	if (entry->loop)
		complete = duration == 0 || (trackLastWrapped > FMOD(entry->trackTime, duration));
	else
		complete = (animationTime >= animationEnd && entry->animationLast < animationEnd);
	if (complete) _sp37EventQueue_complete(internal->queue, entry);

	/* Queue events after complete. */
	for (; i < n; i++) {
		event = events[i];
		if (event->time < animationStart) continue; /* Discard events outside animation start/end. */
		_sp37EventQueue_event(internal->queue, entry, event);
	}
}

void sp37AnimationState_clearTracks (sp37AnimationState* self) {
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);
	int i, n, oldDrainDisabled;
	oldDrainDisabled = internal->queue->drainDisabled;
	internal->queue->drainDisabled = 1;
	for (i = 0, n = self->tracksCount; i < n; i++)
		sp37AnimationState_clearTrack(self, i);
	self->tracksCount = 0;
	internal->queue->drainDisabled = oldDrainDisabled;
	_sp37EventQueue_drain(internal->queue);
}

void sp37AnimationState_clearTrack (sp37AnimationState* self, int trackIndex) {
	sp37TrackEntry* current;
	sp37TrackEntry* entry;
	sp37TrackEntry* from;
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);

	if (trackIndex >= self->tracksCount) return;
	current = self->tracks[trackIndex];
	if (!current) return;

	_sp37EventQueue_end(internal->queue, current);

	_sp37AnimationState_disposeNext(self, current);

	entry = current;
	while (1) {
		from = entry->mixingFrom;
		if (!from) break;
		_sp37EventQueue_end(internal->queue, from);
		entry->mixingFrom = 0;
		entry->mixingTo = 0;
		entry = from;
	}

	self->tracks[current->trackIndex] = 0;
	_sp37EventQueue_drain(internal->queue);
}

void _sp37AnimationState_setCurrent (sp37AnimationState* self, int index, sp37TrackEntry* current, int /*boolean*/ interrupt) {
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);
	sp37TrackEntry* from = _sp37AnimationState_expandToIndex(self, index);
	self->tracks[index] = current;

	if (from) {
		if (interrupt) _sp37EventQueue_interrupt(internal->queue, from);
		current->mixingFrom = from;
		from->mixingTo = current;
		current->mixTime = 0;

		/* Store the interrupted mix percentage. */
		if (from->mixingFrom != 0 && from->mixDuration > 0)
			current->interruptAlpha *= MIN(1, from->mixTime / from->mixDuration);

		from->timelinesRotationCount = 0;
	}

	_sp37EventQueue_start(internal->queue, current);
}

/** Set the current animation. Any queued animations are cleared. */
sp37TrackEntry* sp37AnimationState_setAnimationByName (sp37AnimationState* self, int trackIndex, const char* animationName,
												   int/*bool*/loop) {
	sp37Animation* animation = sp37SkeletonData_findAnimation(self->data->skeletonData, animationName);
	return sp37AnimationState_setAnimation(self, trackIndex, animation, loop);
}

sp37TrackEntry* sp37AnimationState_setAnimation (sp37AnimationState* self, int trackIndex, sp37Animation* animation, int/*bool*/loop) {
	sp37TrackEntry* entry;
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);
	int interrupt = 1;
	sp37TrackEntry* current = _sp37AnimationState_expandToIndex(self, trackIndex);
	if (current) {
		if (current->nextTrackLast == -1) {
			/* Don't mix from an entry that was never applied. */
			self->tracks[trackIndex] = current->mixingFrom;
			_sp37EventQueue_interrupt(internal->queue, current);
			_sp37EventQueue_end(internal->queue, current);
			_sp37AnimationState_disposeNext(self, current);
			current = current->mixingFrom;
			interrupt = 0;
		} else
			_sp37AnimationState_disposeNext(self, current);
	}
	entry = _sp37AnimationState_trackEntry(self, trackIndex, animation, loop, current);
	_sp37AnimationState_setCurrent(self, trackIndex, entry, interrupt);
	_sp37EventQueue_drain(internal->queue);
	return entry;
}

/** Adds an animation to be played delay seconds after the current or last queued animation, taking into account any mix
 * duration. */
sp37TrackEntry* sp37AnimationState_addAnimationByName (sp37AnimationState* self, int trackIndex, const char* animationName,
												   int/*bool*/loop, float delay) {
	sp37Animation* animation = sp37SkeletonData_findAnimation(self->data->skeletonData, animationName);
	return sp37AnimationState_addAnimation(self, trackIndex, animation, loop, delay);
}

sp37TrackEntry* sp37AnimationState_addAnimation (sp37AnimationState* self, int trackIndex, sp37Animation* animation, int/*bool*/loop,
											 float delay) {
	sp37TrackEntry* entry;
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);
	sp37TrackEntry* last = _sp37AnimationState_expandToIndex(self, trackIndex);
	if (last) {
		while (last->next)
			last = last->next;
	}

	entry = _sp37AnimationState_trackEntry(self, trackIndex, animation, loop, last);

	if (!last) {
		_sp37AnimationState_setCurrent(self, trackIndex, entry, 1);
		_sp37EventQueue_drain(internal->queue);
	} else {
		last->next = entry;
		if (delay <= 0) {
			float duration = last->animationEnd - last->animationStart;
			if (duration != 0) {
				if (last->loop) {
					delay += duration * (1 + (int) (last->trackTime / duration));
				} else {
					delay += MAX(duration, last->trackTime);
				}
				delay -= sp37AnimationStateData_getMix(self->data, last->animation, animation);
			} else
				delay = last->trackTime;
		}
	}

	entry->delay = delay;
	return entry;
}

sp37TrackEntry* sp37AnimationState_setEmptyAnimation(sp37AnimationState* self, int trackIndex, float mixDuration) {
	sp37TrackEntry* entry = sp37AnimationState_setAnimation(self, trackIndex, SP_EMPTY_ANIMATION, 0);
	entry->mixDuration = mixDuration;
	entry->trackEnd = mixDuration;
	return entry;
}

sp37TrackEntry* sp37AnimationState_addEmptyAnimation(sp37AnimationState* self, int trackIndex, float mixDuration, float delay) {
	sp37TrackEntry* entry;
	if (delay <= 0) delay -= mixDuration;
	entry = sp37AnimationState_addAnimation(self, trackIndex, SP_EMPTY_ANIMATION, 0, delay);
	entry->mixDuration = mixDuration;
	entry->trackEnd = mixDuration;
	return entry;
}

void sp37AnimationState_setEmptyAnimations(sp37AnimationState* self, float mixDuration) {
	int i, n, oldDrainDisabled;
	sp37TrackEntry* current;
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);
	oldDrainDisabled = internal->queue->drainDisabled;
	internal->queue->drainDisabled = 1;
	for (i = 0, n = self->tracksCount; i < n; i++) {
		current = self->tracks[i];
		if (current) sp37AnimationState_setEmptyAnimation(self, current->trackIndex, mixDuration);
	}
	internal->queue->drainDisabled = oldDrainDisabled;
	_sp37EventQueue_drain(internal->queue);
}

sp37TrackEntry* _sp37AnimationState_expandToIndex (sp37AnimationState* self, int index) {
	sp37TrackEntry** newTracks;
	if (index < self->tracksCount) return self->tracks[index];
	newTracks = CALLOC(sp37TrackEntry*, index + 1);
	memcpy(newTracks, self->tracks, self->tracksCount * sizeof(sp37TrackEntry*));
	FREE(self->tracks);
	self->tracks = newTracks;
	self->tracksCount = index + 1;
	return 0;
}

sp37TrackEntry* _sp37AnimationState_trackEntry (sp37AnimationState* self, int trackIndex, sp37Animation* animation, int /*boolean*/ loop, sp37TrackEntry* last) {
	sp37TrackEntry* entry = NEW(sp37TrackEntry);
	entry->trackIndex = trackIndex;
	entry->animation = animation;
	entry->loop = loop;
	entry->holdPrevious = 0;

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
	entry->mixDuration = !last ? 0 : sp37AnimationStateData_getMix(self->data, last->animation, animation);
	entry->mixBlend = SP_MIX_BLEND_REPLACE;

	entry->timelineMode = sp37IntArray_create(16);
	entry->timelineHoldMix = sp37TrackEntryArray_create(16);

	return entry;
}

void _sp37AnimationState_disposeNext (sp37AnimationState* self, sp37TrackEntry* entry) {
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);
	sp37TrackEntry* next = entry->next;
	while (next) {
		_sp37EventQueue_dispose(internal->queue, next);
		next = next->next;
	}
	entry->next = 0;
}

void _sp37AnimationState_animationsChanged (sp37AnimationState* self) {
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);
	int i, n;
	sp37TrackEntry* entry;
	internal->animationsChanged = 0;

	internal->propertyIDsCount = 0;
	i = 0; n = self->tracksCount;

	for (;i < n; i++) {
		entry = self->tracks[i];
		if (!entry) continue;
		while (entry->mixingFrom != 0)
			entry = entry->mixingFrom;
		do {
			if (entry->mixingTo == 0 || entry->mixBlend != SP_MIX_BLEND_ADD) _sp37TrackEntry_setTimelineData(entry, self);
			entry = entry->mixingTo;
		} while (entry != 0);
	}
}

float* _sp37AnimationState_resizeTimelinesRotation(sp37TrackEntry* entry, int newSize) {
	if (entry->timelinesRotationCount != newSize) {
		float* newTimelinesRotation = CALLOC(float, newSize);
		FREE(entry->timelinesRotation);
		entry->timelinesRotation = newTimelinesRotation;
		entry->timelinesRotationCount = newSize;
	}
	return entry->timelinesRotation;
}

void _sp37AnimationState_ensureCapacityPropertyIDs(sp37AnimationState* self, int capacity) {
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);
	if (internal->propertyIDsCapacity < capacity) {
		int *newPropertyIDs = CALLOC(int, capacity << 1);
		memcpy(newPropertyIDs, internal->propertyIDs, sizeof(int) * internal->propertyIDsCount);
		FREE(internal->propertyIDs);
		internal->propertyIDs = newPropertyIDs;
		internal->propertyIDsCapacity = capacity << 1;
	}
}

int _sp37AnimationState_addPropertyID(sp37AnimationState* self, int id) {
	int i, n;
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);

	for (i = 0, n = internal->propertyIDsCount; i < n; i++) {
		if (internal->propertyIDs[i] == id) return 0;
	}

	_sp37AnimationState_ensureCapacityPropertyIDs(self, internal->propertyIDsCount + 1);
	internal->propertyIDs[internal->propertyIDsCount] = id;
	internal->propertyIDsCount++;
	return 1;
}

sp37TrackEntry* sp37AnimationState_getCurrent (sp37AnimationState* self, int trackIndex) {
	if (trackIndex >= self->tracksCount) return 0;
	return self->tracks[trackIndex];
}

void sp37AnimationState_clearListenerNotifications(sp37AnimationState* self) {
	_sp37AnimationState* internal = SUB_CAST(_sp37AnimationState, self);
	_sp37EventQueue_clear(internal->queue);
}

float sp37TrackEntry_getAnimationTime (sp37TrackEntry* entry) {
	if (entry->loop) {
		float duration = entry->animationEnd - entry->animationStart;
		if (duration == 0) return entry->animationStart;
		return FMOD(entry->trackTime, duration) + entry->animationStart;
	}
	return MIN(entry->trackTime + entry->animationStart, entry->animationEnd);
}

int /*boolean*/ _sp37TrackEntry_hasTimeline(sp37TrackEntry* self, int id) {
	sp37Timeline** timelines = self->animation->timelines;
	int i, n;
	for (i = 0, n = self->animation->timelinesCount; i < n; i++)
		if (sp37Timeline_getPropertyId(timelines[i]) == id) return 1;
	return 0;
}

void _sp37TrackEntry_setTimelineData(sp37TrackEntry* entry, sp37AnimationState* state) {
	sp37TrackEntry* to;
	sp37Timeline** timelines;
	int timelinesCount;
	int* timelineMode;
	sp37TrackEntry** timelineHoldMix;
	sp37TrackEntry* next;
	int i;

	to = entry->mixingTo;
	timelines = entry->animation->timelines;
	timelinesCount = entry->animation->timelinesCount;
	timelineMode = sp37IntArray_setSize(entry->timelineMode, timelinesCount)->items;
	sp37TrackEntryArray_clear(entry->timelineHoldMix);
	timelineHoldMix = sp37TrackEntryArray_setSize(entry->timelineHoldMix, timelinesCount)->items;

	if (to != 0 && to->holdPrevious) {
		for (i = 0; i < timelinesCount; i++) {
			int id = sp37Timeline_getPropertyId(timelines[i]);
			_sp37AnimationState_addPropertyID(state, id);
			timelineMode[i] = HOLD;
		}
		return;
	}

	i = 0;
	continue_outer:
	for (; i < timelinesCount; i++) {
		int id = sp37Timeline_getPropertyId(timelines[i]);
		if (!_sp37AnimationState_addPropertyID(state, id))
			timelineMode[i] = SUBSEQUENT;
		else if (to == 0 || !_sp37TrackEntry_hasTimeline(to, id))
			timelineMode[i] = FIRST;
		else {
			for (next = to->mixingTo; next != 0; next = next->mixingTo) {
				if (_sp37TrackEntry_hasTimeline(next, id)) continue;
				if (next->mixDuration > 0) {
					timelineMode[i] = HOLD_MIX;
					timelineHoldMix[i] = next;
					i++;
					goto continue_outer;
				}
				break;
			}
			timelineMode[i] = HOLD;
		}
	}
}

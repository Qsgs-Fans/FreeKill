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

#include <limits.h>
#include <spine/AnimationState.h>
#include <spine/extension.h>

#define SUBSEQUENT 0
#define FIRST 1
#define HOLD_SUBSEQUENT 2
#define HOLD_FIRST 3
#define HOLD_MIX 4

#define SETUP 1
#define CURRENT 2

_SP_ARRAY_IMPLEMENT_TYPE(sp42TrackEntryArray, sp42TrackEntry *)

static sp42Animation *SP_EMPTY_ANIMATION = 0;

void sp42AnimationState_disposeStatics(void) {
	if (SP_EMPTY_ANIMATION) sp42Animation_dispose(SP_EMPTY_ANIMATION);
	SP_EMPTY_ANIMATION = 0;
}

/* Forward declaration of some "private" functions so we can keep
 the same function order in C as we have method order in Java. */
void _sp42AnimationState_disposeTrackEntry(sp42TrackEntry *entry);

void _sp42AnimationState_disposeTrackEntries(sp42AnimationState *state, sp42TrackEntry *entry);

int /*boolean*/ _sp42AnimationState_updateMixingFrom(sp42AnimationState *self, sp42TrackEntry *entry, float delta);

float _sp42AnimationState_applyMixingFrom(sp42AnimationState *self, sp42TrackEntry *entry, sp42Skeleton *skeleton,
										sp42MixBlend currentBlend);

void _sp42AnimationState_applyRotateTimeline(sp42AnimationState *self, sp42Timeline *timeline, sp42Skeleton *skeleton, float time,
										   float alpha, sp42MixBlend blend, float *timelinesRotation, int i,
										   int /*boolean*/ firstFrame);

void _sp42AnimationState_applyAttachmentTimeline(sp42AnimationState *self, sp42Timeline *timeline, sp42Skeleton *skeleton,
											   float animationTime, sp42MixBlend blend, int /*bool*/ firstFrame);

void _sp42AnimationState_queueEvents(sp42AnimationState *self, sp42TrackEntry *entry, float animationTime);

void _sp42AnimationState_setCurrent(sp42AnimationState *self, int index, sp42TrackEntry *current, int /*boolean*/ interrupt);

sp42TrackEntry *_sp42AnimationState_expandToIndex(sp42AnimationState *self, int index);

sp42TrackEntry *
_sp42AnimationState_trackEntry(sp42AnimationState *self, int trackIndex, sp42Animation *animation, int /*boolean*/ loop,
							 sp42TrackEntry *last);

void _sp42AnimationState_animationsChanged(sp42AnimationState *self);

float *_sp42AnimationState_resizeTimelinesRotation(sp42TrackEntry *entry, int newSize);

void _sp42AnimationState_ensureCapacityPropertyIDs(sp42AnimationState *self, int capacity);

int _sp42AnimationState_addPropertyID(sp42AnimationState *self, sp42PropertyId id);

void _sp42TrackEntry_computeHold(sp42TrackEntry *self, sp42AnimationState *state);

_sp42EventQueue *_sp42EventQueue_create(_sp42AnimationState *state) {
	_sp42EventQueue *self = CALLOC(_sp42EventQueue, 1);
	self->state = state;
	self->objectsCount = 0;
	self->objectsCapacity = 16;
	self->objects = CALLOC(_sp42EventQueueItem, self->objectsCapacity);
	self->drainDisabled = 0;
	return self;
}

void _sp42EventQueue_free(_sp42EventQueue *self) {
	FREE(self->objects);
	FREE(self);
}

void _sp42EventQueue_ensureCapacity(_sp42EventQueue *self, int newElements) {
	if (self->objectsCount + newElements > self->objectsCapacity) {
		_sp42EventQueueItem *newObjects;
		self->objectsCapacity <<= 1;
		newObjects = CALLOC(_sp42EventQueueItem, self->objectsCapacity);
		memcpy(newObjects, self->objects, sizeof(_sp42EventQueueItem) * self->objectsCount);
		FREE(self->objects);
		self->objects = newObjects;
	}
}

void _sp42EventQueue_addType(_sp42EventQueue *self, sp42EventType type) {
	_sp42EventQueue_ensureCapacity(self, 1);
	self->objects[self->objectsCount++].type = type;
}

void _sp42EventQueue_addEntry(_sp42EventQueue *self, sp42TrackEntry *entry) {
	_sp42EventQueue_ensureCapacity(self, 1);
	self->objects[self->objectsCount++].entry = entry;
}

void _sp42EventQueue_addEvent(_sp42EventQueue *self, sp42Event *event) {
	_sp42EventQueue_ensureCapacity(self, 1);
	self->objects[self->objectsCount++].event = event;
}

void _sp42EventQueue_start(_sp42EventQueue *self, sp42TrackEntry *entry) {
	_sp42EventQueue_addType(self, SP_ANIMATION_START);
	_sp42EventQueue_addEntry(self, entry);
	self->state->animationsChanged = 1;
}

void _sp42EventQueue_interrupt(_sp42EventQueue *self, sp42TrackEntry *entry) {
	_sp42EventQueue_addType(self, SP_ANIMATION_INTERRUPT);
	_sp42EventQueue_addEntry(self, entry);
}

void _sp42EventQueue_end(_sp42EventQueue *self, sp42TrackEntry *entry) {
	_sp42EventQueue_addType(self, SP_ANIMATION_END);
	_sp42EventQueue_addEntry(self, entry);
	self->state->animationsChanged = 1;
}

void _sp42EventQueue_dispose(_sp42EventQueue *self, sp42TrackEntry *entry) {
	_sp42EventQueue_addType(self, SP_ANIMATION_DISPOSE);
	_sp42EventQueue_addEntry(self, entry);
}

void _sp42EventQueue_complete(_sp42EventQueue *self, sp42TrackEntry *entry) {
	_sp42EventQueue_addType(self, SP_ANIMATION_COMPLETE);
	_sp42EventQueue_addEntry(self, entry);
}

void _sp42EventQueue_event(_sp42EventQueue *self, sp42TrackEntry *entry, sp42Event *event) {
	_sp42EventQueue_addType(self, SP_ANIMATION_EVENT);
	_sp42EventQueue_addEntry(self, entry);
	_sp42EventQueue_addEvent(self, event);
}

void _sp42EventQueue_clear(_sp42EventQueue *self) {
	self->objectsCount = 0;
}

void _sp42EventQueue_drain(_sp42EventQueue *self) {
	int i;
	if (self->drainDisabled) return;
	self->drainDisabled = 1;
	for (i = 0; i < self->objectsCount; i += 2) {
		sp42EventType type = (sp42EventType) self->objects[i].type;
		sp42TrackEntry *entry = self->objects[i + 1].entry;
		sp42Event *event;
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
				if (self->state->super.listener)
					self->state->super.listener(SUPER(self->state), SP_ANIMATION_DISPOSE, entry, 0);
				_sp42AnimationState_disposeTrackEntry(entry);
				break;
			case SP_ANIMATION_EVENT:
				event = self->objects[i + 2].event;
				if (entry->listener) entry->listener(SUPER(self->state), type, entry, event);
				if (self->state->super.listener) self->state->super.listener(SUPER(self->state), type, entry, event);
				i++;
				break;
		}
	}
	_sp42EventQueue_clear(self);

	self->drainDisabled = 0;
}

/* These two functions are needed in the UE4 runtime, see #1037 */
void _sp42AnimationState_enableQueue(sp42AnimationState *self) {
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
	internal->queue->drainDisabled = 0;
}

void _sp42AnimationState_disableQueue(sp42AnimationState *self) {
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
	internal->queue->drainDisabled = 1;
}

void _sp42AnimationState_disposeTrackEntry(sp42TrackEntry *entry) {
	sp42IntArray_dispose(entry->timelineMode);
	sp42TrackEntryArray_dispose(entry->timelineHoldMix);
	FREE(entry->timelinesRotation);
	FREE(entry);
}

void _sp42AnimationState_disposeTrackEntries(sp42AnimationState *state, sp42TrackEntry *entry) {
	while (entry) {
		sp42TrackEntry *next = entry->next;
		sp42TrackEntry *from = entry->mixingFrom;
		while (from) {
			sp42TrackEntry *nextFrom = from->mixingFrom;
			if (entry->listener) entry->listener(state, SP_ANIMATION_DISPOSE, from, 0);
			if (state->listener) state->listener(state, SP_ANIMATION_DISPOSE, from, 0);
			_sp42AnimationState_disposeTrackEntry(from);
			from = nextFrom;
		}
		if (entry->listener) entry->listener(state, SP_ANIMATION_DISPOSE, entry, 0);
		if (state->listener) state->listener(state, SP_ANIMATION_DISPOSE, entry, 0);
		_sp42AnimationState_disposeTrackEntry(entry);
		entry = next;
	}
}

sp42AnimationState *sp42AnimationState_create(sp42AnimationStateData *data) {
	_sp42AnimationState *internal;
	sp42AnimationState *self;

	if (!SP_EMPTY_ANIMATION) {
		SP_EMPTY_ANIMATION = (sp42Animation *) 1; /* dirty trick so we can recursively call sp42Animation_create */
		SP_EMPTY_ANIMATION = sp42Animation_create("<empty>", NULL, 0);
	}

	internal = NEW(_sp42AnimationState);
	self = SUPER(internal);

	self->data = data;
	self->timeScale = 1;

	internal->queue = _sp42EventQueue_create(internal);
	internal->events = CALLOC(sp42Event *, 128);

	internal->propertyIDs = CALLOC(sp42PropertyId, 128);
	internal->propertyIDsCapacity = 128;

	return self;
}

void sp42AnimationState_dispose(sp42AnimationState *self) {
	int i;
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
	for (i = 0; i < self->tracksCount; i++)
		_sp42AnimationState_disposeTrackEntries(self, self->tracks[i]);
	FREE(self->tracks);
	_sp42EventQueue_free(internal->queue);
	FREE(internal->events);
	FREE(internal->propertyIDs);
	FREE(internal);
}

void sp42AnimationState_update(sp42AnimationState *self, float delta) {
	int i, n;
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
	delta *= self->timeScale;
	for (i = 0, n = self->tracksCount; i < n; i++) {
		float currentDelta;
		sp42TrackEntry *current = self->tracks[i];
		sp42TrackEntry *next;
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
				next->trackTime +=
						current->timeScale == 0 ? 0 : (nextTime / current->timeScale + delta) * next->timeScale;
				current->trackTime += currentDelta;
				_sp42AnimationState_setCurrent(self, i, next, 1);
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
				_sp42EventQueue_end(internal->queue, current);
				sp42AnimationState_clearNext(self, current);
				continue;
			}
		}
		if (current->mixingFrom != 0 && _sp42AnimationState_updateMixingFrom(self, current, delta)) {
			/* End mixing from entries once all have completed. */
			sp42TrackEntry *from = current->mixingFrom;
			current->mixingFrom = 0;
			if (from != 0) from->mixingTo = 0;
			while (from != 0) {
				_sp42EventQueue_end(internal->queue, from);
				from = from->mixingFrom;
			}
		}

		current->trackTime += currentDelta;
	}

	_sp42EventQueue_drain(internal->queue);
}

int /*boolean*/ _sp42AnimationState_updateMixingFrom(sp42AnimationState *self, sp42TrackEntry *to, float delta) {
	sp42TrackEntry *from = to->mixingFrom;
	int finished;
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
	if (!from) return -1;

	finished = _sp42AnimationState_updateMixingFrom(self, from, delta);

	from->animationLast = from->nextAnimationLast;
	from->trackLast = from->nextTrackLast;

	/* Require mixTime > 0 to ensure the mixing from entry was applied at least once. */
	if (to->mixTime > 0 && to->mixTime >= to->mixDuration) {
		/* Require totalAlpha == 0 to ensure mixing is complete, unless mixDuration == 0 (the transition is a single frame). */
		if (from->totalAlpha == 0 || to->mixDuration == 0) {
			to->mixingFrom = from->mixingFrom;
			if (from->mixingFrom != 0) from->mixingFrom->mixingTo = to;
			to->interruptAlpha = from->interruptAlpha;
			_sp42EventQueue_end(internal->queue, from);
		}
		return finished;
	}

	from->trackTime += delta * from->timeScale;
	to->mixTime += delta;
	return 0;
}

int sp42AnimationState_apply(sp42AnimationState *self, sp42Skeleton *skeleton) {
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
	sp42TrackEntry *current;
	int i, ii, n;
	float animationLast, animationTime;
	int timelineCount;
	sp42Timeline **timelines;
	int /*boolean*/ firstFrame, shortestRotation;
	float *timelinesRotation;
	sp42Timeline *timeline;
	int applied = 0;
	sp42MixBlend blend;
	sp42MixBlend timelineBlend;
	int setupState = 0;
	sp42Slot **slots = NULL;
	sp42Slot *slot = NULL;
	const char *attachmentName = NULL;
	sp42Event **applyEvents = NULL;
	float applyTime;

	if (internal->animationsChanged) _sp42AnimationState_animationsChanged(self);

	for (i = 0, n = self->tracksCount; i < n; i++) {
		float alpha;
		current = self->tracks[i];
		if (!current || current->delay > 0) continue;
		applied = -1;
		blend = i == 0 ? SP_MIX_BLEND_FIRST : current->mixBlend;

		/* Apply mixing from entries first. */
		alpha = current->alpha;
		if (current->mixingFrom)
			alpha *= _sp42AnimationState_applyMixingFrom(self, current, skeleton, blend);
		else if (current->trackTime >= current->trackEnd && current->next == 0)
			alpha = 0;
		int /*bool*/ attachments = alpha >= current->alphaAttachmentThreshold;

		/* Apply current entry. */
		animationLast = current->animationLast;
		animationTime = sp42TrackEntry_getAnimationTime(current);
		timelineCount = current->animation->timelines->size;
		applyEvents = internal->events;
		applyTime = animationTime;
		if (current->reverse) {
			applyTime = current->animation->duration - applyTime;
			applyEvents = NULL;
		}
		timelines = current->animation->timelines->items;
		if ((i == 0 && alpha == 1) || blend == SP_MIX_BLEND_ADD) {
			for (ii = 0; ii < timelineCount; ii++) {
				timeline = timelines[ii];
				if (timeline->type == SP_TIMELINE_ATTACHMENT) {
					_sp42AnimationState_applyAttachmentTimeline(self, timeline, skeleton, applyTime, blend, attachments);
				} else {
					sp42Timeline_apply(timelines[ii], skeleton, animationLast, applyTime, applyEvents,
									 &internal->eventsCount, alpha, blend, SP_MIX_DIRECTION_IN);
				}
			}
		} else {
			sp42IntArray *timelineMode = current->timelineMode;

			shortestRotation = current->shortestRotation;
			firstFrame = !shortestRotation && current->timelinesRotationCount != timelineCount << 1;
			if (firstFrame) _sp42AnimationState_resizeTimelinesRotation(current, timelineCount << 1);
			timelinesRotation = current->timelinesRotation;

			for (ii = 0; ii < timelineCount; ii++) {
				timeline = timelines[ii];
				timelineBlend = timelineMode->items[ii] == SUBSEQUENT ? blend : SP_MIX_BLEND_SETUP;
				if (!shortestRotation && timeline->type == SP_TIMELINE_ROTATE)
					_sp42AnimationState_applyRotateTimeline(self, timeline, skeleton, applyTime, alpha, timelineBlend,
														  timelinesRotation, ii << 1, firstFrame);
				else if (timeline->type == SP_TIMELINE_ATTACHMENT)
					_sp42AnimationState_applyAttachmentTimeline(self, timeline, skeleton, applyTime, timelineBlend, attachments);
				else
					sp42Timeline_apply(timeline, skeleton, animationLast, applyTime, applyEvents, &internal->eventsCount,
									 alpha, timelineBlend, SP_MIX_DIRECTION_IN);
			}
		}
		_sp42AnimationState_queueEvents(self, current, animationTime);
		internal->eventsCount = 0;
		current->nextAnimationLast = animationTime;
		current->nextTrackLast = current->trackTime;
	}

	setupState = self->unkeyedState + SETUP;
	slots = skeleton->slots;
	for (i = 0, n = skeleton->slotsCount; i < n; i++) {
		slot = slots[i];
		if (slot->attachmentState == setupState) {
			attachmentName = slot->data->attachmentName;
			sp42Slot_setAttachment(slot, attachmentName == NULL ? NULL : sp42Skeleton_getAttachmentForSlotIndex(skeleton, slot->data->index, attachmentName));
		}
	}
	self->unkeyedState += 2;

	_sp42EventQueue_drain(internal->queue);
	return applied;
}

float _sp42AnimationState_applyMixingFrom(sp42AnimationState *self, sp42TrackEntry *to, sp42Skeleton *skeleton, sp42MixBlend blend) {
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
	float mix;
	sp42Event **events;
	int /*boolean*/ attachments;
	int /*boolean*/ drawOrder;
	float animationLast;
	float animationTime;
	int timelineCount;
	sp42Timeline **timelines;
	sp42IntArray *timelineMode;
	sp42TrackEntryArray *timelineHoldMix;
	sp42MixBlend timelineBlend;
	float alphaHold;
	float alphaMix;
	float alpha;
	int /*boolean*/ firstFrame, shortestRotation;
	float *timelinesRotation;
	int i;
	sp42TrackEntry *holdMix;
	float applyTime;

	sp42TrackEntry *from = to->mixingFrom;
	if (from->mixingFrom) _sp42AnimationState_applyMixingFrom(self, from, skeleton, blend);

	if (to->mixDuration == 0) { /* Single frame mix to undo mixingFrom changes. */
		mix = 1;
		if (blend == SP_MIX_BLEND_FIRST) blend = SP_MIX_BLEND_SETUP;
	} else {
		mix = to->mixTime / to->mixDuration;
		if (mix > 1) mix = 1;
		if (blend != SP_MIX_BLEND_FIRST) blend = from->mixBlend;
	}

	attachments = mix < from->mixAttachmentThreshold;
	drawOrder = mix < from->mixDrawOrderThreshold;
	timelineCount = from->animation->timelines->size;
	timelines = from->animation->timelines->items;
	alphaHold = from->alpha * to->interruptAlpha;
	alphaMix = alphaHold * (1 - mix);
	animationLast = from->animationLast;
	animationTime = sp42TrackEntry_getAnimationTime(from);
	applyTime = animationTime;
	events = NULL;
	if (from->reverse) {
		applyTime = from->animation->duration - applyTime;
	} else {
		if (mix < from->eventThreshold) events = internal->events;
	}

	if (blend == SP_MIX_BLEND_ADD) {
		for (i = 0; i < timelineCount; i++) {
			sp42Timeline *timeline = timelines[i];
			sp42Timeline_apply(timeline, skeleton, animationLast, applyTime, events, &internal->eventsCount, alphaMix,
							 blend, SP_MIX_DIRECTION_OUT);
		}
	} else {
		timelineMode = from->timelineMode;
		timelineHoldMix = from->timelineHoldMix;

		shortestRotation = from->shortestRotation;
		firstFrame = !shortestRotation && from->timelinesRotationCount != timelineCount << 1;
		if (firstFrame) _sp42AnimationState_resizeTimelinesRotation(from, timelineCount << 1);
		timelinesRotation = from->timelinesRotation;

		from->totalAlpha = 0;
		for (i = 0; i < timelineCount; i++) {
			sp42MixDirection direction = SP_MIX_DIRECTION_OUT;
			sp42Timeline *timeline = timelines[i];

			switch (timelineMode->items[i]) {
				case SUBSEQUENT:
					if (!drawOrder && timeline->type == SP_TIMELINE_DRAWORDER) continue;
					timelineBlend = blend;
					alpha = alphaMix;
					break;
				case FIRST:
					timelineBlend = SP_MIX_BLEND_SETUP;
					alpha = alphaMix;
					break;
				case HOLD_SUBSEQUENT:
					timelineBlend = blend;
					alpha = alphaHold;
					break;
				case HOLD_FIRST:
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
			if (!shortestRotation && timeline->type == SP_TIMELINE_ROTATE)
				_sp42AnimationState_applyRotateTimeline(self, timeline, skeleton, applyTime, alpha, timelineBlend,
													  timelinesRotation, i << 1, firstFrame);
			else if (timeline->type == SP_TIMELINE_ATTACHMENT)
				_sp42AnimationState_applyAttachmentTimeline(self, timeline, skeleton, applyTime, timelineBlend,
														  attachments && alpha >= from->alphaAttachmentThreshold);
			else {
				if (drawOrder && timeline->type == SP_TIMELINE_DRAWORDER &&
					timelineBlend == SP_MIX_BLEND_SETUP)
					direction = SP_MIX_DIRECTION_IN;
				sp42Timeline_apply(timeline, skeleton, animationLast, applyTime, events, &internal->eventsCount,
								 alpha, timelineBlend, direction);
			}
		}
	}


	if (to->mixDuration > 0) _sp42AnimationState_queueEvents(self, from, animationTime);
	internal->eventsCount = 0;
	from->nextAnimationLast = animationTime;
	from->nextTrackLast = from->trackTime;

	return mix;
}

static void
_sp42AnimationState_setAttachment(sp42AnimationState *self, sp42Skeleton *skeleton, sp42Slot *slot, const char *attachmentName,
								int /*bool*/ attachments) {
	sp42Slot_setAttachment(slot, attachmentName == NULL ? NULL : sp42Skeleton_getAttachmentForSlotIndex(skeleton, slot->data->index, attachmentName));
	if (attachments) slot->attachmentState = self->unkeyedState + CURRENT;
}

/* @param target After the first and before the last entry. */
static int binarySearch1(float *values, int valuesLength, float target) {
	int i;
	for (i = 1; i < valuesLength; i++) {
		if (values[i] > target) return (int) (i - 1);
	}
	return (int) valuesLength - 1;
}

void _sp42AnimationState_applyAttachmentTimeline(sp42AnimationState *self, sp42Timeline *timeline, sp42Skeleton *skeleton,
											   float time, sp42MixBlend blend, int /*bool*/ attachments) {
	sp42AttachmentTimeline *attachmentTimeline;
	sp42Slot *slot;
	float *frames;

	attachmentTimeline = SUB_CAST(sp42AttachmentTimeline, timeline);
	slot = skeleton->slots[attachmentTimeline->slotIndex];
	if (!slot->bone->active) return;

	frames = attachmentTimeline->super.frames->items;
	if (time < frames[0]) {
		if (blend == SP_MIX_BLEND_SETUP || blend == SP_MIX_BLEND_FIRST)
			_sp42AnimationState_setAttachment(self, skeleton, slot, slot->data->attachmentName, attachments);
	} else {
		_sp42AnimationState_setAttachment(self, skeleton, slot, attachmentTimeline->attachmentNames[binarySearch1(frames, attachmentTimeline->super.frames->size, time)],
										attachments);
	}

	/* If an attachment wasn't set (ie before the first frame or attachments is false), set the setup attachment later.*/
	if (slot->attachmentState <= self->unkeyedState) slot->attachmentState = self->unkeyedState + SETUP;
}

void _sp42AnimationState_applyRotateTimeline(sp42AnimationState *self, sp42Timeline *timeline, sp42Skeleton *skeleton, float time,
										   float alpha, sp42MixBlend blend, float *timelinesRotation, int i,
										   int /*boolean*/ firstFrame) {
	sp42RotateTimeline *rotateTimeline;
	float *frames;
	sp42Bone *bone;
	float r1, r2;
	float total, diff;
	int /*boolean*/ current, dir;
	UNUSED(self);

	if (firstFrame) timelinesRotation[i] = 0;

	if (alpha == 1) {
		sp42Timeline_apply(timeline, skeleton, 0, time, 0, 0, 1, blend, SP_MIX_DIRECTION_IN);
		return;
	}

	rotateTimeline = SUB_CAST(sp42RotateTimeline, timeline);
	frames = rotateTimeline->super.super.frames->items;
	bone = skeleton->bones[rotateTimeline->boneIndex];
	if (!bone->active) return;
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
		r2 = bone->data->rotation + sp42CurveTimeline1_getCurveValue(&rotateTimeline->super, time);
	}

	/* Mix between rotations using the direction of the shortest route on the first frame while detecting crosses. */
	diff = r2 - r1;
	diff -= CEIL(diff / 360 - 0.5) * 360;
	if (diff == 0) {
		total = timelinesRotation[i];
	} else {
		float lastTotal, lastDiff, loops;
		if (firstFrame) {
			lastTotal = 0;
			lastDiff = diff;
		} else {
			lastTotal = timelinesRotation[i];
			lastDiff = timelinesRotation[i + 1];
		}
		loops = lastTotal - FMOD(lastTotal, 360);
		total = diff + loops;
		current = diff >= 0, dir = lastTotal >= 0;
		if (ABS(lastDiff) <= 90 && SIGNUM(lastDiff) != SIGNUM(diff)) {
			if (ABS(lastTotal - loops) > 180) {
				total += 360 * SIGNUM(lastTotal);
				dir = current;
			} else if (loops != 0)
				total -= 360 * SIGNUM(lastTotal);
			else
				dir = current;
		}
		if (dir != current) total += 360 * SIGNUM(lastTotal);
		timelinesRotation[i] = total;
	}
	timelinesRotation[i + 1] = diff;
	bone->rotation = r1 + total * alpha;
}

void _sp42AnimationState_queueEvents(sp42AnimationState *self, sp42TrackEntry *entry, float animationTime) {
	sp42Event **events;
	sp42Event *event;
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
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
		_sp42EventQueue_event(internal->queue, entry, event);
	}

	/* Queue complete if completed a loop iteration or the animation. */
	if (entry->loop) {
		if (duration == 0)
			complete = -1;
		else {
			int cycles = (int) (entry->trackTime / duration);
			complete = cycles > 0 && cycles > (int) (entry->trackLast / duration);
		}
	} else {
		complete = (animationTime >= animationEnd && entry->animationLast < animationEnd);
	}
	if (complete) _sp42EventQueue_complete(internal->queue, entry);

	/* Queue events after complete. */
	for (; i < n; i++) {
		event = events[i];
		if (event->time < animationStart) continue; /* Discard events outside animation start/end. */
		_sp42EventQueue_event(internal->queue, entry, event);
	}
}

void sp42AnimationState_clearTracks(sp42AnimationState *self) {
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
	int i, n, oldDrainDisabled;
	oldDrainDisabled = internal->queue->drainDisabled;
	internal->queue->drainDisabled = 1;
	for (i = 0, n = self->tracksCount; i < n; i++)
		sp42AnimationState_clearTrack(self, i);
	self->tracksCount = 0;
	internal->queue->drainDisabled = oldDrainDisabled;
	_sp42EventQueue_drain(internal->queue);
}

void sp42AnimationState_clearTrack(sp42AnimationState *self, int trackIndex) {
	sp42TrackEntry *current;
	sp42TrackEntry *entry;
	sp42TrackEntry *from;
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);

	if (trackIndex >= self->tracksCount) return;
	current = self->tracks[trackIndex];
	if (!current) return;

	_sp42EventQueue_end(internal->queue, current);

	sp42AnimationState_clearNext(self, current);

	entry = current;
	while (1) {
		from = entry->mixingFrom;
		if (!from) break;
		_sp42EventQueue_end(internal->queue, from);
		entry->mixingFrom = 0;
		entry->mixingTo = 0;
		entry = from;
	}

	self->tracks[current->trackIndex] = 0;
	_sp42EventQueue_drain(internal->queue);
}

void _sp42AnimationState_setCurrent(sp42AnimationState *self, int index, sp42TrackEntry *current, int /*boolean*/ interrupt) {
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
	sp42TrackEntry *from = _sp42AnimationState_expandToIndex(self, index);
	self->tracks[index] = current;
	current->previous = NULL;

	if (from) {
		if (interrupt) _sp42EventQueue_interrupt(internal->queue, from);
		current->mixingFrom = from;
		from->mixingTo = current;
		current->mixTime = 0;

		/* Store the interrupted mix percentage. */
		if (from->mixingFrom != 0 && from->mixDuration > 0)
			current->interruptAlpha *= MIN(1, from->mixTime / from->mixDuration);

		from->timelinesRotationCount = 0;
	}

	_sp42EventQueue_start(internal->queue, current);
}

/** Set the current animation. Any queued animations are cleared. */
sp42TrackEntry *sp42AnimationState_setAnimationByName(sp42AnimationState *self, int trackIndex, const char *animationName,
												  int /*bool*/ loop) {
	sp42Animation *animation = sp42SkeletonData_findAnimation(self->data->skeletonData, animationName);
	return sp42AnimationState_setAnimation(self, trackIndex, animation, loop);
}

sp42TrackEntry *
sp42AnimationState_setAnimation(sp42AnimationState *self, int trackIndex, sp42Animation *animation, int /*bool*/ loop) {
	sp42TrackEntry *entry;
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
	int interrupt = 1;
	sp42TrackEntry *current = _sp42AnimationState_expandToIndex(self, trackIndex);
	if (current) {
		if (current->nextTrackLast == -1) {
			/* Don't mix from an entry that was never applied. */
			self->tracks[trackIndex] = current->mixingFrom;
			_sp42EventQueue_interrupt(internal->queue, current);
			_sp42EventQueue_end(internal->queue, current);
			sp42AnimationState_clearNext(self, current);
			current = current->mixingFrom;
			interrupt = 0;
		} else
			sp42AnimationState_clearNext(self, current);
	}
	entry = _sp42AnimationState_trackEntry(self, trackIndex, animation, loop, current);
	_sp42AnimationState_setCurrent(self, trackIndex, entry, interrupt);
	_sp42EventQueue_drain(internal->queue);
	return entry;
}

/** Adds an animation to be played delay seconds after the current or last queued animation, taking into account any mix
 * duration. */
sp42TrackEntry *sp42AnimationState_addAnimationByName(sp42AnimationState *self, int trackIndex, const char *animationName,
												  int /*bool*/ loop, float delay) {
	sp42Animation *animation = sp42SkeletonData_findAnimation(self->data->skeletonData, animationName);
	return sp42AnimationState_addAnimation(self, trackIndex, animation, loop, delay);
}

sp42TrackEntry *
sp42AnimationState_addAnimation(sp42AnimationState *self, int trackIndex, sp42Animation *animation, int /*bool*/ loop,
							  float delay) {
	sp42TrackEntry *entry;
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
	sp42TrackEntry *last = _sp42AnimationState_expandToIndex(self, trackIndex);
	if (last) {
		while (last->next)
			last = last->next;
	}

	entry = _sp42AnimationState_trackEntry(self, trackIndex, animation, loop, last);

	if (!last) {
		_sp42AnimationState_setCurrent(self, trackIndex, entry, 1);
		_sp42EventQueue_drain(internal->queue);
	} else {
		last->next = entry;
		entry->previous = last;
		if (delay <= 0) delay += sp42TrackEntry_getTrackComplete(last) - entry->mixDuration;
	}

	entry->delay = delay;
	return entry;
}

sp42TrackEntry *sp42AnimationState_setEmptyAnimation(sp42AnimationState *self, int trackIndex, float mixDuration) {
	sp42TrackEntry *entry = sp42AnimationState_setAnimation(self, trackIndex, SP_EMPTY_ANIMATION, 0);
	entry->mixDuration = mixDuration;
	entry->trackEnd = mixDuration;
	return entry;
}

sp42TrackEntry *
sp42AnimationState_addEmptyAnimation(sp42AnimationState *self, int trackIndex, float mixDuration, float delay) {
	sp42TrackEntry *entry = sp42AnimationState_addAnimation(self, trackIndex, SP_EMPTY_ANIMATION, 0, delay);
	if (delay <= 0) entry->delay += entry->mixDuration - mixDuration;
	entry->mixDuration = mixDuration;
	entry->trackEnd = mixDuration;
	return entry;
}

void sp42AnimationState_setEmptyAnimations(sp42AnimationState *self, float mixDuration) {
	int i, n, oldDrainDisabled;
	sp42TrackEntry *current;
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
	oldDrainDisabled = internal->queue->drainDisabled;
	internal->queue->drainDisabled = 1;
	for (i = 0, n = self->tracksCount; i < n; i++) {
		current = self->tracks[i];
		if (current) sp42AnimationState_setEmptyAnimation(self, current->trackIndex, mixDuration);
	}
	internal->queue->drainDisabled = oldDrainDisabled;
	_sp42EventQueue_drain(internal->queue);
}

sp42TrackEntry *_sp42AnimationState_expandToIndex(sp42AnimationState *self, int index) {
	sp42TrackEntry **newTracks;
	if (index < self->tracksCount) return self->tracks[index];
	newTracks = CALLOC(sp42TrackEntry *, index + 1);
	memcpy(newTracks, self->tracks, self->tracksCount * sizeof(sp42TrackEntry *));
	FREE(self->tracks);
	self->tracks = newTracks;
	self->tracksCount = index + 1;
	return 0;
}

sp42TrackEntry *
_sp42AnimationState_trackEntry(sp42AnimationState *self, int trackIndex, sp42Animation *animation, int /*boolean*/ loop,
							 sp42TrackEntry *last) {
	sp42TrackEntry *entry = NEW(sp42TrackEntry);
	entry->trackIndex = trackIndex;
	entry->animation = animation;
	entry->loop = loop;
	entry->holdPrevious = 0;
	entry->reverse = 0;
	entry->shortestRotation = 0;
	entry->previous = 0;
	entry->next = 0;

	entry->eventThreshold = 0;
	entry->mixAttachmentThreshold = 0;
	entry->alphaAttachmentThreshold = 0;
	entry->mixDrawOrderThreshold = 0;

	entry->animationStart = 0;
	entry->animationEnd = animation->duration;
	entry->animationLast = -1;
	entry->nextAnimationLast = -1;

	entry->delay = 0;
	entry->trackTime = 0;
	entry->trackLast = -1;
	entry->nextTrackLast = -1;
	entry->trackEnd = (float) INT_MAX;
	entry->timeScale = 1;

	entry->alpha = 1;
	entry->mixTime = 0;
	entry->mixDuration = !last ? 0 : sp42AnimationStateData_getMix(self->data, last->animation, animation);
	entry->interruptAlpha = 1;
	entry->totalAlpha = 0;
	entry->mixBlend = SP_MIX_BLEND_REPLACE;

	entry->timelineMode = sp42IntArray_create(16);
	entry->timelineHoldMix = sp42TrackEntryArray_create(16);

	return entry;
}

void sp42AnimationState_clearNext(sp42AnimationState *self, sp42TrackEntry *entry) {
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
	sp42TrackEntry *next = entry->next;
	while (next) {
		_sp42EventQueue_dispose(internal->queue, next);
		next = next->next;
	}
	entry->next = 0;
}

void _sp42AnimationState_animationsChanged(sp42AnimationState *self) {
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
	int i, n;
	sp42TrackEntry *entry;
	internal->animationsChanged = 0;

	internal->propertyIDsCount = 0;
	i = 0;
	n = self->tracksCount;

	for (; i < n; i++) {
		entry = self->tracks[i];
		if (!entry) continue;
		while (entry->mixingFrom != 0)
			entry = entry->mixingFrom;
		do {
			if (entry->mixingTo == 0 || entry->mixBlend != SP_MIX_BLEND_ADD) _sp42TrackEntry_computeHold(entry, self);
			entry = entry->mixingTo;
		} while (entry != 0);
	}
}

float *_sp42AnimationState_resizeTimelinesRotation(sp42TrackEntry *entry, int newSize) {
	if (entry->timelinesRotationCount != newSize) {
		float *newTimelinesRotation = CALLOC(float, newSize);
		FREE(entry->timelinesRotation);
		entry->timelinesRotation = newTimelinesRotation;
		entry->timelinesRotationCount = newSize;
	}
	return entry->timelinesRotation;
}

void _sp42AnimationState_ensureCapacityPropertyIDs(sp42AnimationState *self, int capacity) {
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
	if (internal->propertyIDsCapacity < capacity) {
		sp42PropertyId *newPropertyIDs = CALLOC(sp42PropertyId, capacity << 1);
		memcpy(newPropertyIDs, internal->propertyIDs, sizeof(sp42PropertyId) * internal->propertyIDsCount);
		FREE(internal->propertyIDs);
		internal->propertyIDs = newPropertyIDs;
		internal->propertyIDsCapacity = capacity << 1;
	}
}

int _sp42AnimationState_addPropertyID(sp42AnimationState *self, sp42PropertyId id) {
	int i, n;
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);

	for (i = 0, n = internal->propertyIDsCount; i < n; i++) {
		if (internal->propertyIDs[i] == id) return 0;
	}

	_sp42AnimationState_ensureCapacityPropertyIDs(self, internal->propertyIDsCount + 1);
	internal->propertyIDs[internal->propertyIDsCount] = id;
	internal->propertyIDsCount++;
	return 1;
}

int _sp42AnimationState_addPropertyIDs(sp42AnimationState *self, sp42PropertyId *ids, int numIds) {
	int i, n;
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
	int oldSize = internal->propertyIDsCount;

	for (i = 0, n = numIds; i < n; i++) {
		_sp42AnimationState_addPropertyID(self, ids[i]);
	}

	return internal->propertyIDsCount != oldSize;
}

sp42TrackEntry *sp42AnimationState_getCurrent(sp42AnimationState *self, int trackIndex) {
	if (trackIndex >= self->tracksCount) return 0;
	return self->tracks[trackIndex];
}

void sp42AnimationState_clearListenerNotifications(sp42AnimationState *self) {
	_sp42AnimationState *internal = SUB_CAST(_sp42AnimationState, self);
	_sp42EventQueue_clear(internal->queue);
}

float sp42TrackEntry_getAnimationTime(sp42TrackEntry *entry) {
	if (entry->loop) {
		float duration = entry->animationEnd - entry->animationStart;
		if (duration == 0) return entry->animationStart;
		return FMOD(entry->trackTime, duration) + entry->animationStart;
	}
	return MIN(entry->trackTime + entry->animationStart, entry->animationEnd);
}

void sp42TrackEntry_resetRotationDirections(sp42TrackEntry *entry) {
	FREE(entry->timelinesRotation);
	entry->timelinesRotation = NULL;
	entry->timelinesRotationCount = 0;
}

float sp42TrackEntry_getTrackComplete(sp42TrackEntry *entry) {
	float duration = entry->animationEnd - entry->animationStart;
	if (duration != 0) {
		if (entry->loop) return duration * (1 + (int) (entry->trackTime / duration)); /* Completion of next loop. */
		if (entry->trackTime < duration) return duration;                             /* Before duration. */
	}
	return entry->trackTime; /* Next update. */
}

void sp42TrackEntry_setMixDuration(sp42TrackEntry *entry, float mixDuration, float delay) {
	entry->mixDuration = mixDuration;
	if (entry->previous && delay <= 0) delay += sp42TrackEntry_getTrackComplete(entry) - mixDuration;
	entry->delay = delay;
}

int sp42TrackEntry_wasApplied(sp42TrackEntry *entry) {
	return entry->nextTrackLast != -1;
}

int sp42TrackEntry_isNextReady(sp42TrackEntry *entry) {
	return entry->next != NULL && entry->nextTrackLast - entry->next->delay >= 0;
}

void _sp42TrackEntry_computeHold(sp42TrackEntry *entry, sp42AnimationState *state) {
	sp42TrackEntry *to;
	sp42Timeline **timelines;
	int timelinesCount;
	int *timelineMode;
	sp42TrackEntry **timelineHoldMix;
	sp42TrackEntry *next;
	int i;

	to = entry->mixingTo;
	timelines = entry->animation->timelines->items;
	timelinesCount = entry->animation->timelines->size;
	timelineMode = sp42IntArray_setSize(entry->timelineMode, timelinesCount)->items;
	sp42TrackEntryArray_clear(entry->timelineHoldMix);
	timelineHoldMix = sp42TrackEntryArray_setSize(entry->timelineHoldMix, timelinesCount)->items;

	if (to != 0 && to->holdPrevious) {
		for (i = 0; i < timelinesCount; i++) {
			sp42PropertyId *ids = timelines[i]->propertyIds;
			int numIds = timelines[i]->propertyIdsCount;
			timelineMode[i] = _sp42AnimationState_addPropertyIDs(state, ids, numIds) ? HOLD_FIRST : HOLD_SUBSEQUENT;
		}
		return;
	}

	i = 0;
continue_outer:
	for (; i < timelinesCount; i++) {
		sp42Timeline *timeline = timelines[i];
		sp42PropertyId *ids = timeline->propertyIds;
		int numIds = timeline->propertyIdsCount;
		if (!_sp42AnimationState_addPropertyIDs(state, ids, numIds))
			timelineMode[i] = SUBSEQUENT;
		else if (to == 0 || timeline->type == SP_TIMELINE_ATTACHMENT ||
				 timeline->type == SP_TIMELINE_DRAWORDER ||
				 timeline->type == SP_TIMELINE_EVENT ||
				 !sp42Animation_hasTimeline(to->animation, ids, numIds)) {
			timelineMode[i] = FIRST;
		} else {
			for (next = to->mixingTo; next != 0; next = next->mixingTo) {
				if (sp42Animation_hasTimeline(next->animation, ids, numIds)) continue;
				if (next->mixDuration > 0) {
					timelineMode[i] = HOLD_MIX;
					timelineHoldMix[i] = next;
					i++;
					goto continue_outer;
				}
				break;
			}
			timelineMode[i] = HOLD_FIRST;
		}
	}
}

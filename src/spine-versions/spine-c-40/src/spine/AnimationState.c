/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated January 1, 2020. Replaces all prior versions.
 *
 * Copyright (c) 2013-2020, Esoteric Software LLC
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
 * THE SPINE RUNTIMES ARE PROVIDED BY ESOTERIC SOFTWARE LLC "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL ESOTERIC SOFTWARE LLC BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES,
 * BUSINESS INTERRUPTION, OR LOSS OF USE, DATA, OR PROFITS) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THE SPINE RUNTIMES, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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

_SP_ARRAY_IMPLEMENT_TYPE(sp40TrackEntryArray, sp40TrackEntry *)

static sp40Animation *SP_EMPTY_ANIMATION = 0;

void sp40AnimationState_disposeStatics() {
	if (SP_EMPTY_ANIMATION) sp40Animation_dispose(SP_EMPTY_ANIMATION);
	SP_EMPTY_ANIMATION = 0;
}

/* Forward declaration of some "private" functions so we can keep
 the same function order in C as we have method order in Java. */
void _sp40AnimationState_disposeTrackEntry(sp40TrackEntry *entry);

void _sp40AnimationState_disposeTrackEntries(sp40AnimationState *state, sp40TrackEntry *entry);

int /*boolean*/ _sp40AnimationState_updateMixingFrom(sp40AnimationState *self, sp40TrackEntry *entry, float delta);

float _sp40AnimationState_applyMixingFrom(sp40AnimationState *self, sp40TrackEntry *entry, sp40Skeleton *skeleton,
										sp40MixBlend currentBlend);

void _sp40AnimationState_applyRotateTimeline(sp40AnimationState *self, sp40Timeline *timeline, sp40Skeleton *skeleton, float time,
										   float alpha, sp40MixBlend blend, float *timelinesRotation, int i,
										   int /*boolean*/ firstFrame);

void _sp40AnimationState_applyAttachmentTimeline(sp40AnimationState *self, sp40Timeline *timeline, sp40Skeleton *skeleton,
											   float animationTime, sp40MixBlend blend, int /*bool*/ firstFrame);

void _sp40AnimationState_queueEvents(sp40AnimationState *self, sp40TrackEntry *entry, float animationTime);

void _sp40AnimationState_setCurrent(sp40AnimationState *self, int index, sp40TrackEntry *current, int /*boolean*/ interrupt);

sp40TrackEntry *_sp40AnimationState_expandToIndex(sp40AnimationState *self, int index);

sp40TrackEntry *
_sp40AnimationState_trackEntry(sp40AnimationState *self, int trackIndex, sp40Animation *animation, int /*boolean*/ loop,
							 sp40TrackEntry *last);

void _sp40AnimationState_animationsChanged(sp40AnimationState *self);

float *_sp40AnimationState_resizeTimelinesRotation(sp40TrackEntry *entry, int newSize);

void _sp40AnimationState_ensureCapacityPropertyIDs(sp40AnimationState *self, int capacity);

int _sp40AnimationState_addPropertyID(sp40AnimationState *self, sp40PropertyId id);

void _sp40TrackEntry_computeHold(sp40TrackEntry *self, sp40AnimationState *state);

_sp40EventQueue *_sp40EventQueue_create(_sp40AnimationState *state) {
	_sp40EventQueue *self = CALLOC(_sp40EventQueue, 1);
	self->state = state;
	self->objectsCount = 0;
	self->objectsCapacity = 16;
	self->objects = CALLOC(_sp40EventQueueItem, self->objectsCapacity);
	self->drainDisabled = 0;
	return self;
}

void _sp40EventQueue_free(_sp40EventQueue *self) {
	FREE(self->objects);
	FREE(self);
}

void _sp40EventQueue_ensureCapacity(_sp40EventQueue *self, int newElements) {
	if (self->objectsCount + newElements > self->objectsCapacity) {
		_sp40EventQueueItem *newObjects;
		self->objectsCapacity <<= 1;
		newObjects = CALLOC(_sp40EventQueueItem, self->objectsCapacity);
		memcpy(newObjects, self->objects, sizeof(_sp40EventQueueItem) * self->objectsCount);
		FREE(self->objects);
		self->objects = newObjects;
	}
}

void _sp40EventQueue_addType(_sp40EventQueue *self, sp40EventType type) {
	_sp40EventQueue_ensureCapacity(self, 1);
	self->objects[self->objectsCount++].type = type;
}

void _sp40EventQueue_addEntry(_sp40EventQueue *self, sp40TrackEntry *entry) {
	_sp40EventQueue_ensureCapacity(self, 1);
	self->objects[self->objectsCount++].entry = entry;
}

void _sp40EventQueue_addEvent(_sp40EventQueue *self, sp40Event *event) {
	_sp40EventQueue_ensureCapacity(self, 1);
	self->objects[self->objectsCount++].event = event;
}

void _sp40EventQueue_start(_sp40EventQueue *self, sp40TrackEntry *entry) {
	_sp40EventQueue_addType(self, SP_ANIMATION_START);
	_sp40EventQueue_addEntry(self, entry);
	self->state->animationsChanged = 1;
}

void _sp40EventQueue_interrupt(_sp40EventQueue *self, sp40TrackEntry *entry) {
	_sp40EventQueue_addType(self, SP_ANIMATION_INTERRUPT);
	_sp40EventQueue_addEntry(self, entry);
}

void _sp40EventQueue_end(_sp40EventQueue *self, sp40TrackEntry *entry) {
	_sp40EventQueue_addType(self, SP_ANIMATION_END);
	_sp40EventQueue_addEntry(self, entry);
	self->state->animationsChanged = 1;
}

void _sp40EventQueue_dispose(_sp40EventQueue *self, sp40TrackEntry *entry) {
	_sp40EventQueue_addType(self, SP_ANIMATION_DISPOSE);
	_sp40EventQueue_addEntry(self, entry);
}

void _sp40EventQueue_complete(_sp40EventQueue *self, sp40TrackEntry *entry) {
	_sp40EventQueue_addType(self, SP_ANIMATION_COMPLETE);
	_sp40EventQueue_addEntry(self, entry);
}

void _sp40EventQueue_event(_sp40EventQueue *self, sp40TrackEntry *entry, sp40Event *event) {
	_sp40EventQueue_addType(self, SP_ANIMATION_EVENT);
	_sp40EventQueue_addEntry(self, entry);
	_sp40EventQueue_addEvent(self, event);
}

void _sp40EventQueue_clear(_sp40EventQueue *self) {
	self->objectsCount = 0;
}

void _sp40EventQueue_drain(_sp40EventQueue *self) {
	int i;
	if (self->drainDisabled) return;
	self->drainDisabled = 1;
	for (i = 0; i < self->objectsCount; i += 2) {
		sp40EventType type = (sp40EventType) self->objects[i].type;
		sp40TrackEntry *entry = self->objects[i + 1].entry;
		sp40Event *event;
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
				_sp40AnimationState_disposeTrackEntry(entry);
				break;
			case SP_ANIMATION_EVENT:
				event = self->objects[i + 2].event;
				if (entry->listener) entry->listener(SUPER(self->state), type, entry, event);
				if (self->state->super.listener) self->state->super.listener(SUPER(self->state), type, entry, event);
				i++;
				break;
		}
	}
	_sp40EventQueue_clear(self);

	self->drainDisabled = 0;
}

/* These two functions are needed in the UE4 runtime, see #1037 */
void _sp40AnimationState_enableQueue(sp40AnimationState *self) {
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
	internal->queue->drainDisabled = 0;
}

void _sp40AnimationState_disableQueue(sp40AnimationState *self) {
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
	internal->queue->drainDisabled = 1;
}

void _sp40AnimationState_disposeTrackEntry(sp40TrackEntry *entry) {
	sp40IntArray_dispose(entry->timelineMode);
	sp40TrackEntryArray_dispose(entry->timelineHoldMix);
	FREE(entry->timelinesRotation);
	FREE(entry);
}

void _sp40AnimationState_disposeTrackEntries(sp40AnimationState *state, sp40TrackEntry *entry) {
	while (entry) {
		sp40TrackEntry *next = entry->next;
		sp40TrackEntry *from = entry->mixingFrom;
		while (from) {
			sp40TrackEntry *nextFrom = from->mixingFrom;
			if (entry->listener) entry->listener(state, SP_ANIMATION_DISPOSE, from, 0);
			if (state->listener) state->listener(state, SP_ANIMATION_DISPOSE, from, 0);
			_sp40AnimationState_disposeTrackEntry(from);
			from = nextFrom;
		}
		if (entry->listener) entry->listener(state, SP_ANIMATION_DISPOSE, entry, 0);
		if (state->listener) state->listener(state, SP_ANIMATION_DISPOSE, entry, 0);
		_sp40AnimationState_disposeTrackEntry(entry);
		entry = next;
	}
}

sp40AnimationState *sp40AnimationState_create(sp40AnimationStateData *data) {
	_sp40AnimationState *internal;
	sp40AnimationState *self;

	if (!SP_EMPTY_ANIMATION) {
		SP_EMPTY_ANIMATION = (sp40Animation *) 1; /* dirty trick so we can recursively call sp40Animation_create */
		SP_EMPTY_ANIMATION = sp40Animation_create("<empty>", NULL, 0);
	}

	internal = NEW(_sp40AnimationState);
	self = SUPER(internal);

	CONST_CAST(sp40AnimationStateData *, self->data) = data;
	self->timeScale = 1;

	internal->queue = _sp40EventQueue_create(internal);
	internal->events = CALLOC(sp40Event *, 128);

	internal->propertyIDs = CALLOC(sp40PropertyId, 128);
	internal->propertyIDsCapacity = 128;

	return self;
}

void sp40AnimationState_dispose(sp40AnimationState *self) {
	int i;
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
	for (i = 0; i < self->tracksCount; i++)
		_sp40AnimationState_disposeTrackEntries(self, self->tracks[i]);
	FREE(self->tracks);
	_sp40EventQueue_free(internal->queue);
	FREE(internal->events);
	FREE(internal->propertyIDs);
	FREE(internal);
}

void sp40AnimationState_update(sp40AnimationState *self, float delta) {
	int i, n;
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
	delta *= self->timeScale;
	for (i = 0, n = self->tracksCount; i < n; i++) {
		float currentDelta;
		sp40TrackEntry *current = self->tracks[i];
		sp40TrackEntry *next;
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
				_sp40AnimationState_setCurrent(self, i, next, 1);
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
				_sp40EventQueue_end(internal->queue, current);
				sp40AnimationState_clearNext(self, current);
				continue;
			}
		}
		if (current->mixingFrom != 0 && _sp40AnimationState_updateMixingFrom(self, current, delta)) {
			/* End mixing from entries once all have completed. */
			sp40TrackEntry *from = current->mixingFrom;
			current->mixingFrom = 0;
			if (from != 0) from->mixingTo = 0;
			while (from != 0) {
				_sp40EventQueue_end(internal->queue, from);
				from = from->mixingFrom;
			}
		}

		current->trackTime += currentDelta;
	}

	_sp40EventQueue_drain(internal->queue);
}

int /*boolean*/ _sp40AnimationState_updateMixingFrom(sp40AnimationState *self, sp40TrackEntry *to, float delta) {
	sp40TrackEntry *from = to->mixingFrom;
	int finished;
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
	if (!from) return -1;

	finished = _sp40AnimationState_updateMixingFrom(self, from, delta);

	from->animationLast = from->nextAnimationLast;
	from->trackLast = from->nextTrackLast;

	/* Require mixTime > 0 to ensure the mixing from entry was applied at least once. */
	if (to->mixTime > 0 && to->mixTime >= to->mixDuration) {
		/* Require totalAlpha == 0 to ensure mixing is complete, unless mixDuration == 0 (the transition is a single frame). */
		if (from->totalAlpha == 0 || to->mixDuration == 0) {
			to->mixingFrom = from->mixingFrom;
			if (from->mixingFrom != 0) from->mixingFrom->mixingTo = to;
			to->interruptAlpha = from->interruptAlpha;
			_sp40EventQueue_end(internal->queue, from);
		}
		return finished;
	}

	from->trackTime += delta * from->timeScale;
	to->mixTime += delta;
	return 0;
}

int sp40AnimationState_apply(sp40AnimationState *self, sp40Skeleton *skeleton) {
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
	sp40TrackEntry *current;
	int i, ii, n;
	float animationLast, animationTime;
	int timelineCount;
	sp40Timeline **timelines;
	int /*boolean*/ firstFrame;
	float *timelinesRotation;
	sp40Timeline *timeline;
	int applied = 0;
	sp40MixBlend blend;
	sp40MixBlend timelineBlend;
	int setupState = 0;
	sp40Slot **slots = NULL;
	sp40Slot *slot = NULL;
	const char *attachmentName = NULL;
	sp40Event **applyEvents = NULL;
	float applyTime;

	if (internal->animationsChanged) _sp40AnimationState_animationsChanged(self);

	for (i = 0, n = self->tracksCount; i < n; i++) {
		float mix;
		current = self->tracks[i];
		if (!current || current->delay > 0) continue;
		applied = -1;
		blend = i == 0 ? SP_MIX_BLEND_FIRST : current->mixBlend;

		/* Apply mixing from entries first. */
		mix = current->alpha;
		if (current->mixingFrom)
			mix *= _sp40AnimationState_applyMixingFrom(self, current, skeleton, blend);
		else if (current->trackTime >= current->trackEnd && current->next == 0)
			mix = 0;

		/* Apply current entry. */
		animationLast = current->animationLast;
		animationTime = sp40TrackEntry_getAnimationTime(current);
		timelineCount = current->animation->timelines->size;
		applyEvents = internal->events;
		applyTime = animationTime;
		if (current->reverse) {
			applyTime = current->animation->duration - applyTime;
			applyEvents = NULL;
		}
		timelines = current->animation->timelines->items;
		if ((i == 0 && mix == 1) || blend == SP_MIX_BLEND_ADD) {
			for (ii = 0; ii < timelineCount; ii++) {
				timeline = timelines[ii];
				if (timeline->propertyIds[0] == SP_PROPERTY_ATTACHMENT) {
					_sp40AnimationState_applyAttachmentTimeline(self, timeline, skeleton, applyTime, blend, -1);
				} else {
					sp40Timeline_apply(timelines[ii], skeleton, animationLast, applyTime, applyEvents,
									 &internal->eventsCount, mix, blend, SP_MIX_DIRECTION_IN);
				}
			}
		} else {
			sp40IntArray *timelineMode = current->timelineMode;

			firstFrame = current->timelinesRotationCount != timelineCount << 1;
			if (firstFrame) _sp40AnimationState_resizeTimelinesRotation(current, timelineCount << 1);
			timelinesRotation = current->timelinesRotation;

			for (ii = 0; ii < timelineCount; ii++) {
				timeline = timelines[ii];
				timelineBlend = timelineMode->items[ii] == SUBSEQUENT ? blend : SP_MIX_BLEND_SETUP;
				if (timeline->propertyIds[0] == SP_PROPERTY_ROTATE)
					_sp40AnimationState_applyRotateTimeline(self, timeline, skeleton, applyTime, mix, timelineBlend,
														  timelinesRotation, ii << 1, firstFrame);
				else if (timeline->propertyIds[0] == SP_PROPERTY_ATTACHMENT)
					_sp40AnimationState_applyAttachmentTimeline(self, timeline, skeleton, applyTime, timelineBlend, -1);
				else
					sp40Timeline_apply(timeline, skeleton, animationLast, applyTime, applyEvents, &internal->eventsCount,
									 mix, timelineBlend, SP_MIX_DIRECTION_IN);
			}
		}
		_sp40AnimationState_queueEvents(self, current, animationTime);
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
			sp40Slot_setAttachment(slot, attachmentName == NULL ? NULL : sp40Skeleton_getAttachmentForSlotIndex(skeleton, slot->data->index, attachmentName));
		}
	}
	self->unkeyedState += 2;

	_sp40EventQueue_drain(internal->queue);
	return applied;
}

float _sp40AnimationState_applyMixingFrom(sp40AnimationState *self, sp40TrackEntry *to, sp40Skeleton *skeleton, sp40MixBlend blend) {
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
	float mix;
	sp40Event **events;
	int /*boolean*/ attachments;
	int /*boolean*/ drawOrder;
	float animationLast;
	float animationTime;
	int timelineCount;
	sp40Timeline **timelines;
	sp40IntArray *timelineMode;
	sp40TrackEntryArray *timelineHoldMix;
	sp40MixBlend timelineBlend;
	float alphaHold;
	float alphaMix;
	float alpha;
	int /*boolean*/ firstFrame;
	float *timelinesRotation;
	int i;
	sp40TrackEntry *holdMix;
	float applyTime;

	sp40TrackEntry *from = to->mixingFrom;
	if (from->mixingFrom) _sp40AnimationState_applyMixingFrom(self, from, skeleton, blend);

	if (to->mixDuration == 0) { /* Single frame mix to undo mixingFrom changes. */
		mix = 1;
		if (blend == SP_MIX_BLEND_FIRST) blend = SP_MIX_BLEND_SETUP;
	} else {
		mix = to->mixTime / to->mixDuration;
		if (mix > 1) mix = 1;
		if (blend != SP_MIX_BLEND_FIRST) blend = from->mixBlend;
	}

	attachments = mix < from->attachmentThreshold;
	drawOrder = mix < from->drawOrderThreshold;
	timelineCount = from->animation->timelines->size;
	timelines = from->animation->timelines->items;
	alphaHold = from->alpha * to->interruptAlpha;
	alphaMix = alphaHold * (1 - mix);
	animationLast = from->animationLast;
	animationTime = sp40TrackEntry_getAnimationTime(from);
	applyTime = animationTime;
	events = NULL;
	if (from->reverse) {
		applyTime = from->animation->duration - applyTime;
	} else {
		if (mix < from->eventThreshold) events = internal->events;
	}

	if (blend == SP_MIX_BLEND_ADD) {
		for (i = 0; i < timelineCount; i++) {
			sp40Timeline *timeline = timelines[i];
			sp40Timeline_apply(timeline, skeleton, animationLast, applyTime, events, &internal->eventsCount, alphaMix,
							 blend, SP_MIX_DIRECTION_OUT);
		}
	} else {
		timelineMode = from->timelineMode;
		timelineHoldMix = from->timelineHoldMix;

		firstFrame = from->timelinesRotationCount != timelineCount << 1;
		if (firstFrame) _sp40AnimationState_resizeTimelinesRotation(from, timelineCount << 1);
		timelinesRotation = from->timelinesRotation;

		from->totalAlpha = 0;
		for (i = 0; i < timelineCount; i++) {
			sp40MixDirection direction = SP_MIX_DIRECTION_OUT;
			sp40Timeline *timeline = timelines[i];

			switch (timelineMode->items[i]) {
				case SUBSEQUENT:
					if (!drawOrder && timeline->propertyIds[0] == SP_PROPERTY_DRAWORDER) continue;
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
			if (timeline->propertyIds[0] == SP_PROPERTY_ROTATE)
				_sp40AnimationState_applyRotateTimeline(self, timeline, skeleton, applyTime, alpha, timelineBlend,
													  timelinesRotation, i << 1, firstFrame);
			else if (timeline->propertyIds[0] == SP_PROPERTY_ATTACHMENT)
				_sp40AnimationState_applyAttachmentTimeline(self, timeline, skeleton, applyTime, timelineBlend,
														  attachments);
			else {
				if (drawOrder && timeline->propertyIds[0] == SP_PROPERTY_DRAWORDER &&
					timelineBlend == SP_MIX_BLEND_SETUP)
					direction = SP_MIX_DIRECTION_IN;
				sp40Timeline_apply(timeline, skeleton, animationLast, applyTime, events, &internal->eventsCount,
								 alpha, timelineBlend, direction);
			}
		}
	}


	if (to->mixDuration > 0) _sp40AnimationState_queueEvents(self, from, animationTime);
	internal->eventsCount = 0;
	from->nextAnimationLast = animationTime;
	from->nextTrackLast = from->trackTime;

	return mix;
}

static void
_sp40AnimationState_setAttachment(sp40AnimationState *self, sp40Skeleton *skeleton, sp40Slot *slot, const char *attachmentName,
								int /*bool*/ attachments) {
	sp40Slot_setAttachment(slot, attachmentName == NULL ? NULL : sp40Skeleton_getAttachmentForSlotIndex(skeleton, slot->data->index, attachmentName));
	if (attachments) slot->attachmentState = self->unkeyedState + CURRENT;
}

/* @param target After the first and before the last entry. */
static int binarySearch1(float *values, int valuesLength, float target) {
	int low = 0, current;
	int high = valuesLength - 2;
	if (high == 0) return 1;
	current = high >> 1;
	while (1) {
		if (values[(current + 1)] <= target)
			low = current + 1;
		else
			high = current;
		if (low == high) return low + 1;
		current = (low + high) >> 1;
	}
	return 0;
}

void _sp40AnimationState_applyAttachmentTimeline(sp40AnimationState *self, sp40Timeline *timeline, sp40Skeleton *skeleton,
											   float time, sp40MixBlend blend, int /*bool*/ attachments) {
	sp40AttachmentTimeline *attachmentTimeline;
	sp40Slot *slot;
	float *frames;

	attachmentTimeline = SUB_CAST(sp40AttachmentTimeline, timeline);
	slot = skeleton->slots[attachmentTimeline->slotIndex];
	if (!slot->bone->active) return;

	frames = attachmentTimeline->super.frames->items;
	if (time < frames[0]) {
		if (blend == SP_MIX_BLEND_SETUP || blend == SP_MIX_BLEND_FIRST)
			_sp40AnimationState_setAttachment(self, skeleton, slot, slot->data->attachmentName, attachments);
	} else {
		_sp40AnimationState_setAttachment(self, skeleton, slot, attachmentTimeline->attachmentNames[binarySearch1(frames, attachmentTimeline->super.frames->size, time)],
										attachments);
	}

	/* If an attachment wasn't set (ie before the first frame or attachments is false), set the setup attachment later.*/
	if (slot->attachmentState <= self->unkeyedState) slot->attachmentState = self->unkeyedState + SETUP;
}

void _sp40AnimationState_applyRotateTimeline(sp40AnimationState *self, sp40Timeline *timeline, sp40Skeleton *skeleton, float time,
										   float alpha, sp40MixBlend blend, float *timelinesRotation, int i,
										   int /*boolean*/ firstFrame) {
	sp40RotateTimeline *rotateTimeline;
	float *frames;
	sp40Bone *bone;
	float r1, r2;
	float total, diff;
	int /*boolean*/ current, dir;
	UNUSED(self);

	if (firstFrame) timelinesRotation[i] = 0;

	if (alpha == 1) {
		sp40Timeline_apply(timeline, skeleton, 0, time, 0, 0, 1, blend, SP_MIX_DIRECTION_IN);
		return;
	}

	rotateTimeline = SUB_CAST(sp40RotateTimeline, timeline);
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
		r2 = bone->data->rotation + sp40CurveTimeline1_getCurveValue(&rotateTimeline->super, time);
	}

	/* Mix between rotations using the direction of the shortest route on the first frame while detecting crosses. */
	diff = r2 - r1;
	diff -= (16384 - (int) (16384.499999999996 - diff / 360)) * 360;
	if (diff == 0) {
		total = timelinesRotation[i];
	} else {
		float lastTotal, lastDiff;
		if (firstFrame) {
			lastTotal = 0;
			lastDiff = diff;
		} else {
			lastTotal = timelinesRotation[i];    /* Angle and direction of mix, including loops. */
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
	bone->rotation = r1 + total * alpha;
}

void _sp40AnimationState_queueEvents(sp40AnimationState *self, sp40TrackEntry *entry, float animationTime) {
	sp40Event **events;
	sp40Event *event;
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
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
		_sp40EventQueue_event(internal->queue, entry, event);
	}

	/* Queue complete if completed a loop iteration or the animation. */
	if (entry->loop)
		complete = duration == 0 || (trackLastWrapped > FMOD(entry->trackTime, duration));
	else
		complete = (animationTime >= animationEnd && entry->animationLast < animationEnd);
	if (complete) _sp40EventQueue_complete(internal->queue, entry);

	/* Queue events after complete. */
	for (; i < n; i++) {
		event = events[i];
		if (event->time < animationStart) continue; /* Discard events outside animation start/end. */
		_sp40EventQueue_event(internal->queue, entry, event);
	}
}

void sp40AnimationState_clearTracks(sp40AnimationState *self) {
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
	int i, n, oldDrainDisabled;
	oldDrainDisabled = internal->queue->drainDisabled;
	internal->queue->drainDisabled = 1;
	for (i = 0, n = self->tracksCount; i < n; i++)
		sp40AnimationState_clearTrack(self, i);
	self->tracksCount = 0;
	internal->queue->drainDisabled = oldDrainDisabled;
	_sp40EventQueue_drain(internal->queue);
}

void sp40AnimationState_clearTrack(sp40AnimationState *self, int trackIndex) {
	sp40TrackEntry *current;
	sp40TrackEntry *entry;
	sp40TrackEntry *from;
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);

	if (trackIndex >= self->tracksCount) return;
	current = self->tracks[trackIndex];
	if (!current) return;

	_sp40EventQueue_end(internal->queue, current);

	sp40AnimationState_clearNext(self, current);

	entry = current;
	while (1) {
		from = entry->mixingFrom;
		if (!from) break;
		_sp40EventQueue_end(internal->queue, from);
		entry->mixingFrom = 0;
		entry->mixingTo = 0;
		entry = from;
	}

	self->tracks[current->trackIndex] = 0;
	_sp40EventQueue_drain(internal->queue);
}

void _sp40AnimationState_setCurrent(sp40AnimationState *self, int index, sp40TrackEntry *current, int /*boolean*/ interrupt) {
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
	sp40TrackEntry *from = _sp40AnimationState_expandToIndex(self, index);
	self->tracks[index] = current;
	current->previous = NULL;

	if (from) {
		if (interrupt) _sp40EventQueue_interrupt(internal->queue, from);
		current->mixingFrom = from;
		from->mixingTo = current;
		current->mixTime = 0;

		/* Store the interrupted mix percentage. */
		if (from->mixingFrom != 0 && from->mixDuration > 0)
			current->interruptAlpha *= MIN(1, from->mixTime / from->mixDuration);

		from->timelinesRotationCount = 0;
	}

	_sp40EventQueue_start(internal->queue, current);
}

/** Set the current animation. Any queued animations are cleared. */
sp40TrackEntry *sp40AnimationState_setAnimationByName(sp40AnimationState *self, int trackIndex, const char *animationName,
												  int /*bool*/ loop) {
	sp40Animation *animation = sp40SkeletonData_findAnimation(self->data->skeletonData, animationName);
	return sp40AnimationState_setAnimation(self, trackIndex, animation, loop);
}

sp40TrackEntry *
sp40AnimationState_setAnimation(sp40AnimationState *self, int trackIndex, sp40Animation *animation, int /*bool*/ loop) {
	sp40TrackEntry *entry;
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
	int interrupt = 1;
	sp40TrackEntry *current = _sp40AnimationState_expandToIndex(self, trackIndex);
	if (current) {
		if (current->nextTrackLast == -1) {
			/* Don't mix from an entry that was never applied. */
			self->tracks[trackIndex] = current->mixingFrom;
			_sp40EventQueue_interrupt(internal->queue, current);
			_sp40EventQueue_end(internal->queue, current);
			sp40AnimationState_clearNext(self, current);
			current = current->mixingFrom;
			interrupt = 0;
		} else
			sp40AnimationState_clearNext(self, current);
	}
	entry = _sp40AnimationState_trackEntry(self, trackIndex, animation, loop, current);
	_sp40AnimationState_setCurrent(self, trackIndex, entry, interrupt);
	_sp40EventQueue_drain(internal->queue);
	return entry;
}

/** Adds an animation to be played delay seconds after the current or last queued animation, taking into account any mix
 * duration. */
sp40TrackEntry *sp40AnimationState_addAnimationByName(sp40AnimationState *self, int trackIndex, const char *animationName,
												  int /*bool*/ loop, float delay) {
	sp40Animation *animation = sp40SkeletonData_findAnimation(self->data->skeletonData, animationName);
	return sp40AnimationState_addAnimation(self, trackIndex, animation, loop, delay);
}

sp40TrackEntry *
sp40AnimationState_addAnimation(sp40AnimationState *self, int trackIndex, sp40Animation *animation, int /*bool*/ loop,
							  float delay) {
	sp40TrackEntry *entry;
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
	sp40TrackEntry *last = _sp40AnimationState_expandToIndex(self, trackIndex);
	if (last) {
		while (last->next)
			last = last->next;
	}

	entry = _sp40AnimationState_trackEntry(self, trackIndex, animation, loop, last);

	if (!last) {
		_sp40AnimationState_setCurrent(self, trackIndex, entry, 1);
		_sp40EventQueue_drain(internal->queue);
	} else {
		last->next = entry;
		entry->previous = last;
		if (delay <= 0) delay += sp40TrackEntry_getTrackComplete(last) - entry->mixDuration;
	}

	entry->delay = delay;
	return entry;
}

sp40TrackEntry *sp40AnimationState_setEmptyAnimation(sp40AnimationState *self, int trackIndex, float mixDuration) {
	sp40TrackEntry *entry = sp40AnimationState_setAnimation(self, trackIndex, SP_EMPTY_ANIMATION, 0);
	entry->mixDuration = mixDuration;
	entry->trackEnd = mixDuration;
	return entry;
}

sp40TrackEntry *
sp40AnimationState_addEmptyAnimation(sp40AnimationState *self, int trackIndex, float mixDuration, float delay) {
	sp40TrackEntry *entry = sp40AnimationState_addAnimation(self, trackIndex, SP_EMPTY_ANIMATION, 0, delay);
	if (delay <= 0) entry->delay += entry->mixDuration - mixDuration;
	entry->mixDuration = mixDuration;
	entry->trackEnd = mixDuration;
	return entry;
}

void sp40AnimationState_setEmptyAnimations(sp40AnimationState *self, float mixDuration) {
	int i, n, oldDrainDisabled;
	sp40TrackEntry *current;
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
	oldDrainDisabled = internal->queue->drainDisabled;
	internal->queue->drainDisabled = 1;
	for (i = 0, n = self->tracksCount; i < n; i++) {
		current = self->tracks[i];
		if (current) sp40AnimationState_setEmptyAnimation(self, current->trackIndex, mixDuration);
	}
	internal->queue->drainDisabled = oldDrainDisabled;
	_sp40EventQueue_drain(internal->queue);
}

sp40TrackEntry *_sp40AnimationState_expandToIndex(sp40AnimationState *self, int index) {
	sp40TrackEntry **newTracks;
	if (index < self->tracksCount) return self->tracks[index];
	newTracks = CALLOC(sp40TrackEntry *, index + 1);
	memcpy(newTracks, self->tracks, self->tracksCount * sizeof(sp40TrackEntry *));
	FREE(self->tracks);
	self->tracks = newTracks;
	self->tracksCount = index + 1;
	return 0;
}

sp40TrackEntry *
_sp40AnimationState_trackEntry(sp40AnimationState *self, int trackIndex, sp40Animation *animation, int /*boolean*/ loop,
							 sp40TrackEntry *last) {
	sp40TrackEntry *entry = NEW(sp40TrackEntry);
	entry->trackIndex = trackIndex;
	entry->animation = animation;
	entry->loop = loop;
	entry->holdPrevious = 0;
	entry->reverse = 0;
	entry->previous = 0;
	entry->next = 0;

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
	entry->trackEnd = (float) INT_MAX;
	entry->timeScale = 1;

	entry->alpha = 1;
	entry->interruptAlpha = 1;
	entry->mixTime = 0;
	entry->mixDuration = !last ? 0 : sp40AnimationStateData_getMix(self->data, last->animation, animation);
	entry->mixBlend = SP_MIX_BLEND_REPLACE;

	entry->timelineMode = sp40IntArray_create(16);
	entry->timelineHoldMix = sp40TrackEntryArray_create(16);

	return entry;
}

void sp40AnimationState_clearNext(sp40AnimationState *self, sp40TrackEntry *entry) {
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
	sp40TrackEntry *next = entry->next;
	while (next) {
		_sp40EventQueue_dispose(internal->queue, next);
		next = next->next;
	}
	entry->next = 0;
}

void _sp40AnimationState_animationsChanged(sp40AnimationState *self) {
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
	int i, n;
	sp40TrackEntry *entry;
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
			if (entry->mixingTo == 0 || entry->mixBlend != SP_MIX_BLEND_ADD) _sp40TrackEntry_computeHold(entry, self);
			entry = entry->mixingTo;
		} while (entry != 0);
	}
}

float *_sp40AnimationState_resizeTimelinesRotation(sp40TrackEntry *entry, int newSize) {
	if (entry->timelinesRotationCount != newSize) {
		float *newTimelinesRotation = CALLOC(float, newSize);
		FREE(entry->timelinesRotation);
		entry->timelinesRotation = newTimelinesRotation;
		entry->timelinesRotationCount = newSize;
	}
	return entry->timelinesRotation;
}

void _sp40AnimationState_ensureCapacityPropertyIDs(sp40AnimationState *self, int capacity) {
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
	if (internal->propertyIDsCapacity < capacity) {
		sp40PropertyId *newPropertyIDs = CALLOC(sp40PropertyId, capacity << 1);
		memcpy(newPropertyIDs, internal->propertyIDs, sizeof(sp40PropertyId) * internal->propertyIDsCount);
		FREE(internal->propertyIDs);
		internal->propertyIDs = newPropertyIDs;
		internal->propertyIDsCapacity = capacity << 1;
	}
}

int _sp40AnimationState_addPropertyID(sp40AnimationState *self, sp40PropertyId id) {
	int i, n;
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);

	for (i = 0, n = internal->propertyIDsCount; i < n; i++) {
		if (internal->propertyIDs[i] == id) return 0;
	}

	_sp40AnimationState_ensureCapacityPropertyIDs(self, internal->propertyIDsCount + 1);
	internal->propertyIDs[internal->propertyIDsCount] = id;
	internal->propertyIDsCount++;
	return 1;
}

int _sp40AnimationState_addPropertyIDs(sp40AnimationState *self, sp40PropertyId *ids, int numIds) {
	int i, n;
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
	int oldSize = internal->propertyIDsCount;

	for (i = 0, n = numIds; i < n; i++) {
		_sp40AnimationState_addPropertyID(self, ids[i]);
	}

	return internal->propertyIDsCount != oldSize;
}

sp40TrackEntry *sp40AnimationState_getCurrent(sp40AnimationState *self, int trackIndex) {
	if (trackIndex >= self->tracksCount) return 0;
	return self->tracks[trackIndex];
}

void sp40AnimationState_clearListenerNotifications(sp40AnimationState *self) {
	_sp40AnimationState *internal = SUB_CAST(_sp40AnimationState, self);
	_sp40EventQueue_clear(internal->queue);
}

float sp40TrackEntry_getAnimationTime(sp40TrackEntry *entry) {
	if (entry->loop) {
		float duration = entry->animationEnd - entry->animationStart;
		if (duration == 0) return entry->animationStart;
		return FMOD(entry->trackTime, duration) + entry->animationStart;
	}
	return MIN(entry->trackTime + entry->animationStart, entry->animationEnd);
}

float sp40TrackEntry_getTrackComplete(sp40TrackEntry *entry) {
	float duration = entry->animationEnd - entry->animationStart;
	if (duration != 0) {
		if (entry->loop) return duration * (1 + (int) (entry->trackTime / duration)); /* Completion of next loop. */
		if (entry->trackTime < duration) return duration;                             /* Before duration. */
	}
	return entry->trackTime; /* Next update. */
}

void _sp40TrackEntry_computeHold(sp40TrackEntry *entry, sp40AnimationState *state) {
	sp40TrackEntry *to;
	sp40Timeline **timelines;
	int timelinesCount;
	int *timelineMode;
	sp40TrackEntry **timelineHoldMix;
	sp40TrackEntry *next;
	int i;

	to = entry->mixingTo;
	timelines = entry->animation->timelines->items;
	timelinesCount = entry->animation->timelines->size;
	timelineMode = sp40IntArray_setSize(entry->timelineMode, timelinesCount)->items;
	sp40TrackEntryArray_clear(entry->timelineHoldMix);
	timelineHoldMix = sp40TrackEntryArray_setSize(entry->timelineHoldMix, timelinesCount)->items;

	if (to != 0 && to->holdPrevious) {
		for (i = 0; i < timelinesCount; i++) {
			sp40PropertyId *ids = timelines[i]->propertyIds;
			int numIds = timelines[i]->propertyIdsCount;
			timelineMode[i] = _sp40AnimationState_addPropertyIDs(state, ids, numIds) ? HOLD_FIRST : HOLD_SUBSEQUENT;
		}
		return;
	}

	i = 0;
continue_outer:
	for (; i < timelinesCount; i++) {
		sp40Timeline *timeline = timelines[i];
		sp40PropertyId *ids = timeline->propertyIds;
		int numIds = timeline->propertyIdsCount;
		if (!_sp40AnimationState_addPropertyIDs(state, ids, numIds))
			timelineMode[i] = SUBSEQUENT;
		else if (to == 0 || timeline->propertyIds[0] == SP_PROPERTY_ATTACHMENT ||
				 timeline->propertyIds[0] == SP_PROPERTY_DRAWORDER ||
				 timeline->propertyIds[0] == SP_PROPERTY_EVENT ||
				 !sp40Animation_hasTimeline(to->animation, ids, numIds)) {
			timelineMode[i] = FIRST;
		} else {
			for (next = to->mixingTo; next != 0; next = next->mixingTo) {
				if (sp40Animation_hasTimeline(next->animation, ids, numIds)) continue;
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

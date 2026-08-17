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

#include <spine/Animation.h>
#include <spine/IkConstraint.h>
#include <limits.h>
#include <spine/extension.h>

sp21Animation* sp21Animation_create (const char* name, int timelinesCount) {
	sp21Animation* self = NEW(sp21Animation);
	MALLOC_STR(self->name, name);
	self->timelinesCount = timelinesCount;
	self->timelines = MALLOC(sp21Timeline*, timelinesCount);
	return self;
}

void sp21Animation_dispose (sp21Animation* self) {
	int i;
	for (i = 0; i < self->timelinesCount; ++i)
		sp21Timeline_dispose(self->timelines[i]);
	FREE(self->timelines);
	FREE(self->name);
	FREE(self);
}

void sp21Animation_apply (const sp21Animation* self, sp21Skeleton* skeleton, float lastTime, float time, int loop, sp21Event** events,
		int* eventsCount) {
	int i, n = self->timelinesCount;

	if (loop && self->duration) {
		time = FMOD(time, self->duration);
		lastTime = FMOD(lastTime, self->duration);
	}

	for (i = 0; i < n; ++i)
		sp21Timeline_apply(self->timelines[i], skeleton, lastTime, time, events, eventsCount, 1);
}

void sp21Animation_mix (const sp21Animation* self, sp21Skeleton* skeleton, float lastTime, float time, int loop, sp21Event** events,
		int* eventsCount, float alpha) {
	int i, n = self->timelinesCount;

	if (loop && self->duration) {
		time = FMOD(time, self->duration);
		lastTime = FMOD(lastTime, self->duration);
	}

	for (i = 0; i < n; ++i)
		sp21Timeline_apply(self->timelines[i], skeleton, lastTime, time, events, eventsCount, alpha);
}

/**/

typedef struct _sp21TimelineVtable {
	void (*apply) (const sp21Timeline* self, sp21Skeleton* skeleton, float lastTime, float time, sp21Event** firedEvents,
			int* eventsCount, float alpha);
	void (*dispose) (sp21Timeline* self);
} _sp21TimelineVtable;

void _sp21Timeline_init (sp21Timeline* self, sp21TimelineType type, /**/
void (*dispose) (sp21Timeline* self), /**/
		void (*apply) (const sp21Timeline* self, sp21Skeleton* skeleton, float lastTime, float time, sp21Event** firedEvents,
				int* eventsCount, float alpha)) {
	CONST_CAST(sp21TimelineType, self->type) = type;
	CONST_CAST(_sp21TimelineVtable*, self->vtable) = NEW(_sp21TimelineVtable);
	VTABLE(sp21Timeline, self)->dispose = dispose;
	VTABLE(sp21Timeline, self)->apply = apply;
}

void _sp21Timeline_deinit (sp21Timeline* self) {
	FREE(self->vtable);
}

void sp21Timeline_dispose (sp21Timeline* self) {
	VTABLE(sp21Timeline, self)->dispose(self);
}

void sp21Timeline_apply (const sp21Timeline* self, sp21Skeleton* skeleton, float lastTime, float time, sp21Event** firedEvents,
		int* eventsCount, float alpha) {
	VTABLE(sp21Timeline, self)->apply(self, skeleton, lastTime, time, firedEvents, eventsCount, alpha);
}

/**/

static const float CURVE_LINEAR = 0, CURVE_STEPPED = 1, CURVE_BEZIER = 2;
static const int BEZIER_SEGMENTS = 10, BEZIER_SIZE = 10 * 2 - 1;

void _sp21CurveTimeline_init (sp21CurveTimeline* self, sp21TimelineType type, int framesCount, /**/
void (*dispose) (sp21Timeline* self), /**/
		void (*apply) (const sp21Timeline* self, sp21Skeleton* skeleton, float lastTime, float time, sp21Event** firedEvents,
				int* eventsCount, float alpha)) {
	_sp21Timeline_init(SUPER(self), type, dispose, apply);
	self->curves = CALLOC(float, (framesCount - 1) * BEZIER_SIZE);
}

void _sp21CurveTimeline_deinit (sp21CurveTimeline* self) {
	_sp21Timeline_deinit(SUPER(self));
	FREE(self->curves);
}

void sp21CurveTimeline_setLinear (sp21CurveTimeline* self, int frameIndex) {
	self->curves[frameIndex * BEZIER_SIZE] = CURVE_LINEAR;
}

void sp21CurveTimeline_setStepped (sp21CurveTimeline* self, int frameIndex) {
	self->curves[frameIndex * BEZIER_SIZE] = CURVE_STEPPED;
}

void sp21CurveTimeline_setCurve (sp21CurveTimeline* self, int frameIndex, float cx1, float cy1, float cx2, float cy2) {
	float subdiv1 = 1.0f / BEZIER_SEGMENTS, subdiv2 = subdiv1 * subdiv1, subdiv3 = subdiv2 * subdiv1;
	float pre1 = 3 * subdiv1, pre2 = 3 * subdiv2, pre4 = 6 * subdiv2, pre5 = 6 * subdiv3;
	float tmp1x = -cx1 * 2 + cx2, tmp1y = -cy1 * 2 + cy2, tmp2x = (cx1 - cx2) * 3 + 1, tmp2y = (cy1 - cy2) * 3 + 1;
	float dfx = cx1 * pre1 + tmp1x * pre2 + tmp2x * subdiv3, dfy = cy1 * pre1 + tmp1y * pre2 + tmp2y * subdiv3;
	float ddfx = tmp1x * pre4 + tmp2x * pre5, ddfy = tmp1y * pre4 + tmp2y * pre5;
	float dddfx = tmp2x * pre5, dddfy = tmp2y * pre5;
	float x = dfx, y = dfy;

	int i = frameIndex * BEZIER_SIZE, n = i + BEZIER_SIZE - 1;
	self->curves[i++] = CURVE_BEZIER;

	for (; i < n; i += 2) {
		self->curves[i] = x;
		self->curves[i + 1] = y;
		dfx += ddfx;
		dfy += ddfy;
		ddfx += dddfx;
		ddfy += dddfy;
		x += dfx;
		y += dfy;
	}
}

float sp21CurveTimeline_getCurvePercent (const sp21CurveTimeline* self, int frameIndex, float percent) {
	float x, y;
	int i = frameIndex * BEZIER_SIZE, start, n;
	float type = self->curves[i];
	if (type == CURVE_LINEAR) return percent;
	if (type == CURVE_STEPPED) return 0;
	i++;
	x = 0;
	for (start = i, n = i + BEZIER_SIZE - 1; i < n; i += 2) {
		x = self->curves[i];
		if (x >= percent) {
			float prevX, prevY;
			if (i == start) {
				prevX = 0;
				prevY = 0;
			} else {
				prevX = self->curves[i - 2];
				prevY = self->curves[i - 1];
			}
			return prevY + (self->curves[i + 1] - prevY) * (percent - prevX) / (x - prevX);
		}
	}
	y = self->curves[i - 1];
	return y + (1 - y) * (percent - x) / (1 - x); /* Last point is 1,1. */
}

/* @param target After the first and before the last entry. */
static int binarySearch (float *values, int valuesLength, float target, int step) {
	int low = 0, current;
	int high = valuesLength / step - 2;
	if (high == 0) return step;
	current = high >> 1;
	while (1) {
		if (values[(current + 1) * step] <= target)
			low = current + 1;
		else
			high = current;
		if (low == high) return (low + 1) * step;
		current = (low + high) >> 1;
	}
	return 0;
}

/* @param target After the first and before the last entry. */
static int binarySearch1 (float *values, int valuesLength, float target) {
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

/*static int linearSearch (float *values, int valuesLength, float target, int step) {
 int i, last = valuesLength - step;
 for (i = 0; i <= last; i += step) {
 if (values[i] <= target) continue;
 return i;
 }
 return -1;
 }*/

/**/

void _sp21BaseTimeline_dispose (sp21Timeline* timeline) {
	struct sp21BaseTimeline* self = SUB_CAST(struct sp21BaseTimeline, timeline);
	_sp21CurveTimeline_deinit(SUPER(self));
	FREE(self->frames);
	FREE(self);
}

/* Many timelines have structure identical to struct sp21BaseTimeline and extend sp21CurveTimeline. **/
struct sp21BaseTimeline* _sp21BaseTimeline_create (int framesCount, sp21TimelineType type, int frameSize, /**/
		void (*apply) (const sp21Timeline* self, sp21Skeleton* skeleton, float lastTime, float time, sp21Event** firedEvents,
				int* eventsCount, float alpha)) {
	struct sp21BaseTimeline* self = NEW(struct sp21BaseTimeline);
	_sp21CurveTimeline_init(SUPER(self), type, framesCount, _sp21BaseTimeline_dispose, apply);

	CONST_CAST(int, self->framesCount) = framesCount * frameSize;
	CONST_CAST(float*, self->frames) = CALLOC(float, self->framesCount);

	return self;
}

/**/

static const int ROTATE_PREV_FRAME_TIME = -2;
static const int ROTATE_FRAME_VALUE = 1;

void _sp21RotateTimeline_apply (const sp21Timeline* timeline, sp21Skeleton* skeleton, float lastTime, float time, sp21Event** firedEvents,
		int* eventsCount, float alpha) {
	sp21Bone *bone;
	int frameIndex;
	float prevFrameValue, frameTime, percent, amount;

	sp21RotateTimeline* self = SUB_CAST(sp21RotateTimeline, timeline);

	if (time < self->frames[0]) return; /* Time is before first frame. */

	bone = skeleton->bones[self->boneIndex];

	if (time >= self->frames[self->framesCount - 2]) { /* Time is after last frame. */
		float amount = bone->data->rotation + self->frames[self->framesCount - 1] - bone->rotation;
		while (amount > 180)
			amount -= 360;
		while (amount < -180)
			amount += 360;
		bone->rotation += amount * alpha;
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frameIndex = binarySearch(self->frames, self->framesCount, time, 2);
	prevFrameValue = self->frames[frameIndex - 1];
	frameTime = self->frames[frameIndex];
	percent = 1 - (time - frameTime) / (self->frames[frameIndex + ROTATE_PREV_FRAME_TIME] - frameTime);
	percent = sp21CurveTimeline_getCurvePercent(SUPER(self), (frameIndex >> 1) - 1, percent < 0 ? 0 : (percent > 1 ? 1 : percent));

	amount = self->frames[frameIndex + ROTATE_FRAME_VALUE] - prevFrameValue;
	while (amount > 180)
		amount -= 360;
	while (amount < -180)
		amount += 360;
	amount = bone->data->rotation + (prevFrameValue + amount * percent) - bone->rotation;
	while (amount > 180)
		amount -= 360;
	while (amount < -180)
		amount += 360;
	bone->rotation += amount * alpha;
}

sp21RotateTimeline* sp21RotateTimeline_create (int framesCount) {
	return _sp21BaseTimeline_create(framesCount, SP_TIMELINE_ROTATE, 2, _sp21RotateTimeline_apply);
}

void sp21RotateTimeline_setFrame (sp21RotateTimeline* self, int frameIndex, float time, float angle) {
	frameIndex *= 2;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + 1] = angle;
}

/**/

static const int TRANSLATE_PREV_FRAME_TIME = -3;
static const int TRANSLATE_FRAME_X = 1;
static const int TRANSLATE_FRAME_Y = 2;

void _sp21TranslateTimeline_apply (const sp21Timeline* timeline, sp21Skeleton* skeleton, float lastTime, float time,
		sp21Event** firedEvents, int* eventsCount, float alpha) {
	sp21Bone *bone;
	int frameIndex;
	float prevFrameX, prevFrameY, frameTime, percent;

	sp21TranslateTimeline* self = SUB_CAST(sp21TranslateTimeline, timeline);

	if (time < self->frames[0]) return; /* Time is before first frame. */

	bone = skeleton->bones[self->boneIndex];

	if (time >= self->frames[self->framesCount - 3]) { /* Time is after last frame. */
		bone->x += (bone->data->x + self->frames[self->framesCount - 2] - bone->x) * alpha;
		bone->y += (bone->data->y + self->frames[self->framesCount - 1] - bone->y) * alpha;
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frameIndex = binarySearch(self->frames, self->framesCount, time, 3);
	prevFrameX = self->frames[frameIndex - 2];
	prevFrameY = self->frames[frameIndex - 1];
	frameTime = self->frames[frameIndex];
	percent = 1 - (time - frameTime) / (self->frames[frameIndex + TRANSLATE_PREV_FRAME_TIME] - frameTime);
	percent = sp21CurveTimeline_getCurvePercent(SUPER(self), frameIndex / 3 - 1, percent < 0 ? 0 : (percent > 1 ? 1 : percent));

	bone->x += (bone->data->x + prevFrameX + (self->frames[frameIndex + TRANSLATE_FRAME_X] - prevFrameX) * percent - bone->x)
			* alpha;
	bone->y += (bone->data->y + prevFrameY + (self->frames[frameIndex + TRANSLATE_FRAME_Y] - prevFrameY) * percent - bone->y)
			* alpha;
}

sp21TranslateTimeline* sp21TranslateTimeline_create (int framesCount) {
	return _sp21BaseTimeline_create(framesCount, SP_TIMELINE_TRANSLATE, 3, _sp21TranslateTimeline_apply);
}

void sp21TranslateTimeline_setFrame (sp21TranslateTimeline* self, int frameIndex, float time, float x, float y) {
	frameIndex *= 3;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + 1] = x;
	self->frames[frameIndex + 2] = y;
}

/**/

void _sp21ScaleTimeline_apply (const sp21Timeline* timeline, sp21Skeleton* skeleton, float lastTime, float time, sp21Event** firedEvents,
		int* eventsCount, float alpha) {
	sp21Bone *bone;
	int frameIndex;
	float prevFrameX, prevFrameY, frameTime, percent;

	sp21ScaleTimeline* self = SUB_CAST(sp21ScaleTimeline, timeline);

	if (time < self->frames[0]) return; /* Time is before first frame. */

	bone = skeleton->bones[self->boneIndex];
	if (time >= self->frames[self->framesCount - 3]) { /* Time is after last frame. */
		bone->scaleX += (bone->data->scaleX * self->frames[self->framesCount - 2] - bone->scaleX) * alpha;
		bone->scaleY += (bone->data->scaleY * self->frames[self->framesCount - 1] - bone->scaleY) * alpha;
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frameIndex = binarySearch(self->frames, self->framesCount, time, 3);
	prevFrameX = self->frames[frameIndex - 2];
	prevFrameY = self->frames[frameIndex - 1];
	frameTime = self->frames[frameIndex];
	percent = 1 - (time - frameTime) / (self->frames[frameIndex + TRANSLATE_PREV_FRAME_TIME] - frameTime);
	percent = sp21CurveTimeline_getCurvePercent(SUPER(self), frameIndex / 3 - 1, percent < 0 ? 0 : (percent > 1 ? 1 : percent));

	bone->scaleX += (bone->data->scaleX * (prevFrameX + (self->frames[frameIndex + TRANSLATE_FRAME_X] - prevFrameX) * percent)
			- bone->scaleX) * alpha;
	bone->scaleY += (bone->data->scaleY * (prevFrameY + (self->frames[frameIndex + TRANSLATE_FRAME_Y] - prevFrameY) * percent)
			- bone->scaleY) * alpha;
}

sp21ScaleTimeline* sp21ScaleTimeline_create (int framesCount) {
	return _sp21BaseTimeline_create(framesCount, SP_TIMELINE_SCALE, 3, _sp21ScaleTimeline_apply);
}

void sp21ScaleTimeline_setFrame (sp21ScaleTimeline* self, int frameIndex, float time, float x, float y) {
	sp21TranslateTimeline_setFrame(self, frameIndex, time, x, y);
}

/**/

static const int COLOR_PREV_FRAME_TIME = -5;
static const int COLOR_FRAME_R = 1;
static const int COLOR_FRAME_G = 2;
static const int COLOR_FRAME_B = 3;
static const int COLOR_FRAME_A = 4;

void _sp21ColorTimeline_apply (const sp21Timeline* timeline, sp21Skeleton* skeleton, float lastTime, float time, sp21Event** firedEvents,
		int* eventsCount, float alpha) {
	sp21Slot *slot;
	int frameIndex;
	float prevFrameR, prevFrameG, prevFrameB, prevFrameA, percent, frameTime;
	float r, g, b, a;
	sp21ColorTimeline* self = (sp21ColorTimeline*)timeline;

	if (time < self->frames[0]) return; /* Time is before first frame. */

	if (time >= self->frames[self->framesCount - 5]) {
		/* Time is after last frame. */
		int i = self->framesCount - 1;
		r = self->frames[i - 3];
		g = self->frames[i - 2];
		b = self->frames[i - 1];
		a = self->frames[i];
	} else {
		/* Interpolate between the previous frame and the current frame. */
		frameIndex = binarySearch(self->frames, self->framesCount, time, 5);
		prevFrameR = self->frames[frameIndex - 4];
		prevFrameG = self->frames[frameIndex - 3];
		prevFrameB = self->frames[frameIndex - 2];
		prevFrameA = self->frames[frameIndex - 1];
		frameTime = self->frames[frameIndex];
		percent = 1 - (time - frameTime) / (self->frames[frameIndex + COLOR_PREV_FRAME_TIME] - frameTime);
		percent = sp21CurveTimeline_getCurvePercent(SUPER(self), frameIndex / 5 - 1, percent < 0 ? 0 : (percent > 1 ? 1 : percent));

		r = prevFrameR + (self->frames[frameIndex + COLOR_FRAME_R] - prevFrameR) * percent;
		g = prevFrameG + (self->frames[frameIndex + COLOR_FRAME_G] - prevFrameG) * percent;
		b = prevFrameB + (self->frames[frameIndex + COLOR_FRAME_B] - prevFrameB) * percent;
		a = prevFrameA + (self->frames[frameIndex + COLOR_FRAME_A] - prevFrameA) * percent;
	}
	slot = skeleton->slots[self->slotIndex];
	if (alpha < 1) {
		slot->r += (r - slot->r) * alpha;
		slot->g += (g - slot->g) * alpha;
		slot->b += (b - slot->b) * alpha;
		slot->a += (a - slot->a) * alpha;
	} else {
		slot->r = r;
		slot->g = g;
		slot->b = b;
		slot->a = a;
	}
}

sp21ColorTimeline* sp21ColorTimeline_create (int framesCount) {
	return (sp21ColorTimeline*)_sp21BaseTimeline_create(framesCount, SP_TIMELINE_COLOR, 5, _sp21ColorTimeline_apply);
}

void sp21ColorTimeline_setFrame (sp21ColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a) {
	frameIndex *= 5;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + 1] = r;
	self->frames[frameIndex + 2] = g;
	self->frames[frameIndex + 3] = b;
	self->frames[frameIndex + 4] = a;
}

/**/

void _sp21AttachmentTimeline_apply (const sp21Timeline* timeline, sp21Skeleton* skeleton, float lastTime, float time,
		sp21Event** firedEvents, int* eventsCount, float alpha) {
	int frameIndex;
	const char* attachmentName;
	sp21AttachmentTimeline* self = (sp21AttachmentTimeline*)timeline;

	if (time < self->frames[0]) {
		if (lastTime > time) _sp21AttachmentTimeline_apply(timeline, skeleton, lastTime, (float)INT_MAX, 0, 0, 0);
		return;
	} else if (lastTime > time) /**/
		lastTime = -1;

	frameIndex = time >= self->frames[self->framesCount - 1] ?
		self->framesCount - 1 : binarySearch1(self->frames, self->framesCount, time) - 1;
	if (self->frames[frameIndex] < lastTime) return;

	attachmentName = self->attachmentNames[frameIndex];
	sp21Slot_setAttachment(skeleton->slots[self->slotIndex],
			attachmentName ? sp21Skeleton_getAttachmentForSlotIndex(skeleton, self->slotIndex, attachmentName) : 0);
}

void _sp21AttachmentTimeline_dispose (sp21Timeline* timeline) {
	sp21AttachmentTimeline* self = SUB_CAST(sp21AttachmentTimeline, timeline);
	int i;

	_sp21Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->attachmentNames[i]);
	FREE(self->attachmentNames);
	FREE(self->frames);
	FREE(self);
}

sp21AttachmentTimeline* sp21AttachmentTimeline_create (int framesCount) {
	sp21AttachmentTimeline* self = NEW(sp21AttachmentTimeline);
	_sp21Timeline_init(SUPER(self), SP_TIMELINE_ATTACHMENT, _sp21AttachmentTimeline_dispose, _sp21AttachmentTimeline_apply);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(char**, self->attachmentNames) = CALLOC(char*, framesCount);

	return self;
}

void sp21AttachmentTimeline_setFrame (sp21AttachmentTimeline* self, int frameIndex, float time, const char* attachmentName) {
	self->frames[frameIndex] = time;

	FREE(self->attachmentNames[frameIndex]);
	if (attachmentName)
		MALLOC_STR(self->attachmentNames[frameIndex], attachmentName);
	else
		self->attachmentNames[frameIndex] = 0;
}

/**/

/** Fires events for frames > lastTime and <= time. */
void _sp21EventTimeline_apply (const sp21Timeline* timeline, sp21Skeleton* skeleton, float lastTime, float time, sp21Event** firedEvents,
		int* eventsCount, float alpha) {
	sp21EventTimeline* self = (sp21EventTimeline*)timeline;
	int frameIndex;
	if (!firedEvents) return;

	if (lastTime > time) { /* Fire events after last time for looped animations. */
		_sp21EventTimeline_apply(timeline, skeleton, lastTime, (float)INT_MAX, firedEvents, eventsCount, alpha);
		lastTime = -1;
	} else if (lastTime >= self->frames[self->framesCount - 1]) /* Last time is after last frame. */
	return;
	if (time < self->frames[0]) return; /* Time is before first frame. */

	if (lastTime < self->frames[0])
		frameIndex = 0;
	else {
		float frame;
		frameIndex = binarySearch1(self->frames, self->framesCount, lastTime);
		frame = self->frames[frameIndex];
		while (frameIndex > 0) { /* Fire multiple events with the same frame. */
			if (self->frames[frameIndex - 1] != frame) break;
			frameIndex--;
		}
	}
	for (; frameIndex < self->framesCount && time >= self->frames[frameIndex]; ++frameIndex) {
		firedEvents[*eventsCount] = self->events[frameIndex];
		(*eventsCount)++;
	}
}

void _sp21EventTimeline_dispose (sp21Timeline* timeline) {
	sp21EventTimeline* self = SUB_CAST(sp21EventTimeline, timeline);
	int i;

	_sp21Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		sp21Event_dispose(self->events[i]);
	FREE(self->events);
	FREE(self->frames);
	FREE(self);
}

sp21EventTimeline* sp21EventTimeline_create (int framesCount) {
	sp21EventTimeline* self = NEW(sp21EventTimeline);
	_sp21Timeline_init(SUPER(self), SP_TIMELINE_EVENT, _sp21EventTimeline_dispose, _sp21EventTimeline_apply);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(sp21Event**, self->events) = CALLOC(sp21Event*, framesCount);

	return self;
}

void sp21EventTimeline_setFrame (sp21EventTimeline* self, int frameIndex, float time, sp21Event* event) {
	self->frames[frameIndex] = time;

	FREE(self->events[frameIndex]);
	self->events[frameIndex] = event;
}

/**/

void _sp21DrawOrderTimeline_apply (const sp21Timeline* timeline, sp21Skeleton* skeleton, float lastTime, float time,
		sp21Event** firedEvents, int* eventsCount, float alpha) {
	int i;
	int frameIndex;
	const int* drawOrderToSetupIndex;
	sp21DrawOrderTimeline* self = (sp21DrawOrderTimeline*)timeline;

	if (time < self->frames[0]) return; /* Time is before first frame. */

	if (time >= self->frames[self->framesCount - 1]) /* Time is after last frame. */
		frameIndex = self->framesCount - 1;
	else
		frameIndex = binarySearch1(self->frames, self->framesCount, time) - 1;

	drawOrderToSetupIndex = self->drawOrders[frameIndex];
	if (!drawOrderToSetupIndex)
		memcpy(skeleton->drawOrder, skeleton->slots, self->slotsCount * sizeof(sp21Slot*));
	else {
		for (i = 0; i < self->slotsCount; ++i)
			skeleton->drawOrder[i] = skeleton->slots[drawOrderToSetupIndex[i]];
	}
}

void _sp21DrawOrderTimeline_dispose (sp21Timeline* timeline) {
	sp21DrawOrderTimeline* self = SUB_CAST(sp21DrawOrderTimeline, timeline);
	int i;

	_sp21Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->drawOrders[i]);
	FREE(self->drawOrders);
	FREE(self->frames);
	FREE(self);
}

sp21DrawOrderTimeline* sp21DrawOrderTimeline_create (int framesCount, int slotsCount) {
	sp21DrawOrderTimeline* self = NEW(sp21DrawOrderTimeline);
	_sp21Timeline_init(SUPER(self), SP_TIMELINE_DRAWORDER, _sp21DrawOrderTimeline_dispose, _sp21DrawOrderTimeline_apply);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(int**, self->drawOrders) = CALLOC(int*, framesCount);
	CONST_CAST(int, self->slotsCount) = slotsCount;

	return self;
}

void sp21DrawOrderTimeline_setFrame (sp21DrawOrderTimeline* self, int frameIndex, float time, const int* drawOrder) {
	self->frames[frameIndex] = time;

	FREE(self->drawOrders[frameIndex]);
	if (!drawOrder)
		self->drawOrders[frameIndex] = 0;
	else {
		self->drawOrders[frameIndex] = MALLOC(int, self->slotsCount);
		memcpy(CONST_CAST(int*, self->drawOrders[frameIndex]), drawOrder, self->slotsCount * sizeof(int));
	}
}

/**/

void _sp21FFDTimeline_apply (const sp21Timeline* timeline, sp21Skeleton* skeleton, float lastTime, float time, sp21Event** firedEvents,
		int* eventsCount, float alpha) {
	int frameIndex, i;
	float percent, frameTime;
	const float* prevVertices;
	const float* nextVertices;
	sp21FFDTimeline* self = (sp21FFDTimeline*)timeline;

	sp21Slot *slot = skeleton->slots[self->slotIndex];
	if (slot->attachment != self->attachment) return;

	if (time < self->frames[0]) return; /* Time is before first frame. */

	if (slot->attachmentVerticesCount < self->frameVerticesCount) {
		if (slot->attachmentVerticesCapacity < self->frameVerticesCount) {
			FREE(slot->attachmentVertices);
			slot->attachmentVertices = MALLOC(float, self->frameVerticesCount);
			slot->attachmentVerticesCapacity = self->frameVerticesCount;
		}
	}
	if (slot->attachmentVerticesCount != self->frameVerticesCount) alpha = 1; /* Don't mix from uninitialized slot vertices. */
	slot->attachmentVerticesCount = self->frameVerticesCount;

	if (time >= self->frames[self->framesCount - 1]) {
		/* Time is after last frame. */
		const float* lastVertices = self->frameVertices[self->framesCount - 1];
		if (alpha < 1) {
			for (i = 0; i < self->frameVerticesCount; ++i)
				slot->attachmentVertices[i] += (lastVertices[i] - slot->attachmentVertices[i]) * alpha;
		} else
			memcpy(slot->attachmentVertices, lastVertices, self->frameVerticesCount * sizeof(float));
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frameIndex = binarySearch1(self->frames, self->framesCount, time);
	frameTime = self->frames[frameIndex];
	percent = 1 - (time - frameTime) / (self->frames[frameIndex - 1] - frameTime);
	percent = sp21CurveTimeline_getCurvePercent(SUPER(self), frameIndex - 1, percent < 0 ? 0 : (percent > 1 ? 1 : percent));

	prevVertices = self->frameVertices[frameIndex - 1];
	nextVertices = self->frameVertices[frameIndex];

	if (alpha < 1) {
		for (i = 0; i < self->frameVerticesCount; ++i) {
			float prev = prevVertices[i];
			slot->attachmentVertices[i] += (prev + (nextVertices[i] - prev) * percent - slot->attachmentVertices[i]) * alpha;
		}
	} else {
		for (i = 0; i < self->frameVerticesCount; ++i) {
			float prev = prevVertices[i];
			slot->attachmentVertices[i] = prev + (nextVertices[i] - prev) * percent;
		}
	}
}

void _sp21FFDTimeline_dispose (sp21Timeline* timeline) {
	sp21FFDTimeline* self = SUB_CAST(sp21FFDTimeline, timeline);
	int i;

	_sp21CurveTimeline_deinit(SUPER(self));

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->frameVertices[i]);
	FREE(self->frameVertices);
	FREE(self->frames);
	FREE(self);
}

sp21FFDTimeline* sp21FFDTimeline_create (int framesCount, int frameVerticesCount) {
	sp21FFDTimeline* self = NEW(sp21FFDTimeline);
	_sp21CurveTimeline_init(SUPER(self), SP_TIMELINE_FFD, framesCount, _sp21FFDTimeline_dispose, _sp21FFDTimeline_apply);
	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, self->framesCount);
	CONST_CAST(float**, self->frameVertices) = CALLOC(float*, framesCount);
	CONST_CAST(int, self->frameVerticesCount) = frameVerticesCount;
	return self;
}

void sp21FFDTimeline_setFrame (sp21FFDTimeline* self, int frameIndex, float time, float* vertices) {
	self->frames[frameIndex] = time;

	FREE(self->frameVertices[frameIndex]);
	if (!vertices)
		self->frameVertices[frameIndex] = 0;
	else {
		self->frameVertices[frameIndex] = MALLOC(float, self->frameVerticesCount);
		memcpy(CONST_CAST(float*, self->frameVertices[frameIndex]), vertices, self->frameVerticesCount * sizeof(float));
	}
}


/**/

static const int IKCONSTRAINT_PREV_FRAME_TIME = -3;
static const int IKCONSTRAINT_PREV_FRAME_MIX = -2;
static const int IKCONSTRAINT_PREV_FRAME_BEND_DIRECTION = -1;
static const int IKCONSTRAINT_FRAME_MIX = 1;

void _sp21IkConstraintTimeline_apply (const sp21Timeline* timeline, sp21Skeleton* skeleton, float lastTime, float time,
		sp21Event** firedEvents, int* eventsCount, float alpha) {
	int frameIndex;
	float prevFrameMix, frameTime, percent, mix;
	sp21IkConstraint* ikConstraint;
	sp21IkConstraintTimeline* self = (sp21IkConstraintTimeline*)timeline;

	if (time < self->frames[0]) return; /* Time is before first frame. */

	ikConstraint = skeleton->ikConstraints[self->ikConstraintIndex];

	if (time >= self->frames[self->framesCount - 3]) { /* Time is after last frame. */
		ikConstraint->mix += (self->frames[self->framesCount - 2] - ikConstraint->mix) * alpha;
		ikConstraint->bendDirection = (int)self->frames[self->framesCount - 1];
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frameIndex = binarySearch(self->frames, self->framesCount, time, 3);
	prevFrameMix = self->frames[frameIndex + IKCONSTRAINT_PREV_FRAME_MIX];
	frameTime = self->frames[frameIndex];
	percent = 1 - (time - frameTime) / (self->frames[frameIndex + IKCONSTRAINT_PREV_FRAME_TIME] - frameTime);
	percent = sp21CurveTimeline_getCurvePercent(SUPER(self), frameIndex / 3 - 1, percent < 0 ? 0 : (percent > 1 ? 1 : percent));

	mix = prevFrameMix + (self->frames[frameIndex + IKCONSTRAINT_FRAME_MIX] - prevFrameMix) * percent;
	ikConstraint->mix += (mix - ikConstraint->mix) * alpha;
	ikConstraint->bendDirection = (int)self->frames[frameIndex + IKCONSTRAINT_PREV_FRAME_BEND_DIRECTION];
}

sp21IkConstraintTimeline* sp21IkConstraintTimeline_create (int framesCount) {
	return (sp21IkConstraintTimeline*)_sp21BaseTimeline_create(framesCount, SP_TIMELINE_IKCONSTRAINT, 3, _sp21IkConstraintTimeline_apply);
}

void sp21IkConstraintTimeline_setFrame (sp21IkConstraintTimeline* self, int frameIndex, float time, float mix, int bendDirection) {
	frameIndex *= 3;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + 1] = mix;
	self->frames[frameIndex + 2] = (float)bendDirection;
}

/**/

void _sp21FlipTimeline_apply (const sp21Timeline* timeline, sp21Skeleton* skeleton, float lastTime, float time,
		sp21Event** firedEvents, int* eventsCount, float alpha) {
	int frameIndex;
	sp21FlipTimeline* self = (sp21FlipTimeline*)timeline;

	if (time < self->frames[0]) {
		if (lastTime > time) _sp21FlipTimeline_apply(timeline, skeleton, lastTime, (float)INT_MAX, 0, 0, 0);
		return;
	} else if (lastTime > time) /**/
		lastTime = -1;

	frameIndex = (time >= self->frames[self->framesCount - 2] ?
		self->framesCount : binarySearch(self->frames, self->framesCount, time, 2)) - 2;
	if (self->frames[frameIndex] < lastTime) return;

	if (self->x)
		skeleton->bones[self->boneIndex]->flipX = (int)self->frames[frameIndex + 1];
	else
		skeleton->bones[self->boneIndex]->flipY = (int)self->frames[frameIndex + 1];
}

void _sp21FlipTimeline_dispose (sp21Timeline* timeline) {
	sp21FlipTimeline* self = SUB_CAST(sp21FlipTimeline, timeline);
	_sp21Timeline_deinit(SUPER(self));
	FREE(self->frames);
	FREE(self);
}

sp21FlipTimeline* sp21FlipTimeline_create (int framesCount, int/*bool*/x) {
	sp21FlipTimeline* self = NEW(sp21FlipTimeline);
	_sp21Timeline_init(SUPER(self), x ? SP_TIMELINE_FLIPX : SP_TIMELINE_FLIPY, _sp21FlipTimeline_dispose, _sp21FlipTimeline_apply);
	CONST_CAST(int, self->x) = x;
	CONST_CAST(int, self->framesCount) = framesCount << 1;
	CONST_CAST(float*, self->frames) = CALLOC(float, self->framesCount);
	return self;
}

void sp21FlipTimeline_setFrame (sp21FlipTimeline* self, int frameIndex, float time, int/*bool*/flip) {
	frameIndex <<= 1;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + 1] = (float)flip;
}

/**/


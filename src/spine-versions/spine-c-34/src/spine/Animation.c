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

#include <spine/Animation.h>
#include <spine/IkConstraint.h>
#include <limits.h>
#include <spine/extension.h>

sp34Animation* sp34Animation_create (const char* name, int timelinesCount) {
	sp34Animation* self = NEW(sp34Animation);
	MALLOC_STR(self->name, name);
	self->timelinesCount = timelinesCount;
	self->timelines = MALLOC(sp34Timeline*, timelinesCount);
	return self;
}

void sp34Animation_dispose (sp34Animation* self) {
	int i;
	for (i = 0; i < self->timelinesCount; ++i)
		sp34Timeline_dispose(self->timelines[i]);
	FREE(self->timelines);
	FREE(self->name);
	FREE(self);
}

void sp34Animation_apply (const sp34Animation* self, sp34Skeleton* skeleton, float lastTime, float time, int loop, sp34Event** events,
		int* eventsCount) {
	int i, n = self->timelinesCount;

	if (loop && self->duration) {
		time = FMOD(time, self->duration);
		if (lastTime > 0) lastTime = FMOD(lastTime, self->duration);
	}

	for (i = 0; i < n; ++i)
		sp34Timeline_apply(self->timelines[i], skeleton, lastTime, time, events, eventsCount, 1);
}

void sp34Animation_mix (const sp34Animation* self, sp34Skeleton* skeleton, float lastTime, float time, int loop, sp34Event** events,
		int* eventsCount, float alpha) {
	int i, n = self->timelinesCount;

	if (loop && self->duration) {
		time = FMOD(time, self->duration);
		if (lastTime > 0) lastTime = FMOD(lastTime, self->duration);
	}

	for (i = 0; i < n; ++i)
		sp34Timeline_apply(self->timelines[i], skeleton, lastTime, time, events, eventsCount, alpha);
}

/**/

typedef struct _sp34TimelineVtable {
	void (*apply) (const sp34Timeline* self, sp34Skeleton* skeleton, float lastTime, float time, sp34Event** firedEvents,
			int* eventsCount, float alpha);
	void (*dispose) (sp34Timeline* self);
} _sp34TimelineVtable;

void _sp34Timeline_init (sp34Timeline* self, sp34TimelineType type, /**/
void (*dispose) (sp34Timeline* self), /**/
		void (*apply) (const sp34Timeline* self, sp34Skeleton* skeleton, float lastTime, float time, sp34Event** firedEvents,
				int* eventsCount, float alpha)) {
	CONST_CAST(sp34TimelineType, self->type) = type;
	CONST_CAST(_sp34TimelineVtable*, self->vtable) = NEW(_sp34TimelineVtable);
	VTABLE(sp34Timeline, self)->dispose = dispose;
	VTABLE(sp34Timeline, self)->apply = apply;
}

void _sp34Timeline_deinit (sp34Timeline* self) {
	FREE(self->vtable);
}

void sp34Timeline_dispose (sp34Timeline* self) {
	VTABLE(sp34Timeline, self)->dispose(self);
}

void sp34Timeline_apply (const sp34Timeline* self, sp34Skeleton* skeleton, float lastTime, float time, sp34Event** firedEvents,
		int* eventsCount, float alpha) {
	VTABLE(sp34Timeline, self)->apply(self, skeleton, lastTime, time, firedEvents, eventsCount, alpha);
}

/**/

static const float CURVE_LINEAR = 0, CURVE_STEPPED = 1, CURVE_BEZIER = 2;
static const int BEZIER_SIZE = 10 * 2 - 1;

void _sp34CurveTimeline_init (sp34CurveTimeline* self, sp34TimelineType type, int framesCount, /**/
void (*dispose) (sp34Timeline* self), /**/
		void (*apply) (const sp34Timeline* self, sp34Skeleton* skeleton, float lastTime, float time, sp34Event** firedEvents,
				int* eventsCount, float alpha)) {
	_sp34Timeline_init(SUPER(self), type, dispose, apply);
	self->curves = CALLOC(float, (framesCount - 1) * BEZIER_SIZE);
}

void _sp34CurveTimeline_deinit (sp34CurveTimeline* self) {
	_sp34Timeline_deinit(SUPER(self));
	FREE(self->curves);
}

void sp34CurveTimeline_setLinear (sp34CurveTimeline* self, int frameIndex) {
	self->curves[frameIndex * BEZIER_SIZE] = CURVE_LINEAR;
}

void sp34CurveTimeline_setStepped (sp34CurveTimeline* self, int frameIndex) {
	self->curves[frameIndex * BEZIER_SIZE] = CURVE_STEPPED;
}

void sp34CurveTimeline_setCurve (sp34CurveTimeline* self, int frameIndex, float cx1, float cy1, float cx2, float cy2) {
	float tmpx = (-cx1 * 2 + cx2) * 0.03f, tmpy = (-cy1 * 2 + cy2) * 0.03f;
	float dddfx = ((cx1 - cx2) * 3 + 1) * 0.006f, dddfy = ((cy1 - cy2) * 3 + 1) * 0.006f;
	float ddfx = tmpx * 2 + dddfx, ddfy = tmpy * 2 + dddfy;
	float dfx = cx1 * 0.3f + tmpx + dddfx * 0.16666667f, dfy = cy1 * 0.3f + tmpy + dddfy * 0.16666667f;
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

float sp34CurveTimeline_getCurvePercent (const sp34CurveTimeline* self, int frameIndex, float percent) {
	float x, y;
	int i = frameIndex * BEZIER_SIZE, start, n;
	float type = self->curves[i];
	percent = CLAMP(percent, 0, 1);
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

/**/

void _sp34BaseTimeline_dispose (sp34Timeline* timeline) {
	struct sp34BaseTimeline* self = SUB_CAST(struct sp34BaseTimeline, timeline);
	_sp34CurveTimeline_deinit(SUPER(self));
	FREE(self->frames);
	FREE(self);
}

/* Many timelines have structure identical to struct sp34BaseTimeline and extend sp34CurveTimeline. **/
struct sp34BaseTimeline* _sp34BaseTimeline_create (int framesCount, sp34TimelineType type, int frameSize, /**/
		void (*apply) (const sp34Timeline* self, sp34Skeleton* skeleton, float lastTime, float time, sp34Event** firedEvents,
				int* eventsCount, float alpha)) {
	struct sp34BaseTimeline* self = NEW(struct sp34BaseTimeline);
	_sp34CurveTimeline_init(SUPER(self), type, framesCount, _sp34BaseTimeline_dispose, apply);

	CONST_CAST(int, self->framesCount) = framesCount * frameSize;
	CONST_CAST(float*, self->frames) = CALLOC(float, self->framesCount);

	return self;
}

/**/

static const int ROTATE_PREV_TIME = -2, ROTATE_PREV_ROTATION = -1;
static const int ROTATE_ROTATION = 1;

void _sp34RotateTimeline_apply (const sp34Timeline* timeline, sp34Skeleton* skeleton, float lastTime, float time, sp34Event** firedEvents,
		int* eventsCount, float alpha) {
	sp34Bone *bone;
	int frame;
	float prevRotation, frameTime, percent, amount;

	sp34RotateTimeline* self = SUB_CAST(sp34RotateTimeline, timeline);

	if (time < self->frames[0]) return; /* Time is before first frame. */

	bone = skeleton->bones[self->boneIndex];

	if (time >= self->frames[self->framesCount - ROTATE_ENTRIES]) { /* Time is after last frame. */
		amount = bone->data->rotation + self->frames[self->framesCount + ROTATE_PREV_ROTATION] - bone->rotation;
		while (amount > 180)
			amount -= 360;
		while (amount < -180)
			amount += 360;
		bone->rotation += amount * alpha;
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frame = binarySearch(self->frames, self->framesCount, time, ROTATE_ENTRIES);
	prevRotation = self->frames[frame + ROTATE_PREV_ROTATION];
	frameTime = self->frames[frame];
	percent = sp34CurveTimeline_getCurvePercent(SUPER(self), (frame >> 1) - 1, 1 - (time - frameTime) / (self->frames[frame + ROTATE_PREV_TIME] - frameTime));

	amount = self->frames[frame + ROTATE_ROTATION] - prevRotation;
	while (amount > 180)
		amount -= 360;
	while (amount < -180)
		amount += 360;
	amount = bone->data->rotation + (prevRotation + amount * percent) - bone->rotation;
	while (amount > 180)
		amount -= 360;
	while (amount < -180)
		amount += 360;
	bone->rotation += amount * alpha;

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

sp34RotateTimeline* sp34RotateTimeline_create (int framesCount) {
	return _sp34BaseTimeline_create(framesCount, SP_TIMELINE_ROTATE, ROTATE_ENTRIES, _sp34RotateTimeline_apply);
}

void sp34RotateTimeline_setFrame (sp34RotateTimeline* self, int frameIndex, float time, float degrees) {
	frameIndex <<= 1;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + ROTATE_ROTATION] = degrees;
}

/**/

static const int TRANSLATE_PREV_TIME = -3, TRANSLATE_PREV_X = -2, TRANSLATE_PREV_Y = -1;
static const int TRANSLATE_X = 1, TRANSLATE_Y = 2;

void _sp34TranslateTimeline_apply (const sp34Timeline* timeline, sp34Skeleton* skeleton, float lastTime, float time,
		sp34Event** firedEvents, int* eventsCount, float alpha) {
	sp34Bone *bone;
	int frame;
	float prevX, prevY, frameTime, percent;

	sp34TranslateTimeline* self = SUB_CAST(sp34TranslateTimeline, timeline);

	if (time < self->frames[0]) return; /* Time is before first frame. */

	bone = skeleton->bones[self->boneIndex];

	if (time >= self->frames[self->framesCount - TRANSLATE_ENTRIES]) { /* Time is after last frame. */
		bone->x += (bone->data->x + self->frames[self->framesCount + TRANSLATE_PREV_X] - bone->x) * alpha;
		bone->y += (bone->data->y + self->frames[self->framesCount + TRANSLATE_PREV_Y] - bone->y) * alpha;
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frame = binarySearch(self->frames, self->framesCount, time, TRANSLATE_ENTRIES);
	prevX = self->frames[frame + TRANSLATE_PREV_X];
	prevY = self->frames[frame + TRANSLATE_PREV_Y];
	frameTime = self->frames[frame];
	percent = sp34CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSLATE_ENTRIES - 1, 1 - (time - frameTime) / (self->frames[frame + TRANSLATE_PREV_TIME] - frameTime));

	bone->x += (bone->data->x + prevX + (self->frames[frame + TRANSLATE_X] - prevX) * percent - bone->x) * alpha;
	bone->y += (bone->data->y + prevY + (self->frames[frame + TRANSLATE_Y] - prevY) * percent - bone->y) * alpha;

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

sp34TranslateTimeline* sp34TranslateTimeline_create (int framesCount) {
	return _sp34BaseTimeline_create(framesCount, SP_TIMELINE_TRANSLATE, TRANSLATE_ENTRIES, _sp34TranslateTimeline_apply);
}

void sp34TranslateTimeline_setFrame (sp34TranslateTimeline* self, int frameIndex, float time, float x, float y) {
	frameIndex *= TRANSLATE_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + TRANSLATE_X] = x;
	self->frames[frameIndex + TRANSLATE_Y] = y;
}

/**/

void _sp34ScaleTimeline_apply (const sp34Timeline* timeline, sp34Skeleton* skeleton, float lastTime, float time, sp34Event** firedEvents,
		int* eventsCount, float alpha) {
	sp34Bone *bone;
	int frame;
	float prevX, prevY, frameTime, percent;

	sp34ScaleTimeline* self = SUB_CAST(sp34ScaleTimeline, timeline);

	if (time < self->frames[0]) return; /* Time is before first frame. */

	bone = skeleton->bones[self->boneIndex];
	if (time >= self->frames[self->framesCount - TRANSLATE_ENTRIES]) { /* Time is after last frame. */
		bone->scaleX += (bone->data->scaleX * self->frames[self->framesCount + TRANSLATE_PREV_X] - bone->scaleX) * alpha;
		bone->scaleY += (bone->data->scaleY * self->frames[self->framesCount + TRANSLATE_PREV_Y] - bone->scaleY) * alpha;
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frame = binarySearch(self->frames, self->framesCount, time, TRANSLATE_ENTRIES);
	prevX = self->frames[frame + TRANSLATE_PREV_X];
	prevY = self->frames[frame + TRANSLATE_PREV_Y];
	frameTime = self->frames[frame];
	percent = sp34CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSLATE_ENTRIES - 1, 1 - (time - frameTime) / (self->frames[frame + TRANSLATE_PREV_TIME] - frameTime));

	bone->scaleX += (bone->data->scaleX * (prevX + (self->frames[frame + TRANSLATE_X] - prevX) * percent) - bone->scaleX) * alpha;
	bone->scaleY += (bone->data->scaleY * (prevY + (self->frames[frame + TRANSLATE_Y] - prevY) * percent) - bone->scaleY) * alpha;

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

sp34ScaleTimeline* sp34ScaleTimeline_create (int framesCount) {
	return _sp34BaseTimeline_create(framesCount, SP_TIMELINE_SCALE, TRANSLATE_ENTRIES, _sp34ScaleTimeline_apply);
}

void sp34ScaleTimeline_setFrame (sp34ScaleTimeline* self, int frameIndex, float time, float x, float y) {
	sp34TranslateTimeline_setFrame(self, frameIndex, time, x, y);
}

/**/

void _sp34ShearTimeline_apply (const sp34Timeline* timeline, sp34Skeleton* skeleton, float lastTime, float time, sp34Event** firedEvents,
							 int* eventsCount, float alpha) {
	sp34Bone *bone;
	int frame;
	float prevX, prevY, frameTime, percent;

	sp34ShearTimeline* self = SUB_CAST(sp34ShearTimeline, timeline);

	if (time < self->frames[0]) return; /* Time is before first frame. */

	bone = skeleton->bones[self->boneIndex];
	if (time >= self->frames[self->framesCount - TRANSLATE_ENTRIES]) { /* Time is after last frame. */
		bone->shearX += (bone->data->shearX + self->frames[self->framesCount + TRANSLATE_PREV_X] - bone->shearX) * alpha;
		bone->shearY += (bone->data->shearY + self->frames[self->framesCount + TRANSLATE_PREV_Y] - bone->shearY) * alpha;
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frame = binarySearch(self->frames, self->framesCount, time, TRANSLATE_ENTRIES);
	prevX = self->frames[frame + TRANSLATE_PREV_X];
	prevY = self->frames[frame + TRANSLATE_PREV_Y];
	frameTime = self->frames[frame];
	percent = sp34CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSLATE_ENTRIES - 1, 1 - (time - frameTime) / (self->frames[frame + TRANSLATE_PREV_TIME] - frameTime));

	bone->shearX += (bone->data->shearX + prevX + (self->frames[frame + TRANSLATE_X] - prevX) * percent - bone->shearX) * alpha;
	bone->shearY += (bone->data->shearY + prevY + (self->frames[frame + TRANSLATE_Y] - prevY) * percent - bone->shearY) * alpha;

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

sp34ShearTimeline* sp34ShearTimeline_create (int framesCount) {
	return (sp34ShearTimeline*)_sp34BaseTimeline_create(framesCount, SP_TIMELINE_SHEAR, 3, _sp34ShearTimeline_apply);
}

void sp34ShearTimeline_setFrame (sp34ShearTimeline* self, int frameIndex, float time, float x, float y) {
	sp34TranslateTimeline_setFrame(self, frameIndex, time, x, y);
}

/**/

static const int COLOR_PREV_TIME = -5, COLOR_PREV_R = -4, COLOR_PREV_G = -3, COLOR_PREV_B = -2, COLOR_PREV_A = -1;
static const int COLOR_R = 1, COLOR_G = 2, COLOR_B = 3, COLOR_A = 4;

void _sp34ColorTimeline_apply (const sp34Timeline* timeline, sp34Skeleton* skeleton, float lastTime, float time, sp34Event** firedEvents,
		int* eventsCount, float alpha) {
	sp34Slot *slot;
	int frame;
	float percent, frameTime;
	float r, g, b, a;
	sp34ColorTimeline* self = (sp34ColorTimeline*)timeline;

	if (time < self->frames[0]) return; /* Time is before first frame. */

	if (time >= self->frames[self->framesCount - 5]) { /* Time is after last frame */
		int i = self->framesCount;
		r = self->frames[i + COLOR_PREV_R];
		g = self->frames[i + COLOR_PREV_G];
		b = self->frames[i + COLOR_PREV_B];
		a = self->frames[i + COLOR_PREV_A];
	} else {
		/* Interpolate between the previous frame and the current frame. */
		frame = binarySearch(self->frames, self->framesCount, time, COLOR_ENTRIES);

		r = self->frames[frame + COLOR_PREV_R];
		g = self->frames[frame + COLOR_PREV_G];
		b = self->frames[frame + COLOR_PREV_B];
		a = self->frames[frame + COLOR_PREV_A];

		frameTime = self->frames[frame];
		percent = sp34CurveTimeline_getCurvePercent(SUPER(self), frame / COLOR_ENTRIES - 1,
												  1 - (time - frameTime) / (self->frames[frame + COLOR_PREV_TIME] - frameTime));

		r += (self->frames[frame + COLOR_R] - r) * percent;
		g += (self->frames[frame + COLOR_G] - g) * percent;
		b += (self->frames[frame + COLOR_B] - b) * percent;
		a += (self->frames[frame + COLOR_A] - a) * percent;
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

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

sp34ColorTimeline* sp34ColorTimeline_create (int framesCount) {
	return (sp34ColorTimeline*)_sp34BaseTimeline_create(framesCount, SP_TIMELINE_COLOR, 5, _sp34ColorTimeline_apply);
}

void sp34ColorTimeline_setFrame (sp34ColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a) {
	frameIndex *= COLOR_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + COLOR_R] = r;
	self->frames[frameIndex + COLOR_G] = g;
	self->frames[frameIndex + COLOR_B] = b;
	self->frames[frameIndex + COLOR_A] = a;
}

/**/

void _sp34AttachmentTimeline_apply (const sp34Timeline* timeline, sp34Skeleton* skeleton, float lastTime, float time,
		sp34Event** firedEvents, int* eventsCount, float alpha) {
	const char* attachmentName;
	sp34AttachmentTimeline* self = (sp34AttachmentTimeline*)timeline;
	int frameIndex;

	if (time < self->frames[0]) return;

	if (time >= self->frames[self->framesCount - 1])
		frameIndex = self->framesCount - 1;
	else
		frameIndex = binarySearch1(self->frames, self->framesCount, time) - 1;

	attachmentName = self->attachmentNames[frameIndex];
	sp34Slot_setAttachment(skeleton->slots[self->slotIndex],
			attachmentName ? sp34Skeleton_getAttachmentForSlotIndex(skeleton, self->slotIndex, attachmentName) : 0);

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(alpha);
}

void _sp34AttachmentTimeline_dispose (sp34Timeline* timeline) {
	sp34AttachmentTimeline* self = SUB_CAST(sp34AttachmentTimeline, timeline);
	int i;

	_sp34Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->attachmentNames[i]);
	FREE(self->attachmentNames);
	FREE(self->frames);
	FREE(self);
}

sp34AttachmentTimeline* sp34AttachmentTimeline_create (int framesCount) {
	sp34AttachmentTimeline* self = NEW(sp34AttachmentTimeline);
	_sp34Timeline_init(SUPER(self), SP_TIMELINE_ATTACHMENT, _sp34AttachmentTimeline_dispose, _sp34AttachmentTimeline_apply);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(char**, self->attachmentNames) = CALLOC(char*, framesCount);

	return self;
}

void sp34AttachmentTimeline_setFrame (sp34AttachmentTimeline* self, int frameIndex, float time, const char* attachmentName) {
	self->frames[frameIndex] = time;

	FREE(self->attachmentNames[frameIndex]);
	if (attachmentName)
		MALLOC_STR(self->attachmentNames[frameIndex], attachmentName);
	else
		self->attachmentNames[frameIndex] = 0;
}

/**/

/** Fires events for frames > lastTime and <= time. */
void _sp34EventTimeline_apply (const sp34Timeline* timeline, sp34Skeleton* skeleton, float lastTime, float time, sp34Event** firedEvents,
		int* eventsCount, float alpha) {
	sp34EventTimeline* self = (sp34EventTimeline*)timeline;
	int frame;
	if (!firedEvents) return;

	if (lastTime > time) { /* Fire events after last time for looped animations. */
		_sp34EventTimeline_apply(timeline, skeleton, lastTime, (float)INT_MAX, firedEvents, eventsCount, alpha);
		lastTime = -1;
	} else if (lastTime >= self->frames[self->framesCount - 1]) /* Last time is after last frame. */
	return;
	if (time < self->frames[0]) return; /* Time is before first frame. */

	if (lastTime < self->frames[0])
		frame = 0;
	else {
		float frameTime;
		frame = binarySearch1(self->frames, self->framesCount, lastTime);
		frameTime = self->frames[frame];
		while (frame > 0) { /* Fire multiple events with the same frame. */
			if (self->frames[frame - 1] != frameTime) break;
			frame--;
		}
	}
	for (; frame < self->framesCount && time >= self->frames[frame]; ++frame) {
		firedEvents[*eventsCount] = self->events[frame];
		(*eventsCount)++;
	}
}

void _sp34EventTimeline_dispose (sp34Timeline* timeline) {
	sp34EventTimeline* self = SUB_CAST(sp34EventTimeline, timeline);
	int i;

	_sp34Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		sp34Event_dispose(self->events[i]);
	FREE(self->events);
	FREE(self->frames);
	FREE(self);
}

sp34EventTimeline* sp34EventTimeline_create (int framesCount) {
	sp34EventTimeline* self = NEW(sp34EventTimeline);
	_sp34Timeline_init(SUPER(self), SP_TIMELINE_EVENT, _sp34EventTimeline_dispose, _sp34EventTimeline_apply);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(sp34Event**, self->events) = CALLOC(sp34Event*, framesCount);

	return self;
}

void sp34EventTimeline_setFrame (sp34EventTimeline* self, int frameIndex, sp34Event* event) {
	self->frames[frameIndex] = event->time;

	FREE(self->events[frameIndex]);
	self->events[frameIndex] = event;
}

/**/

void _sp34DrawOrderTimeline_apply (const sp34Timeline* timeline, sp34Skeleton* skeleton, float lastTime, float time,
		sp34Event** firedEvents, int* eventsCount, float alpha) {
	int i;
	int frame;
	const int* drawOrderToSetupIndex;
	sp34DrawOrderTimeline* self = (sp34DrawOrderTimeline*)timeline;

	if (time < self->frames[0]) return; /* Time is before first frame. */

	if (time >= self->frames[self->framesCount - 1]) /* Time is after last frame. */
		frame = self->framesCount - 1;
	else
		frame = binarySearch1(self->frames, self->framesCount, time) - 1;

	drawOrderToSetupIndex = self->drawOrders[frame];
	if (!drawOrderToSetupIndex)
		memcpy(skeleton->drawOrder, skeleton->slots, self->slotsCount * sizeof(sp34Slot*));
	else {
		for (i = 0; i < self->slotsCount; ++i)
			skeleton->drawOrder[i] = skeleton->slots[drawOrderToSetupIndex[i]];
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(alpha);
}

void _sp34DrawOrderTimeline_dispose (sp34Timeline* timeline) {
	sp34DrawOrderTimeline* self = SUB_CAST(sp34DrawOrderTimeline, timeline);
	int i;

	_sp34Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->drawOrders[i]);
	FREE(self->drawOrders);
	FREE(self->frames);
	FREE(self);
}

sp34DrawOrderTimeline* sp34DrawOrderTimeline_create (int framesCount, int slotsCount) {
	sp34DrawOrderTimeline* self = NEW(sp34DrawOrderTimeline);
	_sp34Timeline_init(SUPER(self), SP_TIMELINE_DRAWORDER, _sp34DrawOrderTimeline_dispose, _sp34DrawOrderTimeline_apply);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(int**, self->drawOrders) = CALLOC(int*, framesCount);
	CONST_CAST(int, self->slotsCount) = slotsCount;

	return self;
}

void sp34DrawOrderTimeline_setFrame (sp34DrawOrderTimeline* self, int frameIndex, float time, const int* drawOrder) {
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

void _sp34DeformTimeline_apply (const sp34Timeline* timeline, sp34Skeleton* skeleton, float lastTime, float time, sp34Event** firedEvents,
		int* eventsCount, float alpha) {
	int frame, i, vertexCount;
	float percent, frameTime;
	const float* prevVertices;
	const float* nextVertices;
	sp34DeformTimeline* self = (sp34DeformTimeline*)timeline;

	sp34Slot *slot = skeleton->slots[self->slotIndex];

	if (slot->attachment != self->attachment) {
		if (!slot->attachment) return;
		switch (slot->attachment->type) {
		case SP_ATTACHMENT_MESH: {
			sp34MeshAttachment* mesh = SUB_CAST(sp34MeshAttachment, slot->attachment);
			if (!mesh->inheritDeform || mesh->parentMesh != (void*)self->attachment) return;
			break;
		}
		default:
			return;
		}
	}

	if (time < self->frames[0]) return; /* Time is before first frame. */

	vertexCount = self->frameVerticesCount;
	if (slot->attachmentVerticesCount < vertexCount) {
		if (slot->attachmentVerticesCapacity < vertexCount) {
			FREE(slot->attachmentVertices);
			slot->attachmentVertices = MALLOC(float, vertexCount);
			slot->attachmentVerticesCapacity = vertexCount;
		}
	}
	if (slot->attachmentVerticesCount != vertexCount) alpha = 1; /* Don't mix from uninitialized slot vertices. */
	slot->attachmentVerticesCount = vertexCount;

	if (time >= self->frames[self->framesCount - 1]) {
		/* Time is after last frame. */
		const float* lastVertices = self->frameVertices[self->framesCount - 1];
		if (alpha < 1) {
			for (i = 0; i < vertexCount; ++i)
				slot->attachmentVertices[i] += (lastVertices[i] - slot->attachmentVertices[i]) * alpha;
		} else
			memcpy(slot->attachmentVertices, lastVertices, vertexCount * sizeof(float));
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frame = binarySearch1(self->frames, self->framesCount, time);
	frameTime = self->frames[frame];
	percent = sp34CurveTimeline_getCurvePercent(SUPER(self), frame - 1, 1 - (time - frameTime) / (self->frames[frame - 1] - frameTime));

	prevVertices = self->frameVertices[frame - 1];
	nextVertices = self->frameVertices[frame];

	if (alpha < 1) {
		for (i = 0; i < vertexCount; ++i) {
			float prev = prevVertices[i];
			slot->attachmentVertices[i] += (prev + (nextVertices[i] - prev) * percent - slot->attachmentVertices[i]) * alpha;
		}
	} else {
		for (i = 0; i < vertexCount; ++i) {
			float prev = prevVertices[i];
			slot->attachmentVertices[i] = prev + (nextVertices[i] - prev) * percent;
		}
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

void _sp34DeformTimeline_dispose (sp34Timeline* timeline) {
	sp34DeformTimeline* self = SUB_CAST(sp34DeformTimeline, timeline);
	int i;

	_sp34CurveTimeline_deinit(SUPER(self));

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->frameVertices[i]);
	FREE(self->frameVertices);
	FREE(self->frames);
	FREE(self);
}

sp34DeformTimeline* sp34DeformTimeline_create (int framesCount, int frameVerticesCount) {
	sp34DeformTimeline* self = NEW(sp34DeformTimeline);
	_sp34CurveTimeline_init(SUPER(self), SP_TIMELINE_DEFORM, framesCount, _sp34DeformTimeline_dispose, _sp34DeformTimeline_apply);
	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, self->framesCount);
	CONST_CAST(float**, self->frameVertices) = CALLOC(float*, framesCount);
	CONST_CAST(int, self->frameVerticesCount) = frameVerticesCount;
	return self;
}

void sp34DeformTimeline_setFrame (sp34DeformTimeline* self, int frameIndex, float time, float* vertices) {
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

static const int IKCONSTRAINT_PREV_TIME = -3, IKCONSTRAINT_PREV_MIX = -2, IKCONSTRAINT_PREV_BEND_DIRECTION = -1;
static const int IKCONSTRAINT_MIX = 1, IKCONSTRAINT_BEND_DIRECTION = 2;

void _sp34IkConstraintTimeline_apply (const sp34Timeline* timeline, sp34Skeleton* skeleton, float lastTime, float time,
		sp34Event** firedEvents, int* eventsCount, float alpha) {
	int frame;
	float frameTime, percent, mix;
	sp34IkConstraint* constraint;
	sp34IkConstraintTimeline* self = (sp34IkConstraintTimeline*)timeline;

	if (time < self->frames[0]) return; /* Time is before first frame. */

	constraint = skeleton->ikConstraints[self->ikConstraintIndex];

	if (time >= self->frames[self->framesCount - IKCONSTRAINT_ENTRIES]) { /* Time is after last frame. */
		constraint->mix += (self->frames[self->framesCount + IKCONSTRAINT_PREV_MIX] - constraint->mix) * alpha;
		constraint->bendDirection = (int)self->frames[self->framesCount + IKCONSTRAINT_PREV_BEND_DIRECTION];
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frame = binarySearch(self->frames, self->framesCount, time, IKCONSTRAINT_ENTRIES);
	mix = self->frames[frame + IKCONSTRAINT_PREV_MIX];
	frameTime = self->frames[frame];
	percent = sp34CurveTimeline_getCurvePercent(SUPER(self), frame / IKCONSTRAINT_ENTRIES - 1, 1 - (time - frameTime) / (self->frames[frame + IKCONSTRAINT_PREV_TIME] - frameTime));

	constraint->mix += (mix + (self->frames[frame + IKCONSTRAINT_MIX] - mix) * percent - constraint->mix) * alpha;
	constraint->bendDirection = (int)self->frames[frame + IKCONSTRAINT_PREV_BEND_DIRECTION];

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

sp34IkConstraintTimeline* sp34IkConstraintTimeline_create (int framesCount) {
	return (sp34IkConstraintTimeline*)_sp34BaseTimeline_create(framesCount, SP_TIMELINE_IKCONSTRAINT, IKCONSTRAINT_ENTRIES, _sp34IkConstraintTimeline_apply);
}

void sp34IkConstraintTimeline_setFrame (sp34IkConstraintTimeline* self, int frameIndex, float time, float mix, int bendDirection) {
	frameIndex *= IKCONSTRAINT_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + IKCONSTRAINT_MIX] = mix;
	self->frames[frameIndex + IKCONSTRAINT_BEND_DIRECTION] = (float)bendDirection;
}

/**/
static const int TRANSFORMCONSTRAINT_PREV_TIME = -5;
static const int TRANSFORMCONSTRAINT_PREV_ROTATE = -4;
static const int TRANSFORMCONSTRAINT_PREV_TRANSLATE = -3;
static const int TRANSFORMCONSTRAINT_PREV_SCALE = -2;
static const int TRANSFORMCONSTRAINT_PREV_SHEAR = -1;
static const int TRANSFORMCONSTRAINT_ROTATE = 1;
static const int TRANSFORMCONSTRAINT_TRANSLATE = 2;
static const int TRANSFORMCONSTRAINT_SCALE = 3;
static const int TRANSFORMCONSTRAINT_SHEAR = 4;

void _sp34TransformConstraintTimeline_apply (const sp34Timeline* timeline, sp34Skeleton* skeleton, float lastTime, float time,
									sp34Event** firedEvents, int* eventsCount, float alpha) {
	int frame;
	float frameTime, percent, rotate, translate, scale, shear;
	sp34TransformConstraint* constraint;
	sp34TransformConstraintTimeline* self = (sp34TransformConstraintTimeline*)timeline;

	if (time < self->frames[0]) return; /* Time is before first frame. */

	constraint = skeleton->transformConstraints[self->transformConstraintIndex];

	if (time >= self->frames[self->framesCount - TRANSFORMCONSTRAINT_ENTRIES]) { /* Time is after last frame. */
		int len = self->framesCount;
		constraint->rotateMix += (self->frames[len + TRANSFORMCONSTRAINT_PREV_ROTATE] - constraint->rotateMix) * alpha;
		constraint->translateMix += (self->frames[len + TRANSFORMCONSTRAINT_PREV_TRANSLATE] - constraint->translateMix) * alpha;
		constraint->scaleMix += (self->frames[len + TRANSFORMCONSTRAINT_PREV_SCALE] - constraint->scaleMix) * alpha;
		constraint->shearMix += (self->frames[len + TRANSFORMCONSTRAINT_PREV_SHEAR] - constraint->shearMix) * alpha;
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frame = binarySearch(self->frames, self->framesCount, time, TRANSFORMCONSTRAINT_ENTRIES);
	frameTime = self->frames[frame];
	percent = sp34CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSFORMCONSTRAINT_ENTRIES - 1, 1 - (time - frameTime) / (self->frames[frame + TRANSFORMCONSTRAINT_PREV_TIME] - frameTime));

	rotate = self->frames[frame + TRANSFORMCONSTRAINT_PREV_ROTATE];
	translate = self->frames[frame + TRANSFORMCONSTRAINT_PREV_TRANSLATE];
	scale = self->frames[frame + TRANSFORMCONSTRAINT_PREV_SCALE];
	shear = self->frames[frame + TRANSFORMCONSTRAINT_PREV_SHEAR];
	constraint->rotateMix += (rotate + (self->frames[frame + TRANSFORMCONSTRAINT_ROTATE] - rotate) * percent - constraint->rotateMix) * alpha;
	constraint->translateMix += (translate + (self->frames[frame + TRANSFORMCONSTRAINT_TRANSLATE] - translate) * percent - constraint->translateMix) * alpha;
	constraint->scaleMix += (scale + (self->frames[frame + TRANSFORMCONSTRAINT_SCALE] - scale) * percent - constraint->scaleMix) * alpha;
	constraint->shearMix += (shear + (self->frames[frame + TRANSFORMCONSTRAINT_SHEAR] - shear) * percent - constraint->shearMix) * alpha;

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

sp34TransformConstraintTimeline* sp34TransformConstraintTimeline_create (int framesCount) {
	return (sp34TransformConstraintTimeline*)_sp34BaseTimeline_create(framesCount, SP_TIMELINE_TRANSFORMCONSTRAINT, TRANSFORMCONSTRAINT_ENTRIES, _sp34TransformConstraintTimeline_apply);
}

void sp34TransformConstraintTimeline_setFrame (sp34TransformConstraintTimeline* self, int frameIndex, float time, float rotateMix, float translateMix, float scaleMix, float shearMix) {
	frameIndex *= TRANSFORMCONSTRAINT_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + TRANSFORMCONSTRAINT_ROTATE] = rotateMix;
	self->frames[frameIndex + TRANSFORMCONSTRAINT_TRANSLATE] = translateMix;
	self->frames[frameIndex + TRANSFORMCONSTRAINT_SCALE] = scaleMix;
	self->frames[frameIndex + TRANSFORMCONSTRAINT_SHEAR] = shearMix;
}

/**/

static const int PATHCONSTRAINTPOSITION_PREV_TIME = -2;
static const int PATHCONSTRAINTPOSITION_PREV_VALUE = -1;
static const int PATHCONSTRAINTPOSITION_VALUE = 1;

void _sp34PathConstraintPositionTimeline_apply(const sp34Timeline* timeline, sp34Skeleton* skeleton, float lastTime, float time,
											 sp34Event** firedEvents, int* eventsCount, float alpha) {
	int frame;
	float frameTime, percent, position;
	sp34PathConstraint* constraint;
	sp34PathConstraintPositionTimeline* self = (sp34PathConstraintPositionTimeline*)timeline;

	if (time < self->frames[0]) return; /* Time is before first frame. */

	constraint = skeleton->pathConstraints[self->pathConstraintIndex];

	if (time >= self->frames[self->framesCount - PATHCONSTRAINTPOSITION_ENTRIES]) { /* Time is after last frame. */
		int len = self->framesCount;
		constraint->position += (self->frames[len + PATHCONSTRAINTPOSITION_PREV_VALUE] - constraint->position) * alpha;
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frame = binarySearch(self->frames, self->framesCount, time, PATHCONSTRAINTPOSITION_ENTRIES);
	position = self->frames[frame + PATHCONSTRAINTPOSITION_PREV_VALUE];
	frameTime = self->frames[frame];
	percent = sp34CurveTimeline_getCurvePercent(SUPER(self), frame / PATHCONSTRAINTPOSITION_ENTRIES - 1, 1 - (time - frameTime) / (self->frames[frame + PATHCONSTRAINTPOSITION_PREV_TIME] - frameTime));

	constraint->position += (position + (self->frames[frame + PATHCONSTRAINTPOSITION_VALUE] - position) * percent - constraint->position) * alpha;

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

sp34PathConstraintPositionTimeline* sp34PathConstraintPositionTimeline_create (int framesCount) {
	return (sp34PathConstraintPositionTimeline*)_sp34BaseTimeline_create(framesCount, SP_TIMELINE_PATHCONSTRAINTPOSITION, PATHCONSTRAINTPOSITION_ENTRIES, _sp34PathConstraintPositionTimeline_apply);
}

void sp34PathConstraintPositionTimeline_setFrame (sp34PathConstraintPositionTimeline* self, int frameIndex, float time, float value) {
	frameIndex *= PATHCONSTRAINTPOSITION_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + PATHCONSTRAINTPOSITION_VALUE] = value;
}

/**/
static const int PATHCONSTRAINTSPACING_PREV_TIME = -2;
static const int PATHCONSTRAINTSPACING_PREV_VALUE = -1;
static const int PATHCONSTRAINTSPACING_VALUE = 1;

void _sp34PathConstraintSpacingTimeline_apply(const sp34Timeline* timeline, sp34Skeleton* skeleton, float lastTime, float time,
											 sp34Event** firedEvents, int* eventsCount, float alpha) {
	int frame;
	float frameTime, percent, spacing;
	sp34PathConstraint* constraint;
	sp34PathConstraintSpacingTimeline* self = (sp34PathConstraintSpacingTimeline*)timeline;

	if (time < self->frames[0]) return; /* Time is before first frame. */

	constraint = skeleton->pathConstraints[self->pathConstraintIndex];

	if (time >= self->frames[self->framesCount - PATHCONSTRAINTSPACING_ENTRIES]) { /* Time is after last frame. */
		int len = self->framesCount;
		constraint->spacing += (self->frames[len + PATHCONSTRAINTSPACING_PREV_VALUE] - constraint->spacing) * alpha;
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frame = binarySearch(self->frames, self->framesCount, time, PATHCONSTRAINTSPACING_ENTRIES);
	spacing = self->frames[frame + PATHCONSTRAINTSPACING_PREV_VALUE];
	frameTime = self->frames[frame];
	percent = sp34CurveTimeline_getCurvePercent(SUPER(self), frame / PATHCONSTRAINTSPACING_ENTRIES - 1, 1 - (time - frameTime) / (self->frames[frame + PATHCONSTRAINTSPACING_PREV_TIME] - frameTime));

	constraint->spacing += (spacing + (self->frames[frame + PATHCONSTRAINTSPACING_VALUE] - spacing) * percent - constraint->spacing) * alpha;

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

sp34PathConstraintSpacingTimeline* sp34PathConstraintSpacingTimeline_create (int framesCount) {
	return (sp34PathConstraintSpacingTimeline*)_sp34BaseTimeline_create(framesCount, SP_TIMELINE_PATHCONSTRAINTSPACING, PATHCONSTRAINTSPACING_ENTRIES, _sp34PathConstraintSpacingTimeline_apply);
}

void sp34PathConstraintSpacingTimeline_setFrame (sp34PathConstraintSpacingTimeline* self, int frameIndex, float time, float value) {
	frameIndex *= PATHCONSTRAINTSPACING_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + PATHCONSTRAINTSPACING_VALUE] = value;
}

/**/

static const int PATHCONSTRAINTMIX_PREV_TIME = -3;
static const int PATHCONSTRAINTMIX_PREV_ROTATE = -2;
static const int PATHCONSTRAINTMIX_PREV_TRANSLATE = -1;
static const int PATHCONSTRAINTMIX_ROTATE = 1;
static const int PATHCONSTRAINTMIX_TRANSLATE = 2;

void _sp34PathConstraintMixTimeline_apply(const sp34Timeline* timeline, sp34Skeleton* skeleton, float lastTime, float time,
											sp34Event** firedEvents, int* eventsCount, float alpha) {
	int frame;
	float frameTime, percent, rotate, translate;
	sp34PathConstraint* constraint;
	sp34PathConstraintMixTimeline* self = (sp34PathConstraintMixTimeline*)timeline;

	if (time < self->frames[0]) return; /* Time is before first frame. */

	constraint = skeleton->pathConstraints[self->pathConstraintIndex];

	if (time >= self->frames[self->framesCount - PATHCONSTRAINTMIX_ENTRIES]) { /* Time is after last frame. */
		int len = self->framesCount;
		constraint->rotateMix += (self->frames[len + PATHCONSTRAINTMIX_PREV_ROTATE] - constraint->rotateMix) * alpha;
		constraint->translateMix += (self->frames[len + PATHCONSTRAINTMIX_PREV_TRANSLATE] - constraint->translateMix) * alpha;
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frame = binarySearch(self->frames, self->framesCount, time, PATHCONSTRAINTMIX_ENTRIES);
	rotate = self->frames[frame + PATHCONSTRAINTMIX_PREV_ROTATE];
	translate = self->frames[frame + PATHCONSTRAINTMIX_PREV_TRANSLATE];
	frameTime = self->frames[frame];
	percent = sp34CurveTimeline_getCurvePercent(SUPER(self), frame / PATHCONSTRAINTMIX_ENTRIES - 1, 1 - (time - frameTime) / (self->frames[frame + PATHCONSTRAINTMIX_PREV_TIME] - frameTime));

	constraint->rotateMix += (rotate + (self->frames[frame + PATHCONSTRAINTMIX_ROTATE] - rotate) * percent - constraint->rotateMix) * alpha;
	constraint->translateMix += (translate + (self->frames[frame + PATHCONSTRAINTMIX_TRANSLATE] - translate) * percent - constraint->translateMix) * alpha;

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

sp34PathConstraintMixTimeline* sp34PathConstraintMixTimeline_create (int framesCount) {
	return (sp34PathConstraintMixTimeline*)_sp34BaseTimeline_create(framesCount, SP_TIMELINE_PATHCONSTRAINTMIX, PATHCONSTRAINTMIX_ENTRIES, _sp34PathConstraintMixTimeline_apply);
}

void sp34PathConstraintMixTimeline_setFrame (sp34PathConstraintMixTimeline* self, int frameIndex, float time, float rotateMix, float translateMix) {
	frameIndex *= PATHCONSTRAINTMIX_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + PATHCONSTRAINTMIX_ROTATE] = rotateMix;
	self->frames[frameIndex + PATHCONSTRAINTMIX_TRANSLATE] = translateMix;
}

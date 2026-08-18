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

sp35Animation* sp35Animation_create (const char* name, int timelinesCount) {
	sp35Animation* self = NEW(sp35Animation);
	MALLOC_STR(self->name, name);
	self->timelinesCount = timelinesCount;
	self->timelines = MALLOC(sp35Timeline*, timelinesCount);
	return self;
}

void sp35Animation_dispose (sp35Animation* self) {
	int i;
	for (i = 0; i < self->timelinesCount; ++i)
		sp35Timeline_dispose(self->timelines[i]);
	FREE(self->timelines);
	FREE(self->name);
	FREE(self);
}

void sp35Animation_apply (const sp35Animation* self, sp35Skeleton* skeleton, float lastTime, float time, int loop, sp35Event** events,
		int* eventsCount, float alpha, int setupPose, int mixingOut) {
	int i, n = self->timelinesCount;

	if (loop && self->duration) {
		time = FMOD(time, self->duration);
		if (lastTime > 0) lastTime = FMOD(lastTime, self->duration);
	}

	for (i = 0; i < n; ++i)
		sp35Timeline_apply(self->timelines[i], skeleton, lastTime, time, events, eventsCount, alpha, setupPose, mixingOut);
}

/**/

typedef struct _sp35TimelineVtable {
	void (*apply) (const sp35Timeline* self, sp35Skeleton* skeleton, float lastTime, float time, sp35Event** firedEvents,
			int* eventsCount, float alpha, int setupPose, int mixingOut);
	int (*getPropertyId) (const sp35Timeline* self);
	void (*dispose) (sp35Timeline* self);
} _sp35TimelineVtable;

void _sp35Timeline_init (sp35Timeline* self, sp35TimelineType type, /**/
					   void (*dispose) (sp35Timeline* self), /**/
					   void (*apply) (const sp35Timeline* self, sp35Skeleton* skeleton, float lastTime, float time, sp35Event** firedEvents, int* eventsCount, float alpha, int setupPose, int mixingOut),
					   int (*getPropertyId) (const sp35Timeline* self)) {
	CONST_CAST(sp35TimelineType, self->type) = type;
	CONST_CAST(_sp35TimelineVtable*, self->vtable) = NEW(_sp35TimelineVtable);
	VTABLE(sp35Timeline, self)->dispose = dispose;
	VTABLE(sp35Timeline, self)->apply = apply;
	VTABLE(sp35Timeline, self)->getPropertyId = getPropertyId;
}

void _sp35Timeline_deinit (sp35Timeline* self) {
	FREE(self->vtable);
}

void sp35Timeline_dispose (sp35Timeline* self) {
	VTABLE(sp35Timeline, self)->dispose(self);
}

void sp35Timeline_apply (const sp35Timeline* self, sp35Skeleton* skeleton, float lastTime, float time, sp35Event** firedEvents,
		int* eventsCount, float alpha, int /*boolean*/ setupPose, int /*boolean*/ mixingOut) {
	VTABLE(sp35Timeline, self)->apply(self, skeleton, lastTime, time, firedEvents, eventsCount, alpha, setupPose, mixingOut);
}

int sp35Timeline_getPropertyId (const sp35Timeline* self) {
	return VTABLE(sp35Timeline, self)->getPropertyId(self);
}

/**/

static const float CURVE_LINEAR = 0, CURVE_STEPPED = 1, CURVE_BEZIER = 2;
static const int BEZIER_SIZE = 10 * 2 - 1;

void _sp35CurveTimeline_init (sp35CurveTimeline* self, sp35TimelineType type, int framesCount, /**/
		void (*dispose) (sp35Timeline* self), /**/
		void (*apply) (const sp35Timeline* self, sp35Skeleton* skeleton, float lastTime, float time, sp35Event** firedEvents, int* eventsCount, float alpha, int setupPose, int mixingOut),
		int (*getPropertyId)(const sp35Timeline* self)) {
	_sp35Timeline_init(SUPER(self), type, dispose, apply, getPropertyId);
	self->curves = CALLOC(float, (framesCount - 1) * BEZIER_SIZE);
}

void _sp35CurveTimeline_deinit (sp35CurveTimeline* self) {
	_sp35Timeline_deinit(SUPER(self));
	FREE(self->curves);
}

void sp35CurveTimeline_setLinear (sp35CurveTimeline* self, int frameIndex) {
	self->curves[frameIndex * BEZIER_SIZE] = CURVE_LINEAR;
}

void sp35CurveTimeline_setStepped (sp35CurveTimeline* self, int frameIndex) {
	self->curves[frameIndex * BEZIER_SIZE] = CURVE_STEPPED;
}

void sp35CurveTimeline_setCurve (sp35CurveTimeline* self, int frameIndex, float cx1, float cy1, float cx2, float cy2) {
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

float sp35CurveTimeline_getCurvePercent (const sp35CurveTimeline* self, int frameIndex, float percent) {
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

int _sp35CurveTimeline_binarySearch (float *values, int valuesLength, float target, int step) {
	return binarySearch(values, valuesLength, target, step);
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

void _sp35BaseTimeline_dispose (sp35Timeline* timeline) {
	struct sp35BaseTimeline* self = SUB_CAST(struct sp35BaseTimeline, timeline);
	_sp35CurveTimeline_deinit(SUPER(self));
	FREE(self->frames);
	FREE(self);
}

/* Many timelines have structure identical to struct sp35BaseTimeline and extend sp35CurveTimeline. **/
struct sp35BaseTimeline* _sp35BaseTimeline_create (int framesCount, sp35TimelineType type, int frameSize, /**/
		void (*apply) (const sp35Timeline* self, sp35Skeleton* skeleton, float lastTime, float time, sp35Event** firedEvents,
				int* eventsCount, float alpha, int setupPose, int mixingOut),
		int (*getPropertyId) (const sp35Timeline* self)) {
	struct sp35BaseTimeline* self = NEW(struct sp35BaseTimeline);
	_sp35CurveTimeline_init(SUPER(self), type, framesCount, _sp35BaseTimeline_dispose, apply, getPropertyId);

	CONST_CAST(int, self->framesCount) = framesCount * frameSize;
	CONST_CAST(float*, self->frames) = CALLOC(float, self->framesCount);

	return self;
}

/**/

void _sp35RotateTimeline_apply (const sp35Timeline* timeline, sp35Skeleton* skeleton, float lastTime, float time, sp35Event** firedEvents,
		int* eventsCount, float alpha, int setupPose, int mixingOut) {
	sp35Bone *bone;
	int frame;
	float prevRotation, frameTime, percent, r;

	sp35RotateTimeline* self = SUB_CAST(sp35RotateTimeline, timeline);

	bone = skeleton->bones[self->boneIndex];
	if (time < self->frames[0]) {
		if (setupPose) bone->rotation = bone->data->rotation;
		return;
	}

	if (time >= self->frames[self->framesCount - ROTATE_ENTRIES]) { /* Time is after last frame. */
		if (setupPose)
			bone->rotation = bone->data->rotation + self->frames[self->framesCount + ROTATE_PREV_ROTATION] * alpha;
		else {
			r = bone->data->rotation + self->frames[self->framesCount + ROTATE_PREV_ROTATION] - bone->rotation;
			r -= (16384 - (int)(16384.499999999996 - r / 360)) * 360; /* Wrap within -180 and 180. */
			bone->rotation += r * alpha;
		}
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frame = binarySearch(self->frames, self->framesCount, time, ROTATE_ENTRIES);
	prevRotation = self->frames[frame + ROTATE_PREV_ROTATION];
	frameTime = self->frames[frame];
	percent = sp35CurveTimeline_getCurvePercent(SUPER(self), (frame >> 1) - 1, 1 - (time - frameTime) / (self->frames[frame + ROTATE_PREV_TIME] - frameTime));

	r = self->frames[frame + ROTATE_ROTATION] - prevRotation;
	r -= (16384 - (int)(16384.499999999996 - r / 360)) * 360;
	r = prevRotation + r * percent;
	if (setupPose) {
		r -= (16384 - (int)(16384.499999999996 - r / 360)) * 360;
		bone->rotation = bone->data->rotation + r * alpha;
	} else {
		r = bone->data->rotation + r - bone->rotation;
		r -= (16384 - (int)(16384.499999999996 - r / 360)) * 360;
		bone->rotation += r * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp35RotateTimeline_getPropertyId (const sp35Timeline* timeline) {
	return (SP_TIMELINE_ROTATE << 25) + SUB_CAST(sp35RotateTimeline, timeline)->boneIndex;
}

sp35RotateTimeline* sp35RotateTimeline_create (int framesCount) {
	return _sp35BaseTimeline_create(framesCount, SP_TIMELINE_ROTATE, ROTATE_ENTRIES, _sp35RotateTimeline_apply, _sp35RotateTimeline_getPropertyId);
}

void sp35RotateTimeline_setFrame (sp35RotateTimeline* self, int frameIndex, float time, float degrees) {
	frameIndex <<= 1;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + ROTATE_ROTATION] = degrees;
}

/**/

static const int TRANSLATE_PREV_TIME = -3, TRANSLATE_PREV_X = -2, TRANSLATE_PREV_Y = -1;
static const int TRANSLATE_X = 1, TRANSLATE_Y = 2;

void _sp35TranslateTimeline_apply (const sp35Timeline* timeline, sp35Skeleton* skeleton, float lastTime, float time,
		sp35Event** firedEvents, int* eventsCount, float alpha, int setupPose, int mixingOut) {
	sp35Bone *bone;
	int frame;
	float frameTime, percent;
	float x, y;
	float *frames;
	int framesCount;

	sp35TranslateTimeline* self = SUB_CAST(sp35TranslateTimeline, timeline);

	bone = skeleton->bones[self->boneIndex];
	if (time < self->frames[0]) {
		if (setupPose) {
			bone->x = bone->data->x;
			bone->y = bone->data->y;
		}
		return;
	}

	frames = self->frames;
	framesCount = self->framesCount;
	if (time >= frames[framesCount - TRANSLATE_ENTRIES]) { /* Time is after last frame. */
		x = frames[framesCount + TRANSLATE_PREV_X];
		y = frames[framesCount + TRANSLATE_PREV_Y];
	} else {
		/* Interpolate between the previous frame and the current frame. */
		frame = binarySearch(frames, framesCount, time, TRANSLATE_ENTRIES);
		x = frames[frame + TRANSLATE_PREV_X];
		y = frames[frame + TRANSLATE_PREV_Y];
		frameTime = frames[frame];
		percent = sp35CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSLATE_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + TRANSLATE_PREV_TIME] - frameTime));

		x += (frames[frame + TRANSLATE_X] - x) * percent;
		y += (frames[frame + TRANSLATE_Y] - y) * percent;
	}
	if (setupPose) {
		bone->x = bone->data->x + x * alpha;
		bone->y = bone->data->y + y * alpha;
	} else {
		bone->x += (bone->data->x + x - bone->x) * alpha;
		bone->y += (bone->data->y + y - bone->y) * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp35TranslateTimeline_getPropertyId (const sp35Timeline* self) {
	return (SP_TIMELINE_TRANSLATE << 24) + SUB_CAST(sp35TranslateTimeline, self)->boneIndex;
}

sp35TranslateTimeline* sp35TranslateTimeline_create (int framesCount) {
	return _sp35BaseTimeline_create(framesCount, SP_TIMELINE_TRANSLATE, TRANSLATE_ENTRIES, _sp35TranslateTimeline_apply, _sp35TranslateTimeline_getPropertyId);
}

void sp35TranslateTimeline_setFrame (sp35TranslateTimeline* self, int frameIndex, float time, float x, float y) {
	frameIndex *= TRANSLATE_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + TRANSLATE_X] = x;
	self->frames[frameIndex + TRANSLATE_Y] = y;
}

/**/

void _sp35ScaleTimeline_apply (const sp35Timeline* timeline, sp35Skeleton* skeleton, float lastTime, float time, sp35Event** firedEvents,
		int* eventsCount, float alpha, int setupPose, int mixingOut) {
	sp35Bone *bone;
	int frame;
	float frameTime, percent, x, y;
	float *frames;
	int framesCount;

	sp35ScaleTimeline* self = SUB_CAST(sp35ScaleTimeline, timeline);

	bone = skeleton->bones[self->boneIndex];
	if (time < self->frames[0]) {
		if (setupPose) {
			bone->scaleX = bone->data->scaleX;
			bone->scaleY = bone->data->scaleY;
		}
		return;
	}

	frames = self->frames;
	framesCount = self->framesCount;
	if (time >= frames[framesCount - TRANSLATE_ENTRIES]) { /* Time is after last frame. */
		x = frames[framesCount + TRANSLATE_PREV_X] * bone->data->scaleX;
		y = frames[framesCount + TRANSLATE_PREV_Y] * bone->data->scaleY;
	} else {
		/* Interpolate between the previous frame and the current frame. */
		frame = binarySearch(frames, framesCount, time, TRANSLATE_ENTRIES);
		x = frames[frame + TRANSLATE_PREV_X];
		y = frames[frame + TRANSLATE_PREV_Y];
		frameTime = frames[frame];
		percent = sp35CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSLATE_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + TRANSLATE_PREV_TIME] - frameTime));

		x = (x + (frames[frame + TRANSLATE_X] - x) * percent) * bone->data->scaleX;
		y = (y + (frames[frame + TRANSLATE_Y] - y) * percent) * bone->data->scaleY;
	}
	if (alpha == 1) {
		bone->scaleX = x;
		bone->scaleY = y;
	} else {
		float bx, by;
		if (setupPose) {
			bx = bone->data->scaleX;
			by = bone->data->scaleY;
		} else {
			bx = bone->scaleX;
			by = bone->scaleY;
		}
		/* Mixing out uses sign of setup or current pose, else use sign of key. */
		if (mixingOut) {
			x = ABS(x) * SIGNUM(bx);
			y = ABS(y) * SIGNUM(by);
		} else {
			bx = ABS(bx) * SIGNUM(x);
			by = ABS(by) * SIGNUM(y);
		}
		bone->scaleX = bx + (x - bx) * alpha;
		bone->scaleY = by + (y - by) * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp35ScaleTimeline_getPropertyId (const sp35Timeline* timeline) {
	return (SP_TIMELINE_SCALE << 24) + SUB_CAST(sp35ScaleTimeline, timeline)->boneIndex;
}

sp35ScaleTimeline* sp35ScaleTimeline_create (int framesCount) {
	return _sp35BaseTimeline_create(framesCount, SP_TIMELINE_SCALE, TRANSLATE_ENTRIES, _sp35ScaleTimeline_apply, _sp35ScaleTimeline_getPropertyId);
}

void sp35ScaleTimeline_setFrame (sp35ScaleTimeline* self, int frameIndex, float time, float x, float y) {
	sp35TranslateTimeline_setFrame(self, frameIndex, time, x, y);
}

/**/

void _sp35ShearTimeline_apply (const sp35Timeline* timeline, sp35Skeleton* skeleton, float lastTime, float time, sp35Event** firedEvents,
							 int* eventsCount, float alpha, int setupPose, int mixingOut) {
	sp35Bone *bone;
	int frame;
	float frameTime, percent, x, y;
	float *frames;
	int framesCount;

	sp35ShearTimeline* self = SUB_CAST(sp35ShearTimeline, timeline);

	bone = skeleton->bones[self->boneIndex];
	frames = self->frames;
	framesCount = self->framesCount;
	if (time < self->frames[0]) {
		if (setupPose) {
			bone->shearX = bone->data->shearX;
			bone->shearY = bone->data->shearY;
		}
		return;
	}

	if (time >= frames[framesCount - TRANSLATE_ENTRIES]) { /* Time is after last frame. */
		x = frames[framesCount + TRANSLATE_PREV_X];
		y = frames[framesCount + TRANSLATE_PREV_Y];
	} else {
		/* Interpolate between the previous frame and the current frame. */
		frame = binarySearch(frames, framesCount, time, TRANSLATE_ENTRIES);
		x = frames[frame + TRANSLATE_PREV_X];
		y = frames[frame + TRANSLATE_PREV_Y];
		frameTime = frames[frame];
		percent = sp35CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSLATE_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + TRANSLATE_PREV_TIME] - frameTime));

		x = x + (frames[frame + TRANSLATE_X] - x) * percent;
		y = y + (frames[frame + TRANSLATE_Y] - y) * percent;
	}
	if (setupPose) {
		bone->shearX = bone->data->shearX + x * alpha;
		bone->shearY = bone->data->shearY + y * alpha;
	} else {
		bone->shearX += (bone->data->shearX + x - bone->shearX) * alpha;
		bone->shearY += (bone->data->shearY + y - bone->shearY) * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp35ShearTimeline_getPropertyId (const sp35Timeline* timeline) {
	return (SP_TIMELINE_SHEAR << 24) + SUB_CAST(sp35ShearTimeline, timeline)->boneIndex;
}

sp35ShearTimeline* sp35ShearTimeline_create (int framesCount) {
	return (sp35ShearTimeline*)_sp35BaseTimeline_create(framesCount, SP_TIMELINE_SHEAR, 3, _sp35ShearTimeline_apply, _sp35ShearTimeline_getPropertyId);
}

void sp35ShearTimeline_setFrame (sp35ShearTimeline* self, int frameIndex, float time, float x, float y) {
	sp35TranslateTimeline_setFrame(self, frameIndex, time, x, y);
}

/**/

static const int COLOR_PREV_TIME = -5, COLOR_PREV_R = -4, COLOR_PREV_G = -3, COLOR_PREV_B = -2, COLOR_PREV_A = -1;
static const int COLOR_R = 1, COLOR_G = 2, COLOR_B = 3, COLOR_A = 4;

void _sp35ColorTimeline_apply (const sp35Timeline* timeline, sp35Skeleton* skeleton, float lastTime, float time, sp35Event** firedEvents,
		int* eventsCount, float alpha, int setupPose, int mixingOut) {
	sp35Slot *slot;
	int frame;
	float percent, frameTime;
	float r, g, b, a;
	sp35ColorTimeline* self = (sp35ColorTimeline*)timeline;
	slot = skeleton->slots[self->slotIndex];

	if (time < self->frames[0]) {
		if (setupPose) {
			slot->r = slot->data->r;
			slot->g = slot->data->g;
			slot->b = slot->data->b;
			slot->a = slot->data->a;
		}
		return;
	}

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
		percent = sp35CurveTimeline_getCurvePercent(SUPER(self), frame / COLOR_ENTRIES - 1,
			1 - (time - frameTime) / (self->frames[frame + COLOR_PREV_TIME] - frameTime));

		r += (self->frames[frame + COLOR_R] - r) * percent;
		g += (self->frames[frame + COLOR_G] - g) * percent;
		b += (self->frames[frame + COLOR_B] - b) * percent;
		a += (self->frames[frame + COLOR_A] - a) * percent;
	}
	if (alpha == 1) {
		slot->r = r;
		slot->g = g;
		slot->b = b;
		slot->a = a;
	} else {
		if (setupPose) {
			slot->r = slot->data->r;
			slot->g = slot->data->g;
			slot->b = slot->data->b;
			slot->a = slot->data->a;
		}
		slot->r += (r - slot->r) * alpha;
		slot->g += (g - slot->g) * alpha;
		slot->b += (b - slot->b) * alpha;
		slot->a += (a - slot->a) * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp35ColorTimeline_getPropertyId (const sp35Timeline* timeline) {
	return (SP_TIMELINE_COLOR << 24) + SUB_CAST(sp35ColorTimeline, timeline)->slotIndex;
}

sp35ColorTimeline* sp35ColorTimeline_create (int framesCount) {
	return (sp35ColorTimeline*)_sp35BaseTimeline_create(framesCount, SP_TIMELINE_COLOR, 5, _sp35ColorTimeline_apply, _sp35ColorTimeline_getPropertyId);
}

void sp35ColorTimeline_setFrame (sp35ColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a) {
	frameIndex *= COLOR_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + COLOR_R] = r;
	self->frames[frameIndex + COLOR_G] = g;
	self->frames[frameIndex + COLOR_B] = b;
	self->frames[frameIndex + COLOR_A] = a;
}

/**/

void _sp35AttachmentTimeline_apply (const sp35Timeline* timeline, sp35Skeleton* skeleton, float lastTime, float time,
		sp35Event** firedEvents, int* eventsCount, float alpha, int setupPose, int mixingOut) {
	const char* attachmentName;
	sp35AttachmentTimeline* self = (sp35AttachmentTimeline*)timeline;
	int frameIndex;
	sp35Slot* slot = skeleton->slots[self->slotIndex];

	if (mixingOut && setupPose) {
		const char* attachmentName = slot->data->attachmentName;
        sp35Slot_setAttachment(slot, attachmentName ? sp35Skeleton_getAttachmentForSlotIndex(skeleton, self->slotIndex, attachmentName) : 0);
		return;
	}

	if (time < self->frames[0]) {
		if (setupPose) {
			attachmentName = slot->data->attachmentName;
			sp35Slot_setAttachment(skeleton->slots[self->slotIndex],
								 attachmentName ? sp35Skeleton_getAttachmentForSlotIndex(skeleton, self->slotIndex, attachmentName) : 0);
		}
		return;
	}

	if (time >= self->frames[self->framesCount - 1])
		frameIndex = self->framesCount - 1;
	else
		frameIndex = binarySearch1(self->frames, self->framesCount, time) - 1;

	attachmentName = self->attachmentNames[frameIndex];
	sp35Slot_setAttachment(skeleton->slots[self->slotIndex],
			attachmentName ? sp35Skeleton_getAttachmentForSlotIndex(skeleton, self->slotIndex, attachmentName) : 0);

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(alpha);
}

int _sp35AttachmentTimeline_getPropertyId (const sp35Timeline* timeline) {
	return (SP_TIMELINE_ATTACHMENT << 24) + SUB_CAST(sp35AttachmentTimeline, timeline)->slotIndex;
}

void _sp35AttachmentTimeline_dispose (sp35Timeline* timeline) {
	sp35AttachmentTimeline* self = SUB_CAST(sp35AttachmentTimeline, timeline);
	int i;

	_sp35Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->attachmentNames[i]);
	FREE(self->attachmentNames);
	FREE(self->frames);
	FREE(self);
}

sp35AttachmentTimeline* sp35AttachmentTimeline_create (int framesCount) {
	sp35AttachmentTimeline* self = NEW(sp35AttachmentTimeline);
	_sp35Timeline_init(SUPER(self), SP_TIMELINE_ATTACHMENT, _sp35AttachmentTimeline_dispose, _sp35AttachmentTimeline_apply, _sp35AttachmentTimeline_getPropertyId);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(char**, self->attachmentNames) = CALLOC(char*, framesCount);

	return self;
}

void sp35AttachmentTimeline_setFrame (sp35AttachmentTimeline* self, int frameIndex, float time, const char* attachmentName) {
	self->frames[frameIndex] = time;

	FREE(self->attachmentNames[frameIndex]);
	if (attachmentName)
		MALLOC_STR(self->attachmentNames[frameIndex], attachmentName);
	else
		self->attachmentNames[frameIndex] = 0;
}

/**/

void _sp35DeformTimeline_apply (const sp35Timeline* timeline, sp35Skeleton* skeleton, float lastTime, float time, sp35Event** firedEvents,
							  int* eventsCount, float alpha, int setupPose, int mixingOut) {
	int frame, i, vertexCount;
	float percent, frameTime;
	const float* prevVertices;
	const float* nextVertices;
	float* frames;
	int framesCount;
	const float** frameVertices;
	float* vertices;
	sp35DeformTimeline* self = (sp35DeformTimeline*)timeline;

	sp35Slot *slot = skeleton->slots[self->slotIndex];

	if (slot->attachment != self->attachment) {
		if (!slot->attachment) return;
		switch (slot->attachment->type) {
			case SP_ATTACHMENT_MESH: {
				sp35MeshAttachment* mesh = SUB_CAST(sp35MeshAttachment, slot->attachment);
				if (!mesh->inheritDeform || mesh->parentMesh != (void*)self->attachment) return;
				break;
			}
			default:
				return;
		}
	}

	frames = self->frames;
	framesCount = self->framesCount;
	if (time < frames[0]) { /* Time is before first frame. */
		if (setupPose) slot->attachmentVerticesCount = 0;
		return;
	}

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

	frameVertices = self->frameVertices;
	vertices = slot->attachmentVertices;

	if (time >= frames[framesCount - 1]) { /* Time is after last frame. */
		const float* lastVertices = self->frameVertices[framesCount - 1];
		if (alpha == 1) {
			/* Vertex positions or deform offsets, no alpha. */
			memcpy(vertices, lastVertices, vertexCount * sizeof(float));
		} else if (setupPose) {
			sp35VertexAttachment* vertexAttachment = SUB_CAST(sp35VertexAttachment, slot->attachment);
			if (!vertexAttachment->bones) {
				/* Unweighted vertex positions, with alpha. */
				float* setupVertices = vertexAttachment->vertices;
				for (i = 0; i < vertexCount; i++) {
					float setup = setupVertices[i];
					vertices[i] = setup + (lastVertices[i] - setup) * alpha;
				}
			} else {
				/* Weighted deform offsets, with alpha. */
				for (i = 0; i < vertexCount; i++)
					vertices[i] = lastVertices[i] * alpha;
			}
		} else {
			/* Vertex positions or deform offsets, with alpha. */
			for (i = 0; i < vertexCount; i++)
				vertices[i] += (lastVertices[i] - vertices[i]) * alpha;
		}
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frame = binarySearch(frames, framesCount, time, 1);
	prevVertices = frameVertices[frame - 1];
	nextVertices = frameVertices[frame];
	frameTime = frames[frame];
	percent = sp35CurveTimeline_getCurvePercent(SUPER(self), frame - 1, 1 - (time - frameTime) / (frames[frame - 1] - frameTime));

	if (alpha == 1) {
		/* Vertex positions or deform offsets, no alpha. */
		for (i = 0; i < vertexCount; i++) {
			float prev = prevVertices[i];
			vertices[i] = prev + (nextVertices[i] - prev) * percent;
		}
	} else if (setupPose) {
		sp35VertexAttachment* vertexAttachment = SUB_CAST(sp35VertexAttachment, slot->attachment);
		if (!vertexAttachment->bones) {
			/* Unweighted vertex positions, with alpha. */
			float* setupVertices = vertexAttachment->vertices;
			for (i = 0; i < vertexCount; i++) {
				float prev = prevVertices[i], setup = setupVertices[i];
				vertices[i] = setup + (prev + (nextVertices[i] - prev) * percent - setup) * alpha;
			}
		} else {
			/* Weighted deform offsets, with alpha. */
			for (i = 0; i < vertexCount; i++) {
				float prev = prevVertices[i];
				vertices[i] = (prev + (nextVertices[i] - prev) * percent) * alpha;
			}
		}
	} else {
		/* Vertex positions or deform offsets, with alpha. */
		for (i = 0; i < vertexCount; i++) {
			float prev = prevVertices[i];
			vertices[i] += (prev + (nextVertices[i] - prev) * percent - vertices[i]) * alpha;
		}
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp35DeformTimeline_getPropertyId (const sp35Timeline* timeline) {
	return (SP_TIMELINE_DEFORM << 24) + SUB_CAST(sp35DeformTimeline, timeline)->slotIndex;
}

void _sp35DeformTimeline_dispose (sp35Timeline* timeline) {
	sp35DeformTimeline* self = SUB_CAST(sp35DeformTimeline, timeline);
	int i;

	_sp35CurveTimeline_deinit(SUPER(self));

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->frameVertices[i]);
	FREE(self->frameVertices);
	FREE(self->frames);
	FREE(self);
}

sp35DeformTimeline* sp35DeformTimeline_create (int framesCount, int frameVerticesCount) {
	sp35DeformTimeline* self = NEW(sp35DeformTimeline);
	_sp35CurveTimeline_init(SUPER(self), SP_TIMELINE_DEFORM, framesCount, _sp35DeformTimeline_dispose, _sp35DeformTimeline_apply, _sp35DeformTimeline_getPropertyId);
	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, self->framesCount);
	CONST_CAST(float**, self->frameVertices) = CALLOC(float*, framesCount);
	CONST_CAST(int, self->frameVerticesCount) = frameVerticesCount;
	return self;
}

void sp35DeformTimeline_setFrame (sp35DeformTimeline* self, int frameIndex, float time, float* vertices) {
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

/** Fires events for frames > lastTime and <= time. */
void _sp35EventTimeline_apply (const sp35Timeline* timeline, sp35Skeleton* skeleton, float lastTime, float time, sp35Event** firedEvents,
		int* eventsCount, float alpha, int setupPose, int mixingOut) {
	sp35EventTimeline* self = (sp35EventTimeline*)timeline;
	int frame;
	if (!firedEvents) return;

	if (lastTime > time) { /* Fire events after last time for looped animations. */
		_sp35EventTimeline_apply(timeline, skeleton, lastTime, (float)INT_MAX, firedEvents, eventsCount, alpha, setupPose, mixingOut);
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

int _sp35EventTimeline_getPropertyId (const sp35Timeline* timeline) {
	return SP_TIMELINE_EVENT << 24;
}

void _sp35EventTimeline_dispose (sp35Timeline* timeline) {
	sp35EventTimeline* self = SUB_CAST(sp35EventTimeline, timeline);
	int i;

	_sp35Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		sp35Event_dispose(self->events[i]);
	FREE(self->events);
	FREE(self->frames);
	FREE(self);
}

sp35EventTimeline* sp35EventTimeline_create (int framesCount) {
	sp35EventTimeline* self = NEW(sp35EventTimeline);
	_sp35Timeline_init(SUPER(self), SP_TIMELINE_EVENT, _sp35EventTimeline_dispose, _sp35EventTimeline_apply, _sp35EventTimeline_getPropertyId);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(sp35Event**, self->events) = CALLOC(sp35Event*, framesCount);

	return self;
}

void sp35EventTimeline_setFrame (sp35EventTimeline* self, int frameIndex, sp35Event* event) {
	self->frames[frameIndex] = event->time;

	FREE(self->events[frameIndex]);
	self->events[frameIndex] = event;
}

/**/

void _sp35DrawOrderTimeline_apply (const sp35Timeline* timeline, sp35Skeleton* skeleton, float lastTime, float time,
		sp35Event** firedEvents, int* eventsCount, float alpha, int setupPose, int mixingOut) {
	int i;
	int frame;
	const int* drawOrderToSetupIndex;
	sp35DrawOrderTimeline* self = (sp35DrawOrderTimeline*)timeline;

	if (mixingOut && setupPose) {
		memcpy(skeleton->drawOrder, skeleton->slots, self->slotsCount * sizeof(sp35Slot*));
		return;
	}

	if (time < self->frames[0]) {
		if (setupPose) memcpy(skeleton->drawOrder, skeleton->slots, self->slotsCount * sizeof(sp35Slot*));
		return;
	}

	if (time >= self->frames[self->framesCount - 1]) /* Time is after last frame. */
		frame = self->framesCount - 1;
	else
		frame = binarySearch1(self->frames, self->framesCount, time) - 1;

	drawOrderToSetupIndex = self->drawOrders[frame];
	if (!drawOrderToSetupIndex)
		memcpy(skeleton->drawOrder, skeleton->slots, self->slotsCount * sizeof(sp35Slot*));
	else {
		for (i = 0; i < self->slotsCount; ++i)
			skeleton->drawOrder[i] = skeleton->slots[drawOrderToSetupIndex[i]];
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(alpha);
}

int _sp35DrawOrderTimeline_getPropertyId (const sp35Timeline* timeline) {
	return SP_TIMELINE_DRAWORDER << 24;
}

void _sp35DrawOrderTimeline_dispose (sp35Timeline* timeline) {
	sp35DrawOrderTimeline* self = SUB_CAST(sp35DrawOrderTimeline, timeline);
	int i;

	_sp35Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->drawOrders[i]);
	FREE(self->drawOrders);
	FREE(self->frames);
	FREE(self);
}

sp35DrawOrderTimeline* sp35DrawOrderTimeline_create (int framesCount, int slotsCount) {
	sp35DrawOrderTimeline* self = NEW(sp35DrawOrderTimeline);
	_sp35Timeline_init(SUPER(self), SP_TIMELINE_DRAWORDER, _sp35DrawOrderTimeline_dispose, _sp35DrawOrderTimeline_apply, _sp35DrawOrderTimeline_getPropertyId);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(int**, self->drawOrders) = CALLOC(int*, framesCount);
	CONST_CAST(int, self->slotsCount) = slotsCount;

	return self;
}

void sp35DrawOrderTimeline_setFrame (sp35DrawOrderTimeline* self, int frameIndex, float time, const int* drawOrder) {
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

static const int IKCONSTRAINT_PREV_TIME = -3, IKCONSTRAINT_PREV_MIX = -2, IKCONSTRAINT_PREV_BEND_DIRECTION = -1;
static const int IKCONSTRAINT_MIX = 1, IKCONSTRAINT_BEND_DIRECTION = 2;

void _sp35IkConstraintTimeline_apply (const sp35Timeline* timeline, sp35Skeleton* skeleton, float lastTime, float time,
		sp35Event** firedEvents, int* eventsCount, float alpha, int setupPose, int mixingOut) {
	int frame;
	float frameTime, percent, mix;
	float *frames;
	int framesCount;
	sp35IkConstraint* constraint;
	sp35IkConstraintTimeline* self = (sp35IkConstraintTimeline*)timeline;

	constraint = skeleton->ikConstraints[self->ikConstraintIndex];

	if (time < self->frames[0]) {
		if (setupPose) {
			constraint->mix = constraint->data->mix;
			constraint->bendDirection = constraint->data->bendDirection;
		}
		return;
	}

	frames = self->frames;
	framesCount = self->framesCount;
	if (time >= frames[framesCount - IKCONSTRAINT_ENTRIES]) { /* Time is after last frame. */
		if (setupPose) {
			constraint->mix = constraint->data->mix + (frames[framesCount + IKCONSTRAINT_PREV_MIX] - constraint->data->mix) * alpha;
			constraint->bendDirection = mixingOut ? constraint->data->bendDirection
												 : (int)frames[framesCount + IKCONSTRAINT_PREV_BEND_DIRECTION];
		} else {
			constraint->mix += (frames[framesCount + IKCONSTRAINT_PREV_MIX] - constraint->mix) * alpha;
			if (!mixingOut) constraint->bendDirection = (int)frames[framesCount + IKCONSTRAINT_PREV_BEND_DIRECTION];
		}
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frame = binarySearch(self->frames, self->framesCount, time, IKCONSTRAINT_ENTRIES);
	mix = self->frames[frame + IKCONSTRAINT_PREV_MIX];
	frameTime = self->frames[frame];
	percent = sp35CurveTimeline_getCurvePercent(SUPER(self), frame / IKCONSTRAINT_ENTRIES - 1, 1 - (time - frameTime) / (self->frames[frame + IKCONSTRAINT_PREV_TIME] - frameTime));

	if (setupPose) {
		constraint->mix = constraint->data->mix + (mix + (frames[frame + IKCONSTRAINT_MIX] - mix) * percent - constraint->data->mix) * alpha;
		constraint->bendDirection = mixingOut ? constraint->data->bendDirection : (int)frames[frame + IKCONSTRAINT_PREV_BEND_DIRECTION];
	} else {
		constraint->mix += (mix + (frames[frame + IKCONSTRAINT_MIX] - mix) * percent - constraint->mix) * alpha;
		if (!mixingOut) constraint->bendDirection = (int)frames[frame + IKCONSTRAINT_PREV_BEND_DIRECTION];
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp35IkConstraintTimeline_getPropertyId (const sp35Timeline* timeline) {
	return (SP_TIMELINE_IKCONSTRAINT << 24) + SUB_CAST(sp35IkConstraintTimeline, timeline)->ikConstraintIndex;
}

sp35IkConstraintTimeline* sp35IkConstraintTimeline_create (int framesCount) {
	return (sp35IkConstraintTimeline*)_sp35BaseTimeline_create(framesCount, SP_TIMELINE_IKCONSTRAINT, IKCONSTRAINT_ENTRIES, _sp35IkConstraintTimeline_apply, _sp35IkConstraintTimeline_getPropertyId);
}

void sp35IkConstraintTimeline_setFrame (sp35IkConstraintTimeline* self, int frameIndex, float time, float mix, int bendDirection) {
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

void _sp35TransformConstraintTimeline_apply (const sp35Timeline* timeline, sp35Skeleton* skeleton, float lastTime, float time,
									sp35Event** firedEvents, int* eventsCount, float alpha, int setupPose, int mixingOut) {
	int frame;
	float frameTime, percent, rotate, translate, scale, shear;
	sp35TransformConstraint* constraint;
	sp35TransformConstraintTimeline* self = (sp35TransformConstraintTimeline*)timeline;
	float *frames;
	int framesCount;

	constraint = skeleton->transformConstraints[self->transformConstraintIndex];
	if (time < self->frames[0]) {
		if (setupPose) {
			sp35TransformConstraintData* data = constraint->data;
			constraint->rotateMix = data->rotateMix;
			constraint->translateMix = data->translateMix;
			constraint->scaleMix = data->scaleMix;
			constraint->shearMix = data->shearMix;
		}
		return;
	}

	frames = self->frames;
	framesCount = self->framesCount;
	if (time >= frames[framesCount - TRANSFORMCONSTRAINT_ENTRIES]) { /* Time is after last frame. */
		int i = framesCount;
		rotate = frames[i + TRANSFORMCONSTRAINT_PREV_ROTATE];
		translate = frames[i + TRANSFORMCONSTRAINT_PREV_TRANSLATE];
		scale = frames[i + TRANSFORMCONSTRAINT_PREV_SCALE];
		shear = frames[i + TRANSFORMCONSTRAINT_PREV_SHEAR];
	} else {
		/* Interpolate between the previous frame and the current frame. */
		frame = binarySearch(frames, framesCount, time, TRANSFORMCONSTRAINT_ENTRIES);
		rotate = frames[frame + TRANSFORMCONSTRAINT_PREV_ROTATE];
		translate = frames[frame + TRANSFORMCONSTRAINT_PREV_TRANSLATE];
		scale = frames[frame + TRANSFORMCONSTRAINT_PREV_SCALE];
		shear = frames[frame + TRANSFORMCONSTRAINT_PREV_SHEAR];
		frameTime = frames[frame];
		percent = sp35CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSFORMCONSTRAINT_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + TRANSFORMCONSTRAINT_PREV_TIME] - frameTime));

		rotate += (frames[frame + TRANSFORMCONSTRAINT_ROTATE] - rotate) * percent;
		translate += (frames[frame + TRANSFORMCONSTRAINT_TRANSLATE] - translate) * percent;
		scale += (frames[frame + TRANSFORMCONSTRAINT_SCALE] - scale) * percent;
		shear += (frames[frame + TRANSFORMCONSTRAINT_SHEAR] - shear) * percent;
	}
	if (setupPose) {
		sp35TransformConstraintData* data = constraint->data;
		constraint->rotateMix = data->rotateMix + (rotate - data->rotateMix) * alpha;
		constraint->translateMix = data->translateMix + (translate - data->translateMix) * alpha;
		constraint->scaleMix = data->scaleMix + (scale - data->scaleMix) * alpha;
		constraint->shearMix = data->shearMix + (shear - data->shearMix) * alpha;
	} else {
		constraint->rotateMix += (rotate - constraint->rotateMix) * alpha;
		constraint->translateMix += (translate - constraint->translateMix) * alpha;
		constraint->scaleMix += (scale - constraint->scaleMix) * alpha;
		constraint->shearMix += (shear - constraint->shearMix) * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp35TransformConstraintTimeline_getPropertyId (const sp35Timeline* timeline) {
	return (SP_TIMELINE_TRANSFORMCONSTRAINT << 24) + SUB_CAST(sp35TransformConstraintTimeline, timeline)->transformConstraintIndex;
}

sp35TransformConstraintTimeline* sp35TransformConstraintTimeline_create (int framesCount) {
	return (sp35TransformConstraintTimeline*)_sp35BaseTimeline_create(framesCount, SP_TIMELINE_TRANSFORMCONSTRAINT, TRANSFORMCONSTRAINT_ENTRIES, _sp35TransformConstraintTimeline_apply, _sp35TransformConstraintTimeline_getPropertyId);
}

void sp35TransformConstraintTimeline_setFrame (sp35TransformConstraintTimeline* self, int frameIndex, float time, float rotateMix, float translateMix, float scaleMix, float shearMix) {
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

void _sp35PathConstraintPositionTimeline_apply(const sp35Timeline* timeline, sp35Skeleton* skeleton, float lastTime, float time,
		sp35Event** firedEvents, int* eventsCount, float alpha, int setupPose, int mixingOut) {
	int frame;
	float frameTime, percent, position;
	sp35PathConstraint* constraint;
	sp35PathConstraintPositionTimeline* self = (sp35PathConstraintPositionTimeline*)timeline;
	float* frames;
	int framesCount;

	constraint = skeleton->pathConstraints[self->pathConstraintIndex];
	if (time < self->frames[0]) {
		if (setupPose) {
			constraint->position = constraint->data->position;
		}
		return;
	}

	frames = self->frames;
	framesCount = self->framesCount;
	if (time >= frames[framesCount - PATHCONSTRAINTPOSITION_ENTRIES]) /* Time is after last frame. */
		position = frames[framesCount + PATHCONSTRAINTPOSITION_PREV_VALUE];
	else {
		/* Interpolate between the previous frame and the current frame. */
		frame = binarySearch(frames, framesCount, time, PATHCONSTRAINTPOSITION_ENTRIES);
		position = frames[frame + PATHCONSTRAINTPOSITION_PREV_VALUE];
		frameTime = frames[frame];
		percent = sp35CurveTimeline_getCurvePercent(SUPER(self), frame / PATHCONSTRAINTPOSITION_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + PATHCONSTRAINTPOSITION_PREV_TIME] - frameTime));

		position += (frames[frame + PATHCONSTRAINTPOSITION_VALUE] - position) * percent;
	}
	if (setupPose)
		constraint->position = constraint->data->position + (position - constraint->data->position) * alpha;
	else
		constraint->position += (position - constraint->position) * alpha;

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp35PathConstraintPositionTimeline_getPropertyId (const sp35Timeline* timeline) {
	return (SP_TIMELINE_PATHCONSTRAINTPOSITION << 24) + SUB_CAST(sp35PathConstraintPositionTimeline, timeline)->pathConstraintIndex;
}

sp35PathConstraintPositionTimeline* sp35PathConstraintPositionTimeline_create (int framesCount) {
	return (sp35PathConstraintPositionTimeline*)_sp35BaseTimeline_create(framesCount, SP_TIMELINE_PATHCONSTRAINTPOSITION, PATHCONSTRAINTPOSITION_ENTRIES, _sp35PathConstraintPositionTimeline_apply, _sp35PathConstraintPositionTimeline_getPropertyId);
}

void sp35PathConstraintPositionTimeline_setFrame (sp35PathConstraintPositionTimeline* self, int frameIndex, float time, float value) {
	frameIndex *= PATHCONSTRAINTPOSITION_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + PATHCONSTRAINTPOSITION_VALUE] = value;
}

/**/
static const int PATHCONSTRAINTSPACING_PREV_TIME = -2;
static const int PATHCONSTRAINTSPACING_PREV_VALUE = -1;
static const int PATHCONSTRAINTSPACING_VALUE = 1;

void _sp35PathConstraintSpacingTimeline_apply(const sp35Timeline* timeline, sp35Skeleton* skeleton, float lastTime, float time,
		sp35Event** firedEvents, int* eventsCount, float alpha, int setupPose, int mixingOut) {
	int frame;
	float frameTime, percent, spacing;
	sp35PathConstraint* constraint;
	sp35PathConstraintSpacingTimeline* self = (sp35PathConstraintSpacingTimeline*)timeline;
	float* frames;
	int framesCount;

	constraint = skeleton->pathConstraints[self->pathConstraintIndex];
	if (time < self->frames[0]) {
		if (setupPose) {
			constraint->spacing = constraint->data->spacing;
		}
		return;
	}

	frames = self->frames;
	framesCount = self->framesCount;
	if (time >= frames[framesCount - PATHCONSTRAINTSPACING_ENTRIES]) /* Time is after last frame. */
		spacing = frames[framesCount + PATHCONSTRAINTSPACING_PREV_VALUE];
	else {
		/* Interpolate between the previous frame and the current frame. */
		frame = binarySearch(frames, framesCount, time, PATHCONSTRAINTSPACING_ENTRIES);
		spacing = frames[frame + PATHCONSTRAINTSPACING_PREV_VALUE];
		frameTime = frames[frame];
		percent = sp35CurveTimeline_getCurvePercent(SUPER(self), frame / PATHCONSTRAINTSPACING_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + PATHCONSTRAINTSPACING_PREV_TIME] - frameTime));

		spacing += (frames[frame + PATHCONSTRAINTSPACING_VALUE] - spacing) * percent;
	}

	if (setupPose)
		constraint->spacing = constraint->data->spacing + (spacing - constraint->data->spacing) * alpha;
	else
		constraint->spacing += (spacing - constraint->spacing) * alpha;

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp35PathConstraintSpacingTimeline_getPropertyId (const sp35Timeline* timeline) {
	return (SP_TIMELINE_PATHCONSTRAINTSPACING << 24) + SUB_CAST(sp35PathConstraintSpacingTimeline, timeline)->pathConstraintIndex;
}

sp35PathConstraintSpacingTimeline* sp35PathConstraintSpacingTimeline_create (int framesCount) {
	return (sp35PathConstraintSpacingTimeline*)_sp35BaseTimeline_create(framesCount, SP_TIMELINE_PATHCONSTRAINTSPACING, PATHCONSTRAINTSPACING_ENTRIES, _sp35PathConstraintSpacingTimeline_apply, _sp35PathConstraintSpacingTimeline_getPropertyId);
}

void sp35PathConstraintSpacingTimeline_setFrame (sp35PathConstraintSpacingTimeline* self, int frameIndex, float time, float value) {
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

void _sp35PathConstraintMixTimeline_apply(const sp35Timeline* timeline, sp35Skeleton* skeleton, float lastTime, float time,
											sp35Event** firedEvents, int* eventsCount, float alpha, int setupPose, int mixingOut) {
	int frame;
	float frameTime, percent, rotate, translate;
	sp35PathConstraint* constraint;
	sp35PathConstraintMixTimeline* self = (sp35PathConstraintMixTimeline*)timeline;
	float* frames;
	int framesCount;

	constraint = skeleton->pathConstraints[self->pathConstraintIndex];
	if (time < self->frames[0]) {
		if (setupPose) {
			constraint->rotateMix = constraint->data->rotateMix;
			constraint->translateMix = constraint->data->translateMix;
		}
		return;
	}

	frames = self->frames;
	framesCount = self->framesCount;
	if (time >= frames[framesCount - PATHCONSTRAINTMIX_ENTRIES]) { /* Time is after last frame. */
		rotate = frames[framesCount + PATHCONSTRAINTMIX_PREV_ROTATE];
		translate = frames[framesCount + PATHCONSTRAINTMIX_PREV_TRANSLATE];
	} else {
		/* Interpolate between the previous frame and the current frame. */
		frame = binarySearch(frames, framesCount, time, PATHCONSTRAINTMIX_ENTRIES);
		rotate = frames[frame + PATHCONSTRAINTMIX_PREV_ROTATE];
		translate = frames[frame + PATHCONSTRAINTMIX_PREV_TRANSLATE];
		frameTime = frames[frame];
		percent = sp35CurveTimeline_getCurvePercent(SUPER(self), frame / PATHCONSTRAINTMIX_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + PATHCONSTRAINTMIX_PREV_TIME] - frameTime));

		rotate += (frames[frame + PATHCONSTRAINTMIX_ROTATE] - rotate) * percent;
		translate += (frames[frame + PATHCONSTRAINTMIX_TRANSLATE] - translate) * percent;
	}

	if (setupPose) {
		constraint->rotateMix = constraint->data->rotateMix + (rotate - constraint->data->rotateMix) * alpha;
		constraint->translateMix = constraint->data->translateMix + (translate - constraint->data->translateMix) * alpha;
	} else {
		constraint->rotateMix += (rotate - constraint->rotateMix) * alpha;
		constraint->translateMix += (translate - constraint->translateMix) * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp35PathConstraintMixTimeline_getPropertyId (const sp35Timeline* timeline) {
	return (SP_TIMELINE_PATHCONSTRAINTMIX << 24) + SUB_CAST(sp35PathConstraintMixTimeline, timeline)->pathConstraintIndex;
}

sp35PathConstraintMixTimeline* sp35PathConstraintMixTimeline_create (int framesCount) {
	return (sp35PathConstraintMixTimeline*)_sp35BaseTimeline_create(framesCount, SP_TIMELINE_PATHCONSTRAINTMIX, PATHCONSTRAINTMIX_ENTRIES, _sp35PathConstraintMixTimeline_apply, _sp35PathConstraintMixTimeline_getPropertyId);
}

void sp35PathConstraintMixTimeline_setFrame (sp35PathConstraintMixTimeline* self, int frameIndex, float time, float rotateMix, float translateMix) {
	frameIndex *= PATHCONSTRAINTMIX_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + PATHCONSTRAINTMIX_ROTATE] = rotateMix;
	self->frames[frameIndex + PATHCONSTRAINTMIX_TRANSLATE] = translateMix;
}

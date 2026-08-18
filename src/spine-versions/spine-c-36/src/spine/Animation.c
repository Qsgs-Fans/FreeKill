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

sp36Animation* sp36Animation_create (const char* name, int timelinesCount) {
	sp36Animation* self = NEW(sp36Animation);
	MALLOC_STR(self->name, name);
	self->timelinesCount = timelinesCount;
	self->timelines = MALLOC(sp36Timeline*, timelinesCount);
	return self;
}

void sp36Animation_dispose (sp36Animation* self) {
	int i;
	for (i = 0; i < self->timelinesCount; ++i)
		sp36Timeline_dispose(self->timelines[i]);
	FREE(self->timelines);
	FREE(self->name);
	FREE(self);
}

void sp36Animation_apply (const sp36Animation* self, sp36Skeleton* skeleton, float lastTime, float time, int loop, sp36Event** events,
		int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction) {
	int i, n = self->timelinesCount;

	if (loop && self->duration) {
		time = FMOD(time, self->duration);
		if (lastTime > 0) lastTime = FMOD(lastTime, self->duration);
	}

	for (i = 0; i < n; ++i)
		sp36Timeline_apply(self->timelines[i], skeleton, lastTime, time, events, eventsCount, alpha, pose, direction);
}

/**/

typedef struct _sp36TimelineVtable {
	void (*apply) (const sp36Timeline* self, sp36Skeleton* skeleton, float lastTime, float time, sp36Event** firedEvents,
			int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction);
	int (*getPropertyId) (const sp36Timeline* self);
	void (*dispose) (sp36Timeline* self);
} _sp36TimelineVtable;

void _sp36Timeline_init (sp36Timeline* self, sp36TimelineType type, /**/
					   void (*dispose) (sp36Timeline* self), /**/
					   void (*apply) (const sp36Timeline* self, sp36Skeleton* skeleton, float lastTime, float time, sp36Event** firedEvents, int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction),
					   int (*getPropertyId) (const sp36Timeline* self)) {
	CONST_CAST(sp36TimelineType, self->type) = type;
	CONST_CAST(_sp36TimelineVtable*, self->vtable) = NEW(_sp36TimelineVtable);
	VTABLE(sp36Timeline, self)->dispose = dispose;
	VTABLE(sp36Timeline, self)->apply = apply;
	VTABLE(sp36Timeline, self)->getPropertyId = getPropertyId;
}

void _sp36Timeline_deinit (sp36Timeline* self) {
	FREE(self->vtable);
}

void sp36Timeline_dispose (sp36Timeline* self) {
	VTABLE(sp36Timeline, self)->dispose(self);
}

void sp36Timeline_apply (const sp36Timeline* self, sp36Skeleton* skeleton, float lastTime, float time, sp36Event** firedEvents,
		int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction) {
	VTABLE(sp36Timeline, self)->apply(self, skeleton, lastTime, time, firedEvents, eventsCount, alpha, pose, direction);
}

int sp36Timeline_getPropertyId (const sp36Timeline* self) {
	return VTABLE(sp36Timeline, self)->getPropertyId(self);
}

/**/

static const float CURVE_LINEAR = 0, CURVE_STEPPED = 1, CURVE_BEZIER = 2;
static const int BEZIER_SIZE = 10 * 2 - 1;

void _sp36CurveTimeline_init (sp36CurveTimeline* self, sp36TimelineType type, int framesCount, /**/
		void (*dispose) (sp36Timeline* self), /**/
		void (*apply) (const sp36Timeline* self, sp36Skeleton* skeleton, float lastTime, float time, sp36Event** firedEvents, int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction),
		int (*getPropertyId)(const sp36Timeline* self)) {
	_sp36Timeline_init(SUPER(self), type, dispose, apply, getPropertyId);
	self->curves = CALLOC(float, (framesCount - 1) * BEZIER_SIZE);
}

void _sp36CurveTimeline_deinit (sp36CurveTimeline* self) {
	_sp36Timeline_deinit(SUPER(self));
	FREE(self->curves);
}

void sp36CurveTimeline_setLinear (sp36CurveTimeline* self, int frameIndex) {
	self->curves[frameIndex * BEZIER_SIZE] = CURVE_LINEAR;
}

void sp36CurveTimeline_setStepped (sp36CurveTimeline* self, int frameIndex) {
	self->curves[frameIndex * BEZIER_SIZE] = CURVE_STEPPED;
}

void sp36CurveTimeline_setCurve (sp36CurveTimeline* self, int frameIndex, float cx1, float cy1, float cx2, float cy2) {
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

float sp36CurveTimeline_getCurvePercent (const sp36CurveTimeline* self, int frameIndex, float percent) {
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

int _sp36CurveTimeline_binarySearch (float *values, int valuesLength, float target, int step) {
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

void _sp36BaseTimeline_dispose (sp36Timeline* timeline) {
	struct sp36BaseTimeline* self = SUB_CAST(struct sp36BaseTimeline, timeline);
	_sp36CurveTimeline_deinit(SUPER(self));
	FREE(self->frames);
	FREE(self);
}

/* Many timelines have structure identical to struct sp36BaseTimeline and extend sp36CurveTimeline. **/
struct sp36BaseTimeline* _sp36BaseTimeline_create (int framesCount, sp36TimelineType type, int frameSize, /**/
		void (*apply) (const sp36Timeline* self, sp36Skeleton* skeleton, float lastTime, float time, sp36Event** firedEvents,
				int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction),
		int (*getPropertyId) (const sp36Timeline* self)) {
	struct sp36BaseTimeline* self = NEW(struct sp36BaseTimeline);
	_sp36CurveTimeline_init(SUPER(self), type, framesCount, _sp36BaseTimeline_dispose, apply, getPropertyId);

	CONST_CAST(int, self->framesCount) = framesCount * frameSize;
	CONST_CAST(float*, self->frames) = CALLOC(float, self->framesCount);

	return self;
}

/**/

void _sp36RotateTimeline_apply (const sp36Timeline* timeline, sp36Skeleton* skeleton, float lastTime, float time, sp36Event** firedEvents,
		int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction) {
	sp36Bone *bone;
	int frame;
	float prevRotation, frameTime, percent, r;

	sp36RotateTimeline* self = SUB_CAST(sp36RotateTimeline, timeline);

	bone = skeleton->bones[self->boneIndex];
	if (time < self->frames[0]) {
		switch (pose) {
			case SP_MIX_POSE_SETUP:
				bone->rotation = bone->data->rotation;
				return;
			case SP_MIX_POSE_CURRENT:
				r = bone->data->rotation - bone->rotation;
				r -= (16384 - (int)(16384.499999999996 - r / 360)) * 360;
				bone->rotation += r * alpha;
			case SP_MIX_POSE_CURRENT_LAYERED:; /* to appease compiler */
		}
		return;
	}

	if (time >= self->frames[self->framesCount - ROTATE_ENTRIES]) { /* Time is after last frame. */
		if (pose == SP_MIX_POSE_SETUP)
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
	percent = sp36CurveTimeline_getCurvePercent(SUPER(self), (frame >> 1) - 1, 1 - (time - frameTime) / (self->frames[frame + ROTATE_PREV_TIME] - frameTime));

	r = self->frames[frame + ROTATE_ROTATION] - prevRotation;
	r -= (16384 - (int)(16384.499999999996 - r / 360)) * 360;
	r = prevRotation + r * percent;
	if (pose == SP_MIX_POSE_SETUP) {
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

int _sp36RotateTimeline_getPropertyId (const sp36Timeline* timeline) {
	return (SP_TIMELINE_ROTATE << 25) + SUB_CAST(sp36RotateTimeline, timeline)->boneIndex;
}

sp36RotateTimeline* sp36RotateTimeline_create (int framesCount) {
	return _sp36BaseTimeline_create(framesCount, SP_TIMELINE_ROTATE, ROTATE_ENTRIES, _sp36RotateTimeline_apply, _sp36RotateTimeline_getPropertyId);
}

void sp36RotateTimeline_setFrame (sp36RotateTimeline* self, int frameIndex, float time, float degrees) {
	frameIndex <<= 1;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + ROTATE_ROTATION] = degrees;
}

/**/

static const int TRANSLATE_PREV_TIME = -3, TRANSLATE_PREV_X = -2, TRANSLATE_PREV_Y = -1;
static const int TRANSLATE_X = 1, TRANSLATE_Y = 2;

void _sp36TranslateTimeline_apply (const sp36Timeline* timeline, sp36Skeleton* skeleton, float lastTime, float time,
		sp36Event** firedEvents, int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction) {
	sp36Bone *bone;
	int frame;
	float frameTime, percent;
	float x, y;
	float *frames;
	int framesCount;

	sp36TranslateTimeline* self = SUB_CAST(sp36TranslateTimeline, timeline);

	bone = skeleton->bones[self->boneIndex];
	if (time < self->frames[0]) {
		switch (pose) {
			case SP_MIX_POSE_SETUP:
				bone->x = bone->data->x;
				bone->y = bone->data->y;
				return;
			case SP_MIX_POSE_CURRENT:
				bone->x += (bone->data->x - bone->x) * alpha;
				bone->y += (bone->data->y - bone->y) * alpha;
			case SP_MIX_POSE_CURRENT_LAYERED:; /* to appease compiler */
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
		percent = sp36CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSLATE_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + TRANSLATE_PREV_TIME] - frameTime));

		x += (frames[frame + TRANSLATE_X] - x) * percent;
		y += (frames[frame + TRANSLATE_Y] - y) * percent;
	}
	if (pose == SP_MIX_POSE_SETUP) {
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

int _sp36TranslateTimeline_getPropertyId (const sp36Timeline* self) {
	return (SP_TIMELINE_TRANSLATE << 24) + SUB_CAST(sp36TranslateTimeline, self)->boneIndex;
}

sp36TranslateTimeline* sp36TranslateTimeline_create (int framesCount) {
	return _sp36BaseTimeline_create(framesCount, SP_TIMELINE_TRANSLATE, TRANSLATE_ENTRIES, _sp36TranslateTimeline_apply, _sp36TranslateTimeline_getPropertyId);
}

void sp36TranslateTimeline_setFrame (sp36TranslateTimeline* self, int frameIndex, float time, float x, float y) {
	frameIndex *= TRANSLATE_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + TRANSLATE_X] = x;
	self->frames[frameIndex + TRANSLATE_Y] = y;
}

/**/

void _sp36ScaleTimeline_apply (const sp36Timeline* timeline, sp36Skeleton* skeleton, float lastTime, float time, sp36Event** firedEvents,
		int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction) {
	sp36Bone *bone;
	int frame;
	float frameTime, percent, x, y;
	float *frames;
	int framesCount;

	sp36ScaleTimeline* self = SUB_CAST(sp36ScaleTimeline, timeline);

	bone = skeleton->bones[self->boneIndex];
	if (time < self->frames[0]) {
		switch (pose) {
			case SP_MIX_POSE_SETUP:
				bone->scaleX = bone->data->scaleX;
				bone->scaleY = bone->data->scaleY;
				return;
			case SP_MIX_POSE_CURRENT:
				bone->scaleX += (bone->data->scaleX - bone->scaleX) * alpha;
				bone->scaleY += (bone->data->scaleY - bone->scaleY) * alpha;
			case SP_MIX_POSE_CURRENT_LAYERED:; /* to appease compiler */
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
		percent = sp36CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSLATE_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + TRANSLATE_PREV_TIME] - frameTime));

		x = (x + (frames[frame + TRANSLATE_X] - x) * percent) * bone->data->scaleX;
		y = (y + (frames[frame + TRANSLATE_Y] - y) * percent) * bone->data->scaleY;
	}
	if (alpha == 1) {
		bone->scaleX = x;
		bone->scaleY = y;
	} else {
		float bx, by;
		if (pose == SP_MIX_POSE_SETUP) {
			bx = bone->data->scaleX;
			by = bone->data->scaleY;
		} else {
			bx = bone->scaleX;
			by = bone->scaleY;
		}
		/* Mixing out uses sign of setup or current pose, else use sign of key. */
		if (direction == SP_MIX_DIRECTION_OUT) {
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

int _sp36ScaleTimeline_getPropertyId (const sp36Timeline* timeline) {
	return (SP_TIMELINE_SCALE << 24) + SUB_CAST(sp36ScaleTimeline, timeline)->boneIndex;
}

sp36ScaleTimeline* sp36ScaleTimeline_create (int framesCount) {
	return _sp36BaseTimeline_create(framesCount, SP_TIMELINE_SCALE, TRANSLATE_ENTRIES, _sp36ScaleTimeline_apply, _sp36ScaleTimeline_getPropertyId);
}

void sp36ScaleTimeline_setFrame (sp36ScaleTimeline* self, int frameIndex, float time, float x, float y) {
	sp36TranslateTimeline_setFrame(self, frameIndex, time, x, y);
}

/**/

void _sp36ShearTimeline_apply (const sp36Timeline* timeline, sp36Skeleton* skeleton, float lastTime, float time, sp36Event** firedEvents,
							 int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction) {
	sp36Bone *bone;
	int frame;
	float frameTime, percent, x, y;
	float *frames;
	int framesCount;

	sp36ShearTimeline* self = SUB_CAST(sp36ShearTimeline, timeline);

	bone = skeleton->bones[self->boneIndex];
	frames = self->frames;
	framesCount = self->framesCount;
	if (time < self->frames[0]) {
		switch (pose) {
			case SP_MIX_POSE_SETUP:
				bone->shearX = bone->data->shearX;
				bone->shearY = bone->data->shearY;
				return;
			case SP_MIX_POSE_CURRENT:
				bone->shearX += (bone->data->shearX - bone->shearX) * alpha;
				bone->shearY += (bone->data->shearY - bone->shearY) * alpha;
			case SP_MIX_POSE_CURRENT_LAYERED:; /* to appease compiler */
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
		percent = sp36CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSLATE_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + TRANSLATE_PREV_TIME] - frameTime));

		x = x + (frames[frame + TRANSLATE_X] - x) * percent;
		y = y + (frames[frame + TRANSLATE_Y] - y) * percent;
	}
	if (pose == SP_MIX_POSE_SETUP) {
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

int _sp36ShearTimeline_getPropertyId (const sp36Timeline* timeline) {
	return (SP_TIMELINE_SHEAR << 24) + SUB_CAST(sp36ShearTimeline, timeline)->boneIndex;
}

sp36ShearTimeline* sp36ShearTimeline_create (int framesCount) {
	return (sp36ShearTimeline*)_sp36BaseTimeline_create(framesCount, SP_TIMELINE_SHEAR, 3, _sp36ShearTimeline_apply, _sp36ShearTimeline_getPropertyId);
}

void sp36ShearTimeline_setFrame (sp36ShearTimeline* self, int frameIndex, float time, float x, float y) {
	sp36TranslateTimeline_setFrame(self, frameIndex, time, x, y);
}

/**/

static const int COLOR_PREV_TIME = -5, COLOR_PREV_R = -4, COLOR_PREV_G = -3, COLOR_PREV_B = -2, COLOR_PREV_A = -1;
static const int COLOR_R = 1, COLOR_G = 2, COLOR_B = 3, COLOR_A = 4;

void _sp36ColorTimeline_apply (const sp36Timeline* timeline, sp36Skeleton* skeleton, float lastTime, float time, sp36Event** firedEvents,
		int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction) {
	sp36Slot *slot;
	int frame;
	float percent, frameTime;
	float r, g, b, a;
	sp36Color* color;
	sp36Color* setup;
	sp36ColorTimeline* self = (sp36ColorTimeline*)timeline;
	slot = skeleton->slots[self->slotIndex];

	if (time < self->frames[0]) {
		switch (pose) {
			case SP_MIX_POSE_SETUP:
				sp36Color_setFromColor(&slot->color, &slot->data->color);
				return;
			case SP_MIX_POSE_CURRENT:
				color = &slot->color;
				setup = &slot->data->color;
				sp36Color_addFloats(color, (setup->r - color->r) * alpha, (setup->g - color->g) * alpha, (setup->b - color->b) * alpha,
						  (setup->a - color->a) * alpha);
			case SP_MIX_POSE_CURRENT_LAYERED:; /* to appease compiler */
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
		percent = sp36CurveTimeline_getCurvePercent(SUPER(self), frame / COLOR_ENTRIES - 1,
			1 - (time - frameTime) / (self->frames[frame + COLOR_PREV_TIME] - frameTime));

		r += (self->frames[frame + COLOR_R] - r) * percent;
		g += (self->frames[frame + COLOR_G] - g) * percent;
		b += (self->frames[frame + COLOR_B] - b) * percent;
		a += (self->frames[frame + COLOR_A] - a) * percent;
	}
	if (alpha == 1) {
		sp36Color_setFromFloats(&slot->color, r, g, b, a);
	} else {
		if (pose == SP_MIX_POSE_SETUP) {
			sp36Color_setFromColor(&slot->color, &slot->data->color);
		}
		sp36Color_addFloats(&slot->color, (r - slot->color.r) * alpha, (g - slot->color.g) * alpha, (b - slot->color.b) * alpha, (a - slot->color.a) * alpha);
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp36ColorTimeline_getPropertyId (const sp36Timeline* timeline) {
	return (SP_TIMELINE_COLOR << 24) + SUB_CAST(sp36ColorTimeline, timeline)->slotIndex;
}

sp36ColorTimeline* sp36ColorTimeline_create (int framesCount) {
	return (sp36ColorTimeline*)_sp36BaseTimeline_create(framesCount, SP_TIMELINE_COLOR, 5, _sp36ColorTimeline_apply, _sp36ColorTimeline_getPropertyId);
}

void sp36ColorTimeline_setFrame (sp36ColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a) {
	frameIndex *= COLOR_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + COLOR_R] = r;
	self->frames[frameIndex + COLOR_G] = g;
	self->frames[frameIndex + COLOR_B] = b;
	self->frames[frameIndex + COLOR_A] = a;
}

/**/

static const int TWOCOLOR_PREV_TIME = -8, TWOCOLOR_PREV_R = -7, TWOCOLOR_PREV_G = -6, TWOCOLOR_PREV_B = -5, TWOCOLOR_PREV_A = -4;
static const int TWOCOLOR_PREV_R2 = -3, TWOCOLOR_PREV_G2 = -2, TWOCOLOR_PREV_B2 = -1;
static const int TWOCOLOR_R = 1, TWOCOLOR_G = 2, TWOCOLOR_B = 3, TWOCOLOR_A = 4, TWOCOLOR_R2 = 5, TWOCOLOR_G2 = 6, TWOCOLOR_B2 = 7;

void _sp36TwoColorTimeline_apply (const sp36Timeline* timeline, sp36Skeleton* skeleton, float lastTime, float time, sp36Event** firedEvents,
							 int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction) {
	sp36Slot *slot;
	int frame;
	float percent, frameTime;
	float r, g, b, a, r2, g2, b2;
	sp36Color* light;
	sp36Color* dark;
	sp36Color* setupLight;
	sp36Color* setupDark;
	sp36ColorTimeline* self = (sp36ColorTimeline*)timeline;
	slot = skeleton->slots[self->slotIndex];

	if (time < self->frames[0]) {
		switch (pose) {
			case SP_MIX_POSE_SETUP:
				sp36Color_setFromColor(&slot->color, &slot->data->color);
				sp36Color_setFromColor(slot->darkColor, slot->data->darkColor);
				return;
			case SP_MIX_POSE_CURRENT:
				light = &slot->color;
				dark = slot->darkColor;
				setupLight = &slot->data->color;
				setupDark = slot->data->darkColor;
				sp36Color_addFloats(light, (setupLight->r - light->r) * alpha, (setupLight->g - light->g) * alpha, (setupLight->b - light->b) * alpha,
						  (setupLight->a - light->a) * alpha);
				sp36Color_addFloats(dark, (setupDark->r - dark->r) * alpha, (setupDark->g - dark->g) * alpha, (setupDark->b - dark->b) * alpha, 0);
			case SP_MIX_POSE_CURRENT_LAYERED:; /* to appease compiler */
		}
		return;
	}

	if (time >= self->frames[self->framesCount - TWOCOLOR_ENTRIES]) { /* Time is after last frame */
		int i = self->framesCount;
		r = self->frames[i + TWOCOLOR_PREV_R];
		g = self->frames[i + TWOCOLOR_PREV_G];
		b = self->frames[i + TWOCOLOR_PREV_B];
		a = self->frames[i + TWOCOLOR_PREV_A];
		r2 = self->frames[i + TWOCOLOR_PREV_R2];
		g2 = self->frames[i + TWOCOLOR_PREV_G2];
		b2 = self->frames[i + TWOCOLOR_PREV_B2];
	} else {
		/* Interpolate between the previous frame and the current frame. */
		frame = binarySearch(self->frames, self->framesCount, time, TWOCOLOR_ENTRIES);

		r = self->frames[frame + TWOCOLOR_PREV_R];
		g = self->frames[frame + TWOCOLOR_PREV_G];
		b = self->frames[frame + TWOCOLOR_PREV_B];
		a = self->frames[frame + TWOCOLOR_PREV_A];
		r2 = self->frames[frame + TWOCOLOR_PREV_R2];
		g2 = self->frames[frame + TWOCOLOR_PREV_G2];
		b2 = self->frames[frame + TWOCOLOR_PREV_B2];

		frameTime = self->frames[frame];
		percent = sp36CurveTimeline_getCurvePercent(SUPER(self), frame / TWOCOLOR_ENTRIES - 1,
												  1 - (time - frameTime) / (self->frames[frame + TWOCOLOR_PREV_TIME] - frameTime));

		r += (self->frames[frame + TWOCOLOR_R] - r) * percent;
		g += (self->frames[frame + TWOCOLOR_G] - g) * percent;
		b += (self->frames[frame + TWOCOLOR_B] - b) * percent;
		a += (self->frames[frame + TWOCOLOR_A] - a) * percent;
		r2 += (self->frames[frame + TWOCOLOR_R2] - r2) * percent;
		g2 += (self->frames[frame + TWOCOLOR_G2] - g2) * percent;
		b2 += (self->frames[frame + TWOCOLOR_B2] - b2) * percent;
	}
	if (alpha == 1) {
		sp36Color_setFromFloats(&slot->color, r, g, b, a);
		sp36Color_setFromFloats(slot->darkColor, r2, g2, b2, 1);
	} else {
		light = &slot->color;
		dark = slot->darkColor;
		if (pose == SP_MIX_POSE_SETUP) {
			sp36Color_setFromColor(light, &slot->data->color);
			sp36Color_setFromColor(dark, slot->data->darkColor);
		}
		sp36Color_addFloats(light, (r - light->r) * alpha, (g - light->g) * alpha, (b - light->b) * alpha, (a - light->a) * alpha);
		sp36Color_addFloats(dark, (r2 - dark->r) * alpha, (g2 - dark->g) * alpha, (b2 - dark->b) * alpha, 0);
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp36TwoColorTimeline_getPropertyId (const sp36Timeline* timeline) {
	return (SP_TIMELINE_TWOCOLOR << 24) + SUB_CAST(sp36TwoColorTimeline, timeline)->slotIndex;
}

sp36TwoColorTimeline* sp36TwoColorTimeline_create (int framesCount) {
	return (sp36TwoColorTimeline*)_sp36BaseTimeline_create(framesCount, SP_TIMELINE_TWOCOLOR, TWOCOLOR_ENTRIES, _sp36TwoColorTimeline_apply, _sp36TwoColorTimeline_getPropertyId);
}

void sp36TwoColorTimeline_setFrame (sp36TwoColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a, float r2, float g2, float b2) {
	frameIndex *= TWOCOLOR_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + TWOCOLOR_R] = r;
	self->frames[frameIndex + TWOCOLOR_G] = g;
	self->frames[frameIndex + TWOCOLOR_B] = b;
	self->frames[frameIndex + TWOCOLOR_A] = a;
	self->frames[frameIndex + TWOCOLOR_R2] = r2;
	self->frames[frameIndex + TWOCOLOR_G2] = g2;
	self->frames[frameIndex + TWOCOLOR_B2] = b2;
}

/**/

void _sp36AttachmentTimeline_apply (const sp36Timeline* timeline, sp36Skeleton* skeleton, float lastTime, float time,
		sp36Event** firedEvents, int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction) {
	const char* attachmentName;
	sp36AttachmentTimeline* self = (sp36AttachmentTimeline*)timeline;
	int frameIndex;
	sp36Slot* slot = skeleton->slots[self->slotIndex];

	if (direction == SP_MIX_DIRECTION_OUT && pose == SP_MIX_POSE_SETUP) {
		const char* attachmentName = slot->data->attachmentName;
        sp36Slot_setAttachment(slot, attachmentName ? sp36Skeleton_getAttachmentForSlotIndex(skeleton, self->slotIndex, attachmentName) : 0);
		return;
	}

	if (time < self->frames[0]) {
		if (pose == SP_MIX_POSE_SETUP) {
			attachmentName = slot->data->attachmentName;
			sp36Slot_setAttachment(skeleton->slots[self->slotIndex],
								 attachmentName ? sp36Skeleton_getAttachmentForSlotIndex(skeleton, self->slotIndex, attachmentName) : 0);
		}
		return;
	}

	if (time >= self->frames[self->framesCount - 1])
		frameIndex = self->framesCount - 1;
	else
		frameIndex = binarySearch1(self->frames, self->framesCount, time) - 1;

	attachmentName = self->attachmentNames[frameIndex];
	sp36Slot_setAttachment(skeleton->slots[self->slotIndex],
			attachmentName ? sp36Skeleton_getAttachmentForSlotIndex(skeleton, self->slotIndex, attachmentName) : 0);

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(alpha);
}

int _sp36AttachmentTimeline_getPropertyId (const sp36Timeline* timeline) {
	return (SP_TIMELINE_ATTACHMENT << 24) + SUB_CAST(sp36AttachmentTimeline, timeline)->slotIndex;
}

void _sp36AttachmentTimeline_dispose (sp36Timeline* timeline) {
	sp36AttachmentTimeline* self = SUB_CAST(sp36AttachmentTimeline, timeline);
	int i;

	_sp36Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->attachmentNames[i]);
	FREE(self->attachmentNames);
	FREE(self->frames);
	FREE(self);
}

sp36AttachmentTimeline* sp36AttachmentTimeline_create (int framesCount) {
	sp36AttachmentTimeline* self = NEW(sp36AttachmentTimeline);
	_sp36Timeline_init(SUPER(self), SP_TIMELINE_ATTACHMENT, _sp36AttachmentTimeline_dispose, _sp36AttachmentTimeline_apply, _sp36AttachmentTimeline_getPropertyId);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(char**, self->attachmentNames) = CALLOC(char*, framesCount);

	return self;
}

void sp36AttachmentTimeline_setFrame (sp36AttachmentTimeline* self, int frameIndex, float time, const char* attachmentName) {
	self->frames[frameIndex] = time;

	FREE(self->attachmentNames[frameIndex]);
	if (attachmentName)
		MALLOC_STR(self->attachmentNames[frameIndex], attachmentName);
	else
		self->attachmentNames[frameIndex] = 0;
}

/**/

void _sp36DeformTimeline_apply (const sp36Timeline* timeline, sp36Skeleton* skeleton, float lastTime, float time, sp36Event** firedEvents,
							  int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction) {
	int frame, i, vertexCount;
	float percent, frameTime;
	const float* prevVertices;
	const float* nextVertices;
	float* frames;
	int framesCount;
	const float** frameVertices;
	float* vertices;
	sp36DeformTimeline* self = (sp36DeformTimeline*)timeline;

	sp36Slot *slot = skeleton->slots[self->slotIndex];

	if (slot->attachment != self->attachment) {
		if (!slot->attachment) return;
		switch (slot->attachment->type) {
			case SP_ATTACHMENT_MESH: {
				sp36MeshAttachment* mesh = SUB_CAST(sp36MeshAttachment, slot->attachment);
				if (!mesh->inheritDeform || mesh->parentMesh != (void*)self->attachment) return;
				break;
			}
			default:
				return;
		}
	}

	frames = self->frames;
	framesCount = self->framesCount;
	vertexCount = self->frameVerticesCount;
	if (slot->attachmentVerticesCount < vertexCount) {
		if (slot->attachmentVerticesCapacity < vertexCount) {
			FREE(slot->attachmentVertices);
			slot->attachmentVertices = MALLOC(float, vertexCount);
			slot->attachmentVerticesCapacity = vertexCount;
		}
	}
	if (slot->attachmentVerticesCount == 0) alpha = 1;

	frameVertices = self->frameVertices;
	vertices = slot->attachmentVertices;

	if (time < frames[0]) { /* Time is before first frame. */
		sp36VertexAttachment* vertexAttachment = SUB_CAST(sp36VertexAttachment, slot->attachment);
		switch (pose) {
			case SP_MIX_POSE_SETUP:
				slot->attachmentVerticesCount = 0;
				return;
			case SP_MIX_POSE_CURRENT:
				if (alpha == 1) {
					slot->attachmentVerticesCount = 0;
					return;
				}
				slot->attachmentVerticesCount = vertexCount;
				if (!vertexAttachment->bones) {
					float* setupVertices = vertexAttachment->vertices;
					for (i = 0; i < vertexCount; i++) {
						vertices[i] += (setupVertices[i] - vertices[i]) * alpha;
					}
				} else {
					alpha = 1 - alpha;
					for (i = 0; i < vertexCount; i++) {
						vertices[i] *= alpha;
					}
				}
			case SP_MIX_POSE_CURRENT_LAYERED:; /* to appease compiler */
		}
		return;
	}

	slot->attachmentVerticesCount = vertexCount;
	if (time >= frames[framesCount - 1]) { /* Time is after last frame. */
		const float* lastVertices = self->frameVertices[framesCount - 1];
		if (alpha == 1) {
			/* Vertex positions or deform offsets, no alpha. */
			memcpy(vertices, lastVertices, vertexCount * sizeof(float));
		} else if (pose == SP_MIX_POSE_SETUP) {
			sp36VertexAttachment* vertexAttachment = SUB_CAST(sp36VertexAttachment, slot->attachment);
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
	percent = sp36CurveTimeline_getCurvePercent(SUPER(self), frame - 1, 1 - (time - frameTime) / (frames[frame - 1] - frameTime));

	if (alpha == 1) {
		/* Vertex positions or deform offsets, no alpha. */
		for (i = 0; i < vertexCount; i++) {
			float prev = prevVertices[i];
			vertices[i] = prev + (nextVertices[i] - prev) * percent;
		}
	} else if (pose == SP_MIX_POSE_SETUP) {
		sp36VertexAttachment* vertexAttachment = SUB_CAST(sp36VertexAttachment, slot->attachment);
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

int _sp36DeformTimeline_getPropertyId (const sp36Timeline* timeline) {
	return (SP_TIMELINE_DEFORM << 27) + SUB_CAST(sp36VertexAttachment, SUB_CAST(sp36DeformTimeline, timeline)->attachment)->id + SUB_CAST(sp36DeformTimeline, timeline)->slotIndex;
}

void _sp36DeformTimeline_dispose (sp36Timeline* timeline) {
	sp36DeformTimeline* self = SUB_CAST(sp36DeformTimeline, timeline);
	int i;

	_sp36CurveTimeline_deinit(SUPER(self));

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->frameVertices[i]);
	FREE(self->frameVertices);
	FREE(self->frames);
	FREE(self);
}

sp36DeformTimeline* sp36DeformTimeline_create (int framesCount, int frameVerticesCount) {
	sp36DeformTimeline* self = NEW(sp36DeformTimeline);
	_sp36CurveTimeline_init(SUPER(self), SP_TIMELINE_DEFORM, framesCount, _sp36DeformTimeline_dispose, _sp36DeformTimeline_apply, _sp36DeformTimeline_getPropertyId);
	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, self->framesCount);
	CONST_CAST(float**, self->frameVertices) = CALLOC(float*, framesCount);
	CONST_CAST(int, self->frameVerticesCount) = frameVerticesCount;
	return self;
}

void sp36DeformTimeline_setFrame (sp36DeformTimeline* self, int frameIndex, float time, float* vertices) {
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
void _sp36EventTimeline_apply (const sp36Timeline* timeline, sp36Skeleton* skeleton, float lastTime, float time, sp36Event** firedEvents,
		int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction) {
	sp36EventTimeline* self = (sp36EventTimeline*)timeline;
	int frame;
	if (!firedEvents) return;

	if (lastTime > time) { /* Fire events after last time for looped animations. */
		_sp36EventTimeline_apply(timeline, skeleton, lastTime, (float)INT_MAX, firedEvents, eventsCount, alpha, pose, direction);
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

int _sp36EventTimeline_getPropertyId (const sp36Timeline* timeline) {
	return SP_TIMELINE_EVENT << 24;
}

void _sp36EventTimeline_dispose (sp36Timeline* timeline) {
	sp36EventTimeline* self = SUB_CAST(sp36EventTimeline, timeline);
	int i;

	_sp36Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		sp36Event_dispose(self->events[i]);
	FREE(self->events);
	FREE(self->frames);
	FREE(self);
}

sp36EventTimeline* sp36EventTimeline_create (int framesCount) {
	sp36EventTimeline* self = NEW(sp36EventTimeline);
	_sp36Timeline_init(SUPER(self), SP_TIMELINE_EVENT, _sp36EventTimeline_dispose, _sp36EventTimeline_apply, _sp36EventTimeline_getPropertyId);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(sp36Event**, self->events) = CALLOC(sp36Event*, framesCount);

	return self;
}

void sp36EventTimeline_setFrame (sp36EventTimeline* self, int frameIndex, sp36Event* event) {
	self->frames[frameIndex] = event->time;

	FREE(self->events[frameIndex]);
	self->events[frameIndex] = event;
}

/**/

void _sp36DrawOrderTimeline_apply (const sp36Timeline* timeline, sp36Skeleton* skeleton, float lastTime, float time,
		sp36Event** firedEvents, int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction) {
	int i;
	int frame;
	const int* drawOrderToSetupIndex;
	sp36DrawOrderTimeline* self = (sp36DrawOrderTimeline*)timeline;

	if (direction == SP_MIX_DIRECTION_OUT && pose == SP_MIX_POSE_SETUP) {
		memcpy(skeleton->drawOrder, skeleton->slots, self->slotsCount * sizeof(sp36Slot*));
		return;
	}

	if (time < self->frames[0]) {
		if (pose == SP_MIX_POSE_SETUP) memcpy(skeleton->drawOrder, skeleton->slots, self->slotsCount * sizeof(sp36Slot*));
		return;
	}

	if (time >= self->frames[self->framesCount - 1]) /* Time is after last frame. */
		frame = self->framesCount - 1;
	else
		frame = binarySearch1(self->frames, self->framesCount, time) - 1;

	drawOrderToSetupIndex = self->drawOrders[frame];
	if (!drawOrderToSetupIndex)
		memcpy(skeleton->drawOrder, skeleton->slots, self->slotsCount * sizeof(sp36Slot*));
	else {
		for (i = 0; i < self->slotsCount; ++i)
			skeleton->drawOrder[i] = skeleton->slots[drawOrderToSetupIndex[i]];
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(alpha);
}

int _sp36DrawOrderTimeline_getPropertyId (const sp36Timeline* timeline) {
	return SP_TIMELINE_DRAWORDER << 24;
}

void _sp36DrawOrderTimeline_dispose (sp36Timeline* timeline) {
	sp36DrawOrderTimeline* self = SUB_CAST(sp36DrawOrderTimeline, timeline);
	int i;

	_sp36Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->drawOrders[i]);
	FREE(self->drawOrders);
	FREE(self->frames);
	FREE(self);
}

sp36DrawOrderTimeline* sp36DrawOrderTimeline_create (int framesCount, int slotsCount) {
	sp36DrawOrderTimeline* self = NEW(sp36DrawOrderTimeline);
	_sp36Timeline_init(SUPER(self), SP_TIMELINE_DRAWORDER, _sp36DrawOrderTimeline_dispose, _sp36DrawOrderTimeline_apply, _sp36DrawOrderTimeline_getPropertyId);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(int**, self->drawOrders) = CALLOC(int*, framesCount);
	CONST_CAST(int, self->slotsCount) = slotsCount;

	return self;
}

void sp36DrawOrderTimeline_setFrame (sp36DrawOrderTimeline* self, int frameIndex, float time, const int* drawOrder) {
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

void _sp36IkConstraintTimeline_apply (const sp36Timeline* timeline, sp36Skeleton* skeleton, float lastTime, float time,
		sp36Event** firedEvents, int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction) {
	int frame;
	float frameTime, percent, mix;
	float *frames;
	int framesCount;
	sp36IkConstraint* constraint;
	sp36IkConstraintTimeline* self = (sp36IkConstraintTimeline*)timeline;

	constraint = skeleton->ikConstraints[self->ikConstraintIndex];

	if (time < self->frames[0]) {
		switch (pose) {
			case SP_MIX_POSE_SETUP:
				constraint->mix = constraint->data->mix;
				constraint->bendDirection = constraint->data->bendDirection;
				return;
			case SP_MIX_POSE_CURRENT:
				constraint->mix += (constraint->data->mix - constraint->mix) * alpha;
				constraint->bendDirection = constraint->data->bendDirection;
			case SP_MIX_POSE_CURRENT_LAYERED:; /* to appease compiler */
		}
		return;
	}

	frames = self->frames;
	framesCount = self->framesCount;
	if (time >= frames[framesCount - IKCONSTRAINT_ENTRIES]) { /* Time is after last frame. */
		if (pose == SP_MIX_POSE_SETUP) {
			constraint->mix = constraint->data->mix + (frames[framesCount + IKCONSTRAINT_PREV_MIX] - constraint->data->mix) * alpha;
			constraint->bendDirection = direction == SP_MIX_DIRECTION_OUT ? constraint->data->bendDirection
												 : (int)frames[framesCount + IKCONSTRAINT_PREV_BEND_DIRECTION];
		} else {
			constraint->mix += (frames[framesCount + IKCONSTRAINT_PREV_MIX] - constraint->mix) * alpha;
			if (direction == SP_MIX_DIRECTION_IN) constraint->bendDirection = (int)frames[framesCount + IKCONSTRAINT_PREV_BEND_DIRECTION];
		}
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frame = binarySearch(self->frames, self->framesCount, time, IKCONSTRAINT_ENTRIES);
	mix = self->frames[frame + IKCONSTRAINT_PREV_MIX];
	frameTime = self->frames[frame];
	percent = sp36CurveTimeline_getCurvePercent(SUPER(self), frame / IKCONSTRAINT_ENTRIES - 1, 1 - (time - frameTime) / (self->frames[frame + IKCONSTRAINT_PREV_TIME] - frameTime));

	if (pose == SP_MIX_POSE_SETUP) {
		constraint->mix = constraint->data->mix + (mix + (frames[frame + IKCONSTRAINT_MIX] - mix) * percent - constraint->data->mix) * alpha;
		constraint->bendDirection = direction == SP_MIX_DIRECTION_OUT ? constraint->data->bendDirection : (int)frames[frame + IKCONSTRAINT_PREV_BEND_DIRECTION];
	} else {
		constraint->mix += (mix + (frames[frame + IKCONSTRAINT_MIX] - mix) * percent - constraint->mix) * alpha;
		if (direction == SP_MIX_DIRECTION_IN) constraint->bendDirection = (int)frames[frame + IKCONSTRAINT_PREV_BEND_DIRECTION];
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp36IkConstraintTimeline_getPropertyId (const sp36Timeline* timeline) {
	return (SP_TIMELINE_IKCONSTRAINT << 24) + SUB_CAST(sp36IkConstraintTimeline, timeline)->ikConstraintIndex;
}

sp36IkConstraintTimeline* sp36IkConstraintTimeline_create (int framesCount) {
	return (sp36IkConstraintTimeline*)_sp36BaseTimeline_create(framesCount, SP_TIMELINE_IKCONSTRAINT, IKCONSTRAINT_ENTRIES, _sp36IkConstraintTimeline_apply, _sp36IkConstraintTimeline_getPropertyId);
}

void sp36IkConstraintTimeline_setFrame (sp36IkConstraintTimeline* self, int frameIndex, float time, float mix, int bendDirection) {
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

void _sp36TransformConstraintTimeline_apply (const sp36Timeline* timeline, sp36Skeleton* skeleton, float lastTime, float time,
									sp36Event** firedEvents, int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction) {
	int frame;
	float frameTime, percent, rotate, translate, scale, shear;
	sp36TransformConstraint* constraint;
	sp36TransformConstraintTimeline* self = (sp36TransformConstraintTimeline*)timeline;
	float *frames;
	int framesCount;

	constraint = skeleton->transformConstraints[self->transformConstraintIndex];
	if (time < self->frames[0]) {
		sp36TransformConstraintData* data = constraint->data;
		switch (pose) {
			case SP_MIX_POSE_SETUP:
				constraint->rotateMix = data->rotateMix;
				constraint->translateMix = data->translateMix;
				constraint->scaleMix = data->scaleMix;
				constraint->shearMix = data->shearMix;
				return;
			case SP_MIX_POSE_CURRENT:
				constraint->rotateMix += (data->rotateMix - constraint->rotateMix) * alpha;
				constraint->translateMix += (data->translateMix - constraint->translateMix) * alpha;
				constraint->scaleMix += (data->scaleMix - constraint->scaleMix) * alpha;
				constraint->shearMix += (data->shearMix - constraint->shearMix) * alpha;
			case SP_MIX_POSE_CURRENT_LAYERED:; /* to appease compiler */
		}
		return;
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
		percent = sp36CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSFORMCONSTRAINT_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + TRANSFORMCONSTRAINT_PREV_TIME] - frameTime));

		rotate += (frames[frame + TRANSFORMCONSTRAINT_ROTATE] - rotate) * percent;
		translate += (frames[frame + TRANSFORMCONSTRAINT_TRANSLATE] - translate) * percent;
		scale += (frames[frame + TRANSFORMCONSTRAINT_SCALE] - scale) * percent;
		shear += (frames[frame + TRANSFORMCONSTRAINT_SHEAR] - shear) * percent;
	}
	if (pose == SP_MIX_POSE_SETUP) {
		sp36TransformConstraintData* data = constraint->data;
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

int _sp36TransformConstraintTimeline_getPropertyId (const sp36Timeline* timeline) {
	return (SP_TIMELINE_TRANSFORMCONSTRAINT << 24) + SUB_CAST(sp36TransformConstraintTimeline, timeline)->transformConstraintIndex;
}

sp36TransformConstraintTimeline* sp36TransformConstraintTimeline_create (int framesCount) {
	return (sp36TransformConstraintTimeline*)_sp36BaseTimeline_create(framesCount, SP_TIMELINE_TRANSFORMCONSTRAINT, TRANSFORMCONSTRAINT_ENTRIES, _sp36TransformConstraintTimeline_apply, _sp36TransformConstraintTimeline_getPropertyId);
}

void sp36TransformConstraintTimeline_setFrame (sp36TransformConstraintTimeline* self, int frameIndex, float time, float rotateMix, float translateMix, float scaleMix, float shearMix) {
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

void _sp36PathConstraintPositionTimeline_apply(const sp36Timeline* timeline, sp36Skeleton* skeleton, float lastTime, float time,
		sp36Event** firedEvents, int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction) {
	int frame;
	float frameTime, percent, position;
	sp36PathConstraint* constraint;
	sp36PathConstraintPositionTimeline* self = (sp36PathConstraintPositionTimeline*)timeline;
	float* frames;
	int framesCount;

	constraint = skeleton->pathConstraints[self->pathConstraintIndex];
	if (time < self->frames[0]) {
		switch (pose) {
			case SP_MIX_POSE_SETUP:
				constraint->position = constraint->data->position;
				return;
			case SP_MIX_POSE_CURRENT:
				constraint->position += (constraint->data->position - constraint->position) * alpha;
			case SP_MIX_POSE_CURRENT_LAYERED:; /* to appease compiler */
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
		percent = sp36CurveTimeline_getCurvePercent(SUPER(self), frame / PATHCONSTRAINTPOSITION_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + PATHCONSTRAINTPOSITION_PREV_TIME] - frameTime));

		position += (frames[frame + PATHCONSTRAINTPOSITION_VALUE] - position) * percent;
	}
	if (pose == SP_MIX_POSE_SETUP)
		constraint->position = constraint->data->position + (position - constraint->data->position) * alpha;
	else
		constraint->position += (position - constraint->position) * alpha;

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp36PathConstraintPositionTimeline_getPropertyId (const sp36Timeline* timeline) {
	return (SP_TIMELINE_PATHCONSTRAINTPOSITION << 24) + SUB_CAST(sp36PathConstraintPositionTimeline, timeline)->pathConstraintIndex;
}

sp36PathConstraintPositionTimeline* sp36PathConstraintPositionTimeline_create (int framesCount) {
	return (sp36PathConstraintPositionTimeline*)_sp36BaseTimeline_create(framesCount, SP_TIMELINE_PATHCONSTRAINTPOSITION, PATHCONSTRAINTPOSITION_ENTRIES, _sp36PathConstraintPositionTimeline_apply, _sp36PathConstraintPositionTimeline_getPropertyId);
}

void sp36PathConstraintPositionTimeline_setFrame (sp36PathConstraintPositionTimeline* self, int frameIndex, float time, float value) {
	frameIndex *= PATHCONSTRAINTPOSITION_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + PATHCONSTRAINTPOSITION_VALUE] = value;
}

/**/
static const int PATHCONSTRAINTSPACING_PREV_TIME = -2;
static const int PATHCONSTRAINTSPACING_PREV_VALUE = -1;
static const int PATHCONSTRAINTSPACING_VALUE = 1;

void _sp36PathConstraintSpacingTimeline_apply(const sp36Timeline* timeline, sp36Skeleton* skeleton, float lastTime, float time,
		sp36Event** firedEvents, int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction) {
	int frame;
	float frameTime, percent, spacing;
	sp36PathConstraint* constraint;
	sp36PathConstraintSpacingTimeline* self = (sp36PathConstraintSpacingTimeline*)timeline;
	float* frames;
	int framesCount;

	constraint = skeleton->pathConstraints[self->pathConstraintIndex];
	if (time < self->frames[0]) {
		switch (pose) {
			case SP_MIX_POSE_SETUP:
				constraint->spacing = constraint->data->spacing;
				return;
			case SP_MIX_POSE_CURRENT:
				constraint->spacing += (constraint->data->spacing - constraint->spacing) * alpha;
			case SP_MIX_POSE_CURRENT_LAYERED:; /* to appease compiler */
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
		percent = sp36CurveTimeline_getCurvePercent(SUPER(self), frame / PATHCONSTRAINTSPACING_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + PATHCONSTRAINTSPACING_PREV_TIME] - frameTime));

		spacing += (frames[frame + PATHCONSTRAINTSPACING_VALUE] - spacing) * percent;
	}

	if (pose == SP_MIX_POSE_SETUP)
		constraint->spacing = constraint->data->spacing + (spacing - constraint->data->spacing) * alpha;
	else
		constraint->spacing += (spacing - constraint->spacing) * alpha;

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp36PathConstraintSpacingTimeline_getPropertyId (const sp36Timeline* timeline) {
	return (SP_TIMELINE_PATHCONSTRAINTSPACING << 24) + SUB_CAST(sp36PathConstraintSpacingTimeline, timeline)->pathConstraintIndex;
}

sp36PathConstraintSpacingTimeline* sp36PathConstraintSpacingTimeline_create (int framesCount) {
	return (sp36PathConstraintSpacingTimeline*)_sp36BaseTimeline_create(framesCount, SP_TIMELINE_PATHCONSTRAINTSPACING, PATHCONSTRAINTSPACING_ENTRIES, _sp36PathConstraintSpacingTimeline_apply, _sp36PathConstraintSpacingTimeline_getPropertyId);
}

void sp36PathConstraintSpacingTimeline_setFrame (sp36PathConstraintSpacingTimeline* self, int frameIndex, float time, float value) {
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

void _sp36PathConstraintMixTimeline_apply(const sp36Timeline* timeline, sp36Skeleton* skeleton, float lastTime, float time,
											sp36Event** firedEvents, int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction) {
	int frame;
	float frameTime, percent, rotate, translate;
	sp36PathConstraint* constraint;
	sp36PathConstraintMixTimeline* self = (sp36PathConstraintMixTimeline*)timeline;
	float* frames;
	int framesCount;

	constraint = skeleton->pathConstraints[self->pathConstraintIndex];
	if (time < self->frames[0]) {
		switch (pose) {
			case SP_MIX_POSE_SETUP:
				constraint->rotateMix = constraint->data->rotateMix;
				constraint->translateMix = constraint->data->translateMix;
				return;
			case SP_MIX_POSE_CURRENT:
				constraint->rotateMix += (constraint->data->rotateMix - constraint->rotateMix) * alpha;
				constraint->translateMix += (constraint->data->translateMix - constraint->translateMix) * alpha;
			case SP_MIX_POSE_CURRENT_LAYERED:; /* to appease compiler */
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
		percent = sp36CurveTimeline_getCurvePercent(SUPER(self), frame / PATHCONSTRAINTMIX_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + PATHCONSTRAINTMIX_PREV_TIME] - frameTime));

		rotate += (frames[frame + PATHCONSTRAINTMIX_ROTATE] - rotate) * percent;
		translate += (frames[frame + PATHCONSTRAINTMIX_TRANSLATE] - translate) * percent;
	}

	if (pose == SP_MIX_POSE_SETUP) {
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

int _sp36PathConstraintMixTimeline_getPropertyId (const sp36Timeline* timeline) {
	return (SP_TIMELINE_PATHCONSTRAINTMIX << 24) + SUB_CAST(sp36PathConstraintMixTimeline, timeline)->pathConstraintIndex;
}

sp36PathConstraintMixTimeline* sp36PathConstraintMixTimeline_create (int framesCount) {
	return (sp36PathConstraintMixTimeline*)_sp36BaseTimeline_create(framesCount, SP_TIMELINE_PATHCONSTRAINTMIX, PATHCONSTRAINTMIX_ENTRIES, _sp36PathConstraintMixTimeline_apply, _sp36PathConstraintMixTimeline_getPropertyId);
}

void sp36PathConstraintMixTimeline_setFrame (sp36PathConstraintMixTimeline* self, int frameIndex, float time, float rotateMix, float translateMix) {
	frameIndex *= PATHCONSTRAINTMIX_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + PATHCONSTRAINTMIX_ROTATE] = rotateMix;
	self->frames[frameIndex + PATHCONSTRAINTMIX_TRANSLATE] = translateMix;
}

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

#include <spine/Animation.h>
#include <spine/IkConstraint.h>
#include <limits.h>
#include <spine/extension.h>

sp38Animation* sp38Animation_create (const char* name, int timelinesCount) {
	sp38Animation* self = NEW(sp38Animation);
	MALLOC_STR(self->name, name);
	self->timelinesCount = timelinesCount;
	self->timelines = MALLOC(sp38Timeline*, timelinesCount);
	return self;
}

void sp38Animation_dispose (sp38Animation* self) {
	int i;
	for (i = 0; i < self->timelinesCount; ++i)
		sp38Timeline_dispose(self->timelines[i]);
	FREE(self->timelines);
	FREE(self->name);
	FREE(self);
}

void sp38Animation_apply (const sp38Animation* self, sp38Skeleton* skeleton, float lastTime, float time, int loop, sp38Event** events,
	int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction
) {
	int i, n = self->timelinesCount;

	if (loop && self->duration) {
		time = FMOD(time, self->duration);
		if (lastTime > 0) lastTime = FMOD(lastTime, self->duration);
	}

	for (i = 0; i < n; ++i)
		sp38Timeline_apply(self->timelines[i], skeleton, lastTime, time, events, eventsCount, alpha, blend, direction);
}

/**/

typedef struct _sp38TimelineVtable {
	void (*apply) (const sp38Timeline* self, sp38Skeleton* skeleton, float lastTime, float time, sp38Event** firedEvents,
		int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction);
	int (*getPropertyId) (const sp38Timeline* self);
	void (*dispose) (sp38Timeline* self);
} _sp38TimelineVtable;

void _sp38Timeline_init (sp38Timeline* self, sp38TimelineType type, /**/
	void (*dispose) (sp38Timeline* self), /**/
	void (*apply) (const sp38Timeline* self, sp38Skeleton* skeleton, float lastTime, float time, sp38Event** firedEvents,
		int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction),
	int (*getPropertyId) (const sp38Timeline* self)
) {
	CONST_CAST(sp38TimelineType, self->type) = type;
	CONST_CAST(_sp38TimelineVtable*, self->vtable) = NEW(_sp38TimelineVtable);
	VTABLE(sp38Timeline, self)->dispose = dispose;
	VTABLE(sp38Timeline, self)->apply = apply;
	VTABLE(sp38Timeline, self)->getPropertyId = getPropertyId;
}

void _sp38Timeline_deinit (sp38Timeline* self) {
	FREE(self->vtable);
}

void sp38Timeline_dispose (sp38Timeline* self) {
	VTABLE(sp38Timeline, self)->dispose(self);
}

void sp38Timeline_apply (const sp38Timeline* self, sp38Skeleton* skeleton, float lastTime, float time, sp38Event** firedEvents,
		int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction) {
	VTABLE(sp38Timeline, self)->apply(self, skeleton, lastTime, time, firedEvents, eventsCount, alpha, blend, direction);
}

int sp38Timeline_getPropertyId (const sp38Timeline* self) {
	return VTABLE(sp38Timeline, self)->getPropertyId(self);
}

/**/

static const float CURVE_LINEAR = 0, CURVE_STEPPED = 1, CURVE_BEZIER = 2;
static const int BEZIER_SIZE = 10 * 2 - 1;

void _sp38CurveTimeline_init (sp38CurveTimeline* self, sp38TimelineType type, int framesCount, /**/
	void (*dispose) (sp38Timeline* self), /**/
	void (*apply) (const sp38Timeline* self, sp38Skeleton* skeleton, float lastTime, float time, sp38Event** firedEvents,
		int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction),
	int (*getPropertyId)(const sp38Timeline* self)
) {
	_sp38Timeline_init(SUPER(self), type, dispose, apply, getPropertyId);
	self->curves = CALLOC(float, (framesCount - 1) * BEZIER_SIZE);
}

void _sp38CurveTimeline_deinit (sp38CurveTimeline* self) {
	_sp38Timeline_deinit(SUPER(self));
	FREE(self->curves);
}

void sp38CurveTimeline_setLinear (sp38CurveTimeline* self, int frameIndex) {
	self->curves[frameIndex * BEZIER_SIZE] = CURVE_LINEAR;
}

void sp38CurveTimeline_setStepped (sp38CurveTimeline* self, int frameIndex) {
	self->curves[frameIndex * BEZIER_SIZE] = CURVE_STEPPED;
}

void sp38CurveTimeline_setCurve (sp38CurveTimeline* self, int frameIndex, float cx1, float cy1, float cx2, float cy2) {
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

float sp38CurveTimeline_getCurvePercent (const sp38CurveTimeline* self, int frameIndex, float percent) {
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

int _sp38CurveTimeline_binarySearch (float *values, int valuesLength, float target, int step) {
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

void _sp38BaseTimeline_dispose (sp38Timeline* timeline) {
	struct sp38BaseTimeline* self = SUB_CAST(struct sp38BaseTimeline, timeline);
	_sp38CurveTimeline_deinit(SUPER(self));
	FREE(self->frames);
	FREE(self);
}

/* Many timelines have structure identical to struct sp38BaseTimeline and extend sp38CurveTimeline. **/
struct sp38BaseTimeline* _sp38BaseTimeline_create (int framesCount, sp38TimelineType type, int frameSize, /**/
	void (*apply) (const sp38Timeline* self, sp38Skeleton* skeleton, float lastTime, float time, sp38Event** firedEvents,
		int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction),
	int (*getPropertyId) (const sp38Timeline* self)
) {
	struct sp38BaseTimeline* self = NEW(struct sp38BaseTimeline);
	_sp38CurveTimeline_init(SUPER(self), type, framesCount, _sp38BaseTimeline_dispose, apply, getPropertyId);

	CONST_CAST(int, self->framesCount) = framesCount * frameSize;
	CONST_CAST(float*, self->frames) = CALLOC(float, self->framesCount);

	return self;
}

/**/

void _sp38RotateTimeline_apply (const sp38Timeline* timeline, sp38Skeleton* skeleton, float lastTime, float time, sp38Event** firedEvents,
	int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction
) {
	sp38Bone *bone;
	int frame;
	float prevRotation, frameTime, percent, r;
	sp38RotateTimeline* self = SUB_CAST(sp38RotateTimeline, timeline);

	bone = skeleton->bones[self->boneIndex];
	if (!bone->active) return;
	if (time < self->frames[0]) {
		switch (blend) {
		case SP_MIX_BLEND_SETUP:
			bone->rotation = bone->data->rotation;
			return;
		case SP_MIX_BLEND_FIRST:
			r = bone->data->rotation - bone->rotation;
			r -= (16384 - (int)(16384.499999999996 - r / 360)) * 360;
			bone->rotation += r * alpha;
		case SP_MIX_BLEND_REPLACE:
		case SP_MIX_BLEND_ADD:
			; /* to appease compiler */
		}
		return;
	}

	if (time >= self->frames[self->framesCount - ROTATE_ENTRIES]) { /* Time is after last frame. */
		r = self->frames[self->framesCount + ROTATE_PREV_ROTATION];
		switch (blend) {
		case SP_MIX_BLEND_SETUP:
			bone->rotation = bone->data->rotation + r * alpha;
			break;
		case SP_MIX_BLEND_FIRST:
		case SP_MIX_BLEND_REPLACE:
			r += bone->data->rotation - bone->rotation;
			r -= (16384 - (int)(16384.499999999996 - r / 360)) * 360; /* Wrap within -180 and 180. */
		case SP_MIX_BLEND_ADD:
			bone->rotation += r * alpha;
		}
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frame = binarySearch(self->frames, self->framesCount, time, ROTATE_ENTRIES);
	prevRotation = self->frames[frame + ROTATE_PREV_ROTATION];
	frameTime = self->frames[frame];
	percent = sp38CurveTimeline_getCurvePercent(SUPER(self), (frame >> 1) - 1, 1 - (time - frameTime) / (self->frames[frame + ROTATE_PREV_TIME] - frameTime));

	r = self->frames[frame + ROTATE_ROTATION] - prevRotation;
	r = prevRotation + (r - (16384 - (int)(16384.499999999996 - r / 360)) * 360) * percent;
	switch (blend) {
	case SP_MIX_BLEND_SETUP:
		bone->rotation = bone->data->rotation + (r - (16384 - (int)(16384.499999999996 - r / 360)) * 360) * alpha;
		break;
	case SP_MIX_BLEND_FIRST:
	case SP_MIX_BLEND_REPLACE:
		r += bone->data->rotation - bone->rotation;
	case SP_MIX_BLEND_ADD:
		bone->rotation += (r - (16384 - (int)(16384.499999999996 - r / 360)) * 360) * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

int _sp38RotateTimeline_getPropertyId (const sp38Timeline* timeline) {
	return (SP_TIMELINE_ROTATE << 25) + SUB_CAST(sp38RotateTimeline, timeline)->boneIndex;
}

sp38RotateTimeline* sp38RotateTimeline_create (int framesCount) {
	return _sp38BaseTimeline_create(framesCount, SP_TIMELINE_ROTATE, ROTATE_ENTRIES, _sp38RotateTimeline_apply, _sp38RotateTimeline_getPropertyId);
}

void sp38RotateTimeline_setFrame (sp38RotateTimeline* self, int frameIndex, float time, float degrees) {
	frameIndex <<= 1;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + ROTATE_ROTATION] = degrees;
}

/**/

static const int TRANSLATE_PREV_TIME = -3, TRANSLATE_PREV_X = -2, TRANSLATE_PREV_Y = -1;
static const int TRANSLATE_X = 1, TRANSLATE_Y = 2;

void _sp38TranslateTimeline_apply (const sp38Timeline* timeline, sp38Skeleton* skeleton, float lastTime, float time,
	sp38Event** firedEvents, int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction
) {
	sp38Bone *bone;
	int frame;
	float frameTime, percent;
	float x, y;
	float *frames;
	int framesCount;

	sp38TranslateTimeline* self = SUB_CAST(sp38TranslateTimeline, timeline);

	bone = skeleton->bones[self->boneIndex];
	if (!bone->active) return;
	if (time < self->frames[0]) {
		switch (blend) {
		case SP_MIX_BLEND_SETUP:
			bone->x = bone->data->x;
			bone->y = bone->data->y;
			return;
		case SP_MIX_BLEND_FIRST:
			bone->x += (bone->data->x - bone->x) * alpha;
			bone->y += (bone->data->y - bone->y) * alpha;
		case SP_MIX_BLEND_REPLACE:
		case SP_MIX_BLEND_ADD:
			; /* to appease compiler */
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
		percent = sp38CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSLATE_ENTRIES - 1,
			1 - (time - frameTime) / (frames[frame + TRANSLATE_PREV_TIME] - frameTime));

		x += (frames[frame + TRANSLATE_X] - x) * percent;
		y += (frames[frame + TRANSLATE_Y] - y) * percent;
	}
	switch (blend) {
	case SP_MIX_BLEND_SETUP:
		bone->x = bone->data->x + x * alpha;
		bone->y = bone->data->y + y * alpha;
		break;
	case SP_MIX_BLEND_FIRST:
	case SP_MIX_BLEND_REPLACE:
		bone->x += (bone->data->x + x - bone->x) * alpha;
		bone->y += (bone->data->y + y - bone->y) * alpha;
		break;
	case SP_MIX_BLEND_ADD:
		bone->x += x * alpha;
		bone->y += y * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

int _sp38TranslateTimeline_getPropertyId (const sp38Timeline* self) {
	return (SP_TIMELINE_TRANSLATE << 24) + SUB_CAST(sp38TranslateTimeline, self)->boneIndex;
}

sp38TranslateTimeline* sp38TranslateTimeline_create (int framesCount) {
	return _sp38BaseTimeline_create(framesCount, SP_TIMELINE_TRANSLATE, TRANSLATE_ENTRIES, _sp38TranslateTimeline_apply, _sp38TranslateTimeline_getPropertyId);
}

void sp38TranslateTimeline_setFrame (sp38TranslateTimeline* self, int frameIndex, float time, float x, float y) {
	frameIndex *= TRANSLATE_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + TRANSLATE_X] = x;
	self->frames[frameIndex + TRANSLATE_Y] = y;
}

/**/

void _sp38ScaleTimeline_apply (const sp38Timeline* timeline, sp38Skeleton* skeleton, float lastTime, float time, sp38Event** firedEvents,
	int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction
) {
	sp38Bone *bone;
	int frame;
	float frameTime, percent, x, y;
	float *frames;
	int framesCount;

	sp38ScaleTimeline* self = SUB_CAST(sp38ScaleTimeline, timeline);

	bone = skeleton->bones[self->boneIndex];
	if (!bone->active) return;
	if (time < self->frames[0]) {
		switch (blend) {
		case SP_MIX_BLEND_SETUP:
			bone->scaleX = bone->data->scaleX;
			bone->scaleY = bone->data->scaleY;
			return;
		case SP_MIX_BLEND_FIRST:
			bone->scaleX += (bone->data->scaleX - bone->scaleX) * alpha;
			bone->scaleY += (bone->data->scaleY - bone->scaleY) * alpha;
		case SP_MIX_BLEND_REPLACE:
		case SP_MIX_BLEND_ADD:
			; /* to appease compiler */
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
		percent = sp38CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSLATE_ENTRIES - 1,
			1 - (time - frameTime) / (frames[frame + TRANSLATE_PREV_TIME] - frameTime));

		x = (x + (frames[frame + TRANSLATE_X] - x) * percent) * bone->data->scaleX;
		y = (y + (frames[frame + TRANSLATE_Y] - y) * percent) * bone->data->scaleY;
	}
	if (alpha == 1) {
		if (blend == SP_MIX_BLEND_ADD) {
			bone->scaleX += x - bone->data->scaleX;
			bone->scaleY += y - bone->data->scaleY;
		} else {
			bone->scaleX = x;
			bone->scaleY = y;
		}
	} else {
		float bx, by;
		if (direction == SP_MIX_DIRECTION_OUT) {
			switch (blend) {
			case SP_MIX_BLEND_SETUP:
				bx = bone->data->scaleX;
				by = bone->data->scaleY;
				bone->scaleX = bx + (ABS(x) * SIGNUM(bx) - bx) * alpha;
				bone->scaleY = by + (ABS(y) * SIGNUM(by) - by) * alpha;
				break;
			case SP_MIX_BLEND_FIRST:
			case SP_MIX_BLEND_REPLACE:
				bx = bone->scaleX;
				by = bone->scaleY;
				bone->scaleX = bx + (ABS(x) * SIGNUM(bx) - bx) * alpha;
				bone->scaleY = by + (ABS(y) * SIGNUM(by) - by) * alpha;
				break;
			case SP_MIX_BLEND_ADD:
				bx = bone->scaleX;
				by = bone->scaleY;
				bone->scaleX = bx + (ABS(x) * SIGNUM(bx) - bone->data->scaleX) * alpha;
				bone->scaleY = by + (ABS(y) * SIGNUM(by) - bone->data->scaleY) * alpha;
			}
		} else {
			switch (blend) {
			case SP_MIX_BLEND_SETUP:
				bx = ABS(bone->data->scaleX) * SIGNUM(x);
				by = ABS(bone->data->scaleY) * SIGNUM(y);
				bone->scaleX = bx + (x - bx) * alpha;
				bone->scaleY = by + (y - by) * alpha;
				break;
			case SP_MIX_BLEND_FIRST:
			case SP_MIX_BLEND_REPLACE:
				bx = ABS(bone->scaleX) * SIGNUM(x);
				by = ABS(bone->scaleY) * SIGNUM(y);
				bone->scaleX = bx + (x - bx) * alpha;
				bone->scaleY = by + (y - by) * alpha;
				break;
			case SP_MIX_BLEND_ADD:
				bx = SIGNUM(x);
				by = SIGNUM(y);
				bone->scaleX = ABS(bone->scaleX) * bx + (x - ABS(bone->data->scaleX) * bx) * alpha;
				bone->scaleY = ABS(bone->scaleY) * by + (y - ABS(bone->data->scaleY) * by) * alpha;
			}
		}
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp38ScaleTimeline_getPropertyId (const sp38Timeline* timeline) {
	return (SP_TIMELINE_SCALE << 24) + SUB_CAST(sp38ScaleTimeline, timeline)->boneIndex;
}

sp38ScaleTimeline* sp38ScaleTimeline_create (int framesCount) {
	return _sp38BaseTimeline_create(framesCount, SP_TIMELINE_SCALE, TRANSLATE_ENTRIES, _sp38ScaleTimeline_apply, _sp38ScaleTimeline_getPropertyId);
}

void sp38ScaleTimeline_setFrame (sp38ScaleTimeline* self, int frameIndex, float time, float x, float y) {
	sp38TranslateTimeline_setFrame(self, frameIndex, time, x, y);
}

/**/

void _sp38ShearTimeline_apply (const sp38Timeline* timeline, sp38Skeleton* skeleton, float lastTime, float time, sp38Event** firedEvents,
	int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction
) {
	sp38Bone *bone;
	int frame;
	float frameTime, percent, x, y;
	float *frames;
	int framesCount;

	sp38ShearTimeline* self = SUB_CAST(sp38ShearTimeline, timeline);

	bone = skeleton->bones[self->boneIndex];
	if (!bone->active) return;
	frames = self->frames;
	framesCount = self->framesCount;
	if (time < self->frames[0]) {
		switch (blend) {
		case SP_MIX_BLEND_SETUP:
			bone->shearX = bone->data->shearX;
			bone->shearY = bone->data->shearY;
			return;
		case SP_MIX_BLEND_FIRST:
			bone->shearX += (bone->data->shearX - bone->shearX) * alpha;
			bone->shearY += (bone->data->shearY - bone->shearY) * alpha;
		case SP_MIX_BLEND_REPLACE:
		case SP_MIX_BLEND_ADD:
			; /* to appease compiler */
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
		percent = sp38CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSLATE_ENTRIES - 1,
			1 - (time - frameTime) / (frames[frame + TRANSLATE_PREV_TIME] - frameTime));

		x = x + (frames[frame + TRANSLATE_X] - x) * percent;
		y = y + (frames[frame + TRANSLATE_Y] - y) * percent;
	}
	switch (blend) {
	case SP_MIX_BLEND_SETUP:
		bone->shearX = bone->data->shearX + x * alpha;
		bone->shearY = bone->data->shearY + y * alpha;
		break;
	case SP_MIX_BLEND_FIRST:
	case SP_MIX_BLEND_REPLACE:
		bone->shearX += (bone->data->shearX + x - bone->shearX) * alpha;
		bone->shearY += (bone->data->shearY + y - bone->shearY) * alpha;
		break;
	case SP_MIX_BLEND_ADD:
		bone->shearX += x * alpha;
		bone->shearY += y * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

int _sp38ShearTimeline_getPropertyId (const sp38Timeline* timeline) {
	return (SP_TIMELINE_SHEAR << 24) + SUB_CAST(sp38ShearTimeline, timeline)->boneIndex;
}

sp38ShearTimeline* sp38ShearTimeline_create (int framesCount) {
	return (sp38ShearTimeline*)_sp38BaseTimeline_create(framesCount, SP_TIMELINE_SHEAR, 3, _sp38ShearTimeline_apply, _sp38ShearTimeline_getPropertyId);
}

void sp38ShearTimeline_setFrame (sp38ShearTimeline* self, int frameIndex, float time, float x, float y) {
	sp38TranslateTimeline_setFrame(self, frameIndex, time, x, y);
}

/**/

static const int COLOR_PREV_TIME = -5, COLOR_PREV_R = -4, COLOR_PREV_G = -3, COLOR_PREV_B = -2, COLOR_PREV_A = -1;
static const int COLOR_R = 1, COLOR_G = 2, COLOR_B = 3, COLOR_A = 4;

void _sp38ColorTimeline_apply (const sp38Timeline* timeline, sp38Skeleton* skeleton, float lastTime, float time, sp38Event** firedEvents,
	int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction
) {
	sp38Slot *slot;
	int frame;
	float percent, frameTime;
	float r, g, b, a;
	sp38Color* color;
	sp38Color* setup;
	sp38ColorTimeline* self = (sp38ColorTimeline*)timeline;
	slot = skeleton->slots[self->slotIndex];
	if (!slot->bone->active) return;

	if (time < self->frames[0]) {
		switch (blend) {
		case SP_MIX_BLEND_SETUP:
			sp38Color_setFromColor(&slot->color, &slot->data->color);
			return;
		case SP_MIX_BLEND_FIRST:
			color = &slot->color;
			setup = &slot->data->color;
			sp38Color_addFloats(color, (setup->r - color->r) * alpha, (setup->g - color->g) * alpha, (setup->b - color->b) * alpha,
				(setup->a - color->a) * alpha);
		case SP_MIX_BLEND_REPLACE:
		case SP_MIX_BLEND_ADD:
			; /* to appease compiler */
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
		percent = sp38CurveTimeline_getCurvePercent(SUPER(self), frame / COLOR_ENTRIES - 1,
			1 - (time - frameTime) / (self->frames[frame + COLOR_PREV_TIME] - frameTime));

		r += (self->frames[frame + COLOR_R] - r) * percent;
		g += (self->frames[frame + COLOR_G] - g) * percent;
		b += (self->frames[frame + COLOR_B] - b) * percent;
		a += (self->frames[frame + COLOR_A] - a) * percent;
	}
	if (alpha == 1) {
		sp38Color_setFromFloats(&slot->color, r, g, b, a);
	} else {
		if (blend == SP_MIX_BLEND_SETUP) sp38Color_setFromColor(&slot->color, &slot->data->color);
		sp38Color_addFloats(&slot->color, (r - slot->color.r) * alpha, (g - slot->color.g) * alpha, (b - slot->color.b) * alpha, (a - slot->color.a) * alpha);
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

int _sp38ColorTimeline_getPropertyId (const sp38Timeline* timeline) {
	return (SP_TIMELINE_COLOR << 24) + SUB_CAST(sp38ColorTimeline, timeline)->slotIndex;
}

sp38ColorTimeline* sp38ColorTimeline_create (int framesCount) {
	return (sp38ColorTimeline*)_sp38BaseTimeline_create(framesCount, SP_TIMELINE_COLOR, 5, _sp38ColorTimeline_apply, _sp38ColorTimeline_getPropertyId);
}

void sp38ColorTimeline_setFrame (sp38ColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a) {
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

void _sp38TwoColorTimeline_apply (const sp38Timeline* timeline, sp38Skeleton* skeleton, float lastTime, float time, sp38Event** firedEvents,
	int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction
) {
	sp38Slot *slot;
	int frame;
	float percent, frameTime;
	float r, g, b, a, r2, g2, b2;
	sp38Color* light;
	sp38Color* dark;
	sp38Color* setupLight;
	sp38Color* setupDark;
	sp38ColorTimeline* self = (sp38ColorTimeline*)timeline;
	slot = skeleton->slots[self->slotIndex];
	if (!slot->bone->active) return;

	if (time < self->frames[0]) {
		switch (blend) {
		case SP_MIX_BLEND_SETUP:
			sp38Color_setFromColor(&slot->color, &slot->data->color);
			sp38Color_setFromColor(slot->darkColor, slot->data->darkColor);
			return;
		case SP_MIX_BLEND_FIRST:
			light = &slot->color;
			dark = slot->darkColor;
			setupLight = &slot->data->color;
			setupDark = slot->data->darkColor;
			sp38Color_addFloats(light, (setupLight->r - light->r) * alpha, (setupLight->g - light->g) * alpha, (setupLight->b - light->b) * alpha,
				(setupLight->a - light->a) * alpha);
			sp38Color_addFloats(dark, (setupDark->r - dark->r) * alpha, (setupDark->g - dark->g) * alpha, (setupDark->b - dark->b) * alpha, 0);
		case SP_MIX_BLEND_REPLACE:
		case SP_MIX_BLEND_ADD:
			; /* to appease compiler */
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
		percent = sp38CurveTimeline_getCurvePercent(SUPER(self), frame / TWOCOLOR_ENTRIES - 1,
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
		sp38Color_setFromFloats(&slot->color, r, g, b, a);
		sp38Color_setFromFloats(slot->darkColor, r2, g2, b2, 1);
	} else {
		light = &slot->color;
		dark = slot->darkColor;
		if (blend == SP_MIX_BLEND_SETUP) {
			sp38Color_setFromColor(light, &slot->data->color);
			sp38Color_setFromColor(dark, slot->data->darkColor);
		}
		sp38Color_addFloats(light, (r - light->r) * alpha, (g - light->g) * alpha, (b - light->b) * alpha, (a - light->a) * alpha);
		sp38Color_addFloats(dark, (r2 - dark->r) * alpha, (g2 - dark->g) * alpha, (b2 - dark->b) * alpha, 0);
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

int _sp38TwoColorTimeline_getPropertyId (const sp38Timeline* timeline) {
	return (SP_TIMELINE_TWOCOLOR << 24) + SUB_CAST(sp38TwoColorTimeline, timeline)->slotIndex;
}

sp38TwoColorTimeline* sp38TwoColorTimeline_create (int framesCount) {
	return (sp38TwoColorTimeline*)_sp38BaseTimeline_create(framesCount, SP_TIMELINE_TWOCOLOR, TWOCOLOR_ENTRIES, _sp38TwoColorTimeline_apply, _sp38TwoColorTimeline_getPropertyId);
}

void sp38TwoColorTimeline_setFrame (sp38TwoColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a, float r2, float g2, float b2) {
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

static void _sp38SetAttachment(sp38AttachmentTimeline* timeline, sp38Skeleton* skeleton, sp38Slot* slot, const char* attachmentName) {
    slot->attachment = attachmentName == NULL ? NULL : sp38Skeleton_getAttachmentForSlotIndex(skeleton, timeline->slotIndex, attachmentName);
}

void _sp38AttachmentTimeline_apply (const sp38Timeline* timeline, sp38Skeleton* skeleton, float lastTime, float time,
		sp38Event** firedEvents, int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction) {
	const char* attachmentName;
	sp38AttachmentTimeline* self = (sp38AttachmentTimeline*)timeline;
	int frameIndex;
	sp38Slot* slot = skeleton->slots[self->slotIndex];
	if (!slot->bone->active) return;

	if (direction == SP_MIX_DIRECTION_OUT) {
	    if (blend == SP_MIX_BLEND_SETUP)
	        _sp38SetAttachment(self, skeleton, slot, slot->data->attachmentName);
		return;
	}

	if (time < self->frames[0]) {
		if (blend == SP_MIX_BLEND_SETUP || blend == SP_MIX_BLEND_FIRST) {
			_sp38SetAttachment(self, skeleton, slot, slot->data->attachmentName);
		}
		return;
	}

	if (time >= self->frames[self->framesCount - 1])
		frameIndex = self->framesCount - 1;
	else
		frameIndex = binarySearch1(self->frames, self->framesCount, time) - 1;

	attachmentName = self->attachmentNames[frameIndex];
	sp38Slot_setAttachment(skeleton->slots[self->slotIndex],
		attachmentName ? sp38Skeleton_getAttachmentForSlotIndex(skeleton, self->slotIndex, attachmentName) : 0);

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(alpha);
}

int _sp38AttachmentTimeline_getPropertyId (const sp38Timeline* timeline) {
	return (SP_TIMELINE_ATTACHMENT << 24) + SUB_CAST(sp38AttachmentTimeline, timeline)->slotIndex;
}

void _sp38AttachmentTimeline_dispose (sp38Timeline* timeline) {
	sp38AttachmentTimeline* self = SUB_CAST(sp38AttachmentTimeline, timeline);
	int i;

	_sp38Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->attachmentNames[i]);
	FREE(self->attachmentNames);
	FREE(self->frames);
	FREE(self);
}

sp38AttachmentTimeline* sp38AttachmentTimeline_create (int framesCount) {
	sp38AttachmentTimeline* self = NEW(sp38AttachmentTimeline);
	_sp38Timeline_init(SUPER(self), SP_TIMELINE_ATTACHMENT, _sp38AttachmentTimeline_dispose, _sp38AttachmentTimeline_apply, _sp38AttachmentTimeline_getPropertyId);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(char**, self->attachmentNames) = CALLOC(char*, framesCount);

	return self;
}

void sp38AttachmentTimeline_setFrame (sp38AttachmentTimeline* self, int frameIndex, float time, const char* attachmentName) {
	self->frames[frameIndex] = time;

	FREE(self->attachmentNames[frameIndex]);
	if (attachmentName)
		MALLOC_STR(self->attachmentNames[frameIndex], attachmentName);
	else
		self->attachmentNames[frameIndex] = 0;
}

/**/

void _sp38DeformTimeline_apply (const sp38Timeline* timeline, sp38Skeleton* skeleton, float lastTime, float time, sp38Event** firedEvents,
	int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction
) {
	int frame, i, vertexCount;
	float percent, frameTime;
	const float* prevVertices;
	const float* nextVertices;
	float* frames;
	int framesCount;
	const float** frameVertices;
	float* deformArray;
	sp38DeformTimeline* self = (sp38DeformTimeline*)timeline;

	sp38Slot *slot = skeleton->slots[self->slotIndex];
	if (!slot->bone->active) return;

	if (!slot->attachment) return;
	switch (slot->attachment->type) {
		case SP_ATTACHMENT_BOUNDING_BOX:
		case SP_ATTACHMENT_CLIPPING:
		case SP_ATTACHMENT_MESH:
		case SP_ATTACHMENT_PATH: {
			sp38VertexAttachment* vertexAttachment = SUB_CAST(sp38VertexAttachment, slot->attachment);
			if (vertexAttachment->deformAttachment != SUB_CAST(sp38VertexAttachment, self->attachment)) return;
			break;
		}
		default:
			return;
	}

	frames = self->frames;
	framesCount = self->framesCount;
	vertexCount = self->frameVerticesCount;
	if (slot->deformCount < vertexCount) {
		if (slot->deformCapacity < vertexCount) {
			FREE(slot->deform);
			slot->deform = MALLOC(float, vertexCount);
			slot->deformCapacity = vertexCount;
		}
	}
	if (slot->deformCount == 0) blend = SP_MIX_BLEND_SETUP;

	frameVertices = self->frameVertices;
	deformArray = slot->deform;

	if (time < frames[0]) { /* Time is before first frame. */
		sp38VertexAttachment* vertexAttachment = SUB_CAST(sp38VertexAttachment, slot->attachment);
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				slot->deformCount = 0;
				return;
			case SP_MIX_BLEND_FIRST:
				if (alpha == 1) {
					slot->deformCount = 0;
					return;
				}
				slot->deformCount = vertexCount;
				if (!vertexAttachment->bones) {
					float* setupVertices = vertexAttachment->vertices;
					for (i = 0; i < vertexCount; i++) {
						deformArray[i] += (setupVertices[i] - deformArray[i]) * alpha;
					}
				} else {
					alpha = 1 - alpha;
					for (i = 0; i < vertexCount; i++) {
						deformArray[i] *= alpha;
					}
				}
			case SP_MIX_BLEND_REPLACE:
			case SP_MIX_BLEND_ADD:
				; /* to appease compiler */
		}
		return;
	}

	slot->deformCount = vertexCount;
	if (time >= frames[framesCount - 1]) { /* Time is after last frame. */
		const float* lastVertices = self->frameVertices[framesCount - 1];
		if (alpha == 1) {
			if (blend == SP_MIX_BLEND_ADD) {
				sp38VertexAttachment* vertexAttachment = SUB_CAST(sp38VertexAttachment, slot->attachment);
				if (!vertexAttachment->bones) {
					/* Unweighted vertex positions, with alpha. */
					float* setupVertices = vertexAttachment->vertices;
					for (i = 0; i < vertexCount; i++) {
						deformArray[i] += lastVertices[i] - setupVertices[i];
					}
				} else {
					/* Weighted deform offsets, with alpha. */
					for (i = 0; i < vertexCount; i++)
						deformArray[i] += lastVertices[i];
				}
			} else {
				/* Vertex positions or deform offsets, no alpha. */
				memcpy(deformArray, lastVertices, vertexCount * sizeof(float));
			}
		} else {
			sp38VertexAttachment* vertexAttachment;
			switch (blend) {
				case SP_MIX_BLEND_SETUP:
					vertexAttachment = SUB_CAST(sp38VertexAttachment, slot->attachment);
					if (!vertexAttachment->bones) {
						/* Unweighted vertex positions, with alpha. */
						float* setupVertices = vertexAttachment->vertices;
						for (i = 0; i < vertexCount; i++) {
							float setup = setupVertices[i];
							deformArray[i] = setup + (lastVertices[i] - setup) * alpha;
						}
					} else {
						/* Weighted deform offsets, with alpha. */
						for (i = 0; i < vertexCount; i++)
							deformArray[i] = lastVertices[i] * alpha;
					}
					break;
				case SP_MIX_BLEND_FIRST:
				case SP_MIX_BLEND_REPLACE:
					/* Vertex positions or deform offsets, with alpha. */
					for (i = 0; i < vertexCount; i++)
						deformArray[i] += (lastVertices[i] - deformArray[i]) * alpha;
				case SP_MIX_BLEND_ADD:
					vertexAttachment = SUB_CAST(sp38VertexAttachment, slot->attachment);
					if (!vertexAttachment->bones) {
						/* Unweighted vertex positions, with alpha. */
						float* setupVertices = vertexAttachment->vertices;
						for (i = 0; i < vertexCount; i++) {
							deformArray[i] += (lastVertices[i] - setupVertices[i]) * alpha;
						}
					} else {
						for (i = 0; i < vertexCount; i++)
							deformArray[i] += lastVertices[i] * alpha;
					}
			}
		}
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frame = binarySearch(frames, framesCount, time, 1);
	prevVertices = frameVertices[frame - 1];
	nextVertices = frameVertices[frame];
	frameTime = frames[frame];
	percent = sp38CurveTimeline_getCurvePercent(SUPER(self), frame - 1, 1 - (time - frameTime) / (frames[frame - 1] - frameTime));

	if (alpha == 1) {
		if (blend == SP_MIX_BLEND_ADD) {
			sp38VertexAttachment* vertexAttachment = SUB_CAST(sp38VertexAttachment, slot->attachment);
			if (!vertexAttachment->bones) {
				float* setupVertices = vertexAttachment->vertices;
				for (i = 0; i < vertexCount; i++) {
					float prev = prevVertices[i];
					deformArray[i] += prev + (nextVertices[i] - prev) * percent - setupVertices[i];
				}
			} else {
				for (i = 0; i < vertexCount; i++) {
					float prev = prevVertices[i];
					deformArray[i] += prev + (nextVertices[i] - prev) * percent;
				}
			}
		} else {
			for (i = 0; i < vertexCount; i++) {
				float prev = prevVertices[i];
				deformArray[i] = prev + (nextVertices[i] - prev) * percent;
			}
		}
	} else {
		sp38VertexAttachment* vertexAttachment;
		switch (blend) {
		case SP_MIX_BLEND_SETUP:
			vertexAttachment = SUB_CAST(sp38VertexAttachment, slot->attachment);
			if (!vertexAttachment->bones) {
				float *setupVertices = vertexAttachment->vertices;
				for (i = 0; i < vertexCount; i++) {
					float prev = prevVertices[i], setup = setupVertices[i];
					deformArray[i] = setup + (prev + (nextVertices[i] - prev) * percent - setup) * alpha;
				}
			} else {
				for (i = 0; i < vertexCount; i++) {
					float prev = prevVertices[i];
					deformArray[i] = (prev + (nextVertices[i] - prev) * percent) * alpha;
				}
			}
			break;
		case SP_MIX_BLEND_FIRST:
		case SP_MIX_BLEND_REPLACE:
			for (i = 0; i < vertexCount; i++) {
				float prev = prevVertices[i];
				deformArray[i] += (prev + (nextVertices[i] - prev) * percent - deformArray[i]) * alpha;
			}
			break;
		case SP_MIX_BLEND_ADD:
			vertexAttachment = SUB_CAST(sp38VertexAttachment, slot->attachment);
			if (!vertexAttachment->bones) {
				float *setupVertices = vertexAttachment->vertices;
				for (i = 0; i < vertexCount; i++) {
					float prev = prevVertices[i];
					deformArray[i] += (prev + (nextVertices[i] - prev) * percent - setupVertices[i]) * alpha;
				}
			} else {
				for (i = 0; i < vertexCount; i++) {
					float prev = prevVertices[i];
					deformArray[i] += (prev + (nextVertices[i] - prev) * percent) * alpha;
				}
			}
		}
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

int _sp38DeformTimeline_getPropertyId (const sp38Timeline* timeline) {
	return (SP_TIMELINE_DEFORM << 27) + SUB_CAST(sp38VertexAttachment, SUB_CAST(sp38DeformTimeline, timeline)->attachment)->id + SUB_CAST(sp38DeformTimeline, timeline)->slotIndex;
}

void _sp38DeformTimeline_dispose (sp38Timeline* timeline) {
	sp38DeformTimeline* self = SUB_CAST(sp38DeformTimeline, timeline);
	int i;

	_sp38CurveTimeline_deinit(SUPER(self));

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->frameVertices[i]);
	FREE(self->frameVertices);
	FREE(self->frames);
	FREE(self);
}

sp38DeformTimeline* sp38DeformTimeline_create (int framesCount, int frameVerticesCount) {
	sp38DeformTimeline* self = NEW(sp38DeformTimeline);
	_sp38CurveTimeline_init(SUPER(self), SP_TIMELINE_DEFORM, framesCount, _sp38DeformTimeline_dispose, _sp38DeformTimeline_apply, _sp38DeformTimeline_getPropertyId);
	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, self->framesCount);
	CONST_CAST(float**, self->frameVertices) = CALLOC(float*, framesCount);
	CONST_CAST(int, self->frameVerticesCount) = frameVerticesCount;
	return self;
}

void sp38DeformTimeline_setFrame (sp38DeformTimeline* self, int frameIndex, float time, float* vertices) {
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
void _sp38EventTimeline_apply (const sp38Timeline* timeline, sp38Skeleton* skeleton, float lastTime, float time, sp38Event** firedEvents,
	int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction
) {
	sp38EventTimeline* self = (sp38EventTimeline*)timeline;
	int frame;
	if (!firedEvents) return;

	if (lastTime > time) { /* Fire events after last time for looped animations. */
		_sp38EventTimeline_apply(timeline, skeleton, lastTime, (float)INT_MAX, firedEvents, eventsCount, alpha, blend, direction);
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
	UNUSED(direction);
}

int _sp38EventTimeline_getPropertyId (const sp38Timeline* timeline) {
	return SP_TIMELINE_EVENT << 24;
	UNUSED(timeline);
}

void _sp38EventTimeline_dispose (sp38Timeline* timeline) {
	sp38EventTimeline* self = SUB_CAST(sp38EventTimeline, timeline);
	int i;

	_sp38Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		sp38Event_dispose(self->events[i]);
	FREE(self->events);
	FREE(self->frames);
	FREE(self);
}

sp38EventTimeline* sp38EventTimeline_create (int framesCount) {
	sp38EventTimeline* self = NEW(sp38EventTimeline);
	_sp38Timeline_init(SUPER(self), SP_TIMELINE_EVENT, _sp38EventTimeline_dispose, _sp38EventTimeline_apply, _sp38EventTimeline_getPropertyId);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(sp38Event**, self->events) = CALLOC(sp38Event*, framesCount);

	return self;
}

void sp38EventTimeline_setFrame (sp38EventTimeline* self, int frameIndex, sp38Event* event) {
	self->frames[frameIndex] = event->time;

	FREE(self->events[frameIndex]);
	self->events[frameIndex] = event;
}

/**/

void _sp38DrawOrderTimeline_apply (const sp38Timeline* timeline, sp38Skeleton* skeleton, float lastTime, float time,
	sp38Event** firedEvents, int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction
) {
	int i;
	int frame;
	const int* drawOrderToSetupIndex;
	sp38DrawOrderTimeline* self = (sp38DrawOrderTimeline*)timeline;

	if (direction == SP_MIX_DIRECTION_OUT ) {
		if (blend == SP_MIX_BLEND_SETUP) memcpy(skeleton->drawOrder, skeleton->slots, self->slotsCount * sizeof(sp38Slot*));
		return;
	}

	if (time < self->frames[0]) {
		if (blend == SP_MIX_BLEND_SETUP || blend == SP_MIX_BLEND_FIRST) memcpy(skeleton->drawOrder, skeleton->slots, self->slotsCount * sizeof(sp38Slot*));
		return;
	}

	if (time >= self->frames[self->framesCount - 1]) /* Time is after last frame. */
		frame = self->framesCount - 1;
	else
		frame = binarySearch1(self->frames, self->framesCount, time) - 1;

	drawOrderToSetupIndex = self->drawOrders[frame];
	if (!drawOrderToSetupIndex)
		memcpy(skeleton->drawOrder, skeleton->slots, self->slotsCount * sizeof(sp38Slot*));
	else {
		for (i = 0; i < self->slotsCount; ++i)
			skeleton->drawOrder[i] = skeleton->slots[drawOrderToSetupIndex[i]];
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(alpha);
}

int _sp38DrawOrderTimeline_getPropertyId (const sp38Timeline* timeline) {
	return SP_TIMELINE_DRAWORDER << 24;
	UNUSED(timeline);
}

void _sp38DrawOrderTimeline_dispose (sp38Timeline* timeline) {
	sp38DrawOrderTimeline* self = SUB_CAST(sp38DrawOrderTimeline, timeline);
	int i;

	_sp38Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->drawOrders[i]);
	FREE(self->drawOrders);
	FREE(self->frames);
	FREE(self);
}

sp38DrawOrderTimeline* sp38DrawOrderTimeline_create (int framesCount, int slotsCount) {
	sp38DrawOrderTimeline* self = NEW(sp38DrawOrderTimeline);
	_sp38Timeline_init(SUPER(self), SP_TIMELINE_DRAWORDER, _sp38DrawOrderTimeline_dispose, _sp38DrawOrderTimeline_apply, _sp38DrawOrderTimeline_getPropertyId);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(int**, self->drawOrders) = CALLOC(int*, framesCount);
	CONST_CAST(int, self->slotsCount) = slotsCount;

	return self;
}

void sp38DrawOrderTimeline_setFrame (sp38DrawOrderTimeline* self, int frameIndex, float time, const int* drawOrder) {
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

static const int IKCONSTRAINT_PREV_TIME = -6, IKCONSTRAINT_PREV_MIX = -5, IKCONSTRAINT_PREV_SOFTNESS = -4, IKCONSTRAINT_PREV_BEND_DIRECTION = -3, IKCONSTRAINT_PREV_COMPRESS = -2, IKCONSTRAINT_PREV_STRETCH = -1;
static const int IKCONSTRAINT_MIX = 1, IKCONSTRAINT_SOFTNESS = 2, IKCONSTRAINT_BEND_DIRECTION = 3, IKCONSTRAINT_COMPRESS = 4, IKCONSTRAINT_STRETCH = 5;

void _sp38IkConstraintTimeline_apply (const sp38Timeline* timeline, sp38Skeleton* skeleton, float lastTime, float time,
	sp38Event** firedEvents, int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction
) {
	int frame;
	float frameTime, percent, mix, softness;
	float *frames;
	int framesCount;
	sp38IkConstraint* constraint;
	sp38IkConstraintTimeline* self = (sp38IkConstraintTimeline*)timeline;

	constraint = skeleton->ikConstraints[self->ikConstraintIndex];
	if (!constraint->active) return;

	if (time < self->frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				constraint->mix = constraint->data->mix;
				constraint->softness = constraint->data->softness;
				constraint->bendDirection = constraint->data->bendDirection;
				constraint->compress = constraint->data->compress;
				constraint->stretch = constraint->data->stretch;
				return;
			case SP_MIX_BLEND_FIRST:
				constraint->mix += (constraint->data->mix - constraint->mix) * alpha;
				constraint->softness += (constraint->data->softness - constraint->softness) * alpha;
				constraint->bendDirection = constraint->data->bendDirection;
				constraint->compress = constraint->data->compress;
				constraint->stretch = constraint->data->stretch;
			case SP_MIX_BLEND_REPLACE:
			case SP_MIX_BLEND_ADD:
				; /* to appease compiler */
		}
		return;
	}

	frames = self->frames;
	framesCount = self->framesCount;
	if (time >= frames[framesCount - IKCONSTRAINT_ENTRIES]) { /* Time is after last frame. */
		if (blend == SP_MIX_BLEND_SETUP) {
			constraint->mix = constraint->data->mix + (frames[framesCount + IKCONSTRAINT_PREV_MIX] - constraint->data->mix) * alpha;
			constraint->softness = constraint->data->softness
				+ (frames[framesCount + IKCONSTRAINT_PREV_SOFTNESS] - constraint->data->softness) * alpha;
			if (direction == SP_MIX_DIRECTION_OUT) {
				constraint->bendDirection = constraint->data->bendDirection;
				constraint->compress = constraint->data->compress;
				constraint->stretch = constraint->data->stretch;
			} else {
				constraint->bendDirection = (int)frames[framesCount + IKCONSTRAINT_PREV_BEND_DIRECTION];
				constraint->compress = frames[framesCount + IKCONSTRAINT_PREV_COMPRESS] ? 1 : 0;
				constraint->stretch = frames[framesCount + IKCONSTRAINT_PREV_STRETCH] ? 1 : 0;
			}
		} else {
			constraint->mix += (frames[framesCount + IKCONSTRAINT_PREV_MIX] - constraint->mix) * alpha;
			constraint->softness += (frames[framesCount + IKCONSTRAINT_PREV_SOFTNESS] - constraint->softness) * alpha;
			if (direction == SP_MIX_DIRECTION_IN) {
				constraint->bendDirection = (int)frames[framesCount + IKCONSTRAINT_PREV_BEND_DIRECTION];
				constraint->compress = frames[framesCount + IKCONSTRAINT_PREV_COMPRESS] ? 1 : 0;
				constraint->stretch = frames[framesCount + IKCONSTRAINT_PREV_STRETCH] ? 1 : 0;
			}
		}
		return;
	}

	/* Interpolate between the previous frame and the current frame. */
	frame = binarySearch(self->frames, self->framesCount, time, IKCONSTRAINT_ENTRIES);
	mix = self->frames[frame + IKCONSTRAINT_PREV_MIX];
	softness = frames[frame + IKCONSTRAINT_PREV_SOFTNESS];
	frameTime = self->frames[frame];
	percent = sp38CurveTimeline_getCurvePercent(SUPER(self), frame / IKCONSTRAINT_ENTRIES - 1, 1 - (time - frameTime) / (self->frames[frame + IKCONSTRAINT_PREV_TIME] - frameTime));

	if (blend == SP_MIX_BLEND_SETUP) {
		constraint->mix = constraint->data->mix + (mix + (frames[frame + IKCONSTRAINT_MIX] - mix) * percent - constraint->data->mix) * alpha;
		constraint->softness = constraint->data->softness
			+ (softness + (frames[frame + IKCONSTRAINT_SOFTNESS] - softness) * percent - constraint->data->softness) * alpha;
		if (direction == SP_MIX_DIRECTION_OUT) {
			constraint->bendDirection = constraint->data->bendDirection;
			constraint->compress = constraint->data->compress;
			constraint->stretch = constraint->data->stretch;
		} else {
			constraint->bendDirection = (int)frames[frame + IKCONSTRAINT_PREV_BEND_DIRECTION];
			constraint->compress = frames[frame + IKCONSTRAINT_PREV_COMPRESS] ? 1 : 0;
			constraint->stretch = frames[frame + IKCONSTRAINT_PREV_STRETCH] ? 1 : 0;
		}
	} else {
		constraint->mix += (mix + (frames[frame + IKCONSTRAINT_MIX] - mix) * percent - constraint->mix) * alpha;
		constraint->softness += (softness + (frames[frame + IKCONSTRAINT_SOFTNESS] - softness) * percent - constraint->softness) * alpha;
		if (direction == SP_MIX_DIRECTION_IN) {
			constraint->bendDirection = (int)frames[frame + IKCONSTRAINT_PREV_BEND_DIRECTION];
			constraint->compress = frames[frame + IKCONSTRAINT_PREV_COMPRESS] ? 1 : 0;
			constraint->stretch = frames[frame + IKCONSTRAINT_PREV_STRETCH] ? 1 : 0;
		}
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

int _sp38IkConstraintTimeline_getPropertyId (const sp38Timeline* timeline) {
	return (SP_TIMELINE_IKCONSTRAINT << 24) + SUB_CAST(sp38IkConstraintTimeline, timeline)->ikConstraintIndex;
}

sp38IkConstraintTimeline* sp38IkConstraintTimeline_create (int framesCount) {
	return (sp38IkConstraintTimeline*)_sp38BaseTimeline_create(framesCount, SP_TIMELINE_IKCONSTRAINT, IKCONSTRAINT_ENTRIES, _sp38IkConstraintTimeline_apply, _sp38IkConstraintTimeline_getPropertyId);
}

void sp38IkConstraintTimeline_setFrame (sp38IkConstraintTimeline* self, int frameIndex, float time, float mix, float softness,
	int bendDirection, int /*boolean*/ compress, int /*boolean*/ stretch
) {
	frameIndex *= IKCONSTRAINT_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + IKCONSTRAINT_MIX] = mix;
	self->frames[frameIndex + IKCONSTRAINT_SOFTNESS] = softness;
	self->frames[frameIndex + IKCONSTRAINT_BEND_DIRECTION] = (float)bendDirection;
	self->frames[frameIndex + IKCONSTRAINT_COMPRESS] = compress ? 1 : 0;
	self->frames[frameIndex + IKCONSTRAINT_STRETCH] = stretch ? 1 : 0;
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

void _sp38TransformConstraintTimeline_apply (const sp38Timeline* timeline, sp38Skeleton* skeleton, float lastTime, float time,
	sp38Event** firedEvents, int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction
) {
	int frame;
	float frameTime, percent, rotate, translate, scale, shear;
	sp38TransformConstraint* constraint;
	sp38TransformConstraintTimeline* self = (sp38TransformConstraintTimeline*)timeline;
	float *frames;
	int framesCount;

	constraint = skeleton->transformConstraints[self->transformConstraintIndex];
	if (!constraint->active) return;

	if (time < self->frames[0]) {
		sp38TransformConstraintData* data = constraint->data;
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				constraint->rotateMix = data->rotateMix;
				constraint->translateMix = data->translateMix;
				constraint->scaleMix = data->scaleMix;
				constraint->shearMix = data->shearMix;
				return;
			case SP_MIX_BLEND_FIRST:
				constraint->rotateMix += (data->rotateMix - constraint->rotateMix) * alpha;
				constraint->translateMix += (data->translateMix - constraint->translateMix) * alpha;
				constraint->scaleMix += (data->scaleMix - constraint->scaleMix) * alpha;
				constraint->shearMix += (data->shearMix - constraint->shearMix) * alpha;
			case SP_MIX_BLEND_REPLACE:
			case SP_MIX_BLEND_ADD:
				; /* to appease compiler */
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
		percent = sp38CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSFORMCONSTRAINT_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + TRANSFORMCONSTRAINT_PREV_TIME] - frameTime));

		rotate += (frames[frame + TRANSFORMCONSTRAINT_ROTATE] - rotate) * percent;
		translate += (frames[frame + TRANSFORMCONSTRAINT_TRANSLATE] - translate) * percent;
		scale += (frames[frame + TRANSFORMCONSTRAINT_SCALE] - scale) * percent;
		shear += (frames[frame + TRANSFORMCONSTRAINT_SHEAR] - shear) * percent;
	}
	if (blend == SP_MIX_BLEND_SETUP) {
		sp38TransformConstraintData* data = constraint->data;
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
	UNUSED(direction);
}

int _sp38TransformConstraintTimeline_getPropertyId (const sp38Timeline* timeline) {
	return (SP_TIMELINE_TRANSFORMCONSTRAINT << 24) + SUB_CAST(sp38TransformConstraintTimeline, timeline)->transformConstraintIndex;
}

sp38TransformConstraintTimeline* sp38TransformConstraintTimeline_create (int framesCount) {
	return (sp38TransformConstraintTimeline*)_sp38BaseTimeline_create(framesCount, SP_TIMELINE_TRANSFORMCONSTRAINT,
		TRANSFORMCONSTRAINT_ENTRIES, _sp38TransformConstraintTimeline_apply, _sp38TransformConstraintTimeline_getPropertyId);
}

void sp38TransformConstraintTimeline_setFrame (sp38TransformConstraintTimeline* self, int frameIndex, float time, float rotateMix,
	float translateMix, float scaleMix, float shearMix
) {
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

void _sp38PathConstraintPositionTimeline_apply(const sp38Timeline* timeline, sp38Skeleton* skeleton, float lastTime, float time,
	sp38Event** firedEvents, int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction
) {
	int frame;
	float frameTime, percent, position;
	sp38PathConstraint* constraint;
	sp38PathConstraintPositionTimeline* self = (sp38PathConstraintPositionTimeline*)timeline;
	float* frames;
	int framesCount;

	constraint = skeleton->pathConstraints[self->pathConstraintIndex];
	if (!constraint->active) return;

	if (time < self->frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				constraint->position = constraint->data->position;
				return;
			case SP_MIX_BLEND_FIRST:
				constraint->position += (constraint->data->position - constraint->position) * alpha;
			case SP_MIX_BLEND_REPLACE:
			case SP_MIX_BLEND_ADD:
				; /* to appease compiler */
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
		percent = sp38CurveTimeline_getCurvePercent(SUPER(self), frame / PATHCONSTRAINTPOSITION_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + PATHCONSTRAINTPOSITION_PREV_TIME] - frameTime));

		position += (frames[frame + PATHCONSTRAINTPOSITION_VALUE] - position) * percent;
	}
	if (blend == SP_MIX_BLEND_SETUP)
		constraint->position = constraint->data->position + (position - constraint->data->position) * alpha;
	else
		constraint->position += (position - constraint->position) * alpha;

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

int _sp38PathConstraintPositionTimeline_getPropertyId (const sp38Timeline* timeline) {
	return (SP_TIMELINE_PATHCONSTRAINTPOSITION << 24) + SUB_CAST(sp38PathConstraintPositionTimeline, timeline)->pathConstraintIndex;
}

sp38PathConstraintPositionTimeline* sp38PathConstraintPositionTimeline_create (int framesCount) {
	return (sp38PathConstraintPositionTimeline*)_sp38BaseTimeline_create(framesCount, SP_TIMELINE_PATHCONSTRAINTPOSITION,
		PATHCONSTRAINTPOSITION_ENTRIES, _sp38PathConstraintPositionTimeline_apply, _sp38PathConstraintPositionTimeline_getPropertyId);
}

void sp38PathConstraintPositionTimeline_setFrame (sp38PathConstraintPositionTimeline* self, int frameIndex, float time, float value) {
	frameIndex *= PATHCONSTRAINTPOSITION_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + PATHCONSTRAINTPOSITION_VALUE] = value;
}

/**/
static const int PATHCONSTRAINTSPACING_PREV_TIME = -2;
static const int PATHCONSTRAINTSPACING_PREV_VALUE = -1;
static const int PATHCONSTRAINTSPACING_VALUE = 1;

void _sp38PathConstraintSpacingTimeline_apply(const sp38Timeline* timeline, sp38Skeleton* skeleton, float lastTime, float time,
	sp38Event** firedEvents, int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction
) {
	int frame;
	float frameTime, percent, spacing;
	sp38PathConstraint* constraint;
	sp38PathConstraintSpacingTimeline* self = (sp38PathConstraintSpacingTimeline*)timeline;
	float* frames;
	int framesCount;

	constraint = skeleton->pathConstraints[self->pathConstraintIndex];
	if (!constraint->active) return;

	if (time < self->frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				constraint->spacing = constraint->data->spacing;
				return;
			case SP_MIX_BLEND_FIRST:
				constraint->spacing += (constraint->data->spacing - constraint->spacing) * alpha;
			case SP_MIX_BLEND_REPLACE:
			case SP_MIX_BLEND_ADD:
				; /* to appease compiler */
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
		percent = sp38CurveTimeline_getCurvePercent(SUPER(self), frame / PATHCONSTRAINTSPACING_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + PATHCONSTRAINTSPACING_PREV_TIME] - frameTime));

		spacing += (frames[frame + PATHCONSTRAINTSPACING_VALUE] - spacing) * percent;
	}

	if (blend == SP_MIX_BLEND_SETUP)
		constraint->spacing = constraint->data->spacing + (spacing - constraint->data->spacing) * alpha;
	else
		constraint->spacing += (spacing - constraint->spacing) * alpha;

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

int _sp38PathConstraintSpacingTimeline_getPropertyId (const sp38Timeline* timeline) {
	return (SP_TIMELINE_PATHCONSTRAINTSPACING << 24) + SUB_CAST(sp38PathConstraintSpacingTimeline, timeline)->pathConstraintIndex;
}

sp38PathConstraintSpacingTimeline* sp38PathConstraintSpacingTimeline_create (int framesCount) {
	return (sp38PathConstraintSpacingTimeline*)_sp38BaseTimeline_create(framesCount, SP_TIMELINE_PATHCONSTRAINTSPACING,
		PATHCONSTRAINTSPACING_ENTRIES, _sp38PathConstraintSpacingTimeline_apply, _sp38PathConstraintSpacingTimeline_getPropertyId);
}

void sp38PathConstraintSpacingTimeline_setFrame (sp38PathConstraintSpacingTimeline* self, int frameIndex, float time, float value) {
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

void _sp38PathConstraintMixTimeline_apply(const sp38Timeline* timeline, sp38Skeleton* skeleton, float lastTime, float time,
	sp38Event** firedEvents, int* eventsCount, float alpha, sp38MixBlend blend, sp38MixDirection direction
) {
	int frame;
	float frameTime, percent, rotate, translate;
	sp38PathConstraint* constraint;
	sp38PathConstraintMixTimeline* self = (sp38PathConstraintMixTimeline*)timeline;
	float* frames;
	int framesCount;

	constraint = skeleton->pathConstraints[self->pathConstraintIndex];
	if (!constraint->active) return;

	if (time < self->frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				constraint->rotateMix = constraint->data->rotateMix;
				constraint->translateMix = constraint->data->translateMix;
				return;
			case SP_MIX_BLEND_FIRST:
				constraint->rotateMix += (constraint->data->rotateMix - constraint->rotateMix) * alpha;
				constraint->translateMix += (constraint->data->translateMix - constraint->translateMix) * alpha;
			case SP_MIX_BLEND_REPLACE:
			case SP_MIX_BLEND_ADD:
				; /* to appease compiler */
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
		percent = sp38CurveTimeline_getCurvePercent(SUPER(self), frame / PATHCONSTRAINTMIX_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + PATHCONSTRAINTMIX_PREV_TIME] - frameTime));

		rotate += (frames[frame + PATHCONSTRAINTMIX_ROTATE] - rotate) * percent;
		translate += (frames[frame + PATHCONSTRAINTMIX_TRANSLATE] - translate) * percent;
	}

	if (blend == SP_MIX_BLEND_SETUP) {
		constraint->rotateMix = constraint->data->rotateMix + (rotate - constraint->data->rotateMix) * alpha;
		constraint->translateMix = constraint->data->translateMix + (translate - constraint->data->translateMix) * alpha;
	} else {
		constraint->rotateMix += (rotate - constraint->rotateMix) * alpha;
		constraint->translateMix += (translate - constraint->translateMix) * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

int _sp38PathConstraintMixTimeline_getPropertyId (const sp38Timeline* timeline) {
	return (SP_TIMELINE_PATHCONSTRAINTMIX << 24) + SUB_CAST(sp38PathConstraintMixTimeline, timeline)->pathConstraintIndex;
}

sp38PathConstraintMixTimeline* sp38PathConstraintMixTimeline_create (int framesCount) {
	return (sp38PathConstraintMixTimeline*)_sp38BaseTimeline_create(framesCount, SP_TIMELINE_PATHCONSTRAINTMIX,
		PATHCONSTRAINTMIX_ENTRIES, _sp38PathConstraintMixTimeline_apply, _sp38PathConstraintMixTimeline_getPropertyId);
}

void sp38PathConstraintMixTimeline_setFrame (sp38PathConstraintMixTimeline* self, int frameIndex, float time, float rotateMix, float translateMix) {
	frameIndex *= PATHCONSTRAINTMIX_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + PATHCONSTRAINTMIX_ROTATE] = rotateMix;
	self->frames[frameIndex + PATHCONSTRAINTMIX_TRANSLATE] = translateMix;
}

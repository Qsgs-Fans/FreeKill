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

#include <spine/Animation.h>
#include <spine/IkConstraint.h>
#include <limits.h>
#include <spine/extension.h>

sp37Animation* sp37Animation_create (const char* name, int timelinesCount) {
	sp37Animation* self = NEW(sp37Animation);
	MALLOC_STR(self->name, name);
	self->timelinesCount = timelinesCount;
	self->timelines = MALLOC(sp37Timeline*, timelinesCount);
	return self;
}

void sp37Animation_dispose (sp37Animation* self) {
	int i;
	for (i = 0; i < self->timelinesCount; ++i)
		sp37Timeline_dispose(self->timelines[i]);
	FREE(self->timelines);
	FREE(self->name);
	FREE(self);
}

void sp37Animation_apply (const sp37Animation* self, sp37Skeleton* skeleton, float lastTime, float time, int loop, sp37Event** events,
		int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction) {
	int i, n = self->timelinesCount;

	if (loop && self->duration) {
		time = FMOD(time, self->duration);
		if (lastTime > 0) lastTime = FMOD(lastTime, self->duration);
	}

	for (i = 0; i < n; ++i)
		sp37Timeline_apply(self->timelines[i], skeleton, lastTime, time, events, eventsCount, alpha, blend, direction);
}

/**/

typedef struct _sp37TimelineVtable {
	void (*apply) (const sp37Timeline* self, sp37Skeleton* skeleton, float lastTime, float time, sp37Event** firedEvents,
			int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction);
	int (*getPropertyId) (const sp37Timeline* self);
	void (*dispose) (sp37Timeline* self);
} _sp37TimelineVtable;

void _sp37Timeline_init (sp37Timeline* self, sp37TimelineType type, /**/
					   void (*dispose) (sp37Timeline* self), /**/
					   void (*apply) (const sp37Timeline* self, sp37Skeleton* skeleton, float lastTime, float time, sp37Event** firedEvents, int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction),
					   int (*getPropertyId) (const sp37Timeline* self)) {
	CONST_CAST(sp37TimelineType, self->type) = type;
	CONST_CAST(_sp37TimelineVtable*, self->vtable) = NEW(_sp37TimelineVtable);
	VTABLE(sp37Timeline, self)->dispose = dispose;
	VTABLE(sp37Timeline, self)->apply = apply;
	VTABLE(sp37Timeline, self)->getPropertyId = getPropertyId;
}

void _sp37Timeline_deinit (sp37Timeline* self) {
	FREE(self->vtable);
}

void sp37Timeline_dispose (sp37Timeline* self) {
	VTABLE(sp37Timeline, self)->dispose(self);
}

void sp37Timeline_apply (const sp37Timeline* self, sp37Skeleton* skeleton, float lastTime, float time, sp37Event** firedEvents,
		int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction) {
	VTABLE(sp37Timeline, self)->apply(self, skeleton, lastTime, time, firedEvents, eventsCount, alpha, blend, direction);
}

int sp37Timeline_getPropertyId (const sp37Timeline* self) {
	return VTABLE(sp37Timeline, self)->getPropertyId(self);
}

/**/

static const float CURVE_LINEAR = 0, CURVE_STEPPED = 1, CURVE_BEZIER = 2;
static const int BEZIER_SIZE = 10 * 2 - 1;

void _sp37CurveTimeline_init (sp37CurveTimeline* self, sp37TimelineType type, int framesCount, /**/
		void (*dispose) (sp37Timeline* self), /**/
		void (*apply) (const sp37Timeline* self, sp37Skeleton* skeleton, float lastTime, float time, sp37Event** firedEvents, int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction),
		int (*getPropertyId)(const sp37Timeline* self)) {
	_sp37Timeline_init(SUPER(self), type, dispose, apply, getPropertyId);
	self->curves = CALLOC(float, (framesCount - 1) * BEZIER_SIZE);
}

void _sp37CurveTimeline_deinit (sp37CurveTimeline* self) {
	_sp37Timeline_deinit(SUPER(self));
	FREE(self->curves);
}

void sp37CurveTimeline_setLinear (sp37CurveTimeline* self, int frameIndex) {
	self->curves[frameIndex * BEZIER_SIZE] = CURVE_LINEAR;
}

void sp37CurveTimeline_setStepped (sp37CurveTimeline* self, int frameIndex) {
	self->curves[frameIndex * BEZIER_SIZE] = CURVE_STEPPED;
}

void sp37CurveTimeline_setCurve (sp37CurveTimeline* self, int frameIndex, float cx1, float cy1, float cx2, float cy2) {
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

float sp37CurveTimeline_getCurvePercent (const sp37CurveTimeline* self, int frameIndex, float percent) {
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

int _sp37CurveTimeline_binarySearch (float *values, int valuesLength, float target, int step) {
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

void _sp37BaseTimeline_dispose (sp37Timeline* timeline) {
	struct sp37BaseTimeline* self = SUB_CAST(struct sp37BaseTimeline, timeline);
	_sp37CurveTimeline_deinit(SUPER(self));
	FREE(self->frames);
	FREE(self);
}

/* Many timelines have structure identical to struct sp37BaseTimeline and extend sp37CurveTimeline. **/
struct sp37BaseTimeline* _sp37BaseTimeline_create (int framesCount, sp37TimelineType type, int frameSize, /**/
		void (*apply) (const sp37Timeline* self, sp37Skeleton* skeleton, float lastTime, float time, sp37Event** firedEvents,
				int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction),
		int (*getPropertyId) (const sp37Timeline* self)) {
	struct sp37BaseTimeline* self = NEW(struct sp37BaseTimeline);
	_sp37CurveTimeline_init(SUPER(self), type, framesCount, _sp37BaseTimeline_dispose, apply, getPropertyId);

	CONST_CAST(int, self->framesCount) = framesCount * frameSize;
	CONST_CAST(float*, self->frames) = CALLOC(float, self->framesCount);

	return self;
}

/**/

void _sp37RotateTimeline_apply (const sp37Timeline* timeline, sp37Skeleton* skeleton, float lastTime, float time, sp37Event** firedEvents,
		int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction) {
	sp37Bone *bone;
	int frame;
	float prevRotation, frameTime, percent, r;
	sp37RotateTimeline* self = SUB_CAST(sp37RotateTimeline, timeline);

	bone = skeleton->bones[self->boneIndex];
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
	percent = sp37CurveTimeline_getCurvePercent(SUPER(self), (frame >> 1) - 1, 1 - (time - frameTime) / (self->frames[frame + ROTATE_PREV_TIME] - frameTime));

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

int _sp37RotateTimeline_getPropertyId (const sp37Timeline* timeline) {
	return (SP_TIMELINE_ROTATE << 25) + SUB_CAST(sp37RotateTimeline, timeline)->boneIndex;
}

sp37RotateTimeline* sp37RotateTimeline_create (int framesCount) {
	return _sp37BaseTimeline_create(framesCount, SP_TIMELINE_ROTATE, ROTATE_ENTRIES, _sp37RotateTimeline_apply, _sp37RotateTimeline_getPropertyId);
}

void sp37RotateTimeline_setFrame (sp37RotateTimeline* self, int frameIndex, float time, float degrees) {
	frameIndex <<= 1;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + ROTATE_ROTATION] = degrees;
}

/**/

static const int TRANSLATE_PREV_TIME = -3, TRANSLATE_PREV_X = -2, TRANSLATE_PREV_Y = -1;
static const int TRANSLATE_X = 1, TRANSLATE_Y = 2;

void _sp37TranslateTimeline_apply (const sp37Timeline* timeline, sp37Skeleton* skeleton, float lastTime, float time,
		sp37Event** firedEvents, int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction) {
	sp37Bone *bone;
	int frame;
	float frameTime, percent;
	float x, y;
	float *frames;
	int framesCount;

	sp37TranslateTimeline* self = SUB_CAST(sp37TranslateTimeline, timeline);

	bone = skeleton->bones[self->boneIndex];
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
		percent = sp37CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSLATE_ENTRIES - 1,
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

int _sp37TranslateTimeline_getPropertyId (const sp37Timeline* self) {
	return (SP_TIMELINE_TRANSLATE << 24) + SUB_CAST(sp37TranslateTimeline, self)->boneIndex;
}

sp37TranslateTimeline* sp37TranslateTimeline_create (int framesCount) {
	return _sp37BaseTimeline_create(framesCount, SP_TIMELINE_TRANSLATE, TRANSLATE_ENTRIES, _sp37TranslateTimeline_apply, _sp37TranslateTimeline_getPropertyId);
}

void sp37TranslateTimeline_setFrame (sp37TranslateTimeline* self, int frameIndex, float time, float x, float y) {
	frameIndex *= TRANSLATE_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + TRANSLATE_X] = x;
	self->frames[frameIndex + TRANSLATE_Y] = y;
}

/**/

void _sp37ScaleTimeline_apply (const sp37Timeline* timeline, sp37Skeleton* skeleton, float lastTime, float time, sp37Event** firedEvents,
		int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction) {
	sp37Bone *bone;
	int frame;
	float frameTime, percent, x, y;
	float *frames;
	int framesCount;

	sp37ScaleTimeline* self = SUB_CAST(sp37ScaleTimeline, timeline);

	bone = skeleton->bones[self->boneIndex];
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
		percent = sp37CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSLATE_ENTRIES - 1,
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

int _sp37ScaleTimeline_getPropertyId (const sp37Timeline* timeline) {
	return (SP_TIMELINE_SCALE << 24) + SUB_CAST(sp37ScaleTimeline, timeline)->boneIndex;
}

sp37ScaleTimeline* sp37ScaleTimeline_create (int framesCount) {
	return _sp37BaseTimeline_create(framesCount, SP_TIMELINE_SCALE, TRANSLATE_ENTRIES, _sp37ScaleTimeline_apply, _sp37ScaleTimeline_getPropertyId);
}

void sp37ScaleTimeline_setFrame (sp37ScaleTimeline* self, int frameIndex, float time, float x, float y) {
	sp37TranslateTimeline_setFrame(self, frameIndex, time, x, y);
}

/**/

void _sp37ShearTimeline_apply (const sp37Timeline* timeline, sp37Skeleton* skeleton, float lastTime, float time, sp37Event** firedEvents,
							 int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction) {
	sp37Bone *bone;
	int frame;
	float frameTime, percent, x, y;
	float *frames;
	int framesCount;

	sp37ShearTimeline* self = SUB_CAST(sp37ShearTimeline, timeline);

	bone = skeleton->bones[self->boneIndex];
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
		percent = sp37CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSLATE_ENTRIES - 1,
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

int _sp37ShearTimeline_getPropertyId (const sp37Timeline* timeline) {
	return (SP_TIMELINE_SHEAR << 24) + SUB_CAST(sp37ShearTimeline, timeline)->boneIndex;
}

sp37ShearTimeline* sp37ShearTimeline_create (int framesCount) {
	return (sp37ShearTimeline*)_sp37BaseTimeline_create(framesCount, SP_TIMELINE_SHEAR, 3, _sp37ShearTimeline_apply, _sp37ShearTimeline_getPropertyId);
}

void sp37ShearTimeline_setFrame (sp37ShearTimeline* self, int frameIndex, float time, float x, float y) {
	sp37TranslateTimeline_setFrame(self, frameIndex, time, x, y);
}

/**/

static const int COLOR_PREV_TIME = -5, COLOR_PREV_R = -4, COLOR_PREV_G = -3, COLOR_PREV_B = -2, COLOR_PREV_A = -1;
static const int COLOR_R = 1, COLOR_G = 2, COLOR_B = 3, COLOR_A = 4;

void _sp37ColorTimeline_apply (const sp37Timeline* timeline, sp37Skeleton* skeleton, float lastTime, float time, sp37Event** firedEvents,
		int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction) {
	sp37Slot *slot;
	int frame;
	float percent, frameTime;
	float r, g, b, a;
	sp37Color* color;
	sp37Color* setup;
	sp37ColorTimeline* self = (sp37ColorTimeline*)timeline;
	slot = skeleton->slots[self->slotIndex];

	if (time < self->frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				sp37Color_setFromColor(&slot->color, &slot->data->color);
				return;
			case SP_MIX_BLEND_FIRST:
				color = &slot->color;
				setup = &slot->data->color;
				sp37Color_addFloats(color, (setup->r - color->r) * alpha, (setup->g - color->g) * alpha, (setup->b - color->b) * alpha,
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
		percent = sp37CurveTimeline_getCurvePercent(SUPER(self), frame / COLOR_ENTRIES - 1,
			1 - (time - frameTime) / (self->frames[frame + COLOR_PREV_TIME] - frameTime));

		r += (self->frames[frame + COLOR_R] - r) * percent;
		g += (self->frames[frame + COLOR_G] - g) * percent;
		b += (self->frames[frame + COLOR_B] - b) * percent;
		a += (self->frames[frame + COLOR_A] - a) * percent;
	}
	if (alpha == 1) {
		sp37Color_setFromFloats(&slot->color, r, g, b, a);
	} else {
		if (blend == SP_MIX_BLEND_SETUP) {
			sp37Color_setFromColor(&slot->color, &slot->data->color);
		}
		sp37Color_addFloats(&slot->color, (r - slot->color.r) * alpha, (g - slot->color.g) * alpha, (b - slot->color.b) * alpha, (a - slot->color.a) * alpha);
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

int _sp37ColorTimeline_getPropertyId (const sp37Timeline* timeline) {
	return (SP_TIMELINE_COLOR << 24) + SUB_CAST(sp37ColorTimeline, timeline)->slotIndex;
}

sp37ColorTimeline* sp37ColorTimeline_create (int framesCount) {
	return (sp37ColorTimeline*)_sp37BaseTimeline_create(framesCount, SP_TIMELINE_COLOR, 5, _sp37ColorTimeline_apply, _sp37ColorTimeline_getPropertyId);
}

void sp37ColorTimeline_setFrame (sp37ColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a) {
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

void _sp37TwoColorTimeline_apply (const sp37Timeline* timeline, sp37Skeleton* skeleton, float lastTime, float time, sp37Event** firedEvents,
							 int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction) {
	sp37Slot *slot;
	int frame;
	float percent, frameTime;
	float r, g, b, a, r2, g2, b2;
	sp37Color* light;
	sp37Color* dark;
	sp37Color* setupLight;
	sp37Color* setupDark;
	sp37ColorTimeline* self = (sp37ColorTimeline*)timeline;
	slot = skeleton->slots[self->slotIndex];

	if (time < self->frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				sp37Color_setFromColor(&slot->color, &slot->data->color);
				sp37Color_setFromColor(slot->darkColor, slot->data->darkColor);
				return;
			case SP_MIX_BLEND_FIRST:
				light = &slot->color;
				dark = slot->darkColor;
				setupLight = &slot->data->color;
				setupDark = slot->data->darkColor;
				sp37Color_addFloats(light, (setupLight->r - light->r) * alpha, (setupLight->g - light->g) * alpha, (setupLight->b - light->b) * alpha,
						  (setupLight->a - light->a) * alpha);
				sp37Color_addFloats(dark, (setupDark->r - dark->r) * alpha, (setupDark->g - dark->g) * alpha, (setupDark->b - dark->b) * alpha, 0);
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
		percent = sp37CurveTimeline_getCurvePercent(SUPER(self), frame / TWOCOLOR_ENTRIES - 1,
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
		sp37Color_setFromFloats(&slot->color, r, g, b, a);
		sp37Color_setFromFloats(slot->darkColor, r2, g2, b2, 1);
	} else {
		light = &slot->color;
		dark = slot->darkColor;
		if (blend == SP_MIX_BLEND_SETUP) {
			sp37Color_setFromColor(light, &slot->data->color);
			sp37Color_setFromColor(dark, slot->data->darkColor);
		}
		sp37Color_addFloats(light, (r - light->r) * alpha, (g - light->g) * alpha, (b - light->b) * alpha, (a - light->a) * alpha);
		sp37Color_addFloats(dark, (r2 - dark->r) * alpha, (g2 - dark->g) * alpha, (b2 - dark->b) * alpha, 0);
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

int _sp37TwoColorTimeline_getPropertyId (const sp37Timeline* timeline) {
	return (SP_TIMELINE_TWOCOLOR << 24) + SUB_CAST(sp37TwoColorTimeline, timeline)->slotIndex;
}

sp37TwoColorTimeline* sp37TwoColorTimeline_create (int framesCount) {
	return (sp37TwoColorTimeline*)_sp37BaseTimeline_create(framesCount, SP_TIMELINE_TWOCOLOR, TWOCOLOR_ENTRIES, _sp37TwoColorTimeline_apply, _sp37TwoColorTimeline_getPropertyId);
}

void sp37TwoColorTimeline_setFrame (sp37TwoColorTimeline* self, int frameIndex, float time, float r, float g, float b, float a, float r2, float g2, float b2) {
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

void _sp37AttachmentTimeline_apply (const sp37Timeline* timeline, sp37Skeleton* skeleton, float lastTime, float time,
		sp37Event** firedEvents, int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction) {
	const char* attachmentName;
	sp37AttachmentTimeline* self = (sp37AttachmentTimeline*)timeline;
	int frameIndex;
	sp37Slot* slot = skeleton->slots[self->slotIndex];

	if (direction == SP_MIX_DIRECTION_OUT && blend == SP_MIX_BLEND_SETUP) {
		attachmentName = slot->data->attachmentName;
        sp37Slot_setAttachment(slot, attachmentName ? sp37Skeleton_getAttachmentForSlotIndex(skeleton, self->slotIndex, attachmentName) : 0);
		return;
	}

	if (time < self->frames[0]) {
		if (blend == SP_MIX_BLEND_SETUP || blend == SP_MIX_BLEND_FIRST) {
			attachmentName = slot->data->attachmentName;
			sp37Slot_setAttachment(skeleton->slots[self->slotIndex],
								 attachmentName ? sp37Skeleton_getAttachmentForSlotIndex(skeleton, self->slotIndex, attachmentName) : 0);
		}
		return;
	}

	if (time >= self->frames[self->framesCount - 1])
		frameIndex = self->framesCount - 1;
	else
		frameIndex = binarySearch1(self->frames, self->framesCount, time) - 1;

	attachmentName = self->attachmentNames[frameIndex];
	sp37Slot_setAttachment(skeleton->slots[self->slotIndex],
			attachmentName ? sp37Skeleton_getAttachmentForSlotIndex(skeleton, self->slotIndex, attachmentName) : 0);

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(alpha);
}

int _sp37AttachmentTimeline_getPropertyId (const sp37Timeline* timeline) {
	return (SP_TIMELINE_ATTACHMENT << 24) + SUB_CAST(sp37AttachmentTimeline, timeline)->slotIndex;
}

void _sp37AttachmentTimeline_dispose (sp37Timeline* timeline) {
	sp37AttachmentTimeline* self = SUB_CAST(sp37AttachmentTimeline, timeline);
	int i;

	_sp37Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->attachmentNames[i]);
	FREE(self->attachmentNames);
	FREE(self->frames);
	FREE(self);
}

sp37AttachmentTimeline* sp37AttachmentTimeline_create (int framesCount) {
	sp37AttachmentTimeline* self = NEW(sp37AttachmentTimeline);
	_sp37Timeline_init(SUPER(self), SP_TIMELINE_ATTACHMENT, _sp37AttachmentTimeline_dispose, _sp37AttachmentTimeline_apply, _sp37AttachmentTimeline_getPropertyId);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(char**, self->attachmentNames) = CALLOC(char*, framesCount);

	return self;
}

void sp37AttachmentTimeline_setFrame (sp37AttachmentTimeline* self, int frameIndex, float time, const char* attachmentName) {
	self->frames[frameIndex] = time;

	FREE(self->attachmentNames[frameIndex]);
	if (attachmentName)
		MALLOC_STR(self->attachmentNames[frameIndex], attachmentName);
	else
		self->attachmentNames[frameIndex] = 0;
}

/**/

void _sp37DeformTimeline_apply (const sp37Timeline* timeline, sp37Skeleton* skeleton, float lastTime, float time, sp37Event** firedEvents,
							  int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction) {
	int frame, i, vertexCount;
	float percent, frameTime;
	const float* prevVertices;
	const float* nextVertices;
	float* frames;
	int framesCount;
	const float** frameVertices;
	float* vertices;
	sp37DeformTimeline* self = (sp37DeformTimeline*)timeline;

	sp37Slot *slot = skeleton->slots[self->slotIndex];

	if (slot->attachment != self->attachment) {
		if (!slot->attachment) return;
		switch (slot->attachment->type) {
			case SP_ATTACHMENT_MESH: {
				sp37MeshAttachment* mesh = SUB_CAST(sp37MeshAttachment, slot->attachment);
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
	if (slot->attachmentVerticesCount == 0) blend = SP_MIX_BLEND_SETUP;

	frameVertices = self->frameVertices;
	vertices = slot->attachmentVertices;

	if (time < frames[0]) { /* Time is before first frame. */
		sp37VertexAttachment* vertexAttachment = SUB_CAST(sp37VertexAttachment, slot->attachment);
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				slot->attachmentVerticesCount = 0;
				return;
			case SP_MIX_BLEND_FIRST:
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
			case SP_MIX_BLEND_REPLACE:
			case SP_MIX_BLEND_ADD:
				; /* to appease compiler */
		}
		return;
	}

	slot->attachmentVerticesCount = vertexCount;
	if (time >= frames[framesCount - 1]) { /* Time is after last frame. */
		const float* lastVertices = self->frameVertices[framesCount - 1];
		if (alpha == 1) {
			if (blend == SP_MIX_BLEND_ADD) {
				sp37VertexAttachment* vertexAttachment = SUB_CAST(sp37VertexAttachment, slot->attachment);
				if (!vertexAttachment->bones) {
					/* Unweighted vertex positions, with alpha. */
					float* setupVertices = vertexAttachment->vertices;
					for (i = 0; i < vertexCount; i++) {
						vertices[i] += lastVertices[i] - setupVertices[i];
					}
				} else {
					/* Weighted deform offsets, with alpha. */
					for (i = 0; i < vertexCount; i++)
						vertices[i] += lastVertices[i];
				}
			} else {
				/* Vertex positions or deform offsets, no alpha. */
				memcpy(vertices, lastVertices, vertexCount * sizeof(float));
			}
		} else {
			sp37VertexAttachment* vertexAttachment;
			switch (blend) {
				case SP_MIX_BLEND_SETUP:
					vertexAttachment = SUB_CAST(sp37VertexAttachment, slot->attachment);
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
					break;
				case SP_MIX_BLEND_FIRST:
				case SP_MIX_BLEND_REPLACE:
					/* Vertex positions or deform offsets, with alpha. */
					for (i = 0; i < vertexCount; i++)
						vertices[i] += (lastVertices[i] - vertices[i]) * alpha;
				case SP_MIX_BLEND_ADD:
					vertexAttachment = SUB_CAST(sp37VertexAttachment, slot->attachment);
					if (!vertexAttachment->bones) {
						/* Unweighted vertex positions, with alpha. */
						float* setupVertices = vertexAttachment->vertices;
						for (i = 0; i < vertexCount; i++) {
							vertices[i] += (lastVertices[i] - setupVertices[i]) * alpha;
						}
					} else {
						for (i = 0; i < vertexCount; i++)
							vertices[i] += lastVertices[i] * alpha;
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
	percent = sp37CurveTimeline_getCurvePercent(SUPER(self), frame - 1, 1 - (time - frameTime) / (frames[frame - 1] - frameTime));

	if (alpha == 1) {
		if (blend == SP_MIX_BLEND_ADD) {
			sp37VertexAttachment* vertexAttachment = SUB_CAST(sp37VertexAttachment, slot->attachment);
			if (!vertexAttachment->bones) {
				float* setupVertices = vertexAttachment->vertices;
				for (i = 0; i < vertexCount; i++) {
					float prev = prevVertices[i];
					vertices[i] += prev + (nextVertices[i] - prev) * percent - setupVertices[i];
				}
			} else {
				for (i = 0; i < vertexCount; i++) {
					float prev = prevVertices[i];
					vertices[i] += prev + (nextVertices[i] - prev) * percent;
				}
			}
		} else {
			for (i = 0; i < vertexCount; i++) {
				float prev = prevVertices[i];
				vertices[i] = prev + (nextVertices[i] - prev) * percent;
			}
		}
	} else {
		sp37VertexAttachment* vertexAttachment;
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				vertexAttachment = SUB_CAST(sp37VertexAttachment, slot->attachment);
				if (!vertexAttachment->bones) {
					float *setupVertices = vertexAttachment->vertices;
					for (i = 0; i < vertexCount; i++) {
						float prev = prevVertices[i], setup = setupVertices[i];
						vertices[i] = setup + (prev + (nextVertices[i] - prev) * percent - setup) * alpha;
					}
				} else {
					for (i = 0; i < vertexCount; i++) {
						float prev = prevVertices[i];
						vertices[i] = (prev + (nextVertices[i] - prev) * percent) * alpha;
					}
				}
				break;
			case SP_MIX_BLEND_FIRST:
			case SP_MIX_BLEND_REPLACE:
				for (i = 0; i < vertexCount; i++) {
					float prev = prevVertices[i];
					vertices[i] += (prev + (nextVertices[i] - prev) * percent - vertices[i]) * alpha;
				}
				break;
			case SP_MIX_BLEND_ADD:
				vertexAttachment = SUB_CAST(sp37VertexAttachment, slot->attachment);
				if (!vertexAttachment->bones) {
					float *setupVertices = vertexAttachment->vertices;
					for (i = 0; i < vertexCount; i++) {
						float prev = prevVertices[i];
						vertices[i] += (prev + (nextVertices[i] - prev) * percent - setupVertices[i]) * alpha;
					}
				} else {
					for (i = 0; i < vertexCount; i++) {
						float prev = prevVertices[i];
						vertices[i] += (prev + (nextVertices[i] - prev) * percent) * alpha;
					}
				}
		}
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

int _sp37DeformTimeline_getPropertyId (const sp37Timeline* timeline) {
	return (SP_TIMELINE_DEFORM << 27) + SUB_CAST(sp37VertexAttachment, SUB_CAST(sp37DeformTimeline, timeline)->attachment)->id + SUB_CAST(sp37DeformTimeline, timeline)->slotIndex;
}

void _sp37DeformTimeline_dispose (sp37Timeline* timeline) {
	sp37DeformTimeline* self = SUB_CAST(sp37DeformTimeline, timeline);
	int i;

	_sp37CurveTimeline_deinit(SUPER(self));

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->frameVertices[i]);
	FREE(self->frameVertices);
	FREE(self->frames);
	FREE(self);
}

sp37DeformTimeline* sp37DeformTimeline_create (int framesCount, int frameVerticesCount) {
	sp37DeformTimeline* self = NEW(sp37DeformTimeline);
	_sp37CurveTimeline_init(SUPER(self), SP_TIMELINE_DEFORM, framesCount, _sp37DeformTimeline_dispose, _sp37DeformTimeline_apply, _sp37DeformTimeline_getPropertyId);
	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, self->framesCount);
	CONST_CAST(float**, self->frameVertices) = CALLOC(float*, framesCount);
	CONST_CAST(int, self->frameVerticesCount) = frameVerticesCount;
	return self;
}

void sp37DeformTimeline_setFrame (sp37DeformTimeline* self, int frameIndex, float time, float* vertices) {
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
void _sp37EventTimeline_apply (const sp37Timeline* timeline, sp37Skeleton* skeleton, float lastTime, float time, sp37Event** firedEvents,
		int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction) {
	sp37EventTimeline* self = (sp37EventTimeline*)timeline;
	int frame;
	if (!firedEvents) return;

	if (lastTime > time) { /* Fire events after last time for looped animations. */
		_sp37EventTimeline_apply(timeline, skeleton, lastTime, (float)INT_MAX, firedEvents, eventsCount, alpha, blend, direction);
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

int _sp37EventTimeline_getPropertyId (const sp37Timeline* timeline) {
	return SP_TIMELINE_EVENT << 24;
	UNUSED(timeline);
}

void _sp37EventTimeline_dispose (sp37Timeline* timeline) {
	sp37EventTimeline* self = SUB_CAST(sp37EventTimeline, timeline);
	int i;

	_sp37Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		sp37Event_dispose(self->events[i]);
	FREE(self->events);
	FREE(self->frames);
	FREE(self);
}

sp37EventTimeline* sp37EventTimeline_create (int framesCount) {
	sp37EventTimeline* self = NEW(sp37EventTimeline);
	_sp37Timeline_init(SUPER(self), SP_TIMELINE_EVENT, _sp37EventTimeline_dispose, _sp37EventTimeline_apply, _sp37EventTimeline_getPropertyId);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(sp37Event**, self->events) = CALLOC(sp37Event*, framesCount);

	return self;
}

void sp37EventTimeline_setFrame (sp37EventTimeline* self, int frameIndex, sp37Event* event) {
	self->frames[frameIndex] = event->time;

	FREE(self->events[frameIndex]);
	self->events[frameIndex] = event;
}

/**/

void _sp37DrawOrderTimeline_apply (const sp37Timeline* timeline, sp37Skeleton* skeleton, float lastTime, float time,
		sp37Event** firedEvents, int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction) {
	int i;
	int frame;
	const int* drawOrderToSetupIndex;
	sp37DrawOrderTimeline* self = (sp37DrawOrderTimeline*)timeline;

	if (direction == SP_MIX_DIRECTION_OUT && blend == SP_MIX_BLEND_SETUP) {
		memcpy(skeleton->drawOrder, skeleton->slots, self->slotsCount * sizeof(sp37Slot*));
		return;
	}

	if (time < self->frames[0]) {
		if (blend == SP_MIX_BLEND_SETUP || blend == SP_MIX_BLEND_FIRST) memcpy(skeleton->drawOrder, skeleton->slots, self->slotsCount * sizeof(sp37Slot*));
		return;
	}

	if (time >= self->frames[self->framesCount - 1]) /* Time is after last frame. */
		frame = self->framesCount - 1;
	else
		frame = binarySearch1(self->frames, self->framesCount, time) - 1;

	drawOrderToSetupIndex = self->drawOrders[frame];
	if (!drawOrderToSetupIndex)
		memcpy(skeleton->drawOrder, skeleton->slots, self->slotsCount * sizeof(sp37Slot*));
	else {
		for (i = 0; i < self->slotsCount; ++i)
			skeleton->drawOrder[i] = skeleton->slots[drawOrderToSetupIndex[i]];
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(alpha);
}

int _sp37DrawOrderTimeline_getPropertyId (const sp37Timeline* timeline) {
	return SP_TIMELINE_DRAWORDER << 24;
	UNUSED(timeline);
}

void _sp37DrawOrderTimeline_dispose (sp37Timeline* timeline) {
	sp37DrawOrderTimeline* self = SUB_CAST(sp37DrawOrderTimeline, timeline);
	int i;

	_sp37Timeline_deinit(timeline);

	for (i = 0; i < self->framesCount; ++i)
		FREE(self->drawOrders[i]);
	FREE(self->drawOrders);
	FREE(self->frames);
	FREE(self);
}

sp37DrawOrderTimeline* sp37DrawOrderTimeline_create (int framesCount, int slotsCount) {
	sp37DrawOrderTimeline* self = NEW(sp37DrawOrderTimeline);
	_sp37Timeline_init(SUPER(self), SP_TIMELINE_DRAWORDER, _sp37DrawOrderTimeline_dispose, _sp37DrawOrderTimeline_apply, _sp37DrawOrderTimeline_getPropertyId);

	CONST_CAST(int, self->framesCount) = framesCount;
	CONST_CAST(float*, self->frames) = CALLOC(float, framesCount);
	CONST_CAST(int**, self->drawOrders) = CALLOC(int*, framesCount);
	CONST_CAST(int, self->slotsCount) = slotsCount;

	return self;
}

void sp37DrawOrderTimeline_setFrame (sp37DrawOrderTimeline* self, int frameIndex, float time, const int* drawOrder) {
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

static const int IKCONSTRAINT_PREV_TIME = -5, IKCONSTRAINT_PREV_MIX = -4, IKCONSTRAINT_PREV_BEND_DIRECTION = -3, IKCONSTRAINT_PREV_COMPRESS = -2, IKCONSTRAINT_PREV_STRETCH = -1;
static const int IKCONSTRAINT_MIX = 1, IKCONSTRAINT_BEND_DIRECTION = 2, IKCONSTRAINT_COMPRESS = 3, IKCONSTRAINT_STRETCH = 4;

void _sp37IkConstraintTimeline_apply (const sp37Timeline* timeline, sp37Skeleton* skeleton, float lastTime, float time,
		sp37Event** firedEvents, int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction) {
	int frame;
	float frameTime, percent, mix;
	float *frames;
	int framesCount;
	sp37IkConstraint* constraint;
	sp37IkConstraintTimeline* self = (sp37IkConstraintTimeline*)timeline;

	constraint = skeleton->ikConstraints[self->ikConstraintIndex];

	if (time < self->frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				constraint->mix = constraint->data->mix;
				constraint->bendDirection = constraint->data->bendDirection;
				constraint->compress = constraint->data->compress;
				constraint->stretch = constraint->data->stretch;
				return;
			case SP_MIX_BLEND_FIRST:
				constraint->mix += (constraint->data->mix - constraint->mix) * alpha;
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
	frameTime = self->frames[frame];
	percent = sp37CurveTimeline_getCurvePercent(SUPER(self), frame / IKCONSTRAINT_ENTRIES - 1, 1 - (time - frameTime) / (self->frames[frame + IKCONSTRAINT_PREV_TIME] - frameTime));

	if (blend == SP_MIX_BLEND_SETUP) {
		constraint->mix = constraint->data->mix + (mix + (frames[frame + IKCONSTRAINT_MIX] - mix) * percent - constraint->data->mix) * alpha;
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

int _sp37IkConstraintTimeline_getPropertyId (const sp37Timeline* timeline) {
	return (SP_TIMELINE_IKCONSTRAINT << 24) + SUB_CAST(sp37IkConstraintTimeline, timeline)->ikConstraintIndex;
}

sp37IkConstraintTimeline* sp37IkConstraintTimeline_create (int framesCount) {
	return (sp37IkConstraintTimeline*)_sp37BaseTimeline_create(framesCount, SP_TIMELINE_IKCONSTRAINT, IKCONSTRAINT_ENTRIES, _sp37IkConstraintTimeline_apply, _sp37IkConstraintTimeline_getPropertyId);
}

void sp37IkConstraintTimeline_setFrame (sp37IkConstraintTimeline* self, int frameIndex, float time, float mix, int bendDirection, int /*boolean*/ compress, int /*boolean*/ stretch) {
	frameIndex *= IKCONSTRAINT_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + IKCONSTRAINT_MIX] = mix;
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

void _sp37TransformConstraintTimeline_apply (const sp37Timeline* timeline, sp37Skeleton* skeleton, float lastTime, float time,
									sp37Event** firedEvents, int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction) {
	int frame;
	float frameTime, percent, rotate, translate, scale, shear;
	sp37TransformConstraint* constraint;
	sp37TransformConstraintTimeline* self = (sp37TransformConstraintTimeline*)timeline;
	float *frames;
	int framesCount;

	constraint = skeleton->transformConstraints[self->transformConstraintIndex];
	if (time < self->frames[0]) {
		sp37TransformConstraintData* data = constraint->data;
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
		percent = sp37CurveTimeline_getCurvePercent(SUPER(self), frame / TRANSFORMCONSTRAINT_ENTRIES - 1,
										1 - (time - frameTime) / (frames[frame + TRANSFORMCONSTRAINT_PREV_TIME] - frameTime));

		rotate += (frames[frame + TRANSFORMCONSTRAINT_ROTATE] - rotate) * percent;
		translate += (frames[frame + TRANSFORMCONSTRAINT_TRANSLATE] - translate) * percent;
		scale += (frames[frame + TRANSFORMCONSTRAINT_SCALE] - scale) * percent;
		shear += (frames[frame + TRANSFORMCONSTRAINT_SHEAR] - shear) * percent;
	}
	if (blend == SP_MIX_BLEND_SETUP) {
		sp37TransformConstraintData* data = constraint->data;
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

int _sp37TransformConstraintTimeline_getPropertyId (const sp37Timeline* timeline) {
	return (SP_TIMELINE_TRANSFORMCONSTRAINT << 24) + SUB_CAST(sp37TransformConstraintTimeline, timeline)->transformConstraintIndex;
}

sp37TransformConstraintTimeline* sp37TransformConstraintTimeline_create (int framesCount) {
	return (sp37TransformConstraintTimeline*)_sp37BaseTimeline_create(framesCount, SP_TIMELINE_TRANSFORMCONSTRAINT, TRANSFORMCONSTRAINT_ENTRIES, _sp37TransformConstraintTimeline_apply, _sp37TransformConstraintTimeline_getPropertyId);
}

void sp37TransformConstraintTimeline_setFrame (sp37TransformConstraintTimeline* self, int frameIndex, float time, float rotateMix, float translateMix, float scaleMix, float shearMix) {
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

void _sp37PathConstraintPositionTimeline_apply(const sp37Timeline* timeline, sp37Skeleton* skeleton, float lastTime, float time,
		sp37Event** firedEvents, int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction) {
	int frame;
	float frameTime, percent, position;
	sp37PathConstraint* constraint;
	sp37PathConstraintPositionTimeline* self = (sp37PathConstraintPositionTimeline*)timeline;
	float* frames;
	int framesCount;

	constraint = skeleton->pathConstraints[self->pathConstraintIndex];
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
		percent = sp37CurveTimeline_getCurvePercent(SUPER(self), frame / PATHCONSTRAINTPOSITION_ENTRIES - 1,
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

int _sp37PathConstraintPositionTimeline_getPropertyId (const sp37Timeline* timeline) {
	return (SP_TIMELINE_PATHCONSTRAINTPOSITION << 24) + SUB_CAST(sp37PathConstraintPositionTimeline, timeline)->pathConstraintIndex;
}

sp37PathConstraintPositionTimeline* sp37PathConstraintPositionTimeline_create (int framesCount) {
	return (sp37PathConstraintPositionTimeline*)_sp37BaseTimeline_create(framesCount, SP_TIMELINE_PATHCONSTRAINTPOSITION, PATHCONSTRAINTPOSITION_ENTRIES, _sp37PathConstraintPositionTimeline_apply, _sp37PathConstraintPositionTimeline_getPropertyId);
}

void sp37PathConstraintPositionTimeline_setFrame (sp37PathConstraintPositionTimeline* self, int frameIndex, float time, float value) {
	frameIndex *= PATHCONSTRAINTPOSITION_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + PATHCONSTRAINTPOSITION_VALUE] = value;
}

/**/
static const int PATHCONSTRAINTSPACING_PREV_TIME = -2;
static const int PATHCONSTRAINTSPACING_PREV_VALUE = -1;
static const int PATHCONSTRAINTSPACING_VALUE = 1;

void _sp37PathConstraintSpacingTimeline_apply(const sp37Timeline* timeline, sp37Skeleton* skeleton, float lastTime, float time,
		sp37Event** firedEvents, int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction) {
	int frame;
	float frameTime, percent, spacing;
	sp37PathConstraint* constraint;
	sp37PathConstraintSpacingTimeline* self = (sp37PathConstraintSpacingTimeline*)timeline;
	float* frames;
	int framesCount;

	constraint = skeleton->pathConstraints[self->pathConstraintIndex];
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
		percent = sp37CurveTimeline_getCurvePercent(SUPER(self), frame / PATHCONSTRAINTSPACING_ENTRIES - 1,
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

int _sp37PathConstraintSpacingTimeline_getPropertyId (const sp37Timeline* timeline) {
	return (SP_TIMELINE_PATHCONSTRAINTSPACING << 24) + SUB_CAST(sp37PathConstraintSpacingTimeline, timeline)->pathConstraintIndex;
}

sp37PathConstraintSpacingTimeline* sp37PathConstraintSpacingTimeline_create (int framesCount) {
	return (sp37PathConstraintSpacingTimeline*)_sp37BaseTimeline_create(framesCount, SP_TIMELINE_PATHCONSTRAINTSPACING, PATHCONSTRAINTSPACING_ENTRIES, _sp37PathConstraintSpacingTimeline_apply, _sp37PathConstraintSpacingTimeline_getPropertyId);
}

void sp37PathConstraintSpacingTimeline_setFrame (sp37PathConstraintSpacingTimeline* self, int frameIndex, float time, float value) {
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

void _sp37PathConstraintMixTimeline_apply(const sp37Timeline* timeline, sp37Skeleton* skeleton, float lastTime, float time,
											sp37Event** firedEvents, int* eventsCount, float alpha, sp37MixBlend blend, sp37MixDirection direction) {
	int frame;
	float frameTime, percent, rotate, translate;
	sp37PathConstraint* constraint;
	sp37PathConstraintMixTimeline* self = (sp37PathConstraintMixTimeline*)timeline;
	float* frames;
	int framesCount;

	constraint = skeleton->pathConstraints[self->pathConstraintIndex];
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
		percent = sp37CurveTimeline_getCurvePercent(SUPER(self), frame / PATHCONSTRAINTMIX_ENTRIES - 1,
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

int _sp37PathConstraintMixTimeline_getPropertyId (const sp37Timeline* timeline) {
	return (SP_TIMELINE_PATHCONSTRAINTMIX << 24) + SUB_CAST(sp37PathConstraintMixTimeline, timeline)->pathConstraintIndex;
}

sp37PathConstraintMixTimeline* sp37PathConstraintMixTimeline_create (int framesCount) {
	return (sp37PathConstraintMixTimeline*)_sp37BaseTimeline_create(framesCount, SP_TIMELINE_PATHCONSTRAINTMIX, PATHCONSTRAINTMIX_ENTRIES, _sp37PathConstraintMixTimeline_apply, _sp37PathConstraintMixTimeline_getPropertyId);
}

void sp37PathConstraintMixTimeline_setFrame (sp37PathConstraintMixTimeline* self, int frameIndex, float time, float rotateMix, float translateMix) {
	frameIndex *= PATHCONSTRAINTMIX_ENTRIES;
	self->frames[frameIndex] = time;
	self->frames[frameIndex + PATHCONSTRAINTMIX_ROTATE] = rotateMix;
	self->frames[frameIndex + PATHCONSTRAINTMIX_TRANSLATE] = translateMix;
}

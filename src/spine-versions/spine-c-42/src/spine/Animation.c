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
#include <spine/Animation.h>
#include <spine/IkConstraint.h>
#include <spine/extension.h>

_SP_ARRAY_IMPLEMENT_TYPE(sp42PropertyIdArray, sp42PropertyId)

_SP_ARRAY_IMPLEMENT_TYPE(sp42TimelineArray, sp42Timeline *)

sp42Animation *sp42Animation_create(const char *name, sp42TimelineArray *timelines, float duration) {
	int i, n, totalCount = 0;
	sp42Animation *self = NEW(sp42Animation);
	MALLOC_STR(self->name, name);
	self->timelines = timelines != NULL ? timelines : sp42TimelineArray_create(1);
	timelines = self->timelines;

	for (i = 0, n = timelines->size; i < n; i++)
		totalCount += timelines->items[i]->propertyIdsCount;
	self->timelineIds = sp42PropertyIdArray_create(totalCount);

	for (i = 0, n = timelines->size; i < n; i++) {
		sp42PropertyIdArray_addAllValues(self->timelineIds, timelines->items[i]->propertyIds, 0,
									   timelines->items[i]->propertyIdsCount);
	}
	self->duration = duration;
	return self;
}

void sp42Animation_dispose(sp42Animation *self) {
	int i;
	for (i = 0; i < self->timelines->size; ++i)
		sp42Timeline_dispose(self->timelines->items[i]);
	sp42TimelineArray_dispose(self->timelines);
	sp42PropertyIdArray_dispose(self->timelineIds);
	FREE(self->name);
	FREE(self);
}

int /*bool*/ sp42Animation_hasTimeline(sp42Animation *self, sp42PropertyId *ids, int idsCount) {
	int i, n, ii;
	for (i = 0, n = self->timelineIds->size; i < n; i++) {
		for (ii = 0; ii < idsCount; ii++) {
			if (self->timelineIds->items[i] == ids[ii]) return 1;
		}
	}
	return 0;
}

void sp42Animation_apply(const sp42Animation *self, sp42Skeleton *skeleton, float lastTime, float time, int loop, sp42Event **events,
					   int *eventsCount, float alpha, sp42MixBlend blend, sp42MixDirection direction) {
	int i, n = self->timelines->size;

	if (loop && self->duration) {
		time = FMOD(time, self->duration);
		if (lastTime > 0) lastTime = FMOD(lastTime, self->duration);
	}

	for (i = 0; i < n; ++i)
		sp42Timeline_apply(self->timelines->items[i], skeleton, lastTime, time, events, eventsCount, alpha, blend,
						 direction);
}

static int search(sp42FloatArray
						  *values,
				  float time) {
	int i, n;
	float *items = values->items;
	for (
			i = 1, n = values->size;
			i < n;
			i++)
		if (items[i] > time) return i - 1;
	return values->size - 1;
}

static int search2(sp42FloatArray
						   *values,
				   float time,
				   int step) {
	int i, n;
	float *items = values->items;
	for (
			i = step, n = values->size;
			i < n;
			i += step)
		if (items[i] > time) return i -
									step;
	return values->size -
		   step;
}

/**/

void _sp42Timeline_init(sp42Timeline *self,
					  int frameCount,
					  int frameEntries,
					  sp42PropertyId *propertyIds,
					  int propertyIdsCount,
					  sp42TimelineType type,
					  void (*dispose)(sp42Timeline *self),
					  void (*apply)(sp42Timeline *self, sp42Skeleton *skeleton, float lastTime, float time,
									sp42Event **firedEvents,
									int *eventsCount, float alpha, sp42MixBlend blend, sp42MixDirection direction),
					  void (*setBezier)(sp42Timeline *self, int bezier, int frame, float value, float time1, float value1,
										float cx1, float cy1,
										float cx2, float cy2, float time2, float value2)) {
	int i;
	self->frames = sp42FloatArray_create(frameCount * frameEntries);
	self->frames->size = frameCount * frameEntries;
	self->frameCount = frameCount;
	self->frameEntries = frameEntries;

	for (i = 0; i < propertyIdsCount; i++)
		self->propertyIds[i] = propertyIds[i];
	self->propertyIdsCount = propertyIdsCount;

	self->type = type;

	self->vtable.dispose = dispose;
	self->vtable.apply = apply;
	self->vtable.setBezier = setBezier;
}

void sp42Timeline_dispose(sp42Timeline *self) {
	self->vtable.dispose(self);
	sp42FloatArray_dispose(self->frames);
	FREE(self);
}

void sp42Timeline_apply(sp42Timeline *self, sp42Skeleton *skeleton, float lastTime, float time, sp42Event **firedEvents,
					  int *eventsCount, float alpha, sp42MixBlend blend, sp42MixDirection direction) {
	self->vtable.apply(self, skeleton, lastTime, time, firedEvents, eventsCount, alpha, blend, direction);
}

void sp42Timeline_setBezier(sp42Timeline *self, int bezier, int frame, float value, float time1, float value1, float cx1,
						  float cy1, float cx2, float cy2, float time2, float value2) {
	if (self->vtable.setBezier)
		self->vtable.setBezier(self, bezier, frame, value, time1, value1, cx1, cy1, cx2, cy2, time2, value2);
}

float sp42Timeline_getDuration(const sp42Timeline *self) {
	return self->frames->items[self->frames->size - self->frameEntries];
}

/**/

#define CURVE_LINEAR 0
#define CURVE_STEPPED 1
#define CURVE_BEZIER 2
#define BEZIER_SIZE 18

void _sp42CurveTimeline_init(sp42CurveTimeline *self,
						   int frameCount,
						   int frameEntries,
						   int bezierCount,
						   sp42PropertyId *propertyIds,
						   int propertyIdsCount,
						   sp42TimelineType type,
						   void (*dispose)(sp42Timeline *self),
						   void (*apply)(sp42Timeline *self, sp42Skeleton *skeleton, float lastTime, float time,
										 sp42Event **firedEvents,
										 int *eventsCount, float alpha, sp42MixBlend blend, sp42MixDirection direction),
						   void (*setBezier)(sp42Timeline *self, int bezier, int frame, float value, float time1,
											 float value1, float cx1, float cy1,
											 float cx2, float cy2, float time2, float value2)) {
	_sp42Timeline_init(SUPER(self), frameCount, frameEntries, propertyIds, propertyIdsCount, type, dispose, apply,
					 setBezier);
	self->curves = sp42FloatArray_create(frameCount + bezierCount * BEZIER_SIZE);
	self->curves->size = frameCount + bezierCount * BEZIER_SIZE;
	self->curves->items[frameCount - 1] = CURVE_STEPPED;
}

void _sp42CurveTimeline_dispose(sp42Timeline *self) {
	sp42FloatArray_dispose(SUB_CAST(sp42CurveTimeline, self)->curves);
}

void _sp42CurveTimeline_setBezier(sp42Timeline *timeline, int bezier, int frame, float value, float time1, float value1,
								float cx1, float cy1, float cx2, float cy2, float time2, float value2) {
	sp42CurveTimeline *self = SUB_CAST(sp42CurveTimeline, timeline);
	float tmpx, tmpy, dddx, dddy, ddx, ddy, dx, dy, x, y;
	int i = self->super.frameCount + bezier * BEZIER_SIZE, n;
	float *curves = self->curves->items;
	if (value == 0) curves[frame] = CURVE_BEZIER + i;
	tmpx = (time1 - cx1 * 2 + cx2) * 0.03;
	tmpy = (value1 - cy1 * 2 + cy2) * 0.03;
	dddx = ((cx1 - cx2) * 3 - time1 + time2) * 0.006;
	dddy = ((cy1 - cy2) * 3 - value1 + value2) * 0.006;
	ddx = tmpx * 2 + dddx;
	ddy = tmpy * 2 + dddy;
	dx = (cx1 - time1) * 0.3 + tmpx + dddx * 0.16666667;
	dy = (cy1 - value1) * 0.3 + tmpy + dddy * 0.16666667;
	x = time1 + dx, y = value1 + dy;
	for (n = i + BEZIER_SIZE; i < n; i += 2) {
		curves[i] = x;
		curves[i + 1] = y;
		dx += ddx;
		dy += ddy;
		ddx += dddx;
		ddy += dddy;
		x += dx;
		y += dy;
	}
}

float _sp42CurveTimeline_getBezierValue(sp42CurveTimeline *self, float time, int frameIndex, int valueOffset, int i) {
	float *curves = self->curves->items;
	float *frames = SUPER(self)->frames->items;
	float x, y;
	int n;
	if (curves[i] > time) {
		x = frames[frameIndex];
		y = frames[frameIndex + valueOffset];
		return y + (time - x) / (curves[i] - x) * (curves[i + 1] - y);
	}
	n = i + BEZIER_SIZE;
	for (i += 2; i < n; i += 2) {
		if (curves[i] >= time) {
			x = curves[i - 2];
			y = curves[i - 1];
			return y + (time - x) / (curves[i] - x) * (curves[i + 1] - y);
		}
	}
	frameIndex += self->super.frameEntries;
	x = curves[n - 2];
	y = curves[n - 1];
	return y + (time - x) / (frames[frameIndex] - x) * (frames[frameIndex + valueOffset] - y);
}

void sp42CurveTimeline_setLinear(sp42CurveTimeline *self, int frame) {
	self->curves->items[frame] = CURVE_LINEAR;
}

void sp42CurveTimeline_setStepped(sp42CurveTimeline *self, int frame) {
	self->curves->items[frame] = CURVE_STEPPED;
}

#define CURVE1_ENTRIES 2
#define CURVE1_VALUE 1

void sp42CurveTimeline1_setFrame(sp42CurveTimeline1 *self, int frame, float time, float value) {
	float *frames = self->super.frames->items;
	frame <<= 1;
	frames[frame] = time;
	frames[frame + CURVE1_VALUE] = value;
}

float sp42CurveTimeline1_getCurveValue(sp42CurveTimeline1 *self, float time) {
	float *frames = self->super.frames->items;
	float *curves = self->curves->items;
	int i = self->super.frames->size - 2;
	int ii, curveType;
	for (ii = 2; ii <= i; ii += 2) {
		if (frames[ii] > time) {
			i = ii - 2;
			break;
		}
	}

	curveType = (int) curves[i >> 1];
	switch (curveType) {
		case CURVE_LINEAR: {
			float before = frames[i], value = frames[i + CURVE1_VALUE];
			return value + (time - before) / (frames[i + CURVE1_ENTRIES] - before) *
								   (frames[i + CURVE1_ENTRIES + CURVE1_VALUE] - value);
		}
		case CURVE_STEPPED:
			return frames[i + CURVE1_VALUE];
	}
	return _sp42CurveTimeline_getBezierValue(self, time, i, CURVE1_VALUE, curveType - CURVE_BEZIER);
}

float sp42CurveTimeline1_getRelativeValue(sp42CurveTimeline1 *self, float time, float alpha, sp42MixBlend blend, float current, float setup) {
	float *frames = self->super.frames->items;
	if (time < frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				return setup;
			case SP_MIX_BLEND_FIRST:
				return current + (setup - current) * alpha;
			default:
				return current;
		}
	}
	float value = sp42CurveTimeline1_getCurveValue(self, time);
	switch (blend) {
		case SP_MIX_BLEND_SETUP:
			return setup + value * alpha;
		case SP_MIX_BLEND_FIRST:
		case SP_MIX_BLEND_REPLACE:
			value += setup - current;
			break;
		case SP_MIX_BLEND_ADD:
			break;
	}
	return current + value * alpha;
}

float sp42CurveTimeline1_getAbsoluteValue(sp42CurveTimeline1 *self, float time, float alpha, sp42MixBlend blend, float current, float setup) {
	float *frames = self->super.frames->items;
	if (time < frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				return setup;
			case SP_MIX_BLEND_FIRST:
				return current + (setup - current) * alpha;
			default:
				return current;
		}
	}
	float value = sp42CurveTimeline1_getCurveValue(self, time);
	if (blend == SP_MIX_BLEND_SETUP) return setup + (value - setup) * alpha;
	return current + (value - current) * alpha;
}

float sp42CurveTimeline1_getAbsoluteValue2(sp42CurveTimeline1 *self, float time, float alpha, sp42MixBlend blend, float current, float setup, float value) {
	float *frames = self->super.frames->items;
	if (time < frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				return setup;
			case SP_MIX_BLEND_FIRST:
				return current + (setup - current) * alpha;
			default:
				return current;
		}
	}
	if (blend == SP_MIX_BLEND_SETUP) return setup + (value - setup) * alpha;
	return current + (value - current) * alpha;
}

float sp42CurveTimeline1_getScaleValue(sp42CurveTimeline1 *self, float time, float alpha, sp42MixBlend blend, sp42MixDirection direction, float current, float setup) {
	float *frames = self->super.frames->items;
	if (time < frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				return setup;
			case SP_MIX_BLEND_FIRST:
				return current + (setup - current) * alpha;
			default:
				return current;
		}
	}
	float value = sp42CurveTimeline1_getCurveValue(self, time) * setup;
	if (alpha == 1) {
		if (blend == SP_MIX_BLEND_ADD) return current + value - setup;
		return value;
	}
	// Mixing out uses sign of setup or current pose, else use sign of key.
	if (direction == SP_MIX_DIRECTION_OUT) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				return setup + (ABS(value) * SIGNUM(setup) - setup) * alpha;
			case SP_MIX_BLEND_FIRST:
			case SP_MIX_BLEND_REPLACE:
				return current + (ABS(value) * SIGNUM(current) - current) * alpha;
			default:
				break;
		}
	} else {
		float s;
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				s = ABS(setup) * SIGNUM(value);
				return s + (value - s) * alpha;
			case SP_MIX_BLEND_FIRST:
			case SP_MIX_BLEND_REPLACE:
				s = ABS(current) * SIGNUM(value);
				return s + (value - s) * alpha;
			default:
				break;
		}
	}
	return current + (value - setup) * alpha;
}

#define CURVE2_ENTRIES 3
#define CURVE2_VALUE1 1
#define CURVE2_VALUE2 2

SP_API void sp42CurveTimeline2_setFrame(sp42CurveTimeline1 *self, int frame, float time, float value1, float value2) {
	float *frames = self->super.frames->items;
	frame *= CURVE2_ENTRIES;
	frames[frame] = time;
	frames[frame + CURVE2_VALUE1] = value1;
	frames[frame + CURVE2_VALUE2] = value2;
}

/**/

void _sp42RotateTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time, sp42Event **firedEvents,
							 int *eventsCount, float alpha, sp42MixBlend blend, sp42MixDirection direction) {
	sp42RotateTimeline *self = SUB_CAST(sp42RotateTimeline, timeline);
	sp42Bone *bone = skeleton->bones[self->boneIndex];
	if (bone->active) bone->rotation = sp42CurveTimeline1_getRelativeValue(SUPER(self), time, alpha, blend, bone->rotation, bone->data->rotation);

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

sp42RotateTimeline *sp42RotateTimeline_create(int frameCount, int bezierCount, int boneIndex) {
	sp42RotateTimeline *timeline = NEW(sp42RotateTimeline);
	sp42PropertyId ids[1];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_ROTATE << 32) | boneIndex;
	_sp42CurveTimeline_init(SUPER(timeline), frameCount, CURVE1_ENTRIES, bezierCount, ids, 1, SP_TIMELINE_ROTATE,
						  _sp42CurveTimeline_dispose, _sp42RotateTimeline_apply, _sp42CurveTimeline_setBezier);
	timeline->boneIndex = boneIndex;
	return timeline;
}

void sp42RotateTimeline_setFrame(sp42RotateTimeline *self, int frame, float time, float degrees) {
	sp42CurveTimeline1_setFrame(SUPER(self), frame, time, degrees);
}

/**/

void _sp42TranslateTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
								sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
								sp42MixDirection direction) {
	sp42Bone *bone;
	float x, y, t;
	int i, curveType;

	sp42TranslateTimeline *self = SUB_CAST(sp42TranslateTimeline, timeline);
	float *frames = self->super.super.frames->items;
	float *curves = self->super.curves->items;

	bone = skeleton->bones[self->boneIndex];
	if (!bone->active) return;

	if (time < frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				bone->x = bone->data->x;
				bone->y = bone->data->y;
				return;
			case SP_MIX_BLEND_FIRST:
				bone->x += (bone->data->x - bone->x) * alpha;
				bone->y += (bone->data->y - bone->y) * alpha;
			default: {
			}
		}
		return;
	}

	i = search2(self->super.super.frames, time, CURVE2_ENTRIES);
	curveType = (int) curves[i / CURVE2_ENTRIES];
	switch (curveType) {
		case CURVE_LINEAR: {
			float before = frames[i];
			x = frames[i + CURVE2_VALUE1];
			y = frames[i + CURVE2_VALUE2];
			t = (time - before) / (frames[i + CURVE2_ENTRIES] - before);
			x += (frames[i + CURVE2_ENTRIES + CURVE2_VALUE1] - x) * t;
			y += (frames[i + CURVE2_ENTRIES + CURVE2_VALUE2] - y) * t;
			break;
		}
		case CURVE_STEPPED: {
			x = frames[i + CURVE2_VALUE1];
			y = frames[i + CURVE2_VALUE2];
			break;
		}
		default: {
			x = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, CURVE2_VALUE1, curveType - CURVE_BEZIER);
			y = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, CURVE2_VALUE2,
												curveType + BEZIER_SIZE - CURVE_BEZIER);
		}
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

sp42TranslateTimeline *sp42TranslateTimeline_create(int frameCount, int bezierCount, int boneIndex) {
	sp42TranslateTimeline *timeline = NEW(sp42TranslateTimeline);
	sp42PropertyId ids[2];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_X << 32) | boneIndex;
	ids[1] = ((sp42PropertyId) SP_PROPERTY_Y << 32) | boneIndex;
	_sp42CurveTimeline_init(SUPER(timeline), frameCount, CURVE2_ENTRIES, bezierCount, ids, 2, SP_TIMELINE_TRANSLATE,
						  _sp42CurveTimeline_dispose, _sp42TranslateTimeline_apply, _sp42CurveTimeline_setBezier);
	timeline->boneIndex = boneIndex;
	return timeline;
}

void sp42TranslateTimeline_setFrame(sp42TranslateTimeline *self, int frame, float time, float x, float y) {
	sp42CurveTimeline2_setFrame(SUPER(self), frame, time, x, y);
}

/**/

void _sp42TranslateXTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
								 sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
								 sp42MixDirection direction) {
	sp42Bone *bone;
	float x;

	sp42TranslateXTimeline *self = SUB_CAST(sp42TranslateXTimeline, timeline);
	float *frames = self->super.super.frames->items;

	bone = skeleton->bones[self->boneIndex];
	if (!bone->active) return;

	if (time < frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				bone->x = bone->data->x;
				return;
			case SP_MIX_BLEND_FIRST:
				bone->x += (bone->data->x - bone->x) * alpha;
			default: {
			}
		}
		return;
	}

	x = sp42CurveTimeline1_getCurveValue(SUPER(self), time);
	switch (blend) {
		case SP_MIX_BLEND_SETUP:
			bone->x = bone->data->x + x * alpha;
			break;
		case SP_MIX_BLEND_FIRST:
		case SP_MIX_BLEND_REPLACE:
			bone->x += (bone->data->x + x - bone->x) * alpha;
			break;
		case SP_MIX_BLEND_ADD:
			bone->x += x * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

sp42TranslateXTimeline *sp42TranslateXTimeline_create(int frameCount, int bezierCount, int boneIndex) {
	sp42TranslateXTimeline *timeline = NEW(sp42TranslateXTimeline);
	sp42PropertyId ids[1];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_X << 32) | boneIndex;
	_sp42CurveTimeline_init(SUPER(timeline), frameCount, CURVE1_ENTRIES, bezierCount, ids, 1, SP_TIMELINE_TRANSLATEX,
						  _sp42CurveTimeline_dispose, _sp42TranslateXTimeline_apply, _sp42CurveTimeline_setBezier);
	timeline->boneIndex = boneIndex;
	return timeline;
}

void sp42TranslateXTimeline_setFrame(sp42TranslateXTimeline *self, int frame, float time, float x) {
	sp42CurveTimeline1_setFrame(SUPER(self), frame, time, x);
}

/**/

void _sp42TranslateYTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
								 sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
								 sp42MixDirection direction) {
	sp42Bone *bone;
	float y;

	sp42TranslateYTimeline *self = SUB_CAST(sp42TranslateYTimeline, timeline);
	float *frames = self->super.super.frames->items;

	bone = skeleton->bones[self->boneIndex];
	if (!bone->active) return;

	if (time < frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				bone->y = bone->data->y;
				return;
			case SP_MIX_BLEND_FIRST:
				bone->y += (bone->data->y - bone->y) * alpha;
			default: {
			}
		}
		return;
	}

	y = sp42CurveTimeline1_getCurveValue(SUPER(self), time);
	switch (blend) {
		case SP_MIX_BLEND_SETUP:
			bone->y = bone->data->y + y * alpha;
			break;
		case SP_MIX_BLEND_FIRST:
		case SP_MIX_BLEND_REPLACE:
			bone->y += (bone->data->y + y - bone->y) * alpha;
			break;
		case SP_MIX_BLEND_ADD:
			bone->y += y * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

sp42TranslateYTimeline *sp42TranslateYTimeline_create(int frameCount, int bezierCount, int boneIndex) {
	sp42TranslateYTimeline *timeline = NEW(sp42TranslateYTimeline);
	sp42PropertyId ids[1];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_Y << 32) | boneIndex;
	_sp42CurveTimeline_init(SUPER(timeline), frameCount, CURVE1_ENTRIES, bezierCount, ids, 1, SP_TIMELINE_TRANSLATEY,
						  _sp42CurveTimeline_dispose, _sp42TranslateYTimeline_apply, _sp42CurveTimeline_setBezier);
	timeline->boneIndex = boneIndex;
	return timeline;
}

void sp42TranslateYTimeline_setFrame(sp42TranslateYTimeline *self, int frame, float time, float y) {
	sp42CurveTimeline1_setFrame(SUPER(self), frame, time, y);
}

/**/

void _sp42ScaleTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time, sp42Event **firedEvents,
							int *eventsCount, float alpha, sp42MixBlend blend, sp42MixDirection direction) {
	sp42Bone *bone;
	int i, curveType;
	float x, y, t;

	sp42ScaleTimeline *self = SUB_CAST(sp42ScaleTimeline, timeline);
	float *frames = self->super.super.frames->items;
	float *curves = self->super.curves->items;

	bone = skeleton->bones[self->boneIndex];
	if (!bone->active) return;
	if (time < frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				bone->scaleX = bone->data->scaleX;
				bone->scaleY = bone->data->scaleY;
				return;
			case SP_MIX_BLEND_FIRST:
				bone->scaleX += (bone->data->scaleX - bone->scaleX) * alpha;
				bone->scaleY += (bone->data->scaleY - bone->scaleY) * alpha;
			default: {
			}
		}
		return;
	}

	i = search2(self->super.super.frames, time, CURVE2_ENTRIES);
	curveType = (int) curves[i / CURVE2_ENTRIES];
	switch (curveType) {
		case CURVE_LINEAR: {
			float before = frames[i];
			x = frames[i + CURVE2_VALUE1];
			y = frames[i + CURVE2_VALUE2];
			t = (time - before) / (frames[i + CURVE2_ENTRIES] - before);
			x += (frames[i + CURVE2_ENTRIES + CURVE2_VALUE1] - x) * t;
			y += (frames[i + CURVE2_ENTRIES + CURVE2_VALUE2] - y) * t;
			break;
		}
		case CURVE_STEPPED: {
			x = frames[i + CURVE2_VALUE1];
			y = frames[i + CURVE2_VALUE2];
			break;
		}
		default: {
			x = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, CURVE2_VALUE1, curveType - CURVE_BEZIER);
			y = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, CURVE2_VALUE2,
												curveType + BEZIER_SIZE - CURVE_BEZIER);
		}
	}
	x *= bone->data->scaleX;
	y *= bone->data->scaleY;

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
					bone->scaleX += (x - bone->data->scaleX) * alpha;
					bone->scaleY += (y - bone->data->scaleY) * alpha;
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
					bone->scaleX += (x - bone->data->scaleX) * alpha;
					bone->scaleY += (y - bone->data->scaleY) * alpha;
			}
		}
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

sp42ScaleTimeline *sp42ScaleTimeline_create(int frameCount, int bezierCount, int boneIndex) {
	sp42ScaleTimeline *timeline = NEW(sp42ScaleTimeline);
	sp42PropertyId ids[2];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_SCALEX << 32) | boneIndex;
	ids[1] = ((sp42PropertyId) SP_PROPERTY_SCALEY << 32) | boneIndex;
	_sp42CurveTimeline_init(SUPER(timeline), frameCount, CURVE2_ENTRIES, bezierCount, ids, 2, SP_TIMELINE_SCALE,
						  _sp42CurveTimeline_dispose, _sp42ScaleTimeline_apply, _sp42CurveTimeline_setBezier);
	timeline->boneIndex = boneIndex;
	return timeline;
}

void sp42ScaleTimeline_setFrame(sp42ScaleTimeline *self, int frame, float time, float x, float y) {
	sp42CurveTimeline2_setFrame(SUPER(self), frame, time, x, y);
}

/**/

void _sp42ScaleXTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
							 sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
							 sp42MixDirection direction) {
	sp42ScaleXTimeline *self = SUB_CAST(sp42ScaleXTimeline, timeline);
	sp42Bone *bone = skeleton->bones[self->boneIndex];

	if (bone->active) bone->scaleX = sp42CurveTimeline1_getScaleValue(SUPER(self), time, alpha, blend, direction, bone->scaleX, bone->data->scaleX);

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

sp42ScaleXTimeline *sp42ScaleXTimeline_create(int frameCount, int bezierCount, int boneIndex) {
	sp42ScaleXTimeline *timeline = NEW(sp42ScaleXTimeline);
	sp42PropertyId ids[1];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_SCALEX << 32) | boneIndex;
	_sp42CurveTimeline_init(SUPER(timeline), frameCount, CURVE1_ENTRIES, bezierCount, ids, 1, SP_TIMELINE_SCALEX,
						  _sp42CurveTimeline_dispose, _sp42ScaleXTimeline_apply, _sp42CurveTimeline_setBezier);
	timeline->boneIndex = boneIndex;
	return timeline;
}

void sp42ScaleXTimeline_setFrame(sp42ScaleXTimeline *self, int frame, float time, float y) {
	sp42CurveTimeline1_setFrame(SUPER(self), frame, time, y);
}

/**/

void _sp42ScaleYTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
							 sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
							 sp42MixDirection direction) {
	sp42ScaleYTimeline *self = SUB_CAST(sp42ScaleYTimeline, timeline);
	sp42Bone *bone = skeleton->bones[self->boneIndex];

	if (bone->active) bone->scaleY = sp42CurveTimeline1_getScaleValue(SUPER(self), time, alpha, blend, direction, bone->scaleX, bone->data->scaleY);

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

sp42ScaleYTimeline *sp42ScaleYTimeline_create(int frameCount, int bezierCount, int boneIndex) {
	sp42ScaleYTimeline *timeline = NEW(sp42ScaleYTimeline);
	sp42PropertyId ids[1];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_SCALEY << 32) | boneIndex;
	_sp42CurveTimeline_init(SUPER(timeline), frameCount, CURVE1_ENTRIES, bezierCount, ids, 1, SP_TIMELINE_SCALEY,
						  _sp42CurveTimeline_dispose, _sp42ScaleYTimeline_apply, _sp42CurveTimeline_setBezier);
	timeline->boneIndex = boneIndex;
	return timeline;
}

void sp42ScaleYTimeline_setFrame(sp42ScaleYTimeline *self, int frame, float time, float y) {
	sp42CurveTimeline1_setFrame(SUPER(self), frame, time, y);
}

/**/

void _sp42ShearTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time, sp42Event **firedEvents,
							int *eventsCount, float alpha, sp42MixBlend blend, sp42MixDirection direction) {
	sp42Bone *bone;
	float x, y, t;
	int i, curveType;

	sp42ShearTimeline *self = SUB_CAST(sp42ShearTimeline, timeline);
	float *frames = SUPER(self)->super.frames->items;
	float *curves = SUPER(self)->curves->items;

	bone = skeleton->bones[self->boneIndex];
	if (!bone->active) return;
	if (time < frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				bone->shearX = bone->data->shearX;
				bone->shearY = bone->data->shearY;
				return;
			case SP_MIX_BLEND_FIRST:
				bone->shearX += (bone->data->shearX - bone->shearX) * alpha;
				bone->shearY += (bone->data->shearY - bone->shearY) * alpha;
			default: {
			}
		}
		return;
	}

	i = search2(self->super.super.frames, time, CURVE2_ENTRIES);
	curveType = (int) curves[i / CURVE2_ENTRIES];
	switch (curveType) {
		case CURVE_LINEAR: {
			float before = frames[i];
			x = frames[i + CURVE2_VALUE1];
			y = frames[i + CURVE2_VALUE2];
			t = (time - before) / (frames[i + CURVE2_ENTRIES] - before);
			x += (frames[i + CURVE2_ENTRIES + CURVE2_VALUE1] - x) * t;
			y += (frames[i + CURVE2_ENTRIES + CURVE2_VALUE2] - y) * t;
			break;
		}
		case CURVE_STEPPED: {
			x = frames[i + CURVE2_VALUE1];
			y = frames[i + CURVE2_VALUE2];
			break;
		}
		default: {
			x = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, CURVE2_VALUE1, curveType - CURVE_BEZIER);
			y = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, CURVE2_VALUE2,
												curveType + BEZIER_SIZE - CURVE_BEZIER);
		}
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

sp42ShearTimeline *sp42ShearTimeline_create(int frameCount, int bezierCount, int boneIndex) {
	sp42ShearTimeline *timeline = NEW(sp42ShearTimeline);
	sp42PropertyId ids[2];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_SHEARX << 32) | boneIndex;
	ids[1] = ((sp42PropertyId) SP_PROPERTY_SHEARY << 32) | boneIndex;
	_sp42CurveTimeline_init(SUPER(timeline), frameCount, CURVE2_ENTRIES, bezierCount, ids, 2, SP_TIMELINE_SHEAR,
						  _sp42CurveTimeline_dispose, _sp42ShearTimeline_apply, _sp42CurveTimeline_setBezier);
	timeline->boneIndex = boneIndex;
	return timeline;
}

void sp42ShearTimeline_setFrame(sp42ShearTimeline *self, int frame, float time, float x, float y) {
	sp42CurveTimeline2_setFrame(SUPER(self), frame, time, x, y);
}

/**/

void _sp42ShearXTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
							 sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
							 sp42MixDirection direction) {
	sp42ShearXTimeline *self = SUB_CAST(sp42ShearXTimeline, timeline);
	sp42Bone *bone = skeleton->bones[self->boneIndex];

	if (bone->active) bone->shearX = sp42CurveTimeline1_getRelativeValue(SUPER(self), time, alpha, blend, bone->shearX, bone->data->shearX);

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

sp42ShearXTimeline *sp42ShearXTimeline_create(int frameCount, int bezierCount, int boneIndex) {
	sp42ShearXTimeline *timeline = NEW(sp42ShearXTimeline);
	sp42PropertyId ids[1];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_SHEARX << 32) | boneIndex;
	_sp42CurveTimeline_init(SUPER(timeline), frameCount, CURVE1_ENTRIES, bezierCount, ids, 1, SP_TIMELINE_SHEARX,
						  _sp42CurveTimeline_dispose, _sp42ShearXTimeline_apply, _sp42CurveTimeline_setBezier);
	timeline->boneIndex = boneIndex;
	return timeline;
}

void sp42ShearXTimeline_setFrame(sp42ShearXTimeline *self, int frame, float time, float x) {
	sp42CurveTimeline1_setFrame(SUPER(self), frame, time, x);
}

/**/

void _sp42ShearYTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
							 sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
							 sp42MixDirection direction) {
	sp42ShearYTimeline *self = SUB_CAST(sp42ShearYTimeline, timeline);
	sp42Bone *bone = skeleton->bones[self->boneIndex];

	if (bone->active) bone->shearY = sp42CurveTimeline1_getRelativeValue(SUPER(self), time, alpha, blend, bone->shearY, bone->data->shearY);

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

sp42ShearYTimeline *sp42ShearYTimeline_create(int frameCount, int bezierCount, int boneIndex) {
	sp42ShearYTimeline *timeline = NEW(sp42ShearYTimeline);
	sp42PropertyId ids[1];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_SHEARY << 32) | boneIndex;
	_sp42CurveTimeline_init(SUPER(timeline), frameCount, CURVE1_ENTRIES, bezierCount, ids, 1, SP_TIMELINE_SHEARY,
						  _sp42CurveTimeline_dispose, _sp42ShearYTimeline_apply, _sp42CurveTimeline_setBezier);
	timeline->boneIndex = boneIndex;
	return timeline;
}

void sp42ShearYTimeline_setFrame(sp42ShearYTimeline *self, int frame, float time, float y) {
	sp42CurveTimeline1_setFrame(SUPER(self), frame, time, y);
}

/**/

static const int RGBA_ENTRIES = 5, COLOR_R = 1, COLOR_G = 2, COLOR_B = 3, COLOR_A = 4;

void _sp42RGBATimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time, sp42Event **firedEvents,
						   int *eventsCount, float alpha, sp42MixBlend blend, sp42MixDirection direction) {
	sp42Slot *slot;
	int i, curveType;
	float r, g, b, a, t;
	sp42Color *color;
	sp42Color *setup;
	sp42RGBATimeline *self = (sp42RGBATimeline *) timeline;
	float *frames = self->super.super.frames->items;
	float *curves = self->super.curves->items;

	slot = skeleton->slots[self->slotIndex];
	if (!slot->bone->active) return;

	if (time < frames[0]) {
		color = &slot->color;
		setup = &slot->data->color;
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				sp42Color_setFromColor(color, setup);
				return;
			case SP_MIX_BLEND_FIRST:
				sp42Color_addFloats(color, (setup->r - color->r) * alpha, (setup->g - color->g) * alpha,
								  (setup->b - color->b) * alpha,
								  (setup->a - color->a) * alpha);
			default: {
			}
		}
		return;
	}

	i = search2(self->super.super.frames, time, RGBA_ENTRIES);
	curveType = (int) curves[i / RGBA_ENTRIES];
	switch (curveType) {
		case CURVE_LINEAR: {
			float before = frames[i];
			r = frames[i + COLOR_R];
			g = frames[i + COLOR_G];
			b = frames[i + COLOR_B];
			a = frames[i + COLOR_A];
			t = (time - before) / (frames[i + RGBA_ENTRIES] - before);
			r += (frames[i + RGBA_ENTRIES + COLOR_R] - r) * t;
			g += (frames[i + RGBA_ENTRIES + COLOR_G] - g) * t;
			b += (frames[i + RGBA_ENTRIES + COLOR_B] - b) * t;
			a += (frames[i + RGBA_ENTRIES + COLOR_A] - a) * t;
			break;
		}
		case CURVE_STEPPED: {
			r = frames[i + COLOR_R];
			g = frames[i + COLOR_G];
			b = frames[i + COLOR_B];
			a = frames[i + COLOR_A];
			break;
		}
		default: {
			r = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR_R, curveType - CURVE_BEZIER);
			g = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR_G,
												curveType + BEZIER_SIZE - CURVE_BEZIER);
			b = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR_B,
												curveType + BEZIER_SIZE * 2 - CURVE_BEZIER);
			a = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR_A,
												curveType + BEZIER_SIZE * 3 - CURVE_BEZIER);
		}
	}
	color = &slot->color;
	if (alpha == 1)
		sp42Color_setFromFloats(color, r, g, b, a);
	else {
		if (blend == SP_MIX_BLEND_SETUP) sp42Color_setFromColor(color, &slot->data->color);
		sp42Color_addFloats(color, (r - color->r) * alpha, (g - color->g) * alpha, (b - color->b) * alpha,
						  (a - color->a) * alpha);
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

sp42RGBATimeline *sp42RGBATimeline_create(int framesCount, int bezierCount, int slotIndex) {
	sp42RGBATimeline *timeline = NEW(sp42RGBATimeline);
	sp42PropertyId ids[2];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_RGB << 32) | slotIndex;
	ids[1] = ((sp42PropertyId) SP_PROPERTY_ALPHA << 32) | slotIndex;
	_sp42CurveTimeline_init(SUPER(timeline), framesCount, RGBA_ENTRIES, bezierCount, ids, 2, SP_TIMELINE_RGBA,
						  _sp42CurveTimeline_dispose, _sp42RGBATimeline_apply, _sp42CurveTimeline_setBezier);
	timeline->slotIndex = slotIndex;
	return timeline;
}

void sp42RGBATimeline_setFrame(sp42RGBATimeline *self, int frame, float time, float r, float g, float b, float a) {
	float *frames = self->super.super.frames->items;
	frame *= RGBA_ENTRIES;
	frames[frame] = time;
	frames[frame + COLOR_R] = r;
	frames[frame + COLOR_G] = g;
	frames[frame + COLOR_B] = b;
	frames[frame + COLOR_A] = a;
}

/**/

#define RGB_ENTRIES 4

void _sp42RGBTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time, sp42Event **firedEvents,
						  int *eventsCount, float alpha, sp42MixBlend blend, sp42MixDirection direction) {
	sp42Slot *slot;
	int i, curveType;
	float r, g, b, t;
	sp42Color *color;
	sp42Color *setup;
	sp42RGBTimeline *self = (sp42RGBTimeline *) timeline;
	float *frames = self->super.super.frames->items;
	float *curves = self->super.curves->items;

	slot = skeleton->slots[self->slotIndex];
	if (!slot->bone->active) return;

	if (time < frames[0]) {
		color = &slot->color;
		setup = &slot->data->color;
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				sp42Color_setFromColor(color, setup);
				return;
			case SP_MIX_BLEND_FIRST:
				sp42Color_addFloats(color, (setup->r - color->r) * alpha, (setup->g - color->g) * alpha,
								  (setup->b - color->b) * alpha,
								  (setup->a - color->a) * alpha);
			default: {
			}
		}
		return;
	}

	i = search2(self->super.super.frames, time, RGB_ENTRIES);
	curveType = (int) curves[i / RGB_ENTRIES];
	switch (curveType) {
		case CURVE_LINEAR: {
			float before = frames[i];
			r = frames[i + COLOR_R];
			g = frames[i + COLOR_G];
			b = frames[i + COLOR_B];
			t = (time - before) / (frames[i + RGB_ENTRIES] - before);
			r += (frames[i + RGB_ENTRIES + COLOR_R] - r) * t;
			g += (frames[i + RGB_ENTRIES + COLOR_G] - g) * t;
			b += (frames[i + RGB_ENTRIES + COLOR_B] - b) * t;
			break;
		}
		case CURVE_STEPPED: {
			r = frames[i + COLOR_R];
			g = frames[i + COLOR_G];
			b = frames[i + COLOR_B];
			break;
		}
		default: {
			r = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR_R, curveType - CURVE_BEZIER);
			g = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR_G,
												curveType + BEZIER_SIZE - CURVE_BEZIER);
			b = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR_B,
												curveType + BEZIER_SIZE * 2 - CURVE_BEZIER);
		}
	}
	color = &slot->color;
	if (alpha == 1) {
		color->r = r;
		color->g = g;
		color->b = b;
	} else {
		if (blend == SP_MIX_BLEND_SETUP) {
			color->r = slot->data->color.r;
			color->g = slot->data->color.g;
			color->b = slot->data->color.b;
		}
		color->r += (r - color->r) * alpha;
		color->g += (g - color->g) * alpha;
		color->b += (b - color->b) * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

sp42RGBTimeline *sp42RGBTimeline_create(int framesCount, int bezierCount, int slotIndex) {
	sp42RGBTimeline *timeline = NEW(sp42RGBTimeline);
	sp42PropertyId ids[1];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_RGB << 32) | slotIndex;
	_sp42CurveTimeline_init(SUPER(timeline), framesCount, RGB_ENTRIES, bezierCount, ids, 1, SP_TIMELINE_RGB,
						  _sp42CurveTimeline_dispose, _sp42RGBTimeline_apply, _sp42CurveTimeline_setBezier);
	timeline->slotIndex = slotIndex;
	return timeline;
}

void sp42RGBTimeline_setFrame(sp42RGBTimeline *self, int frame, float time, float r, float g, float b) {
	float *frames = self->super.super.frames->items;
	frame *= RGB_ENTRIES;
	frames[frame] = time;
	frames[frame + COLOR_R] = r;
	frames[frame + COLOR_G] = g;
	frames[frame + COLOR_B] = b;
}

/**/

void _sp42AlphaTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
							sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
							sp42MixDirection direction) {
	sp42Slot *slot;
	float a;
	sp42Color *color;
	sp42Color *setup;
	sp42AlphaTimeline *self = (sp42AlphaTimeline *) timeline;
	float *frames = self->super.super.frames->items;

	slot = skeleton->slots[self->slotIndex];
	if (!slot->bone->active) return;

	if (time < frames[0]) { /* Time is before first frame-> */
		color = &slot->color;
		setup = &slot->data->color;
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				color->a = setup->a;
				return;
			case SP_MIX_BLEND_FIRST:
				color->a += (setup->a - color->a) * alpha;
			default: {
			}
		}
		return;
	}

	a = sp42CurveTimeline1_getCurveValue(SUPER(self), time);
	if (alpha == 1)
		slot->color.a = a;
	else {
		if (blend == SP_MIX_BLEND_SETUP) slot->color.a = slot->data->color.a;
		slot->color.a += (a - slot->color.a) * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

sp42AlphaTimeline *sp42AlphaTimeline_create(int frameCount, int bezierCount, int slotIndex) {
	sp42AlphaTimeline *timeline = NEW(sp42AlphaTimeline);
	sp42PropertyId ids[1];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_ALPHA << 32) | slotIndex;
	_sp42CurveTimeline_init(SUPER(timeline), frameCount, CURVE1_ENTRIES, bezierCount, ids, 1, SP_TIMELINE_ALPHA,
						  _sp42CurveTimeline_dispose, _sp42AlphaTimeline_apply, _sp42CurveTimeline_setBezier);
	timeline->slotIndex = slotIndex;
	return timeline;
}

void sp42AlphaTimeline_setFrame(sp42AlphaTimeline *self, int frame, float time, float alpha) {
	sp42CurveTimeline1_setFrame(SUPER(self), frame, time, alpha);
}

/**/

static const int RGBA2_ENTRIES = 8, COLOR_R2 = 5, COLOR_G2 = 6, COLOR_B2 = 7;

void _sp42RGBA2Timeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time, sp42Event **firedEvents,
							int *eventsCount, float alpha, sp42MixBlend blend, sp42MixDirection direction) {
	sp42Slot *slot;
	int i, curveType;
	float r, g, b, a, r2, g2, b2, t;
	sp42Color *light, *setupLight;
	sp42Color *dark, *setupDark;
	sp42RGBA2Timeline *self = (sp42RGBA2Timeline *) timeline;
	float *frames = self->super.super.frames->items;
	float *curves = self->super.curves->items;

	slot = skeleton->slots[self->slotIndex];
	if (!slot->bone->active) return;

	if (time < frames[0]) {
		light = &slot->color;
		dark = slot->darkColor;
		setupLight = &slot->data->color;
		setupDark = slot->data->darkColor;
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				sp42Color_setFromColor(light, setupLight);
				sp42Color_setFromFloats3(dark, setupDark->r, setupDark->g, setupDark->b);
				return;
			case SP_MIX_BLEND_FIRST:
				sp42Color_addFloats(light, (setupLight->r - light->r) * alpha, (setupLight->g - light->g) * alpha,
								  (setupLight->b - light->b) * alpha,
								  (setupLight->a - light->a) * alpha);
				dark->r += (setupDark->r - dark->r) * alpha;
				dark->g += (setupDark->g - dark->g) * alpha;
				dark->b += (setupDark->b - dark->b) * alpha;
			default: {
			}
		}
		return;
	}

	r = 0, g = 0, b = 0, a = 0, r2 = 0, g2 = 0, b2 = 0;
	i = search2(self->super.super.frames, time, RGBA2_ENTRIES);
	curveType = (int) curves[i / RGBA2_ENTRIES];
	switch (curveType) {
		case CURVE_LINEAR: {
			float before = frames[i];
			r = frames[i + COLOR_R];
			g = frames[i + COLOR_G];
			b = frames[i + COLOR_B];
			a = frames[i + COLOR_A];
			r2 = frames[i + COLOR_R2];
			g2 = frames[i + COLOR_G2];
			b2 = frames[i + COLOR_B2];
			t = (time - before) / (frames[i + RGBA2_ENTRIES] - before);
			r += (frames[i + RGBA2_ENTRIES + COLOR_R] - r) * t;
			g += (frames[i + RGBA2_ENTRIES + COLOR_G] - g) * t;
			b += (frames[i + RGBA2_ENTRIES + COLOR_B] - b) * t;
			a += (frames[i + RGBA2_ENTRIES + COLOR_A] - a) * t;
			r2 += (frames[i + RGBA2_ENTRIES + COLOR_R2] - r2) * t;
			g2 += (frames[i + RGBA2_ENTRIES + COLOR_G2] - g2) * t;
			b2 += (frames[i + RGBA2_ENTRIES + COLOR_B2] - b2) * t;
			break;
		}
		case CURVE_STEPPED: {
			r = frames[i + COLOR_R];
			g = frames[i + COLOR_G];
			b = frames[i + COLOR_B];
			a = frames[i + COLOR_A];
			r2 = frames[i + COLOR_R2];
			g2 = frames[i + COLOR_G2];
			b2 = frames[i + COLOR_B2];
			break;
		}
		default: {
			r = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR_R, curveType - CURVE_BEZIER);
			g = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR_G,
												curveType + BEZIER_SIZE - CURVE_BEZIER);
			b = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR_B,
												curveType + BEZIER_SIZE * 2 - CURVE_BEZIER);
			a = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR_A,
												curveType + BEZIER_SIZE * 3 - CURVE_BEZIER);
			r2 = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR_R2,
												 curveType + BEZIER_SIZE * 4 - CURVE_BEZIER);
			g2 = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR_G2,
												 curveType + BEZIER_SIZE * 5 - CURVE_BEZIER);
			b2 = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR_B2,
												 curveType + BEZIER_SIZE * 6 - CURVE_BEZIER);
		}
	}

	light = &slot->color, dark = slot->darkColor;
	if (alpha == 1) {
		sp42Color_setFromFloats(light, r, g, b, a);
		sp42Color_setFromFloats3(dark, r2, g2, b2);
	} else {
		if (blend == SP_MIX_BLEND_SETUP) {
			sp42Color_setFromColor(light, &slot->data->color);
			sp42Color_setFromColor(dark, slot->data->darkColor);
		}
		sp42Color_addFloats(light, (r - light->r) * alpha, (g - light->g) * alpha, (b - light->b) * alpha,
						  (a - light->a) * alpha);
		dark->r += (r2 - dark->r) * alpha;
		dark->g += (g2 - dark->g) * alpha;
		dark->b += (b2 - dark->b) * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

sp42RGBA2Timeline *sp42RGBA2Timeline_create(int framesCount, int bezierCount, int slotIndex) {
	sp42RGBA2Timeline *timeline = NEW(sp42RGBA2Timeline);
	sp42PropertyId ids[3];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_RGB << 32) | slotIndex;
	ids[1] = ((sp42PropertyId) SP_PROPERTY_ALPHA << 32) | slotIndex;
	ids[2] = ((sp42PropertyId) SP_PROPERTY_RGB2 << 32) | slotIndex;
	_sp42CurveTimeline_init(SUPER(timeline), framesCount, RGBA2_ENTRIES, bezierCount, ids, 3, SP_TIMELINE_RGBA2,
						  _sp42CurveTimeline_dispose, _sp42RGBA2Timeline_apply, _sp42CurveTimeline_setBezier);
	timeline->slotIndex = slotIndex;
	return timeline;
}

void sp42RGBA2Timeline_setFrame(sp42RGBA2Timeline *self, int frame, float time, float r, float g, float b, float a, float r2,
							  float g2, float b2) {
	float *frames = self->super.super.frames->items;
	frame *= RGBA2_ENTRIES;
	frames[frame] = time;
	frames[frame + COLOR_R] = r;
	frames[frame + COLOR_G] = g;
	frames[frame + COLOR_B] = b;
	frames[frame + COLOR_A] = a;
	frames[frame + COLOR_R2] = r2;
	frames[frame + COLOR_G2] = g2;
	frames[frame + COLOR_B2] = b2;
}

/**/

static const int RGB2_ENTRIES = 7, COLOR2_R2 = 5, COLOR2_G2 = 6, COLOR2_B2 = 7;

void _sp42RGB2Timeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time, sp42Event **firedEvents,
						   int *eventsCount, float alpha, sp42MixBlend blend, sp42MixDirection direction) {
	sp42Slot *slot;
	int i, curveType;
	float r, g, b, r2, g2, b2, t;
	sp42Color *light, *setupLight;
	sp42Color *dark, *setupDark;
	sp42RGB2Timeline *self = (sp42RGB2Timeline *) timeline;
	float *frames = self->super.super.frames->items;
	float *curves = self->super.curves->items;

	slot = skeleton->slots[self->slotIndex];
	if (!slot->bone->active) return;

	if (time < frames[0]) {
		light = &slot->color;
		dark = slot->darkColor;
		setupLight = &slot->data->color;
		setupDark = slot->data->darkColor;
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				sp42Color_setFromColor3(light, setupLight);
				sp42Color_setFromColor3(dark, setupDark);
				return;
			case SP_MIX_BLEND_FIRST:
				sp42Color_addFloats3(light, (setupLight->r - light->r) * alpha, (setupLight->g - light->g) * alpha,
								   (setupLight->b - light->b) * alpha);
				dark->r += (setupDark->r - dark->r) * alpha;
				dark->g += (setupDark->g - dark->g) * alpha;
				dark->b += (setupDark->b - dark->b) * alpha;
			default: {
			}
		}
		return;
	}

	r = 0, g = 0, b = 0, r2 = 0, g2 = 0, b2 = 0;
	i = search2(self->super.super.frames, time, RGB2_ENTRIES);
	curveType = (int) curves[i / RGB2_ENTRIES];
	switch (curveType) {
		case CURVE_LINEAR: {
			float before = frames[i];
			r = frames[i + COLOR_R];
			g = frames[i + COLOR_G];
			b = frames[i + COLOR_B];
			r2 = frames[i + COLOR2_R2];
			g2 = frames[i + COLOR2_G2];
			b2 = frames[i + COLOR2_B2];
			t = (time - before) / (frames[i + RGB2_ENTRIES] - before);
			r += (frames[i + RGB2_ENTRIES + COLOR_R] - r) * t;
			g += (frames[i + RGB2_ENTRIES + COLOR_G] - g) * t;
			b += (frames[i + RGB2_ENTRIES + COLOR_B] - b) * t;
			r2 += (frames[i + RGB2_ENTRIES + COLOR2_R2] - r2) * t;
			g2 += (frames[i + RGB2_ENTRIES + COLOR2_G2] - g2) * t;
			b2 += (frames[i + RGB2_ENTRIES + COLOR2_B2] - b2) * t;
			break;
		}
		case CURVE_STEPPED: {
			r = frames[i + COLOR_R];
			g = frames[i + COLOR_G];
			b = frames[i + COLOR_B];
			r2 = frames[i + COLOR2_R2];
			g2 = frames[i + COLOR2_G2];
			b2 = frames[i + COLOR2_B2];
			break;
		}
		default: {
			r = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR_R, curveType - CURVE_BEZIER);
			g = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR_G,
												curveType + BEZIER_SIZE - CURVE_BEZIER);
			b = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR_B,
												curveType + BEZIER_SIZE * 2 - CURVE_BEZIER);
			r2 = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR2_R2,
												 curveType + BEZIER_SIZE * 3 - CURVE_BEZIER);
			g2 = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR2_G2,
												 curveType + BEZIER_SIZE * 4 - CURVE_BEZIER);
			b2 = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, COLOR2_B2,
												 curveType + BEZIER_SIZE * 5 - CURVE_BEZIER);
		}
	}

	light = &slot->color, dark = slot->darkColor;
	if (alpha == 1) {
		sp42Color_setFromFloats3(light, r, g, b);
		sp42Color_setFromFloats3(dark, r2, g2, b2);
	} else {
		if (blend == SP_MIX_BLEND_SETUP) {
			sp42Color_setFromColor3(light, &slot->data->color);

			sp42Color_setFromColor3(dark, slot->data->darkColor);
		}
		sp42Color_addFloats3(light, (r - light->r) * alpha, (g - light->g) * alpha, (b - light->b) * alpha);
		dark->r += (r2 - dark->r) * alpha;
		dark->g += (g2 - dark->g) * alpha;
		dark->b += (b2 - dark->b) * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

sp42RGB2Timeline *sp42RGB2Timeline_create(int framesCount, int bezierCount, int slotIndex) {
	sp42RGB2Timeline *timeline = NEW(sp42RGB2Timeline);
	sp42PropertyId ids[2];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_RGB << 32) | slotIndex;
	ids[1] = ((sp42PropertyId) SP_PROPERTY_RGB2 << 32) | slotIndex;
	_sp42CurveTimeline_init(SUPER(timeline), framesCount, RGB2_ENTRIES, bezierCount, ids, 2, SP_TIMELINE_RGB2,
						  _sp42CurveTimeline_dispose, _sp42RGB2Timeline_apply, _sp42CurveTimeline_setBezier);
	timeline->slotIndex = slotIndex;
	return timeline;
}

void sp42RGB2Timeline_setFrame(sp42RGB2Timeline *self, int frame, float time, float r, float g, float b, float r2, float g2,
							 float b2) {
	float *frames = self->super.super.frames->items;
	frame *= RGB2_ENTRIES;
	frames[frame] = time;
	frames[frame + COLOR_R] = r;
	frames[frame + COLOR_G] = g;
	frames[frame + COLOR_B] = b;
	frames[frame + COLOR2_R2] = r2;
	frames[frame + COLOR2_G2] = g2;
	frames[frame + COLOR2_B2] = b2;
}

/**/

static void
_sp42SetAttachment(sp42AttachmentTimeline *timeline, sp42Skeleton *skeleton, sp42Slot *slot, const char *attachmentName) {
	sp42Slot_setAttachment(slot, attachmentName == NULL ? NULL : sp42Skeleton_getAttachmentForSlotIndex(skeleton, timeline->slotIndex, attachmentName));
}

void _sp42AttachmentTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
								 sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
								 sp42MixDirection direction) {
	const char *attachmentName;
	sp42AttachmentTimeline *self = (sp42AttachmentTimeline *) timeline;
	float *frames = self->super.frames->items;
	sp42Slot *slot = skeleton->slots[self->slotIndex];
	if (!slot->bone->active) return;

	if (direction == SP_MIX_DIRECTION_OUT) {
		if (blend == SP_MIX_BLEND_SETUP) {
			_sp42SetAttachment(self, skeleton, slot, slot->data->attachmentName);
		}
		return;
	}

	if (time < frames[0]) {
		if (blend == SP_MIX_BLEND_SETUP || blend == SP_MIX_BLEND_FIRST) {
			_sp42SetAttachment(self, skeleton, slot, slot->data->attachmentName);
		}
		return;
	}

	if (time < frames[0]) {
		if (blend == SP_MIX_BLEND_SETUP || blend == SP_MIX_BLEND_FIRST)
			_sp42SetAttachment(self, skeleton, slot, slot->data->attachmentName);
		return;
	}

	attachmentName = self->attachmentNames[search(self->super.frames, time)];
	_sp42SetAttachment(self, skeleton, slot, attachmentName);

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(alpha);
}

void _sp42AttachmentTimeline_dispose(sp42Timeline *timeline) {
	sp42AttachmentTimeline *self = SUB_CAST(sp42AttachmentTimeline, timeline);
	int i;
	for (i = 0; i < self->super.frames->size; ++i)
		FREE(self->attachmentNames[i]);
	FREE(self->attachmentNames);
}

sp42AttachmentTimeline *sp42AttachmentTimeline_create(int framesCount, int slotIndex) {
	sp42AttachmentTimeline *self = NEW(sp42AttachmentTimeline);
	sp42PropertyId ids[1];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_ATTACHMENT << 32) | slotIndex;
	_sp42Timeline_init(SUPER(self), framesCount, 1, ids, 1, SP_TIMELINE_ATTACHMENT, _sp42AttachmentTimeline_dispose,
					 _sp42AttachmentTimeline_apply, 0);
	self->attachmentNames = CALLOC(char *, framesCount);
	self->slotIndex = slotIndex;
	return self;
}

void sp42AttachmentTimeline_setFrame(sp42AttachmentTimeline *self, int frame, float time, const char *attachmentName) {
	self->super.frames->items[frame] = time;

	FREE(self->attachmentNames[frame]);
	if (attachmentName)
		MALLOC_STR(self->attachmentNames[frame], attachmentName);
	else
		self->attachmentNames[frame] = 0;
}

/**/

void _sp42DeformTimeline_setBezier(sp42Timeline *timeline, int bezier, int frame, float value, float time1, float value1,
								 float cx1, float cy1,
								 float cx2, float cy2, float time2, float value2) {
	sp42DeformTimeline *self = SUB_CAST(sp42DeformTimeline, timeline);
	int n, i = self->super.super.frameCount + bezier * BEZIER_SIZE;
	float *curves = self->super.curves->items;
	float tmpx = (time1 - cx1 * 2 + cx2) * 0.03, tmpy = cy2 * 0.03 - cy1 * 0.06;
	float dddx = ((cx1 - cx2) * 3 - time1 + time2) * 0.006, dddy = (cy1 - cy2 + 0.33333333) * 0.018;
	float ddx = tmpx * 2 + dddx, ddy = tmpy * 2 + dddy;
	float dx = (cx1 - time1) * 0.3 + tmpx + dddx * 0.16666667, dy = cy1 * 0.3 + tmpy + dddy * 0.16666667;
	float x = time1 + dx, y = dy;
	if (value == 0) curves[frame] = CURVE_BEZIER + i;
	for (n = i + BEZIER_SIZE; i < n; i += 2) {
		curves[i] = x;
		curves[i + 1] = y;
		dx += ddx;
		dy += ddy;
		ddx += dddx;
		ddy += dddy;
		x += dx;
		y += dy;
	}

	UNUSED(value1);
	UNUSED(value2);
}

float _sp42DeformTimeline_getCurvePercent(sp42DeformTimeline *self, float time, int frame) {
	float *curves = self->super.curves->items;
	float *frames = self->super.super.frames->items;
	int n, i = (int) curves[frame];
	int frameEntries = self->super.super.frameEntries;
	float x, y;
	switch (i) {
		case CURVE_LINEAR: {
			x = frames[frame];
			return (time - x) / (frames[frame + frameEntries] - x);
		}
		case CURVE_STEPPED: {
			return 0;
		}
		default: {
		}
	}
	i -= CURVE_BEZIER;
	if (curves[i] > time) {
		x = frames[frame];
		return curves[i + 1] * (time - x) / (curves[i] - x);
	}
	n = i + BEZIER_SIZE;
	for (i += 2; i < n; i += 2) {
		if (curves[i] >= time) {
			x = curves[i - 2], y = curves[i - 1];
			return y + (time - x) / (curves[i] - x) * (curves[i + 1] - y);
		}
	}
	x = curves[n - 2], y = curves[n - 1];
	return y + (1 - y) * (time - x) / (frames[frame + frameEntries] - x);
}

void _sp42DeformTimeline_apply(
		sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time, sp42Event **firedEvents,
		int *eventsCount, float alpha, sp42MixBlend blend, sp42MixDirection direction) {
	int frame, i, vertexCount;
	float percent;
	const float *prevVertices;
	const float *nextVertices;
	float *frames;
	int framesCount;
	float **frameVertices;
	float *deformArray;
	sp42DeformTimeline *self = (sp42DeformTimeline *) timeline;

	sp42Slot *slot = skeleton->slots[self->slotIndex];
	if (!slot->bone->active) return;

	if (!slot->attachment) return;
	switch (slot->attachment->type) {
		case SP_ATTACHMENT_BOUNDING_BOX:
		case SP_ATTACHMENT_CLIPPING:
		case SP_ATTACHMENT_MESH:
		case SP_ATTACHMENT_PATH: {
			sp42VertexAttachment *vertexAttachment = SUB_CAST(sp42VertexAttachment, slot->attachment);
			if (vertexAttachment->timelineAttachment != self->attachment) return;
			break;
		}
		default:
			return;
	}

	frames = self->super.super.frames->items;
	framesCount = self->super.super.frames->size;
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
		sp42VertexAttachment *vertexAttachment = SUB_CAST(sp42VertexAttachment, slot->attachment);
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
					float *setupVertices = vertexAttachment->vertices;
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
			case SP_MIX_BLEND_ADD:; /* to appease compiler */
		}
		return;
	}

	slot->deformCount = vertexCount;
	if (time >= frames[framesCount - 1]) { /* Time is after last frame. */
		const float *lastVertices = self->frameVertices[framesCount - 1];
		if (alpha == 1) {
			if (blend == SP_MIX_BLEND_ADD) {
				sp42VertexAttachment *vertexAttachment = SUB_CAST(sp42VertexAttachment, slot->attachment);
				if (!vertexAttachment->bones) {
					/* Unweighted vertex positions, with alpha. */
					float *setupVertices = vertexAttachment->vertices;
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
			sp42VertexAttachment *vertexAttachment;
			switch (blend) {
				case SP_MIX_BLEND_SETUP:
					vertexAttachment = SUB_CAST(sp42VertexAttachment, slot->attachment);
					if (!vertexAttachment->bones) {
						/* Unweighted vertex positions, with alpha. */
						float *setupVertices = vertexAttachment->vertices;
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
					break;
				case SP_MIX_BLEND_ADD:
					vertexAttachment = SUB_CAST(sp42VertexAttachment, slot->attachment);
					if (!vertexAttachment->bones) {
						/* Unweighted vertex positions, with alpha. */
						float *setupVertices = vertexAttachment->vertices;
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
	frame = search(self->super.super.frames, time);
	percent = _sp42DeformTimeline_getCurvePercent(self, time, frame);
	prevVertices = frameVertices[frame];
	nextVertices = frameVertices[frame + 1];

	if (alpha == 1) {
		if (blend == SP_MIX_BLEND_ADD) {
			sp42VertexAttachment *vertexAttachment = SUB_CAST(sp42VertexAttachment, slot->attachment);
			if (!vertexAttachment->bones) {
				float *setupVertices = vertexAttachment->vertices;
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
		sp42VertexAttachment *vertexAttachment;
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				vertexAttachment = SUB_CAST(sp42VertexAttachment, slot->attachment);
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
				vertexAttachment = SUB_CAST(sp42VertexAttachment, slot->attachment);
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

void _sp42DeformTimeline_dispose(sp42Timeline *timeline) {
	sp42DeformTimeline *self = SUB_CAST(sp42DeformTimeline, timeline);
	int i;
	for (i = 0; i < self->super.super.frames->size; ++i)
		FREE(self->frameVertices[i]);
	FREE(self->frameVertices);
	_sp42CurveTimeline_dispose(timeline);
}

sp42DeformTimeline *sp42DeformTimeline_create(int framesCount, int frameVerticesCount, int bezierCount, int slotIndex,
										  sp42VertexAttachment *attachment) {
	sp42DeformTimeline *self = NEW(sp42DeformTimeline);
	sp42PropertyId ids[1];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_DEFORM << 32) | ((slotIndex << 16 | attachment->id) & 0xffffffff);
	_sp42CurveTimeline_init(SUPER(self), framesCount, 1, bezierCount, ids, 1, SP_TIMELINE_DEFORM,
						  _sp42DeformTimeline_dispose, _sp42DeformTimeline_apply, _sp42DeformTimeline_setBezier);
	self->frameVertices = CALLOC(float *, framesCount);
	self->frameVerticesCount = frameVerticesCount;
	self->slotIndex = slotIndex;
	self->attachment = SUPER(attachment);
	return self;
}

void sp42DeformTimeline_setFrame(sp42DeformTimeline *self, int frame, float time, float *vertices) {
	self->super.super.frames->items[frame] = time;

	FREE(self->frameVertices[frame]);
	if (!vertices)
		self->frameVertices[frame] = 0;
	else {
		self->frameVertices[frame] = MALLOC(float, self->frameVerticesCount);
		memcpy(self->frameVertices[frame], vertices, self->frameVerticesCount * sizeof(float));
	}
}

/**/

static const int SEQUENCE_ENTRIES = 3, MODE = 1, DELAY = 2;

void _sp42SequenceTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time, sp42Event **firedEvents,
							   int *eventsCount, float alpha, sp42MixBlend blend, sp42MixDirection direction) {
	sp42SequenceTimeline *self = (sp42SequenceTimeline *) timeline;
	sp42Slot *slot = skeleton->slots[self->slotIndex];
	sp42Attachment *slotAttachment;
	float *frames;
	int i, modeAndIndex, count, index, mode;
	float before, delay;
	sp42Sequence *sequence = NULL;

	if (!slot->bone->active) return;

	slotAttachment = slot->attachment;
	if (slotAttachment != self->attachment) {
		if (slotAttachment == NULL) return;
		switch (slotAttachment->type) {
			case SP_ATTACHMENT_BOUNDING_BOX:
			case SP_ATTACHMENT_CLIPPING:
			case SP_ATTACHMENT_MESH:
			case SP_ATTACHMENT_PATH: {
				sp42VertexAttachment *vertexAttachment = SUB_CAST(sp42VertexAttachment, slot->attachment);
				if (vertexAttachment->timelineAttachment != self->attachment) return;
				break;
			}
			default:
				return;
		}
	}

	frames = self->super.frames->items;
	if (time < frames[0]) { /* Time is before first frame. */
		if (blend == SP_MIX_BLEND_SETUP || blend == SP_MIX_BLEND_FIRST) slot->sequenceIndex = -1;
		return;
	}

	i = search2(self->super.frames, time, SEQUENCE_ENTRIES);
	before = frames[i];
	modeAndIndex = (int) frames[i + MODE];
	delay = frames[i + DELAY];

	if (self->attachment->type == SP_ATTACHMENT_REGION) sequence = ((sp42RegionAttachment *) self->attachment)->sequence;
	if (self->attachment->type == SP_ATTACHMENT_MESH) sequence = ((sp42MeshAttachment *) self->attachment)->sequence;
	if (!sequence) return;
	index = modeAndIndex >> 4;
	count = sequence->regions->size;
	mode = modeAndIndex & 0xf;
	if (mode != SP_SEQUENCE_MODE_HOLD) {
		index += (int) (((time - before) / delay + 0.0001));
		switch (mode) {
			case SP_SEQUENCE_MODE_ONCE:
				index = MIN(count - 1, index);
				break;
			case SP_SEQUENCE_MODE_LOOP:
				index %= count;
				break;
			case SP_SEQUENCE_MODE_PINGPONG: {
				int n = (count << 1) - 2;
				index = n == 0 ? 0 : index % n;
				if (index >= count) index = n - index;
				break;
			}
			case SP_SEQUENCE_MODE_ONCEREVERSE:
				index = MAX(count - 1 - index, 0);
				break;
			case SP_SEQUENCE_MODE_LOOPREVERSE:
				index = count - 1 - (index % count);
				break;
			case SP_SEQUENCE_MODE_PINGPONGREVERSE: {
				int n = (count << 1) - 2;
				index = n == 0 ? 0 : (index + count - 1) % n;
				if (index >= count) index = n - index;
			}
		}
	}
	slot->sequenceIndex = index;

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(alpha);
	UNUSED(direction);
}

void _sp42SequenceTimeline_dispose(sp42Timeline *timeline) {
	/* NO-OP */
	UNUSED(timeline);
}

sp42SequenceTimeline *sp42SequenceTimeline_create(int framesCount, int slotIndex, sp42Attachment *attachment) {
	int sequenceId = 0;
	sp42SequenceTimeline *self = NEW(sp42SequenceTimeline);
	sp42PropertyId ids[1];
	if (attachment->type == SP_ATTACHMENT_REGION) sequenceId = ((sp42RegionAttachment *) attachment)->sequence->id;
	if (attachment->type == SP_ATTACHMENT_MESH) sequenceId = ((sp42MeshAttachment *) attachment)->sequence->id;
	ids[0] = (sp42PropertyId) SP_PROPERTY_SEQUENCE << 32 | ((slotIndex << 16 | sequenceId) & 0xffffffff);
	_sp42Timeline_init(SUPER(self), framesCount, SEQUENCE_ENTRIES, ids, 1, SP_TIMELINE_SEQUENCE, _sp42SequenceTimeline_dispose,
					 _sp42SequenceTimeline_apply, 0);
	self->slotIndex = slotIndex;
	self->attachment = attachment;
	return self;
}

void sp42SequenceTimeline_setFrame(sp42SequenceTimeline *self, int frame, float time, int mode, int index, float delay) {
	float *frames = self->super.frames->items;
	frame *= SEQUENCE_ENTRIES;
	frames[frame] = time;
	frames[frame + MODE] = mode | (index << 4);
	frames[frame + DELAY] = delay;
}

/**/

/** Fires events for frames > lastTime and <= time. */
void _sp42EventTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time, sp42Event **firedEvents,
							int *eventsCount, float alpha, sp42MixBlend blend, sp42MixDirection direction) {
	sp42EventTimeline *self = (sp42EventTimeline *) timeline;
	float *frames = self->super.frames->items;
	int framesCount = self->super.frames->size;
	int i;
	if (!firedEvents) return;

	if (lastTime > time) { /* Fire events after last time for looped animations. */
		_sp42EventTimeline_apply(timeline, skeleton, lastTime, (float) INT_MAX, firedEvents, eventsCount, alpha, blend,
							   direction);
		lastTime = -1;
	} else if (lastTime >= frames[framesCount - 1]) {
		/* Last time is after last i. */
		return;
	}

	if (time < frames[0]) return; /* Time is before first i. */

	if (lastTime < frames[0])
		i = 0;
	else {
		float frameTime;
		i = search(self->super.frames, lastTime) + 1;
		frameTime = frames[i];
		while (i > 0) { /* Fire multiple events with the same i. */
			if (frames[i - 1] != frameTime) break;
			i--;
		}
	}
	for (; i < framesCount && time >= frames[i]; ++i) {
		firedEvents[*eventsCount] = self->events[i];
		(*eventsCount)++;
	}
	UNUSED(direction);
}

void _sp42EventTimeline_dispose(sp42Timeline *timeline) {
	sp42EventTimeline *self = SUB_CAST(sp42EventTimeline, timeline);
	int i;

	for (i = 0; i < self->super.frames->size; ++i)
		sp42Event_dispose(self->events[i]);
	FREE(self->events);
}

sp42EventTimeline *sp42EventTimeline_create(int framesCount) {
	sp42EventTimeline *self = NEW(sp42EventTimeline);
	sp42PropertyId ids[1];
	ids[0] = (sp42PropertyId) SP_PROPERTY_EVENT << 32;
	_sp42Timeline_init(SUPER(self), framesCount, 1, ids, 1, SP_TIMELINE_EVENT, _sp42EventTimeline_dispose,
					 _sp42EventTimeline_apply, 0);
	self->events = CALLOC(sp42Event *, framesCount);
	return self;
}

void sp42EventTimeline_setFrame(sp42EventTimeline *self, int frame, sp42Event *event) {
	self->super.frames->items[frame] = event->time;

	FREE(self->events[frame]);
	self->events[frame] = event;
}

/**/

void _sp42DrawOrderTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
								sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
								sp42MixDirection direction) {
	int i;
	const int *drawOrderToSetupIndex;
	sp42DrawOrderTimeline *self = (sp42DrawOrderTimeline *) timeline;
	float *frames = self->super.frames->items;

	if (direction == SP_MIX_DIRECTION_OUT) {
		if (blend == SP_MIX_BLEND_SETUP)
			memcpy(skeleton->drawOrder, skeleton->slots, self->slotsCount * sizeof(sp42Slot *));
		return;
	}

	if (time < frames[0]) {
		if (blend == SP_MIX_BLEND_SETUP || blend == SP_MIX_BLEND_FIRST)
			memcpy(skeleton->drawOrder, skeleton->slots, self->slotsCount * sizeof(sp42Slot *));
		return;
	}

	drawOrderToSetupIndex = self->drawOrders[search(self->super.frames, time)];
	if (!drawOrderToSetupIndex)
		memcpy(skeleton->drawOrder, skeleton->slots, self->slotsCount * sizeof(sp42Slot *));
	else {
		for (i = 0; i < self->slotsCount; ++i)
			skeleton->drawOrder[i] = skeleton->slots[drawOrderToSetupIndex[i]];
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(alpha);
}

void _sp42DrawOrderTimeline_dispose(sp42Timeline *timeline) {
	sp42DrawOrderTimeline *self = SUB_CAST(sp42DrawOrderTimeline, timeline);
	int i;

	for (i = 0; i < self->super.frames->size; ++i)
		FREE(self->drawOrders[i]);
	FREE(self->drawOrders);
}

sp42DrawOrderTimeline *sp42DrawOrderTimeline_create(int framesCount, int slotsCount) {
	sp42DrawOrderTimeline *self = NEW(sp42DrawOrderTimeline);
	sp42PropertyId ids[1];
	ids[0] = (sp42PropertyId) SP_PROPERTY_DRAWORDER << 32;
	_sp42Timeline_init(SUPER(self), framesCount, 1, ids, 1, SP_TIMELINE_DRAWORDER, _sp42DrawOrderTimeline_dispose,
					 _sp42DrawOrderTimeline_apply, 0);

	self->drawOrders = CALLOC(int *, framesCount);
	self->slotsCount = slotsCount;

	return self;
}

void sp42DrawOrderTimeline_setFrame(sp42DrawOrderTimeline *self, int frame, float time, const int *drawOrder) {
	self->super.frames->items[frame] = time;

	FREE(self->drawOrders[frame]);
	if (!drawOrder)
		self->drawOrders[frame] = 0;
	else {
		self->drawOrders[frame] = MALLOC(int, self->slotsCount);
		memcpy(self->drawOrders[frame], drawOrder, self->slotsCount * sizeof(int));
	}
}

/**/
void _sp42InheritTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
							  sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
							  sp42MixDirection direction) {
	sp42InheritTimeline *self = (sp42InheritTimeline *) timeline;
	sp42Bone *bone = skeleton->bones[self->boneIndex];
	float *frames = self->super.frames->items;
	if (!bone->active) return;

	if (time < frames[0]) {
		if (blend == SP_MIX_BLEND_SETUP || blend == SP_MIX_BLEND_FIRST) bone->inherit = bone->data->inherit;
		return;
	}
	int idx = search2(self->super.frames, time, 2) + 1;
	bone->inherit = (sp42Inherit) frames[idx];

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(alpha);
	UNUSED(direction);
}

void _sp42InheritTimeline_dispose(sp42Timeline *timeline) {
	// no-op, sp42Timeline_dispose disposes frames.
	UNUSED(timeline);
}

sp42InheritTimeline *sp42InheritTimeline_create(int framesCount, int boneIndex) {
	sp42InheritTimeline *self = NEW(sp42InheritTimeline);
	sp42PropertyId ids[1];
	ids[0] = (sp42PropertyId) SP_PROPERTY_INHERIT << 32;
	_sp42Timeline_init(SUPER(self), framesCount, 2, ids, 1, SP_TIMELINE_INHERIT, _sp42InheritTimeline_dispose,
					 _sp42InheritTimeline_apply, 0);

	self->boneIndex = boneIndex;

	return self;
}

void sp42InheritTimeline_setFrame(sp42InheritTimeline *self, int frame, float time, sp42Inherit inherit) {
	frame *= 2;
	self->super.frames->items[frame] = time;
	self->super.frames->items[frame + 1] = inherit;
}


/**/

static const int IKCONSTRAINT_ENTRIES = 6;
static const int IKCONSTRAINT_MIX = 1, IKCONSTRAINT_SOFTNESS = 2, IKCONSTRAINT_BEND_DIRECTION = 3, IKCONSTRAINT_COMPRESS = 4, IKCONSTRAINT_STRETCH = 5;

void _sp42IkConstraintTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
								   sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
								   sp42MixDirection direction) {
	int i, curveType;
	float mix, softness, t;
	sp42IkConstraint *constraint;
	sp42IkConstraintTimeline *self = (sp42IkConstraintTimeline *) timeline;
	float *frames = self->super.super.frames->items;
	float *curves = self->super.curves->items;

	constraint = skeleton->ikConstraints[self->ikConstraintIndex];
	if (!constraint->active) return;

	if (time < frames[0]) {
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
				return;
			default:
				return;
		}
	}

	i = search2(self->super.super.frames, time, IKCONSTRAINT_ENTRIES);
	curveType = (int) curves[i / IKCONSTRAINT_ENTRIES];
	switch (curveType) {
		case CURVE_LINEAR: {
			float before = frames[i];
			mix = frames[i + IKCONSTRAINT_MIX];
			softness = frames[i + IKCONSTRAINT_SOFTNESS];
			t = (time - before) / (frames[i + IKCONSTRAINT_ENTRIES] - before);
			mix += (frames[i + IKCONSTRAINT_ENTRIES + IKCONSTRAINT_MIX] - mix) * t;
			softness += (frames[i + IKCONSTRAINT_ENTRIES + IKCONSTRAINT_SOFTNESS] - softness) * t;
			break;
		}
		case CURVE_STEPPED: {
			mix = frames[i + IKCONSTRAINT_MIX];
			softness = frames[i + IKCONSTRAINT_SOFTNESS];
			break;
		}
		default: {
			mix = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, IKCONSTRAINT_MIX, curveType - CURVE_BEZIER);
			softness = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, IKCONSTRAINT_SOFTNESS,
													   curveType + BEZIER_SIZE - CURVE_BEZIER);
		}
	}

	if (blend == SP_MIX_BLEND_SETUP) {
		constraint->mix = constraint->data->mix + (mix - constraint->data->mix) * alpha;
		constraint->softness = constraint->data->softness + (softness - constraint->data->softness) * alpha;

		if (direction == SP_MIX_DIRECTION_OUT) {
			constraint->bendDirection = constraint->data->bendDirection;
			constraint->compress = constraint->data->compress;
			constraint->stretch = constraint->data->stretch;
		} else {
			constraint->bendDirection = frames[i + IKCONSTRAINT_BEND_DIRECTION];
			constraint->compress = frames[i + IKCONSTRAINT_COMPRESS] != 0;
			constraint->stretch = frames[i + IKCONSTRAINT_STRETCH] != 0;
		}
	} else {
		constraint->mix += (mix - constraint->mix) * alpha;
		constraint->softness += (softness - constraint->softness) * alpha;
		if (direction == SP_MIX_DIRECTION_IN) {
			constraint->bendDirection = frames[i + IKCONSTRAINT_BEND_DIRECTION];
			constraint->compress = frames[i + IKCONSTRAINT_COMPRESS] != 0;
			constraint->stretch = frames[i + IKCONSTRAINT_STRETCH] != 0;
		}
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
}

sp42IkConstraintTimeline *sp42IkConstraintTimeline_create(int framesCount, int bezierCount, int ikConstraintIndex) {
	sp42IkConstraintTimeline *timeline = NEW(sp42IkConstraintTimeline);
	sp42PropertyId ids[1];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_IKCONSTRAINT << 32) | ikConstraintIndex;
	_sp42CurveTimeline_init(SUPER(timeline), framesCount, IKCONSTRAINT_ENTRIES, bezierCount, ids, 1,
						  SP_TIMELINE_IKCONSTRAINT, _sp42CurveTimeline_dispose, _sp42IkConstraintTimeline_apply,
						  _sp42CurveTimeline_setBezier);
	timeline->ikConstraintIndex = ikConstraintIndex;
	return timeline;
}

void sp42IkConstraintTimeline_setFrame(sp42IkConstraintTimeline *self, int frame, float time, float mix, float softness,
									 int bendDirection, int /*boolean*/ compress, int /*boolean*/ stretch) {
	float *frames = self->super.super.frames->items;
	frame *= IKCONSTRAINT_ENTRIES;
	frames[frame] = time;
	frames[frame + IKCONSTRAINT_MIX] = mix;
	frames[frame + IKCONSTRAINT_SOFTNESS] = softness;
	frames[frame + IKCONSTRAINT_BEND_DIRECTION] = (float) bendDirection;
	frames[frame + IKCONSTRAINT_COMPRESS] = compress ? 1 : 0;
	frames[frame + IKCONSTRAINT_STRETCH] = stretch ? 1 : 0;
}

/**/
static const int TRANSFORMCONSTRAINT_ENTRIES = 7;
static const int TRANSFORMCONSTRAINT_ROTATE = 1;
static const int TRANSFORMCONSTRAINT_X = 2;
static const int TRANSFORMCONSTRAINT_Y = 3;
static const int TRANSFORMCONSTRAINT_SCALEX = 4;
static const int TRANSFORMCONSTRAINT_SCALEY = 5;
static const int TRANSFORMCONSTRAINT_SHEARY = 6;

void _sp42TransformConstraintTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
										  sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
										  sp42MixDirection direction) {
	int i, curveType;
	float rotate, x, y, scaleX, scaleY, shearY, t;
	sp42TransformConstraint *constraint;
	sp42TransformConstraintTimeline *self = (sp42TransformConstraintTimeline *) timeline;
	float *frames;
	float *curves;
	sp42TransformConstraintData *data;

	constraint = skeleton->transformConstraints[self->transformConstraintIndex];
	if (!constraint->active) return;

	frames = self->super.super.frames->items;
	curves = self->super.curves->items;

	data = constraint->data;
	if (time < frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				constraint->mixRotate = data->mixRotate;
				constraint->mixX = data->mixX;
				constraint->mixY = data->mixY;
				constraint->mixScaleX = data->mixScaleX;
				constraint->mixScaleY = data->mixScaleY;
				constraint->mixShearY = data->mixShearY;
				return;
			case SP_MIX_BLEND_FIRST:
				constraint->mixRotate += (data->mixRotate - constraint->mixRotate) * alpha;
				constraint->mixX += (data->mixX - constraint->mixX) * alpha;
				constraint->mixY += (data->mixY - constraint->mixY) * alpha;
				constraint->mixScaleX += (data->mixScaleX - constraint->mixScaleX) * alpha;
				constraint->mixScaleY += (data->mixScaleY - constraint->mixScaleY) * alpha;
				constraint->mixShearY += (data->mixShearY - constraint->mixShearY) * alpha;
				return;
			default:
				return;
		}
	}

	i = search2(self->super.super.frames, time, TRANSFORMCONSTRAINT_ENTRIES);
	curveType = (int) curves[i / TRANSFORMCONSTRAINT_ENTRIES];
	switch (curveType) {
		case CURVE_LINEAR: {
			float before = frames[i];
			rotate = frames[i + TRANSFORMCONSTRAINT_ROTATE];
			x = frames[i + TRANSFORMCONSTRAINT_X];
			y = frames[i + TRANSFORMCONSTRAINT_Y];
			scaleX = frames[i + TRANSFORMCONSTRAINT_SCALEX];
			scaleY = frames[i + TRANSFORMCONSTRAINT_SCALEY];
			shearY = frames[i + TRANSFORMCONSTRAINT_SHEARY];
			t = (time - before) / (frames[i + TRANSFORMCONSTRAINT_ENTRIES] - before);
			rotate += (frames[i + TRANSFORMCONSTRAINT_ENTRIES + TRANSFORMCONSTRAINT_ROTATE] - rotate) * t;
			x += (frames[i + TRANSFORMCONSTRAINT_ENTRIES + TRANSFORMCONSTRAINT_X] - x) * t;
			y += (frames[i + TRANSFORMCONSTRAINT_ENTRIES + TRANSFORMCONSTRAINT_Y] - y) * t;
			scaleX += (frames[i + TRANSFORMCONSTRAINT_ENTRIES + TRANSFORMCONSTRAINT_SCALEX] - scaleX) * t;
			scaleY += (frames[i + TRANSFORMCONSTRAINT_ENTRIES + TRANSFORMCONSTRAINT_SCALEY] - scaleY) * t;
			shearY += (frames[i + TRANSFORMCONSTRAINT_ENTRIES + TRANSFORMCONSTRAINT_SHEARY] - shearY) * t;
			break;
		}
		case CURVE_STEPPED: {
			rotate = frames[i + TRANSFORMCONSTRAINT_ROTATE];
			x = frames[i + TRANSFORMCONSTRAINT_X];
			y = frames[i + TRANSFORMCONSTRAINT_Y];
			scaleX = frames[i + TRANSFORMCONSTRAINT_SCALEX];
			scaleY = frames[i + TRANSFORMCONSTRAINT_SCALEY];
			shearY = frames[i + TRANSFORMCONSTRAINT_SHEARY];
			break;
		}
		default: {
			rotate = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, TRANSFORMCONSTRAINT_ROTATE,
													 curveType - CURVE_BEZIER);
			x = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, TRANSFORMCONSTRAINT_X,
												curveType + BEZIER_SIZE - CURVE_BEZIER);
			y = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, TRANSFORMCONSTRAINT_Y,
												curveType + BEZIER_SIZE * 2 - CURVE_BEZIER);
			scaleX = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, TRANSFORMCONSTRAINT_SCALEX,
													 curveType + BEZIER_SIZE * 3 - CURVE_BEZIER);
			scaleY = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, TRANSFORMCONSTRAINT_SCALEY,
													 curveType + BEZIER_SIZE * 4 - CURVE_BEZIER);
			shearY = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, TRANSFORMCONSTRAINT_SHEARY,
													 curveType + BEZIER_SIZE * 5 - CURVE_BEZIER);
		}
	}

	if (blend == SP_MIX_BLEND_SETUP) {
		constraint->mixRotate = data->mixRotate + (rotate - data->mixRotate) * alpha;
		constraint->mixX = data->mixX + (x - data->mixX) * alpha;
		constraint->mixY = data->mixY + (y - data->mixY) * alpha;
		constraint->mixScaleX = data->mixScaleX + (scaleX - data->mixScaleX) * alpha;
		constraint->mixScaleY = data->mixScaleY + (scaleY - data->mixScaleY) * alpha;
		constraint->mixShearY = data->mixShearY + (shearY - data->mixShearY) * alpha;
	} else {
		constraint->mixRotate += (rotate - constraint->mixRotate) * alpha;
		constraint->mixX += (x - constraint->mixX) * alpha;
		constraint->mixY += (y - constraint->mixY) * alpha;
		constraint->mixScaleX += (scaleX - constraint->mixScaleX) * alpha;
		constraint->mixScaleY += (scaleY - constraint->mixScaleY) * alpha;
		constraint->mixShearY += (shearY - constraint->mixShearY) * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

sp42TransformConstraintTimeline *
sp42TransformConstraintTimeline_create(int framesCount, int bezierCount, int transformConstraintIndex) {
	sp42TransformConstraintTimeline *timeline = NEW(sp42TransformConstraintTimeline);
	sp42PropertyId ids[1];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_TRANSFORMCONSTRAINT << 32) | transformConstraintIndex;
	_sp42CurveTimeline_init(SUPER(timeline), framesCount, TRANSFORMCONSTRAINT_ENTRIES, bezierCount, ids, 1,
						  SP_TIMELINE_TRANSFORMCONSTRAINT, _sp42CurveTimeline_dispose,
						  _sp42TransformConstraintTimeline_apply, _sp42CurveTimeline_setBezier);
	timeline->transformConstraintIndex = transformConstraintIndex;
	return timeline;
}

void sp42TransformConstraintTimeline_setFrame(sp42TransformConstraintTimeline *self, int frame, float time, float mixRotate,
											float mixX, float mixY, float mixScaleX, float mixScaleY, float mixShearY) {
	float *frames = self->super.super.frames->items;
	frame *= TRANSFORMCONSTRAINT_ENTRIES;
	frames[frame] = time;
	frames[frame + TRANSFORMCONSTRAINT_ROTATE] = mixRotate;
	frames[frame + TRANSFORMCONSTRAINT_X] = mixX;
	frames[frame + TRANSFORMCONSTRAINT_Y] = mixY;
	frames[frame + TRANSFORMCONSTRAINT_SCALEX] = mixScaleX;
	frames[frame + TRANSFORMCONSTRAINT_SCALEY] = mixScaleY;
	frames[frame + TRANSFORMCONSTRAINT_SHEARY] = mixShearY;
}

/**/
static const int PATHCONSTRAINTPOSITION_ENTRIES = 2;
static const int PATHCONSTRAINTPOSITION_VALUE = 1;

void _sp42PathConstraintPositionTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
											 sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
											 sp42MixDirection direction) {
	sp42PathConstraintPositionTimeline *self = (sp42PathConstraintPositionTimeline *) timeline;
	sp42PathConstraint *constraint = skeleton->pathConstraints[self->pathConstraintIndex];
	if (constraint->active) constraint->position = sp42CurveTimeline1_getAbsoluteValue(SUPER(self), time, alpha, blend, constraint->position, constraint->data->position);

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

sp42PathConstraintPositionTimeline *
sp42PathConstraintPositionTimeline_create(int framesCount, int bezierCount, int pathConstraintIndex) {
	sp42PathConstraintPositionTimeline *timeline = NEW(sp42PathConstraintPositionTimeline);
	sp42PropertyId ids[1];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_PATHCONSTRAINT_POSITION << 32) | pathConstraintIndex;
	_sp42CurveTimeline_init(SUPER(timeline), framesCount, PATHCONSTRAINTPOSITION_ENTRIES, bezierCount, ids, 1,
						  SP_TIMELINE_PATHCONSTRAINTPOSITION, _sp42CurveTimeline_dispose,
						  _sp42PathConstraintPositionTimeline_apply, _sp42CurveTimeline_setBezier);
	timeline->pathConstraintIndex = pathConstraintIndex;
	return timeline;
}

void sp42PathConstraintPositionTimeline_setFrame(sp42PathConstraintPositionTimeline *self, int frame, float time, float value) {
	float *frames = self->super.super.frames->items;
	frame *= PATHCONSTRAINTPOSITION_ENTRIES;
	frames[frame] = time;
	frames[frame + PATHCONSTRAINTPOSITION_VALUE] = value;
}

/**/
static const int PATHCONSTRAINTSPACING_ENTRIES = 2;
static const int PATHCONSTRAINTSPACING_VALUE = 1;

void _sp42PathConstraintSpacingTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
											sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
											sp42MixDirection direction) {
	sp42PathConstraintSpacingTimeline *self = (sp42PathConstraintSpacingTimeline *) timeline;
	sp42PathConstraint *constraint = skeleton->pathConstraints[self->pathConstraintIndex];
	if (constraint->active) constraint->spacing = sp42CurveTimeline1_getAbsoluteValue(SUPER(self), time, alpha, blend, constraint->spacing, constraint->data->spacing);

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

sp42PathConstraintSpacingTimeline *
sp42PathConstraintSpacingTimeline_create(int framesCount, int bezierCount, int pathConstraintIndex) {
	sp42PathConstraintSpacingTimeline *timeline = NEW(sp42PathConstraintSpacingTimeline);
	sp42PropertyId ids[1];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_PATHCONSTRAINT_SPACING << 32) | pathConstraintIndex;
	_sp42CurveTimeline_init(SUPER(timeline), framesCount, PATHCONSTRAINTSPACING_ENTRIES, bezierCount, ids, 1,
						  SP_TIMELINE_PATHCONSTRAINTSPACING, _sp42CurveTimeline_dispose,
						  _sp42PathConstraintSpacingTimeline_apply, _sp42CurveTimeline_setBezier);
	timeline->pathConstraintIndex = pathConstraintIndex;
	return timeline;
}

void sp42PathConstraintSpacingTimeline_setFrame(sp42PathConstraintSpacingTimeline *self, int frame, float time, float value) {
	float *frames = self->super.super.frames->items;
	frame *= PATHCONSTRAINTSPACING_ENTRIES;
	frames[frame] = time;
	frames[frame + PATHCONSTRAINTSPACING_VALUE] = value;
}

/**/

static const int PATHCONSTRAINTMIX_ENTRIES = 4;
static const int PATHCONSTRAINTMIX_ROTATE = 1;
static const int PATHCONSTRAINTMIX_X = 2;
static const int PATHCONSTRAINTMIX_Y = 3;

void _sp42PathConstraintMixTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
										sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
										sp42MixDirection direction) {
	int i, curveType;
	float rotate, x, y, t;
	sp42PathConstraint *constraint;
	sp42PathConstraintMixTimeline *self = (sp42PathConstraintMixTimeline *) timeline;
	float *frames;
	float *curves;

	constraint = skeleton->pathConstraints[self->pathConstraintIndex];
	if (!constraint->active) return;

	frames = self->super.super.frames->items;
	curves = self->super.curves->items;

	if (time < frames[0]) {
		switch (blend) {
			case SP_MIX_BLEND_SETUP:
				constraint->mixRotate = constraint->data->mixRotate;
				constraint->mixX = constraint->data->mixX;
				constraint->mixY = constraint->data->mixY;
				return;
			case SP_MIX_BLEND_FIRST:
				constraint->mixRotate += (constraint->data->mixRotate - constraint->mixRotate) * alpha;
				constraint->mixX += (constraint->data->mixX - constraint->mixX) * alpha;
				constraint->mixY += (constraint->data->mixY - constraint->mixY) * alpha;
			default: {
			}
		}
		return;
	}

	i = search2(self->super.super.frames, time, PATHCONSTRAINTMIX_ENTRIES);
	curveType = (int) curves[i >> 2];
	switch (curveType) {
		case CURVE_LINEAR: {
			float before = frames[i];
			rotate = frames[i + PATHCONSTRAINTMIX_ROTATE];
			x = frames[i + PATHCONSTRAINTMIX_X];
			y = frames[i + PATHCONSTRAINTMIX_Y];
			t = (time - before) / (frames[i + PATHCONSTRAINTMIX_ENTRIES] - before);
			rotate += (frames[i + PATHCONSTRAINTMIX_ENTRIES + PATHCONSTRAINTMIX_ROTATE] - rotate) * t;
			x += (frames[i + PATHCONSTRAINTMIX_ENTRIES + PATHCONSTRAINTMIX_X] - x) * t;
			y += (frames[i + PATHCONSTRAINTMIX_ENTRIES + PATHCONSTRAINTMIX_Y] - y) * t;
			break;
		}
		case CURVE_STEPPED: {
			rotate = frames[i + PATHCONSTRAINTMIX_ROTATE];
			x = frames[i + PATHCONSTRAINTMIX_X];
			y = frames[i + PATHCONSTRAINTMIX_Y];
			break;
		}
		default: {
			rotate = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, PATHCONSTRAINTMIX_ROTATE,
													 curveType - CURVE_BEZIER);
			x = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, PATHCONSTRAINTMIX_X,
												curveType + BEZIER_SIZE - CURVE_BEZIER);
			y = _sp42CurveTimeline_getBezierValue(SUPER(self), time, i, PATHCONSTRAINTMIX_Y,
												curveType + BEZIER_SIZE * 2 - CURVE_BEZIER);
		}
	}

	if (blend == SP_MIX_BLEND_SETUP) {
		sp42PathConstraintData *data = constraint->data;
		constraint->mixRotate = data->mixRotate + (rotate - data->mixRotate) * alpha;
		constraint->mixX = data->mixX + (x - data->mixX) * alpha;
		constraint->mixY = data->mixY + (y - data->mixY) * alpha;
	} else {
		constraint->mixRotate += (rotate - constraint->mixRotate) * alpha;
		constraint->mixX += (x - constraint->mixX) * alpha;
		constraint->mixY += (y - constraint->mixY) * alpha;
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

sp42PathConstraintMixTimeline *
sp42PathConstraintMixTimeline_create(int framesCount, int bezierCount, int pathConstraintIndex) {
	sp42PathConstraintMixTimeline *timeline = NEW(sp42PathConstraintMixTimeline);
	sp42PropertyId ids[1];
	ids[0] = ((sp42PropertyId) SP_PROPERTY_PATHCONSTRAINT_MIX << 32) | pathConstraintIndex;
	_sp42CurveTimeline_init(SUPER(timeline), framesCount, PATHCONSTRAINTMIX_ENTRIES, bezierCount, ids, 1,
						  SP_TIMELINE_PATHCONSTRAINTMIX, _sp42CurveTimeline_dispose, _sp42PathConstraintMixTimeline_apply,
						  _sp42CurveTimeline_setBezier);
	timeline->pathConstraintIndex = pathConstraintIndex;
	return timeline;
}

void sp42PathConstraintMixTimeline_setFrame(sp42PathConstraintMixTimeline *self, int frame, float time, float mixRotate,
										  float mixX, float mixY) {
	float *frames = self->super.super.frames->items;
	frame *= PATHCONSTRAINTMIX_ENTRIES;
	frames[frame] = time;
	frames[frame + PATHCONSTRAINTMIX_ROTATE] = mixRotate;
	frames[frame + PATHCONSTRAINTMIX_X] = mixX;
	frames[frame + PATHCONSTRAINTMIX_Y] = mixY;
}

/**/

int /*bool*/ _sp42PhysicsConstraintTimeline_global(sp42PhysicsConstraintData *data, sp42TimelineType type) {
	switch (type) {
		case SP_TIMELINE_PHYSICSCONSTRAINT_INERTIA:
			return data->inertiaGlobal;
		case SP_TIMELINE_PHYSICSCONSTRAINT_STRENGTH:
			return data->strengthGlobal;
		case SP_TIMELINE_PHYSICSCONSTRAINT_DAMPING:
			return data->dampingGlobal;
		case SP_TIMELINE_PHYSICSCONSTRAINT_MASS:
			return data->massGlobal;
		case SP_TIMELINE_PHYSICSCONSTRAINT_WIND:
			return data->windGlobal;
		case SP_TIMELINE_PHYSICSCONSTRAINT_GRAVITY:
			return data->gravityGlobal;
		case SP_TIMELINE_PHYSICSCONSTRAINT_MIX:
			return data->mixGlobal;
		default:
			// should never happen
			return 0;
	}
}

void _sp42PhysicsConstraintTimeline_set(sp42PhysicsConstraint *constraint, sp42TimelineType type, float value) {
	switch (type) {
		case SP_TIMELINE_PHYSICSCONSTRAINT_INERTIA:
			constraint->inertia = value;
			break;
		case SP_TIMELINE_PHYSICSCONSTRAINT_STRENGTH:
			constraint->strength = value;
			break;
		case SP_TIMELINE_PHYSICSCONSTRAINT_DAMPING:
			constraint->damping = value;
			break;
		case SP_TIMELINE_PHYSICSCONSTRAINT_MASS:
			constraint->massInverse = value;
			break;
		case SP_TIMELINE_PHYSICSCONSTRAINT_WIND:
			constraint->wind = value;
			break;
		case SP_TIMELINE_PHYSICSCONSTRAINT_GRAVITY:
			constraint->gravity = value;
			break;
		case SP_TIMELINE_PHYSICSCONSTRAINT_MIX:
			constraint->mix = value;
			break;
		default:
			// should never happen
			break;
	}
}

float _sp42PhysicsConstraintTimeline_get(sp42PhysicsConstraint *constraint, sp42TimelineType type) {
	switch (type) {
		case SP_TIMELINE_PHYSICSCONSTRAINT_INERTIA:
			return constraint->inertia;
		case SP_TIMELINE_PHYSICSCONSTRAINT_STRENGTH:
			return constraint->strength;
		case SP_TIMELINE_PHYSICSCONSTRAINT_DAMPING:
			return constraint->damping;
		case SP_TIMELINE_PHYSICSCONSTRAINT_MASS:
			return constraint->massInverse;
		case SP_TIMELINE_PHYSICSCONSTRAINT_WIND:
			return constraint->wind;
		case SP_TIMELINE_PHYSICSCONSTRAINT_GRAVITY:
			return constraint->gravity;
		case SP_TIMELINE_PHYSICSCONSTRAINT_MIX:
			return constraint->mix;
		default:
			// should never happen
			return 0;
	}
}

float _sp42PhysicsConstraintTimeline_setup(sp42PhysicsConstraint *constraint, sp42TimelineType type) {
	switch (type) {
		case SP_TIMELINE_PHYSICSCONSTRAINT_INERTIA:
			return constraint->data->inertia;
		case SP_TIMELINE_PHYSICSCONSTRAINT_STRENGTH:
			return constraint->data->strength;
		case SP_TIMELINE_PHYSICSCONSTRAINT_DAMPING:
			return constraint->data->damping;
		case SP_TIMELINE_PHYSICSCONSTRAINT_MASS:
			return constraint->data->massInverse;
		case SP_TIMELINE_PHYSICSCONSTRAINT_WIND:
			return constraint->data->wind;
		case SP_TIMELINE_PHYSICSCONSTRAINT_GRAVITY:
			return constraint->data->gravity;
		case SP_TIMELINE_PHYSICSCONSTRAINT_MIX:
			return constraint->data->mix;
		default:
			// should never happen
			return 0;
	}
}

void _sp42PhysicsConstraintTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
										sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
										sp42MixDirection direction) {
	sp42PhysicsConstraintTimeline *self = SUB_CAST(sp42PhysicsConstraintTimeline, timeline);
	sp42TimelineType type = self->super.super.type;
	float *frames = self->super.super.frames->items;
	if (self->physicsConstraintIndex == -1) {
		float value = time >= frames[0] ? sp42CurveTimeline1_getCurveValue(SUPER(self), time) : 0;

		sp42PhysicsConstraint **physicsConstraints = skeleton->physicsConstraints;
		for (int i = 0; i < skeleton->physicsConstraintsCount; i++) {
			sp42PhysicsConstraint *constraint = physicsConstraints[i];
			if (constraint->active && _sp42PhysicsConstraintTimeline_global(constraint->data, type))
				_sp42PhysicsConstraintTimeline_set(constraint, type, sp42CurveTimeline1_getAbsoluteValue2(SUPER(self), time, alpha, blend, _sp42PhysicsConstraintTimeline_get(constraint, type), _sp42PhysicsConstraintTimeline_setup(constraint, type), value));
		}
	} else {
		sp42PhysicsConstraint *constraint = skeleton->physicsConstraints[self->physicsConstraintIndex];
		if (constraint->active) _sp42PhysicsConstraintTimeline_set(constraint, type, sp42CurveTimeline1_getAbsoluteValue(SUPER(self), time, alpha, blend, _sp42PhysicsConstraintTimeline_get(constraint, type), _sp42PhysicsConstraintTimeline_setup(constraint, type)));
	}
	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(direction);
}

sp42PhysicsConstraintTimeline *
sp42PhysicsConstraintTimeline_create(int frameCount, int bezierCount, int physicsConstraintIndex, sp42TimelineType type) {
	sp42PhysicsConstraintTimeline *timeline = NEW(sp42PhysicsConstraintTimeline);
	sp42PropertyId ids[1];
	sp42PropertyId id;
	switch (type) {
		case SP_TIMELINE_PHYSICSCONSTRAINT_INERTIA:
			id = SP_PROPERTY_PHYSICSCONSTRAINT_INERTIA;
			break;
		case SP_TIMELINE_PHYSICSCONSTRAINT_STRENGTH:
			id = SP_PROPERTY_PHYSICSCONSTRAINT_STRENGTH;
			break;
		case SP_TIMELINE_PHYSICSCONSTRAINT_DAMPING:
			id = SP_PROPERTY_PHYSICSCONSTRAINT_DAMPING;
			break;
		case SP_TIMELINE_PHYSICSCONSTRAINT_MASS:
			id = SP_PROPERTY_PHYSICSCONSTRAINT_MASS;
			break;
		case SP_TIMELINE_PHYSICSCONSTRAINT_WIND:
			id = SP_PROPERTY_PHYSICSCONSTRAINT_WIND;
			break;
		case SP_TIMELINE_PHYSICSCONSTRAINT_GRAVITY:
			id = SP_PROPERTY_PHYSICSCONSTRAINT_GRAVITY;
			break;
		case SP_TIMELINE_PHYSICSCONSTRAINT_MIX:
			id = SP_PROPERTY_PHYSICSCONSTRAINT_MIX;
			break;
		default:
			// should never happen
			id = SP_PROPERTY_PHYSICSCONSTRAINT_INERTIA;
	}
	ids[0] = ((sp42PropertyId) id << 32) | physicsConstraintIndex;
	_sp42CurveTimeline_init(SUPER(timeline), frameCount, CURVE1_ENTRIES, bezierCount, ids, 1, type,
						  _sp42CurveTimeline_dispose, _sp42PhysicsConstraintTimeline_apply, _sp42CurveTimeline_setBezier);
	timeline->physicsConstraintIndex = physicsConstraintIndex;
	return timeline;
}

void sp42PhysicsConstraintTimeline_setFrame(sp42PhysicsConstraintTimeline *self, int frame, float time, float value) {
	sp42CurveTimeline1_setFrame(SUPER(self), frame, time, value);
}

/**/
void _sp42PhysicsConstraintResetTimeline_apply(sp42Timeline *timeline, sp42Skeleton *skeleton, float lastTime, float time,
											 sp42Event **firedEvents, int *eventsCount, float alpha, sp42MixBlend blend,
											 sp42MixDirection direction) {
	sp42PhysicsConstraintResetTimeline *self = (sp42PhysicsConstraintResetTimeline *) timeline;
	sp42PhysicsConstraint *constraint = NULL;
	if (self->physicsConstraintIndex != -1) {
		constraint = skeleton->physicsConstraints[self->physicsConstraintIndex];
		if (!constraint->active) return;
	}

	float *frames = SUPER(self)->frames->items;
	if (lastTime > time) {// Apply after lastTime for looped animations.
		_sp42PhysicsConstraintResetTimeline_apply(SUPER(self), skeleton, lastTime, INT_MAX, NULL, 0, alpha, blend, direction);
		lastTime = -1;
	} else if (lastTime >= frames[SUPER(self)->frameCount - 1])// Last time is after last frame.
		return;
	if (time < frames[0]) return;

	if (lastTime < frames[0] || time >= frames[search(self->super.frames, lastTime) + 1]) {
		if (constraint != NULL)
			sp42PhysicsConstraint_reset(constraint);
		else {
			sp42PhysicsConstraint **physicsConstraints = skeleton->physicsConstraints;
			for (int i = 0; i < skeleton->physicsConstraintsCount; i++) {
				constraint = physicsConstraints[i];
				if (constraint->active) sp42PhysicsConstraint_reset(constraint);
			}
		}
	}

	UNUSED(lastTime);
	UNUSED(firedEvents);
	UNUSED(eventsCount);
	UNUSED(alpha);
	UNUSED(direction);
}

void _sp42PhysicsConstraintResetTimeline_dispose(sp42Timeline *timeline) {
	// no-op, sp42Timeline_dispose disposes frames.
	UNUSED(timeline);
}

sp42PhysicsConstraintResetTimeline *sp42PhysicsConstraintResetTimeline_create(int framesCount, int physicsConstraintIndex) {
	sp42PhysicsConstraintResetTimeline *self = NEW(sp42PhysicsConstraintResetTimeline);
	sp42PropertyId ids[1];
	ids[0] = (sp42PropertyId) SP_PROPERTY_PHYSICSCONSTRAINT_RESET << 32;
	_sp42Timeline_init(SUPER(self), framesCount, 1, ids, 1, SP_TIMELINE_PHYSICSCONSTRAINT_RESET, _sp42PhysicsConstraintResetTimeline_dispose,
					 _sp42PhysicsConstraintResetTimeline_apply, 0);

	self->physicsConstraintIndex = physicsConstraintIndex;

	return self;
}

void sp42PhysicsConstraintResetTimeline_setFrame(sp42PhysicsConstraintResetTimeline *self, int frame, float time) {
	self->super.frames->items[frame] = time;
}

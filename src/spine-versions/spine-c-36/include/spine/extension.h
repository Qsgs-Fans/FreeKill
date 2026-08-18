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

/*
 Implementation notes:

 - An OOP style is used where each "class" is made up of a struct and a number of functions prefixed with the struct name.

 - struct fields that are const are readonly. Either they are set in a create function and can never be changed, or they can only
 be changed by calling a function.

 - Inheritance is done using a struct field named "super" as the first field, allowing the struct to be cast to its "super class".
 This works because a pointer to a struct is guaranteed to be a pointer to the first struct field.

 - Classes intended for inheritance provide init/deinit functions which subclasses must call in their create/dispose functions.

 - Polymorphism is done by a base class providing function pointers in its init function. The public API delegates to these
 function pointers.

 - Subclasses do not provide a dispose function, instead the base class' dispose function should be used, which will delegate to
 a dispose function pointer.

 - Classes not designed for inheritance cannot be extended because they may use an internal subclass to hide private data and don't
 expose function pointers.

 - The public API hides implementation details, such as init/deinit functions. An internal API is exposed by extension.h to allow
 classes to be extended. Internal functions begin with underscore (_).

 - OOP in C tends to lose type safety. Macros for casting are provided in extension.h to give context for why a cast is being done.

 - If SPINE_SHORT_NAMES is defined, the "sp" prefix for all class names is optional.
 */

#ifndef SPINE_EXTENSION_H_
#define SPINE_EXTENSION_H_

#include <spine/dll.h>

/* All allocation uses these. */
#define MALLOC(TYPE,COUNT) ((TYPE*)_sp36Malloc(sizeof(TYPE) * (COUNT), __FILE__, __LINE__))
#define CALLOC(TYPE,COUNT) ((TYPE*)_sp36Calloc(COUNT, sizeof(TYPE), __FILE__, __LINE__))
#define REALLOC(PTR,TYPE,COUNT) ((TYPE*)_sp36Realloc(PTR, sizeof(TYPE) * (COUNT)))
#define NEW(TYPE) CALLOC(TYPE,1)

/* Gets the direct super class. Type safe. */
#define SUPER(VALUE) (&VALUE->super)

/* Cast to a super class. Not type safe, use with care. Prefer SUPER() where possible. */
#define SUPER_CAST(TYPE,VALUE) ((TYPE*)VALUE)

/* Cast to a sub class. Not type safe, use with care. */
#define SUB_CAST(TYPE,VALUE) ((TYPE*)VALUE)

/* Casts away const. Can be used as an lvalue. Not type safe, use with care. */
#define CONST_CAST(TYPE,VALUE) (*(TYPE*)&VALUE)

/* Gets the vtable for the specified type. Not type safe, use with care. */
#define VTABLE(TYPE,VALUE) ((_##TYPE##Vtable*)((TYPE*)VALUE)->vtable)

/* Frees memory. Can be used on const types. */
#define FREE(VALUE) _sp36Free((void*)VALUE)

/* Allocates a new char[], assigns it to TO, and copies FROM to it. Can be used on const types. */
#define MALLOC_STR(TO,FROM) strcpy(CONST_CAST(char*, TO) = (char*)MALLOC(char, strlen(FROM) + 1), FROM)

#define PI 3.1415926535897932385f
#define PI2 (PI * 2)
#define DEG_RAD (PI / 180)
#define RAD_DEG (180 / PI)

#define ABS(A) ((A) < 0? -(A): (A))
#define SIGNUM(A) ((A) < 0? -1: (A) > 0 ? 1 : 0)

#ifdef __STDC_VERSION__
#define FMOD(A,B) fmodf(A, B)
#define ATAN2(A,B) atan2f(A, B)
#define SIN(A) sinf(A)
#define COS(A) cosf(A)
#define SQRT(A) sqrtf(A)
#define ACOS(A) acosf(A)
#define POW(A,B) pow(A, B)
#else
#define FMOD(A,B) (float)fmod(A, B)
#define ATAN2(A,B) (float)atan2(A, B)
#define COS(A) (float)cos(A)
#define SIN(A) (float)sin(A)
#define SQRT(A) (float)sqrt(A)
#define ACOS(A) (float)acos(A)
#define POW(A,B) (float)pow(A, B)
#endif

#define SIN_DEG(A) SIN((A) * DEG_RAD)
#define COS_DEG(A) COS((A) * DEG_RAD)
#define CLAMP(x, min, max) ((x) < (min) ? (min) : ((x) > (max) ? (max) : (x)))
#ifndef MIN
#define MIN(x, y) ((x) < (y) ? (x) : (y))
#endif
#ifndef MAX
#define MAX(x, y) ((x) > (y) ? (x) : (y))
#endif

#define UNUSED(x) (void)(x)

#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <spine/Skeleton.h>
#include <spine/Animation.h>
#include <spine/Atlas.h>
#include <spine/AttachmentLoader.h>
#include <spine/VertexAttachment.h>
#include <spine/RegionAttachment.h>
#include <spine/MeshAttachment.h>
#include <spine/BoundingBoxAttachment.h>
#include <spine/ClippingAttachment.h>
#include <spine/PathAttachment.h>
#include <spine/PointAttachment.h>
#include <spine/AnimationState.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Functions that must be implemented:
 */

void _sp36AtlasPage_createTexture (sp36AtlasPage* self, const char* path);
void _sp36AtlasPage_disposeTexture (sp36AtlasPage* self);
char* _sp36Util_readFile (const char* path, int* length);

#ifdef SPINE_SHORT_NAMES
#define _AtlasPage_createTexture(...) _sp36AtlasPage_createTexture(__VA_ARGS__)
#define _AtlasPage_disposeTexture(...) _sp36AtlasPage_disposeTexture(__VA_ARGS__)
#define _Util_readFile(...) _sp36Util_readFile(__VA_ARGS__)
#endif

/*
 * Internal API available for extension:
 */

void* _sp36Malloc (size_t size, const char* file, int line);
void* _sp36Calloc (size_t num, size_t size, const char* file, int line);
void* _sp36Realloc(void* ptr, size_t size);
void _sp36Free (void* ptr);
float _sp36Random ();

SP_API void _sp36SetMalloc (void* (*_malloc) (size_t size));
SP_API void _sp36SetDebugMalloc (void* (*_malloc) (size_t size, const char* file, int line));
SP_API void _sp36SetRealloc(void* (*_realloc) (void* ptr, size_t size));
SP_API void _sp36SetFree (void (*_free) (void* ptr));
SP_API void _sp36SetRandom(float (*_random) ());

char* _sp36ReadFile (const char* path, int* length);


/*
 * Math utilities
 */
float _sp36Math_random(float min, float max);
float _sp36Math_randomTriangular(float min, float max);
float _sp36Math_randomTriangularWith(float min, float max, float mode);
float _sp36Math_interpolate(float (*apply) (float a), float start, float end, float a);
float _sp36Math_pow2_apply(float a);
float _sp36Math_pow2out_apply(float a);

/**/

typedef union _sp36EventQueueItem {
	int type;
	sp36TrackEntry* entry;
	sp36Event* event;
} _sp36EventQueueItem;

typedef struct _sp36AnimationState _sp36AnimationState;

typedef struct _sp36EventQueue {
	_sp36AnimationState* state;
	_sp36EventQueueItem* objects;
	int objectsCount;
	int objectsCapacity;
	int /*boolean*/ drainDisabled;

#ifdef __cplusplus
	_sp36EventQueue() :
		state(0),
		objects(0),
		objectsCount(0),
		objectsCapacity(0),
		drainDisabled(0) {
	}
#endif
} _sp36EventQueue;

struct _sp36AnimationState {
	sp36AnimationState super;

	int eventsCount;
	sp36Event** events;

	_sp36EventQueue* queue;

	int* propertyIDs;
	int propertyIDsCount;
	int propertyIDsCapacity;

	int /*boolean*/ animationsChanged;

#ifdef __cplusplus
	_sp36AnimationState() :
		super(),
		eventsCount(0),
		events(0),
		queue(0),
		propertyIDs(0),
		propertyIDsCount(0),
		propertyIDsCapacity(0),
		animationsChanged(0) {
	}
#endif
};


/**/

/* configureAttachment and disposeAttachment may be 0. */
void _sp36AttachmentLoader_init (sp36AttachmentLoader* self,
	void (*dispose) (sp36AttachmentLoader* self),
	sp36Attachment* (*createAttachment) (sp36AttachmentLoader* self, sp36Skin* skin, sp36AttachmentType type, const char* name,
		const char* path),
	void (*configureAttachment) (sp36AttachmentLoader* self, sp36Attachment*),
	void (*disposeAttachment) (sp36AttachmentLoader* self, sp36Attachment*)
);
void _sp36AttachmentLoader_deinit (sp36AttachmentLoader* self);
/* Can only be called from createAttachment. */
void _sp36AttachmentLoader_setError (sp36AttachmentLoader* self, const char* error1, const char* error2);
void _sp36AttachmentLoader_setUnknownTypeError (sp36AttachmentLoader* self, sp36AttachmentType type);

#ifdef SPINE_SHORT_NAMES
#define _AttachmentLoader_init(...) _sp36AttachmentLoader_init(__VA_ARGS__)
#define _AttachmentLoader_deinit(...) _sp36AttachmentLoader_deinit(__VA_ARGS__)
#define _AttachmentLoader_setError(...) _sp36AttachmentLoader_setError(__VA_ARGS__)
#define _AttachmentLoader_setUnknownTypeError(...) _sp36AttachmentLoader_setUnknownTypeError(__VA_ARGS__)
#endif

/**/

void _sp36Attachment_init (sp36Attachment* self, const char* name, sp36AttachmentType type,
void (*dispose) (sp36Attachment* self));
void _sp36Attachment_deinit (sp36Attachment* self);
void _sp36VertexAttachment_init (sp36VertexAttachment* self);
void _sp36VertexAttachment_deinit (sp36VertexAttachment* self);

#ifdef SPINE_SHORT_NAMES
#define _Attachment_init(...) _sp36Attachment_init(__VA_ARGS__)
#define _Attachment_deinit(...) _sp36Attachment_deinit(__VA_ARGS__)
#define _VertexAttachment_deinit(...) _sp36VertexAttachment_deinit(__VA_ARGS__)
#endif

/**/

void _sp36Timeline_init (sp36Timeline* self, sp36TimelineType type,
	void (*dispose) (sp36Timeline* self),
	void (*apply) (const sp36Timeline* self, sp36Skeleton* skeleton, float lastTime, float time, sp36Event** firedEvents,
		int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction),
	int (*getPropertyId) (const sp36Timeline* self));
void _sp36Timeline_deinit (sp36Timeline* self);

#ifdef SPINE_SHORT_NAMES
#define _Timeline_init(...) _sp36Timeline_init(__VA_ARGS__)
#define _Timeline_deinit(...) _sp36Timeline_deinit(__VA_ARGS__)
#endif

/**/

void _sp36CurveTimeline_init (sp36CurveTimeline* self, sp36TimelineType type, int framesCount,
	void (*dispose) (sp36Timeline* self),
	void (*apply) (const sp36Timeline* self, sp36Skeleton* skeleton, float lastTime, float time, sp36Event** firedEvents, int* eventsCount, float alpha, sp36MixPose pose, sp36MixDirection direction),
	int (*getPropertyId) (const sp36Timeline* self));
void _sp36CurveTimeline_deinit (sp36CurveTimeline* self);
int _sp36CurveTimeline_binarySearch (float *values, int valuesLength, float target, int step);

#ifdef SPINE_SHORT_NAMES
#define _CurveTimeline_init(...) _sp36CurveTimeline_init(__VA_ARGS__)
#define _CurveTimeline_deinit(...) _sp36CurveTimeline_deinit(__VA_ARGS__)
#define _CurveTimeline_binarySearch(...) _sp36CurveTimeline_binarySearch(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_EXTENSION_H_ */

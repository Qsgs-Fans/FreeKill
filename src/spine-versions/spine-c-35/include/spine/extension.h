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

/* All allocation uses these. */
#define MALLOC(TYPE,COUNT) ((TYPE*)_sp35Malloc(sizeof(TYPE) * (COUNT), __FILE__, __LINE__))
#define CALLOC(TYPE,COUNT) ((TYPE*)_sp35Calloc(COUNT, sizeof(TYPE), __FILE__, __LINE__))
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
#define FREE(VALUE) _sp35Free((void*)VALUE)

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
#else
#define FMOD(A,B) (float)fmod(A, B)
#define ATAN2(A,B) (float)atan2(A, B)
#define COS(A) (float)cos(A)
#define SIN(A) (float)sin(A)
#define SQRT(A) (float)sqrt(A)
#define ACOS(A) (float)acos(A)
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
#include <spine/PathAttachment.h>
#include <spine/AnimationState.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Functions that must be implemented:
 */

void _sp35AtlasPage_createTexture (sp35AtlasPage* self, const char* path);
void _sp35AtlasPage_disposeTexture (sp35AtlasPage* self);
char* _sp35Util_readFile (const char* path, int* length);

#ifdef SPINE_SHORT_NAMES
#define _AtlasPage_createTexture(...) _sp35AtlasPage_createTexture(__VA_ARGS__)
#define _AtlasPage_disposeTexture(...) _sp35AtlasPage_disposeTexture(__VA_ARGS__)
#define _Util_readFile(...) _sp35Util_readFile(__VA_ARGS__)
#endif

/*
 * Internal API available for extension:
 */

void* _sp35Malloc (size_t size, const char* file, int line);
void* _sp35Calloc (size_t num, size_t size, const char* file, int line);
void _sp35Free (void* ptr);

void _sp35SetMalloc (void* (*_sp35Malloc) (size_t size));
void _sp35SetDebugMalloc (void* (*_sp35Malloc) (size_t size, const char* file, int line));
void _sp35SetFree (void (*_sp35Free) (void* ptr));

char* _sp35ReadFile (const char* path, int* length);

/**/

typedef union _sp35EventQueueItem {
	int type;
	sp35TrackEntry* entry;
	sp35Event* event;
} _sp35EventQueueItem;

typedef struct _sp35AnimationState _sp35AnimationState;

typedef struct _sp35EventQueue {
	_sp35AnimationState* state;
	_sp35EventQueueItem* objects;
	int objectsCount;
	int objectsCapacity;
	int /*boolean*/ drainDisabled;

#ifdef __cplusplus
	_sp35EventQueue() :
		state(0),
		objects(0),
		objectsCount(0),
		objectsCapacity(0),
		drainDisabled(0) {
	}
#endif
} _sp35EventQueue;

struct _sp35AnimationState {
	sp35AnimationState super;

	int eventsCount;
	sp35Event** events;

	_sp35EventQueue* queue;

	int* propertyIDs;
	int propertyIDsCount;
	int propertyIDsCapacity;

	int /*boolean*/ animationsChanged;

#ifdef __cplusplus
	_sp35AnimationState() :
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
void _sp35AttachmentLoader_init (sp35AttachmentLoader* self,
	void (*dispose) (sp35AttachmentLoader* self),
	sp35Attachment* (*createAttachment) (sp35AttachmentLoader* self, sp35Skin* skin, sp35AttachmentType type, const char* name,
		const char* path),
	void (*configureAttachment) (sp35AttachmentLoader* self, sp35Attachment*),
	void (*disposeAttachment) (sp35AttachmentLoader* self, sp35Attachment*)
);
void _sp35AttachmentLoader_deinit (sp35AttachmentLoader* self);
/* Can only be called from createAttachment. */
void _sp35AttachmentLoader_setError (sp35AttachmentLoader* self, const char* error1, const char* error2);
void _sp35AttachmentLoader_setUnknownTypeError (sp35AttachmentLoader* self, sp35AttachmentType type);

#ifdef SPINE_SHORT_NAMES
#define _AttachmentLoader_init(...) _sp35AttachmentLoader_init(__VA_ARGS__)
#define _AttachmentLoader_deinit(...) _sp35AttachmentLoader_deinit(__VA_ARGS__)
#define _AttachmentLoader_setError(...) _sp35AttachmentLoader_setError(__VA_ARGS__)
#define _AttachmentLoader_setUnknownTypeError(...) _sp35AttachmentLoader_setUnknownTypeError(__VA_ARGS__)
#endif

/**/

void _sp35Attachment_init (sp35Attachment* self, const char* name, sp35AttachmentType type,
void (*dispose) (sp35Attachment* self));
void _sp35Attachment_deinit (sp35Attachment* self);
void _sp35VertexAttachment_deinit (sp35VertexAttachment* self);

#ifdef SPINE_SHORT_NAMES
#define _Attachment_init(...) _sp35Attachment_init(__VA_ARGS__)
#define _Attachment_deinit(...) _sp35Attachment_deinit(__VA_ARGS__)
#define _VertexAttachment_deinit(...) _sp35VertexAttachment_deinit(__VA_ARGS__)
#endif

/**/

void _sp35Timeline_init (sp35Timeline* self, sp35TimelineType type,
	void (*dispose) (sp35Timeline* self),
	void (*apply) (const sp35Timeline* self, sp35Skeleton* skeleton, float lastTime, float time, sp35Event** firedEvents,
		int* eventsCount, float alpha, int setupPose, int mixingOut),
	int (*getPropertyId) (const sp35Timeline* self));
void _sp35Timeline_deinit (sp35Timeline* self);

#ifdef SPINE_SHORT_NAMES
#define _Timeline_init(...) _sp35Timeline_init(__VA_ARGS__)
#define _Timeline_deinit(...) _sp35Timeline_deinit(__VA_ARGS__)
#endif

/**/

void _sp35CurveTimeline_init (sp35CurveTimeline* self, sp35TimelineType type, int framesCount,
	void (*dispose) (sp35Timeline* self),
	void (*apply) (const sp35Timeline* self, sp35Skeleton* skeleton, float lastTime, float time, sp35Event** firedEvents, int* eventsCount, float alpha, int setupPose, int mixingOut),
	int (*getPropertyId) (const sp35Timeline* self));
void _sp35CurveTimeline_deinit (sp35CurveTimeline* self);
int _sp35CurveTimeline_binarySearch (float *values, int valuesLength, float target, int step);

#ifdef SPINE_SHORT_NAMES
#define _CurveTimeline_init(...) _sp35CurveTimeline_init(__VA_ARGS__)
#define _CurveTimeline_deinit(...) _sp35CurveTimeline_deinit(__VA_ARGS__)
#define _CurveTimeline_binarySearch(...) _sp35CurveTimeline_binarySearch(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_EXTENSION_H_ */

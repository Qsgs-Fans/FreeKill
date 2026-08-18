/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated September 24, 2021. Replaces all prior versions.
 *
 * Copyright (c) 2013-2021, Esoteric Software LLC
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

 */

#ifndef SPINE_EXTENSION_H_
#define SPINE_EXTENSION_H_

#include <spine/dll.h>

/* Required for sprintf and consorts on MSVC */
#ifdef _MSC_VER
#pragma warning(disable:4996)
#endif

/* All allocation uses these. */
#define MALLOC(TYPE, COUNT) ((TYPE*)_sp41Malloc(sizeof(TYPE) * (COUNT), __FILE__, __LINE__))
#define CALLOC(TYPE, COUNT) ((TYPE*)_sp41Calloc(COUNT, sizeof(TYPE), __FILE__, __LINE__))
#define REALLOC(PTR, TYPE, COUNT) ((TYPE*)_sp41Realloc(PTR, sizeof(TYPE) * (COUNT)))
#define NEW(TYPE) CALLOC(TYPE,1)

/* Gets the direct super class. Type safe. */
#define SUPER(VALUE) (&VALUE->super)

/* Cast to a super class. Not type safe, use with care. Prefer SUPER() where possible. */
#define SUPER_CAST(TYPE, VALUE) ((TYPE*)VALUE)

/* Cast to a sub class. Not type safe, use with care. */
#define SUB_CAST(TYPE, VALUE) ((TYPE*)VALUE)

/* Casts away const. Can be used as an lvalue. Not type safe, use with care. */
#define CONST_CAST(TYPE, VALUE) (*(TYPE*)&VALUE)

/* Gets the vtable for the specified type. Not type safe, use with care. */
#define VTABLE(TYPE, VALUE) ((_##TYPE##Vtable*)((TYPE*)VALUE)->vtable)

/* Frees memory. Can be used on const types. */
#define FREE(VALUE) _sp41Free((void*)VALUE)

/* Allocates a new char[], assigns it to TO, and copies FROM to it. Can be used on const types. */
#define MALLOC_STR(TO, FROM) strcpy(CONST_CAST(char*, TO) = (char*)MALLOC(char, strlen(FROM) + 1), FROM)

#define PI 3.1415926535897932385f
#define PI2 (PI * 2)
#define DEG_RAD (PI / 180)
#define RAD_DEG (180 / PI)

#define ABS(A) ((A) < 0? -(A): (A))
#define SIGNUM(A) ((A) < 0? -1.0f: (A) > 0 ? 1.0f : 0.0f)

#ifdef __STDC_VERSION__
#define FMOD(A,B) fmodf(A, B)
#define ATAN2(A,B) atan2f(A, B)
#define SIN(A) sinf(A)
#define COS(A) cosf(A)
#define SQRT(A) sqrtf(A)
#define ACOS(A) acosf(A)
#define POW(A,B) pow(A, B)
#define ISNAN(A) (int)isnan(A)
#else
#define FMOD(A, B) (float)fmod(A, B)
#define ATAN2(A, B) (float)atan2(A, B)
#define COS(A) (float)cos(A)
#define SIN(A) (float)sin(A)
#define SQRT(A) (float)sqrt(A)
#define ACOS(A) (float)acos(A)
#define POW(A, B) (float)pow(A, B)
#define ISNAN(A) (int)isnan(A)
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

void _sp41AtlasPage_createTexture(sp41AtlasPage *self, const char *path);

void _sp41AtlasPage_disposeTexture(sp41AtlasPage *self);

char *_sp41Util_readFile(const char *path, int *length);

/*
 * Internal API available for extension:
 */

void *_sp41Malloc(size_t size, const char *file, int line);

void *_sp41Calloc(size_t num, size_t size, const char *file, int line);

void *_sp41Realloc(void *ptr, size_t size);

void _sp41Free(void *ptr);

float _sp41Random();

SP_API void _sp41SetMalloc(void *(*_malloc)(size_t size));

SP_API void _sp41SetDebugMalloc(void *(*_malloc)(size_t size, const char *file, int line));

SP_API void _sp41SetRealloc(void *(*_realloc)(void *ptr, size_t size));

SP_API void _sp41SetFree(void (*_free)(void *ptr));

SP_API void _sp41SetRandom(float (*_random)());

char *_sp41ReadFile(const char *path, int *length);


/*
 * Math utilities
 */
float _sp41Math_random(float min, float max);

float _sp41Math_randomTriangular(float min, float max);

float _sp41Math_randomTriangularWith(float min, float max, float mode);

float _sp41Math_interpolate(float (*apply)(float a), float start, float end, float a);

float _sp41Math_pow2_apply(float a);

float _sp41Math_pow2out_apply(float a);

/**/

typedef union _sp41EventQueueItem {
	int type;
	sp41TrackEntry *entry;
	sp41Event *event;
} _sp41EventQueueItem;

typedef struct _sp41AnimationState _sp41AnimationState;

typedef struct _sp41EventQueue {
	_sp41AnimationState *state;
	_sp41EventQueueItem *objects;
	int objectsCount;
	int objectsCapacity;
	int /*boolean*/ drainDisabled;
} _sp41EventQueue;

struct _sp41AnimationState {
	sp41AnimationState super;

	int eventsCount;
	sp41Event **events;

	_sp41EventQueue *queue;

	sp41PropertyId *propertyIDs;
	int propertyIDsCount;
	int propertyIDsCapacity;

	int /*boolean*/ animationsChanged;
};


/**/

/* configureAttachment and disposeAttachment may be 0. */
void _sp41AttachmentLoader_init(sp41AttachmentLoader *self,
							  void (*dispose)(sp41AttachmentLoader *self),
							  sp41Attachment *(*createAttachment)(sp41AttachmentLoader *self, sp41Skin *skin,
																sp41AttachmentType type, const char *name,
																const char *path, sp41Sequence *sequence),
							  void (*configureAttachment)(sp41AttachmentLoader *self, sp41Attachment *),
							  void (*disposeAttachment)(sp41AttachmentLoader *self, sp41Attachment *)
);

void _sp41AttachmentLoader_deinit(sp41AttachmentLoader *self);

/* Can only be called from createAttachment. */
void _sp41AttachmentLoader_setError(sp41AttachmentLoader *self, const char *error1, const char *error2);

void _sp41AttachmentLoader_setUnknownTypeError(sp41AttachmentLoader *self, sp41AttachmentType type);

/**/

void _sp41Attachment_init(sp41Attachment *self, const char *name, sp41AttachmentType type,
						void (*dispose)(sp41Attachment *self), sp41Attachment *(*copy)(sp41Attachment *self));

void _sp41Attachment_deinit(sp41Attachment *self);

void _sp41VertexAttachment_init(sp41VertexAttachment *self);

void _sp41VertexAttachment_deinit(sp41VertexAttachment *self);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_EXTENSION_H_ */

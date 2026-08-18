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
#define MALLOC(TYPE,COUNT) ((TYPE*)_sp34Malloc(sizeof(TYPE) * (COUNT), __FILE__, __LINE__))
#define CALLOC(TYPE,COUNT) ((TYPE*)_sp34Calloc(COUNT, sizeof(TYPE), __FILE__, __LINE__))
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
#define FREE(VALUE) _sp34Free((void*)VALUE)

/* Allocates a new char[], assigns it to TO, and copies FROM to it. Can be used on const types. */
#define MALLOC_STR(TO,FROM) strcpy(CONST_CAST(char*, TO) = (char*)MALLOC(char, strlen(FROM) + 1), FROM)

#define PI 3.1415926535897932385f
#define PI2 (PI * 2)
#define DEG_RAD (PI / 180)
#define RAD_DEG (180 / PI)

#define ABS(A) ((A) < 0? -(A): (A))

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

void _sp34AtlasPage_createTexture (sp34AtlasPage* self, const char* path);
void _sp34AtlasPage_disposeTexture (sp34AtlasPage* self);
char* _sp34Util_readFile (const char* path, int* length);

#ifdef SPINE_SHORT_NAMES
#define _AtlasPage_createTexture(...) _sp34AtlasPage_createTexture(__VA_ARGS__)
#define _AtlasPage_disposeTexture(...) _sp34AtlasPage_disposeTexture(__VA_ARGS__)
#define _Util_readFile(...) _sp34Util_readFile(__VA_ARGS__)
#endif

/*
 * Internal API available for extension:
 */

void* _sp34Malloc (size_t size, const char* file, int line);
void* _sp34Calloc (size_t num, size_t size, const char* file, int line);
void _sp34Free (void* ptr);

void _sp34SetMalloc (void* (*_sp34Malloc) (size_t size));
void _sp34SetDebugMalloc (void* (*_sp34Malloc) (size_t size, const char* file, int line));
void _sp34SetFree (void (*_sp34Free) (void* ptr));

char* _sp34ReadFile (const char* path, int* length);

/**/

typedef struct _sp34AnimationState {
	sp34AnimationState super;
	sp34Event** events;

	sp34TrackEntry* (*createTrackEntry) (sp34AnimationState* self);
	void (*disposeTrackEntry) (sp34TrackEntry* entry);

#ifdef __cplusplus
	_sp34AnimationState() :
		super(),
		events(0),
		createTrackEntry(0),
		disposeTrackEntry(0) {
	}
#endif
} _sp34AnimationState;

sp34TrackEntry* _sp34TrackEntry_create (sp34AnimationState* self);
void _sp34TrackEntry_dispose (sp34TrackEntry* self);

/**/

/* configureAttachment and disposeAttachment may be 0. */
void _sp34AttachmentLoader_init (sp34AttachmentLoader* self,
	void (*dispose) (sp34AttachmentLoader* self),
	sp34Attachment* (*createAttachment) (sp34AttachmentLoader* self, sp34Skin* skin, sp34AttachmentType type, const char* name,
		const char* path),
	void (*configureAttachment) (sp34AttachmentLoader* self, sp34Attachment*),
	void (*disposeAttachment) (sp34AttachmentLoader* self, sp34Attachment*)
);
void _sp34AttachmentLoader_deinit (sp34AttachmentLoader* self);
/* Can only be called from createAttachment. */
void _sp34AttachmentLoader_setError (sp34AttachmentLoader* self, const char* error1, const char* error2);
void _sp34AttachmentLoader_setUnknownTypeError (sp34AttachmentLoader* self, sp34AttachmentType type);

#ifdef SPINE_SHORT_NAMES
#define _AttachmentLoader_init(...) _sp34AttachmentLoader_init(__VA_ARGS__)
#define _AttachmentLoader_deinit(...) _sp34AttachmentLoader_deinit(__VA_ARGS__)
#define _AttachmentLoader_setError(...) _sp34AttachmentLoader_setError(__VA_ARGS__)
#define _AttachmentLoader_setUnknownTypeError(...) _sp34AttachmentLoader_setUnknownTypeError(__VA_ARGS__)
#endif

/**/

void _sp34Attachment_init (sp34Attachment* self, const char* name, sp34AttachmentType type,
void (*dispose) (sp34Attachment* self));
void _sp34Attachment_deinit (sp34Attachment* self);
void _sp34VertexAttachment_deinit (sp34VertexAttachment* self);

#ifdef SPINE_SHORT_NAMES
#define _Attachment_init(...) _sp34Attachment_init(__VA_ARGS__)
#define _Attachment_deinit(...) _sp34Attachment_deinit(__VA_ARGS__)
#define _VertexAttachment_deinit(...) _sp34VertexAttachment_deinit(__VA_ARGS__)
#endif

/**/

void _sp34Timeline_init (sp34Timeline* self, sp34TimelineType type,
	void (*dispose) (sp34Timeline* self),
	void (*apply) (const sp34Timeline* self, sp34Skeleton* skeleton, float lastTime, float time, sp34Event** firedEvents,
		int* eventsCount, float alpha));
void _sp34Timeline_deinit (sp34Timeline* self);

#ifdef SPINE_SHORT_NAMES
#define _Timeline_init(...) _sp34Timeline_init(__VA_ARGS__)
#define _Timeline_deinit(...) _sp34Timeline_deinit(__VA_ARGS__)
#endif

/**/

void _sp34CurveTimeline_init (sp34CurveTimeline* self, sp34TimelineType type, int framesCount,
	void (*dispose) (sp34Timeline* self),
	void (*apply) (const sp34Timeline* self, sp34Skeleton* skeleton, float lastTime, float time, sp34Event** firedEvents,
		int* eventsCount, float alpha));
void _sp34CurveTimeline_deinit (sp34CurveTimeline* self);

#ifdef SPINE_SHORT_NAMES
#define _CurveTimeline_init(...) _sp34CurveTimeline_init(__VA_ARGS__)
#define _CurveTimeline_deinit(...) _sp34CurveTimeline_deinit(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_EXTENSION_H_ */

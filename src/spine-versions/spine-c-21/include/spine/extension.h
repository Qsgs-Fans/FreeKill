/*
 Implementation notes:

 - An OOP style is used where each "class" is made up of a struct and a number of functions prefixed with the struct name.

 - struct fields that are const are readonly. Either they are set in a create function and can never be changed, or they can only
 be changed by calling a function.

 - Inheritance is done using a struct field named "super" as the first field, allowing the struct to be cast to its "super class".
 This works because a pointer to a struct is guaranteed to be a pointer to the first struct field.

 - Classes intended for inheritance provide init/deinit functions which subclasses must call in their create/dispose functions.

 - Polymorphism is done by a base class providing function pointers in its init function. The public API delegates to this
 function.

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
#define MALLOC(TYPE,COUNT) ((TYPE*)_sp21Malloc(sizeof(TYPE) * COUNT, __FILE__, __LINE__))
#define CALLOC(TYPE,COUNT) ((TYPE*)_sp21Calloc(COUNT, sizeof(TYPE), __FILE__, __LINE__))
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
#define FREE(VALUE) _sp21Free((void*)VALUE)

/* Allocates a new char[], assigns it to TO, and copies FROM to it. Can be used on const types. */
#define MALLOC_STR(TO,FROM) strcpy(CONST_CAST(char*, TO) = (char*)MALLOC(char, strlen(FROM) + 1), FROM)

#define PI 3.1415926535897932385f
#define DEG_RAD (PI / 180)
#define RAD_DEG (180 / PI)

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

#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <spine/Skeleton.h>
#include <spine/Animation.h>
#include <spine/Atlas.h>
#include <spine/AttachmentLoader.h>
#include <spine/RegionAttachment.h>
#include <spine/MeshAttachment.h>
#include <spine/SkinnedMeshAttachment.h>
#include <spine/BoundingBoxAttachment.h>
#include <spine/AnimationState.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Functions that must be implemented:
 */

void _sp21AtlasPage_createTexture (sp21AtlasPage* self, const char* path);
void _sp21AtlasPage_disposeTexture (sp21AtlasPage* self);
char* _sp21Util_readFile (const char* path, int* length);

#ifdef SPINE_SHORT_NAMES
#define _AtlasPage_createTexture(...) _sp21AtlasPage_createTexture(__VA_ARGS__)
#define _AtlasPage_disposeTexture(...) _sp21AtlasPage_disposeTexture(__VA_ARGS__)
#define _Util_readFile(...) _sp21Util_readFile(__VA_ARGS__)
#endif

/*
 * Internal API available for extension:
 */

void* _sp21Malloc (size_t size, const char* file, int line);
void* _sp21Calloc (size_t num, size_t size, const char* file, int line);
void _sp21Free (void* ptr);

void _sp21SetMalloc (void* (*_sp21Malloc) (size_t size));
void _sp21SetDebugMalloc (void* (*_sp21Malloc) (size_t size, const char* file, int line));
void _sp21SetFree (void (*_sp21Free) (void* ptr));

char* _sp21ReadFile (const char* path, int* length);

/**/

typedef struct _sp21AnimationState {
	sp21AnimationState super;
	sp21Event** events;

	sp21TrackEntry* (*createTrackEntry) (sp21AnimationState* self);
	void (*disposeTrackEntry) (sp21TrackEntry* entry);

#ifdef __cplusplus
	_sp21AnimationState() :
		super(),
		events(0),
		createTrackEntry(0),
		disposeTrackEntry(0) {
	}
#endif
} _sp21AnimationState;

sp21TrackEntry* _sp21TrackEntry_create (sp21AnimationState* self);
void _sp21TrackEntry_dispose (sp21TrackEntry* self);

/**/

void _sp21AttachmentLoader_init (sp21AttachmentLoader* self, /**/
void (*dispose) (sp21AttachmentLoader* self), /**/
		sp21Attachment* (*newAttachment) (sp21AttachmentLoader* self, sp21Skin* skin, sp21AttachmentType type, const char* name,
				const char* path));
void _sp21AttachmentLoader_deinit (sp21AttachmentLoader* self);
void _sp21AttachmentLoader_setError (sp21AttachmentLoader* self, const char* error1, const char* error2);
void _sp21AttachmentLoader_setUnknownTypeError (sp21AttachmentLoader* self, sp21AttachmentType type);

#ifdef SPINE_SHORT_NAMES
#define _AttachmentLoader_init(...) _sp21AttachmentLoader_init(__VA_ARGS__)
#define _AttachmentLoader_deinit(...) _sp21AttachmentLoader_deinit(__VA_ARGS__)
#define _AttachmentLoader_setError(...) _sp21AttachmentLoader_setError(__VA_ARGS__)
#define _AttachmentLoader_setUnknownTypeError(...) _sp21AttachmentLoader_setUnknownTypeError(__VA_ARGS__)
#endif

/**/

void _sp21Attachment_init (sp21Attachment* self, const char* name, sp21AttachmentType type, /**/
void (*dispose) (sp21Attachment* self));
void _sp21Attachment_deinit (sp21Attachment* self);

#ifdef SPINE_SHORT_NAMES
#define _Attachment_init(...) _sp21Attachment_init(__VA_ARGS__)
#define _Attachment_deinit(...) _sp21Attachment_deinit(__VA_ARGS__)
#endif

/**/

void _sp21Timeline_init (sp21Timeline* self, sp21TimelineType type, /**/
void (*dispose) (sp21Timeline* self), /**/
		void (*apply) (const sp21Timeline* self, sp21Skeleton* skeleton, float lastTime, float time, sp21Event** firedEvents,
				int* eventsCount, float alpha));
void _sp21Timeline_deinit (sp21Timeline* self);

#ifdef SPINE_SHORT_NAMES
#define _Timeline_init(...) _sp21Timeline_init(__VA_ARGS__)
#define _Timeline_deinit(...) _sp21Timeline_deinit(__VA_ARGS__)
#endif

/**/

void _sp21CurveTimeline_init (sp21CurveTimeline* self, sp21TimelineType type, int framesCount, /**/
void (*dispose) (sp21Timeline* self), /**/
		void (*apply) (const sp21Timeline* self, sp21Skeleton* skeleton, float lastTime, float time, sp21Event** firedEvents,
				int* eventsCount, float alpha));
void _sp21CurveTimeline_deinit (sp21CurveTimeline* self);

#ifdef SPINE_SHORT_NAMES
#define _CurveTimeline_init(...) _sp21CurveTimeline_init(__VA_ARGS__)
#define _CurveTimeline_deinit(...) _sp21CurveTimeline_deinit(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_EXTENSION_H_ */

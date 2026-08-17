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

#ifndef SPINE_ATLAS_H_
#define SPINE_ATLAS_H_

#include <spine/dll.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp37Atlas sp37Atlas;

typedef enum {
	SP_ATLAS_UNKNOWN_FORMAT,
	SP_ATLAS_ALPHA,
	SP_ATLAS_INTENSITY,
	SP_ATLAS_LUMINANCE_ALPHA,
	SP_ATLAS_RGB565,
	SP_ATLAS_RGBA4444,
	SP_ATLAS_RGB888,
	SP_ATLAS_RGBA8888
} sp37AtlasFormat;

typedef enum {
	SP_ATLAS_UNKNOWN_FILTER,
	SP_ATLAS_NEAREST,
	SP_ATLAS_LINEAR,
	SP_ATLAS_MIPMAP,
	SP_ATLAS_MIPMAP_NEAREST_NEAREST,
	SP_ATLAS_MIPMAP_LINEAR_NEAREST,
	SP_ATLAS_MIPMAP_NEAREST_LINEAR,
	SP_ATLAS_MIPMAP_LINEAR_LINEAR
} sp37AtlasFilter;

typedef enum {
	SP_ATLAS_MIRROREDREPEAT,
	SP_ATLAS_CLAMPTOEDGE,
	SP_ATLAS_REPEAT
} sp37AtlasWrap;

typedef struct sp37AtlasPage sp37AtlasPage;
struct sp37AtlasPage {
	const sp37Atlas* atlas;
	const char* name;
	sp37AtlasFormat format;
	sp37AtlasFilter minFilter, magFilter;
	sp37AtlasWrap uWrap, vWrap;

	void* rendererObject;
	int width, height;

	sp37AtlasPage* next;
};

SP_API sp37AtlasPage* sp37AtlasPage_create (sp37Atlas* atlas, const char* name);
SP_API void sp37AtlasPage_dispose (sp37AtlasPage* self);

#ifdef SPINE_SHORT_NAMES
typedef sp37AtlasFormat AtlasFormat;
#define ATLAS_UNKNOWN_FORMAT SP_ATLAS_UNKNOWN_FORMAT
#define ATLAS_ALPHA SP_ATLAS_ALPHA
#define ATLAS_INTENSITY SP_ATLAS_INTENSITY
#define ATLAS_LUMINANCE_ALPHA SP_ATLAS_LUMINANCE_ALPHA
#define ATLAS_RGB565 SP_ATLAS_RGB565
#define ATLAS_RGBA4444 SP_ATLAS_RGBA4444
#define ATLAS_RGB888 SP_ATLAS_RGB888
#define ATLAS_RGBA8888 SP_ATLAS_RGBA8888
typedef sp37AtlasFilter AtlasFilter;
#define ATLAS_UNKNOWN_FILTER SP_ATLAS_UNKNOWN_FILTER
#define ATLAS_NEAREST SP_ATLAS_NEAREST
#define ATLAS_LINEAR SP_ATLAS_LINEAR
#define ATLAS_MIPMAP SP_ATLAS_MIPMAP
#define ATLAS_MIPMAP_NEAREST_NEAREST SP_ATLAS_MIPMAP_NEAREST_NEAREST
#define ATLAS_MIPMAP_LINEAR_NEAREST SP_ATLAS_MIPMAP_LINEAR_NEAREST
#define ATLAS_MIPMAP_NEAREST_LINEAR SP_ATLAS_MIPMAP_NEAREST_LINEAR
#define ATLAS_MIPMAP_LINEAR_LINEAR SP_ATLAS_MIPMAP_LINEAR_LINEAR
typedef sp37AtlasWrap AtlasWrap;
#define ATLAS_MIRROREDREPEAT SP_ATLAS_MIRROREDREPEAT
#define ATLAS_CLAMPTOEDGE SP_ATLAS_CLAMPTOEDGE
#define ATLAS_REPEAT SP_ATLAS_REPEAT
typedef sp37AtlasPage AtlasPage;
#define AtlasPage_create(...) sp37AtlasPage_create(__VA_ARGS__)
#define AtlasPage_dispose(...) sp37AtlasPage_dispose(__VA_ARGS__)
#endif

/**/

typedef struct sp37AtlasRegion sp37AtlasRegion;
struct sp37AtlasRegion {
	const char* name;
	int x, y, width, height;
	float u, v, u2, v2;
	int offsetX, offsetY;
	int originalWidth, originalHeight;
	int index;
	int/*bool*/rotate;
	int/*bool*/flip;
	int* splits;
	int* pads;

	sp37AtlasPage* page;

	sp37AtlasRegion* next;
};

SP_API sp37AtlasRegion* sp37AtlasRegion_create ();
SP_API void sp37AtlasRegion_dispose (sp37AtlasRegion* self);

#ifdef SPINE_SHORT_NAMES
typedef sp37AtlasRegion AtlasRegion;
#define AtlasRegion_create(...) sp37AtlasRegion_create(__VA_ARGS__)
#define AtlasRegion_dispose(...) sp37AtlasRegion_dispose(__VA_ARGS__)
#endif

/**/

struct sp37Atlas {
	sp37AtlasPage* pages;
	sp37AtlasRegion* regions;

	void* rendererObject;
};

/* Image files referenced in the atlas file will be prefixed with dir. */
SP_API sp37Atlas* sp37Atlas_create (const char* data, int length, const char* dir, void* rendererObject);
/* Image files referenced in the atlas file will be prefixed with the directory containing the atlas file. */
SP_API sp37Atlas* sp37Atlas_createFromFile (const char* path, void* rendererObject);
SP_API void sp37Atlas_dispose (sp37Atlas* atlas);

/* Returns 0 if the region was not found. */
SP_API sp37AtlasRegion* sp37Atlas_findRegion (const sp37Atlas* self, const char* name);

#ifdef SPINE_SHORT_NAMES
typedef sp37Atlas Atlas;
#define Atlas_create(...) sp37Atlas_create(__VA_ARGS__)
#define Atlas_createFromFile(...) sp37Atlas_createFromFile(__VA_ARGS__)
#define Atlas_dispose(...) sp37Atlas_dispose(__VA_ARGS__)
#define Atlas_findRegion(...) sp37Atlas_findRegion(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ATLAS_H_ */

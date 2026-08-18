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

#ifndef SPINE_ATLAS_H_
#define SPINE_ATLAS_H_

#include <spine/dll.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp36Atlas sp36Atlas;

typedef enum {
	SP_ATLAS_UNKNOWN_FORMAT,
	SP_ATLAS_ALPHA,
	SP_ATLAS_INTENSITY,
	SP_ATLAS_LUMINANCE_ALPHA,
	SP_ATLAS_RGB565,
	SP_ATLAS_RGBA4444,
	SP_ATLAS_RGB888,
	SP_ATLAS_RGBA8888
} sp36AtlasFormat;

typedef enum {
	SP_ATLAS_UNKNOWN_FILTER,
	SP_ATLAS_NEAREST,
	SP_ATLAS_LINEAR,
	SP_ATLAS_MIPMAP,
	SP_ATLAS_MIPMAP_NEAREST_NEAREST,
	SP_ATLAS_MIPMAP_LINEAR_NEAREST,
	SP_ATLAS_MIPMAP_NEAREST_LINEAR,
	SP_ATLAS_MIPMAP_LINEAR_LINEAR
} sp36AtlasFilter;

typedef enum {
	SP_ATLAS_MIRROREDREPEAT,
	SP_ATLAS_CLAMPTOEDGE,
	SP_ATLAS_REPEAT
} sp36AtlasWrap;

typedef struct sp36AtlasPage sp36AtlasPage;
struct sp36AtlasPage {
	const sp36Atlas* atlas;
	const char* name;
	sp36AtlasFormat format;
	sp36AtlasFilter minFilter, magFilter;
	sp36AtlasWrap uWrap, vWrap;

	void* rendererObject;
	int width, height;

	sp36AtlasPage* next;
};

SP_API sp36AtlasPage* sp36AtlasPage_create (sp36Atlas* atlas, const char* name);
SP_API void sp36AtlasPage_dispose (sp36AtlasPage* self);

#ifdef SPINE_SHORT_NAMES
typedef sp36AtlasFormat AtlasFormat;
#define ATLAS_UNKNOWN_FORMAT SP_ATLAS_UNKNOWN_FORMAT
#define ATLAS_ALPHA SP_ATLAS_ALPHA
#define ATLAS_INTENSITY SP_ATLAS_INTENSITY
#define ATLAS_LUMINANCE_ALPHA SP_ATLAS_LUMINANCE_ALPHA
#define ATLAS_RGB565 SP_ATLAS_RGB565
#define ATLAS_RGBA4444 SP_ATLAS_RGBA4444
#define ATLAS_RGB888 SP_ATLAS_RGB888
#define ATLAS_RGBA8888 SP_ATLAS_RGBA8888
typedef sp36AtlasFilter AtlasFilter;
#define ATLAS_UNKNOWN_FILTER SP_ATLAS_UNKNOWN_FILTER
#define ATLAS_NEAREST SP_ATLAS_NEAREST
#define ATLAS_LINEAR SP_ATLAS_LINEAR
#define ATLAS_MIPMAP SP_ATLAS_MIPMAP
#define ATLAS_MIPMAP_NEAREST_NEAREST SP_ATLAS_MIPMAP_NEAREST_NEAREST
#define ATLAS_MIPMAP_LINEAR_NEAREST SP_ATLAS_MIPMAP_LINEAR_NEAREST
#define ATLAS_MIPMAP_NEAREST_LINEAR SP_ATLAS_MIPMAP_NEAREST_LINEAR
#define ATLAS_MIPMAP_LINEAR_LINEAR SP_ATLAS_MIPMAP_LINEAR_LINEAR
typedef sp36AtlasWrap AtlasWrap;
#define ATLAS_MIRROREDREPEAT SP_ATLAS_MIRROREDREPEAT
#define ATLAS_CLAMPTOEDGE SP_ATLAS_CLAMPTOEDGE
#define ATLAS_REPEAT SP_ATLAS_REPEAT
typedef sp36AtlasPage AtlasPage;
#define AtlasPage_create(...) sp36AtlasPage_create(__VA_ARGS__)
#define AtlasPage_dispose(...) sp36AtlasPage_dispose(__VA_ARGS__)
#endif

/**/

typedef struct sp36AtlasRegion sp36AtlasRegion;
struct sp36AtlasRegion {
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

	sp36AtlasPage* page;

	sp36AtlasRegion* next;
};

SP_API sp36AtlasRegion* sp36AtlasRegion_create ();
SP_API void sp36AtlasRegion_dispose (sp36AtlasRegion* self);

#ifdef SPINE_SHORT_NAMES
typedef sp36AtlasRegion AtlasRegion;
#define AtlasRegion_create(...) sp36AtlasRegion_create(__VA_ARGS__)
#define AtlasRegion_dispose(...) sp36AtlasRegion_dispose(__VA_ARGS__)
#endif

/**/

struct sp36Atlas {
	sp36AtlasPage* pages;
	sp36AtlasRegion* regions;

	void* rendererObject;
};

/* Image files referenced in the atlas file will be prefixed with dir. */
SP_API sp36Atlas* sp36Atlas_create (const char* data, int length, const char* dir, void* rendererObject);
/* Image files referenced in the atlas file will be prefixed with the directory containing the atlas file. */
SP_API sp36Atlas* sp36Atlas_createFromFile (const char* path, void* rendererObject);
SP_API void sp36Atlas_dispose (sp36Atlas* atlas);

/* Returns 0 if the region was not found. */
SP_API sp36AtlasRegion* sp36Atlas_findRegion (const sp36Atlas* self, const char* name);

#ifdef SPINE_SHORT_NAMES
typedef sp36Atlas Atlas;
#define Atlas_create(...) sp36Atlas_create(__VA_ARGS__)
#define Atlas_createFromFile(...) sp36Atlas_createFromFile(__VA_ARGS__)
#define Atlas_dispose(...) sp36Atlas_dispose(__VA_ARGS__)
#define Atlas_findRegion(...) sp36Atlas_findRegion(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ATLAS_H_ */

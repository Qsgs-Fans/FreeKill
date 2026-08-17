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

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp34Atlas sp34Atlas;

typedef enum {
	SP_ATLAS_UNKNOWN_FORMAT,
	SP_ATLAS_ALPHA,
	SP_ATLAS_INTENSITY,
	SP_ATLAS_LUMINANCE_ALPHA,
	SP_ATLAS_RGB565,
	SP_ATLAS_RGBA4444,
	SP_ATLAS_RGB888,
	SP_ATLAS_RGBA8888
} sp34AtlasFormat;

typedef enum {
	SP_ATLAS_UNKNOWN_FILTER,
	SP_ATLAS_NEAREST,
	SP_ATLAS_LINEAR,
	SP_ATLAS_MIPMAP,
	SP_ATLAS_MIPMAP_NEAREST_NEAREST,
	SP_ATLAS_MIPMAP_LINEAR_NEAREST,
	SP_ATLAS_MIPMAP_NEAREST_LINEAR,
	SP_ATLAS_MIPMAP_LINEAR_LINEAR
} sp34AtlasFilter;

typedef enum {
	SP_ATLAS_MIRROREDREPEAT,
	SP_ATLAS_CLAMPTOEDGE,
	SP_ATLAS_REPEAT
} sp34AtlasWrap;

typedef struct sp34AtlasPage sp34AtlasPage;
struct sp34AtlasPage {
	const sp34Atlas* atlas;
	const char* name;
	sp34AtlasFormat format;
	sp34AtlasFilter minFilter, magFilter;
	sp34AtlasWrap uWrap, vWrap;

	void* rendererObject;
	int width, height;

	sp34AtlasPage* next;
};

sp34AtlasPage* sp34AtlasPage_create (sp34Atlas* atlas, const char* name);
void sp34AtlasPage_dispose (sp34AtlasPage* self);

#ifdef SPINE_SHORT_NAMES
typedef sp34AtlasFormat AtlasFormat;
#define ATLAS_UNKNOWN_FORMAT SP_ATLAS_UNKNOWN_FORMAT
#define ATLAS_ALPHA SP_ATLAS_ALPHA
#define ATLAS_INTENSITY SP_ATLAS_INTENSITY
#define ATLAS_LUMINANCE_ALPHA SP_ATLAS_LUMINANCE_ALPHA
#define ATLAS_RGB565 SP_ATLAS_RGB565
#define ATLAS_RGBA4444 SP_ATLAS_RGBA4444
#define ATLAS_RGB888 SP_ATLAS_RGB888
#define ATLAS_RGBA8888 SP_ATLAS_RGBA8888
typedef sp34AtlasFilter AtlasFilter;
#define ATLAS_UNKNOWN_FILTER SP_ATLAS_UNKNOWN_FILTER
#define ATLAS_NEAREST SP_ATLAS_NEAREST
#define ATLAS_LINEAR SP_ATLAS_LINEAR
#define ATLAS_MIPMAP SP_ATLAS_MIPMAP
#define ATLAS_MIPMAP_NEAREST_NEAREST SP_ATLAS_MIPMAP_NEAREST_NEAREST
#define ATLAS_MIPMAP_LINEAR_NEAREST SP_ATLAS_MIPMAP_LINEAR_NEAREST
#define ATLAS_MIPMAP_NEAREST_LINEAR SP_ATLAS_MIPMAP_NEAREST_LINEAR
#define ATLAS_MIPMAP_LINEAR_LINEAR SP_ATLAS_MIPMAP_LINEAR_LINEAR
typedef sp34AtlasWrap AtlasWrap;
#define ATLAS_MIRROREDREPEAT SP_ATLAS_MIRROREDREPEAT
#define ATLAS_CLAMPTOEDGE SP_ATLAS_CLAMPTOEDGE
#define ATLAS_REPEAT SP_ATLAS_REPEAT
typedef sp34AtlasPage AtlasPage;
#define AtlasPage_create(...) sp34AtlasPage_create(__VA_ARGS__)
#define AtlasPage_dispose(...) sp34AtlasPage_dispose(__VA_ARGS__)
#endif

/**/

typedef struct sp34AtlasRegion sp34AtlasRegion;
struct sp34AtlasRegion {
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

	sp34AtlasPage* page;

	sp34AtlasRegion* next;
};

sp34AtlasRegion* sp34AtlasRegion_create ();
void sp34AtlasRegion_dispose (sp34AtlasRegion* self);

#ifdef SPINE_SHORT_NAMES
typedef sp34AtlasRegion AtlasRegion;
#define AtlasRegion_create(...) sp34AtlasRegion_create(__VA_ARGS__)
#define AtlasRegion_dispose(...) sp34AtlasRegion_dispose(__VA_ARGS__)
#endif

/**/

struct sp34Atlas {
	sp34AtlasPage* pages;
	sp34AtlasRegion* regions;

	void* rendererObject;
};

/* Image files referenced in the atlas file will be prefixed with dir. */
sp34Atlas* sp34Atlas_create (const char* data, int length, const char* dir, void* rendererObject);
/* Image files referenced in the atlas file will be prefixed with the directory containing the atlas file. */
sp34Atlas* sp34Atlas_createFromFile (const char* path, void* rendererObject);
void sp34Atlas_dispose (sp34Atlas* atlas);

/* Returns 0 if the region was not found. */
sp34AtlasRegion* sp34Atlas_findRegion (const sp34Atlas* self, const char* name);

#ifdef SPINE_SHORT_NAMES
typedef sp34Atlas Atlas;
#define Atlas_create(...) sp34Atlas_create(__VA_ARGS__)
#define Atlas_createFromFile(...) sp34Atlas_createFromFile(__VA_ARGS__)
#define Atlas_dispose(...) sp34Atlas_dispose(__VA_ARGS__)
#define Atlas_findRegion(...) sp34Atlas_findRegion(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ATLAS_H_ */

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

typedef struct sp35Atlas sp35Atlas;

typedef enum {
	SP_ATLAS_UNKNOWN_FORMAT,
	SP_ATLAS_ALPHA,
	SP_ATLAS_INTENSITY,
	SP_ATLAS_LUMINANCE_ALPHA,
	SP_ATLAS_RGB565,
	SP_ATLAS_RGBA4444,
	SP_ATLAS_RGB888,
	SP_ATLAS_RGBA8888
} sp35AtlasFormat;

typedef enum {
	SP_ATLAS_UNKNOWN_FILTER,
	SP_ATLAS_NEAREST,
	SP_ATLAS_LINEAR,
	SP_ATLAS_MIPMAP,
	SP_ATLAS_MIPMAP_NEAREST_NEAREST,
	SP_ATLAS_MIPMAP_LINEAR_NEAREST,
	SP_ATLAS_MIPMAP_NEAREST_LINEAR,
	SP_ATLAS_MIPMAP_LINEAR_LINEAR
} sp35AtlasFilter;

typedef enum {
	SP_ATLAS_MIRROREDREPEAT,
	SP_ATLAS_CLAMPTOEDGE,
	SP_ATLAS_REPEAT
} sp35AtlasWrap;

typedef struct sp35AtlasPage sp35AtlasPage;
struct sp35AtlasPage {
	const sp35Atlas* atlas;
	const char* name;
	sp35AtlasFormat format;
	sp35AtlasFilter minFilter, magFilter;
	sp35AtlasWrap uWrap, vWrap;

	void* rendererObject;
	int width, height;

	sp35AtlasPage* next;
};

sp35AtlasPage* sp35AtlasPage_create (sp35Atlas* atlas, const char* name);
void sp35AtlasPage_dispose (sp35AtlasPage* self);

#ifdef SPINE_SHORT_NAMES
typedef sp35AtlasFormat AtlasFormat;
#define ATLAS_UNKNOWN_FORMAT SP_ATLAS_UNKNOWN_FORMAT
#define ATLAS_ALPHA SP_ATLAS_ALPHA
#define ATLAS_INTENSITY SP_ATLAS_INTENSITY
#define ATLAS_LUMINANCE_ALPHA SP_ATLAS_LUMINANCE_ALPHA
#define ATLAS_RGB565 SP_ATLAS_RGB565
#define ATLAS_RGBA4444 SP_ATLAS_RGBA4444
#define ATLAS_RGB888 SP_ATLAS_RGB888
#define ATLAS_RGBA8888 SP_ATLAS_RGBA8888
typedef sp35AtlasFilter AtlasFilter;
#define ATLAS_UNKNOWN_FILTER SP_ATLAS_UNKNOWN_FILTER
#define ATLAS_NEAREST SP_ATLAS_NEAREST
#define ATLAS_LINEAR SP_ATLAS_LINEAR
#define ATLAS_MIPMAP SP_ATLAS_MIPMAP
#define ATLAS_MIPMAP_NEAREST_NEAREST SP_ATLAS_MIPMAP_NEAREST_NEAREST
#define ATLAS_MIPMAP_LINEAR_NEAREST SP_ATLAS_MIPMAP_LINEAR_NEAREST
#define ATLAS_MIPMAP_NEAREST_LINEAR SP_ATLAS_MIPMAP_NEAREST_LINEAR
#define ATLAS_MIPMAP_LINEAR_LINEAR SP_ATLAS_MIPMAP_LINEAR_LINEAR
typedef sp35AtlasWrap AtlasWrap;
#define ATLAS_MIRROREDREPEAT SP_ATLAS_MIRROREDREPEAT
#define ATLAS_CLAMPTOEDGE SP_ATLAS_CLAMPTOEDGE
#define ATLAS_REPEAT SP_ATLAS_REPEAT
typedef sp35AtlasPage AtlasPage;
#define AtlasPage_create(...) sp35AtlasPage_create(__VA_ARGS__)
#define AtlasPage_dispose(...) sp35AtlasPage_dispose(__VA_ARGS__)
#endif

/**/

typedef struct sp35AtlasRegion sp35AtlasRegion;
struct sp35AtlasRegion {
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

	sp35AtlasPage* page;

	sp35AtlasRegion* next;
};

sp35AtlasRegion* sp35AtlasRegion_create ();
void sp35AtlasRegion_dispose (sp35AtlasRegion* self);

#ifdef SPINE_SHORT_NAMES
typedef sp35AtlasRegion AtlasRegion;
#define AtlasRegion_create(...) sp35AtlasRegion_create(__VA_ARGS__)
#define AtlasRegion_dispose(...) sp35AtlasRegion_dispose(__VA_ARGS__)
#endif

/**/

struct sp35Atlas {
	sp35AtlasPage* pages;
	sp35AtlasRegion* regions;

	void* rendererObject;
};

/* Image files referenced in the atlas file will be prefixed with dir. */
sp35Atlas* sp35Atlas_create (const char* data, int length, const char* dir, void* rendererObject);
/* Image files referenced in the atlas file will be prefixed with the directory containing the atlas file. */
sp35Atlas* sp35Atlas_createFromFile (const char* path, void* rendererObject);
void sp35Atlas_dispose (sp35Atlas* atlas);

/* Returns 0 if the region was not found. */
sp35AtlasRegion* sp35Atlas_findRegion (const sp35Atlas* self, const char* name);

#ifdef SPINE_SHORT_NAMES
typedef sp35Atlas Atlas;
#define Atlas_create(...) sp35Atlas_create(__VA_ARGS__)
#define Atlas_createFromFile(...) sp35Atlas_createFromFile(__VA_ARGS__)
#define Atlas_dispose(...) sp35Atlas_dispose(__VA_ARGS__)
#define Atlas_findRegion(...) sp35Atlas_findRegion(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ATLAS_H_ */

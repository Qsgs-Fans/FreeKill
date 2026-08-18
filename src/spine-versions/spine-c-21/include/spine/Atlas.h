/******************************************************************************
 * Spine Runtimes Software License
 * Version 2.1
 * 
 * Copyright (c) 2013, Esoteric Software
 * All rights reserved.
 * 
 * You are granted a perpetual, non-exclusive, non-sublicensable and
 * non-transferable license to install, execute and perform the Spine Runtimes
 * Software (the "Software") solely for internal use. Without the written
 * permission of Esoteric Software (typically granted by licensing Spine), you
 * may not (a) modify, translate, adapt or otherwise create derivative works,
 * improvements of the Software or develop new applications using the Software
 * or (b) remove, delete, alter or obscure any trademarks or any copyright,
 * trademark, patent or other intellectual property or proprietary rights
 * notices on or in the Software, including any copy thereof. Redistributions
 * in binary or source form must include this license and terms.
 * 
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#ifndef SPINE_ATLAS_H_
#define SPINE_ATLAS_H_

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp21Atlas sp21Atlas;

typedef enum {
	SP_ATLAS_ALPHA,
	SP_ATLAS_INTENSITY,
	SP_ATLAS_LUMINANCE_ALPHA,
	SP_ATLAS_RGB565,
	SP_ATLAS_RGBA4444,
	SP_ATLAS_RGB888,
	SP_ATLAS_RGBA8888
} sp21AtlasFormat;

typedef enum {
	SP_ATLAS_NEAREST,
	SP_ATLAS_LINEAR,
	SP_ATLAS_MIPMAP,
	SP_ATLAS_MIPMAP_NEAREST_NEAREST,
	SP_ATLAS_MIPMAP_LINEAR_NEAREST,
	SP_ATLAS_MIPMAP_NEAREST_LINEAR,
	SP_ATLAS_MIPMAP_LINEAR_LINEAR
} sp21AtlasFilter;

typedef enum {
	SP_ATLAS_MIRROREDREPEAT, SP_ATLAS_CLAMPTOEDGE, SP_ATLAS_REPEAT
} sp21AtlasWrap;

typedef struct sp21AtlasPage sp21AtlasPage;
struct sp21AtlasPage {
	const sp21Atlas* atlas;
	const char* name;
	sp21AtlasFormat format;
	sp21AtlasFilter minFilter, magFilter;
	sp21AtlasWrap uWrap, vWrap;

	void* rendererObject;
	int width, height;

	sp21AtlasPage* next;
};

sp21AtlasPage* sp21AtlasPage_create (sp21Atlas* atlas, const char* name);
void sp21AtlasPage_dispose (sp21AtlasPage* self);

#ifdef SPINE_SHORT_NAMES
typedef sp21AtlasFormat AtlasFormat;
#define ATLAS_ALPHA SP_ATLAS_ALPHA
#define ATLAS_INTENSITY SP_ATLAS_INTENSITY
#define ATLAS_LUMINANCE_ALPHA SP_ATLAS_LUMINANCE_ALPHA
#define ATLAS_RGB565 SP_ATLAS_RGB565
#define ATLAS_RGBA4444 SP_ATLAS_RGBA4444
#define ATLAS_RGB888 SP_ATLAS_RGB888
#define ATLAS_RGBA8888 SP_ATLAS_RGBA8888
typedef sp21AtlasFilter AtlasFilter;
#define ATLAS_NEAREST SP_ATLAS_NEAREST
#define ATLAS_LINEAR SP_ATLAS_LINEAR
#define ATLAS_MIPMAP SP_ATLAS_MIPMAP
#define ATLAS_MIPMAP_NEAREST_NEAREST SP_ATLAS_MIPMAP_NEAREST_NEAREST
#define ATLAS_MIPMAP_LINEAR_NEAREST SP_ATLAS_MIPMAP_LINEAR_NEAREST
#define ATLAS_MIPMAP_NEAREST_LINEAR SP_ATLAS_MIPMAP_NEAREST_LINEAR
#define ATLAS_MIPMAP_LINEAR_LINEAR SP_ATLAS_MIPMAP_LINEAR_LINEAR
typedef sp21AtlasWrap AtlasWrap;
#define ATLAS_MIRROREDREPEAT SP_ATLAS_MIRROREDREPEAT
#define ATLAS_CLAMPTOEDGE SP_ATLAS_CLAMPTOEDGE
#define ATLAS_REPEAT SP_ATLAS_REPEAT
typedef sp21AtlasPage AtlasPage;
#define AtlasPage_create(...) sp21AtlasPage_create(__VA_ARGS__)
#define AtlasPage_dispose(...) sp21AtlasPage_dispose(__VA_ARGS__)
#endif

/**/

typedef struct sp21AtlasRegion sp21AtlasRegion;
struct sp21AtlasRegion {
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

	sp21AtlasPage* page;

	sp21AtlasRegion* next;
};

sp21AtlasRegion* sp21AtlasRegion_create ();
void sp21AtlasRegion_dispose (sp21AtlasRegion* self);

#ifdef SPINE_SHORT_NAMES
typedef sp21AtlasRegion AtlasRegion;
#define AtlasRegion_create(...) sp21AtlasRegion_create(__VA_ARGS__)
#define AtlasRegion_dispose(...) sp21AtlasRegion_dispose(__VA_ARGS__)
#endif

/**/

struct sp21Atlas {
	sp21AtlasPage* pages;
	sp21AtlasRegion* regions;

	void* rendererObject;
};

/* Image files referenced in the atlas file will be prefixed with dir. */
sp21Atlas* sp21Atlas_create (const char* data, int length, const char* dir, void* rendererObject);
/* Image files referenced in the atlas file will be prefixed with the directory containing the atlas file. */
sp21Atlas* sp21Atlas_createFromFile (const char* path, void* rendererObject);
void sp21Atlas_dispose (sp21Atlas* atlas);

/* Returns 0 if the region was not found. */
sp21AtlasRegion* sp21Atlas_findRegion (const sp21Atlas* self, const char* name);

#ifdef SPINE_SHORT_NAMES
typedef sp21Atlas Atlas;
#define Atlas_create(...) sp21Atlas_create(__VA_ARGS__)
#define Atlas_createFromFile(...) sp21Atlas_createFromFile(__VA_ARGS__)
#define Atlas_dispose(...) sp21Atlas_dispose(__VA_ARGS__)
#define Atlas_findRegion(...) sp21Atlas_findRegion(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ATLAS_H_ */

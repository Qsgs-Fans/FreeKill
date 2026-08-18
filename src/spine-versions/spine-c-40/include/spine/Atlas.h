/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated January 1, 2020. Replaces all prior versions.
 *
 * Copyright (c) 2013-2020, Esoteric Software LLC
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

#ifndef SPINE_ATLAS_H_
#define SPINE_ATLAS_H_

#include <spine/dll.h>
#include <spine/Array.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp40Atlas sp40Atlas;

typedef enum {
	SP_ATLAS_UNKNOWN_FORMAT,
	SP_ATLAS_ALPHA,
	SP_ATLAS_INTENSITY,
	SP_ATLAS_LUMINANCE_ALPHA,
	SP_ATLAS_RGB565,
	SP_ATLAS_RGBA4444,
	SP_ATLAS_RGB888,
	SP_ATLAS_RGBA8888
} sp40AtlasFormat;

typedef enum {
	SP_ATLAS_UNKNOWN_FILTER,
	SP_ATLAS_NEAREST,
	SP_ATLAS_LINEAR,
	SP_ATLAS_MIPMAP,
	SP_ATLAS_MIPMAP_NEAREST_NEAREST,
	SP_ATLAS_MIPMAP_LINEAR_NEAREST,
	SP_ATLAS_MIPMAP_NEAREST_LINEAR,
	SP_ATLAS_MIPMAP_LINEAR_LINEAR
} sp40AtlasFilter;

typedef enum {
	SP_ATLAS_MIRROREDREPEAT,
	SP_ATLAS_CLAMPTOEDGE,
	SP_ATLAS_REPEAT
} sp40AtlasWrap;

typedef struct sp40AtlasPage sp40AtlasPage;
struct sp40AtlasPage {
	const sp40Atlas *atlas;
	const char *name;
	sp40AtlasFormat format;
	sp40AtlasFilter minFilter, magFilter;
	sp40AtlasWrap uWrap, vWrap;

	void *rendererObject;
	int width, height;
	int /*boolean*/ pma;

	sp40AtlasPage *next;
};

SP_API sp40AtlasPage *sp40AtlasPage_create(sp40Atlas *atlas, const char *name);

SP_API void sp40AtlasPage_dispose(sp40AtlasPage *self);

/**/
typedef struct sp40KeyValue {
	char *name;
	float values[5];
} sp40KeyValue;
_SP_ARRAY_DECLARE_TYPE(sp40KeyValueArray, sp40KeyValue)

/**/
typedef struct sp40AtlasRegion sp40AtlasRegion;
struct sp40AtlasRegion {
	const char *name;
	int x, y, width, height;
	float u, v, u2, v2;
	int offsetX, offsetY;
	int originalWidth, originalHeight;
	int index;
	int degrees;
	int *splits;
	int *pads;
	sp40KeyValueArray *keyValues;

	sp40AtlasPage *page;

	sp40AtlasRegion *next;
};

SP_API sp40AtlasRegion *sp40AtlasRegion_create();

SP_API void sp40AtlasRegion_dispose(sp40AtlasRegion *self);

/**/

struct sp40Atlas {
	sp40AtlasPage *pages;
	sp40AtlasRegion *regions;

	void *rendererObject;
};

/* Image files referenced in the atlas file will be prefixed with dir. */
SP_API sp40Atlas *sp40Atlas_create(const char *data, int length, const char *dir, void *rendererObject);
/* Image files referenced in the atlas file will be prefixed with the directory containing the atlas file. */
SP_API sp40Atlas *sp40Atlas_createFromFile(const char *path, void *rendererObject);

SP_API void sp40Atlas_dispose(sp40Atlas *atlas);

/* Returns 0 if the region was not found. */
SP_API sp40AtlasRegion *sp40Atlas_findRegion(const sp40Atlas *self, const char *name);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ATLAS_H_ */

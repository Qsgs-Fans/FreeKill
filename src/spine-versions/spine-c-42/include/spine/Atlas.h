/******************************************************************************
 * Spine Runtimes License Agreement
 * Last updated July 28, 2023. Replaces all prior versions.
 *
 * Copyright (c) 2013-2023, Esoteric Software LLC
 *
 * Integration of the Spine Runtimes into software or otherwise creating
 * derivative works of the Spine Runtimes is permitted under the terms and
 * conditions of Section 2 of the Spine Editor License Agreement:
 * http://esotericsoftware.com/spine-editor-license
 *
 * Otherwise, it is permitted to integrate the Spine Runtimes into software or
 * otherwise create derivative works of the Spine Runtimes (collectively,
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
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE
 * SPINE RUNTIMES, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#ifndef SPINE_ATLAS_H_
#define SPINE_ATLAS_H_

#include <spine/dll.h>
#include <spine/Array.h>
#include "TextureRegion.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp42Atlas sp42Atlas;

typedef enum {
	SP_ATLAS_UNKNOWN_FORMAT,
	SP_ATLAS_ALPHA,
	SP_ATLAS_INTENSITY,
	SP_ATLAS_LUMINANCE_ALPHA,
	SP_ATLAS_RGB565,
	SP_ATLAS_RGBA4444,
	SP_ATLAS_RGB888,
	SP_ATLAS_RGBA8888
} sp42AtlasFormat;

typedef enum {
	SP_ATLAS_UNKNOWN_FILTER,
	SP_ATLAS_NEAREST,
	SP_ATLAS_LINEAR,
	SP_ATLAS_MIPMAP,
	SP_ATLAS_MIPMAP_NEAREST_NEAREST,
	SP_ATLAS_MIPMAP_LINEAR_NEAREST,
	SP_ATLAS_MIPMAP_NEAREST_LINEAR,
	SP_ATLAS_MIPMAP_LINEAR_LINEAR
} sp42AtlasFilter;

typedef enum {
	SP_ATLAS_MIRROREDREPEAT,
	SP_ATLAS_CLAMPTOEDGE,
	SP_ATLAS_REPEAT
} sp42AtlasWrap;

typedef struct sp42AtlasPage sp42AtlasPage;
struct sp42AtlasPage {
	sp42Atlas *atlas;
	char *name;
	sp42AtlasFormat format;
	sp42AtlasFilter minFilter, magFilter;
	sp42AtlasWrap uWrap, vWrap;

	void *rendererObject;
	int width, height;
	int /*boolean*/ pma;

	sp42AtlasPage *next;
};

SP_API sp42AtlasPage *sp42AtlasPage_create(sp42Atlas *atlas, const char *name);

SP_API void sp42AtlasPage_dispose(sp42AtlasPage *self);

/**/
typedef struct sp42KeyValue {
	char *name;
	float values[5];
} sp42KeyValue;
_SP_ARRAY_DECLARE_TYPE(sp42KeyValueArray, sp42KeyValue)

/**/
typedef struct sp42AtlasRegion sp42AtlasRegion;
struct sp42AtlasRegion {
	sp42TextureRegion super;
	const char *name;
	int x, y;
	int index;
	int *splits;
	int *pads;
	sp42KeyValueArray *keyValues;

	sp42AtlasPage *page;

	sp42AtlasRegion *next;
};

SP_API sp42AtlasRegion *sp42AtlasRegion_create(void);

SP_API void sp42AtlasRegion_dispose(sp42AtlasRegion *self);

/**/

struct sp42Atlas {
	sp42AtlasPage *pages;
	sp42AtlasRegion *regions;

	void *rendererObject;
};

/* Image files referenced in the atlas file will be prefixed with dir. */
SP_API sp42Atlas *sp42Atlas_create(const char *data, int length, const char *dir, void *rendererObject);
/* Image files referenced in the atlas file will be prefixed with the directory containing the atlas file. */
SP_API sp42Atlas *sp42Atlas_createFromFile(const char *path, void *rendererObject);

SP_API void sp42Atlas_dispose(sp42Atlas *atlas);

/* Returns 0 if the region was not found. */
SP_API sp42AtlasRegion *sp42Atlas_findRegion(const sp42Atlas *self, const char *name);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ATLAS_H_ */

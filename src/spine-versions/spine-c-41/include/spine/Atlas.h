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

#ifndef SPINE_ATLAS_H_
#define SPINE_ATLAS_H_

#include <spine/dll.h>
#include <spine/Array.h>
#include "TextureRegion.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp41Atlas sp41Atlas;

typedef enum {
	SP_ATLAS_UNKNOWN_FORMAT,
	SP_ATLAS_ALPHA,
	SP_ATLAS_INTENSITY,
	SP_ATLAS_LUMINANCE_ALPHA,
	SP_ATLAS_RGB565,
	SP_ATLAS_RGBA4444,
	SP_ATLAS_RGB888,
	SP_ATLAS_RGBA8888
} sp41AtlasFormat;

typedef enum {
	SP_ATLAS_UNKNOWN_FILTER,
	SP_ATLAS_NEAREST,
	SP_ATLAS_LINEAR,
	SP_ATLAS_MIPMAP,
	SP_ATLAS_MIPMAP_NEAREST_NEAREST,
	SP_ATLAS_MIPMAP_LINEAR_NEAREST,
	SP_ATLAS_MIPMAP_NEAREST_LINEAR,
	SP_ATLAS_MIPMAP_LINEAR_LINEAR
} sp41AtlasFilter;

typedef enum {
	SP_ATLAS_MIRROREDREPEAT,
	SP_ATLAS_CLAMPTOEDGE,
	SP_ATLAS_REPEAT
} sp41AtlasWrap;

typedef struct sp41AtlasPage sp41AtlasPage;
struct sp41AtlasPage {
	const sp41Atlas *atlas;
	const char *name;
	sp41AtlasFormat format;
	sp41AtlasFilter minFilter, magFilter;
	sp41AtlasWrap uWrap, vWrap;

	void *rendererObject;
	int width, height;
	int /*boolean*/ pma;

	sp41AtlasPage *next;
};

SP_API sp41AtlasPage *sp41AtlasPage_create(sp41Atlas *atlas, const char *name);

SP_API void sp41AtlasPage_dispose(sp41AtlasPage *self);

/**/
typedef struct sp41KeyValue {
	char *name;
	float values[5];
} sp41KeyValue;
_SP_ARRAY_DECLARE_TYPE(sp41KeyValueArray, sp41KeyValue)

/**/
typedef struct sp41AtlasRegion sp41AtlasRegion;
struct sp41AtlasRegion {
	sp41TextureRegion super;
	const char *name;
	int x, y;
	int index;
	int *splits;
	int *pads;
	sp41KeyValueArray *keyValues;

	sp41AtlasPage *page;

	sp41AtlasRegion *next;
};

SP_API sp41AtlasRegion *sp41AtlasRegion_create();

SP_API void sp41AtlasRegion_dispose(sp41AtlasRegion *self);

/**/

struct sp41Atlas {
	sp41AtlasPage *pages;
	sp41AtlasRegion *regions;

	void *rendererObject;
};

/* Image files referenced in the atlas file will be prefixed with dir. */
SP_API sp41Atlas *sp41Atlas_create(const char *data, int length, const char *dir, void *rendererObject);
/* Image files referenced in the atlas file will be prefixed with the directory containing the atlas file. */
SP_API sp41Atlas *sp41Atlas_createFromFile(const char *path, void *rendererObject);

SP_API void sp41Atlas_dispose(sp41Atlas *atlas);

/* Returns 0 if the region was not found. */
SP_API sp41AtlasRegion *sp41Atlas_findRegion(const sp41Atlas *self, const char *name);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_ATLAS_H_ */

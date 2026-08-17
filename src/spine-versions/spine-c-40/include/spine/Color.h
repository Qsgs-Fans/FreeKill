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

#ifndef SPINE_COLOR_H_
#define SPINE_COLOR_H_

#include <spine/dll.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp40Color {
	float r, g, b, a;
} sp40Color;

/* @param attachmentName May be 0 for no setup pose attachment. */
SP_API sp40Color *sp40Color_create();

SP_API void sp40Color_dispose(sp40Color *self);

SP_API void sp40Color_setFromFloats(sp40Color *color, float r, float g, float b, float a);

SP_API void sp40Color_setFromFloats3(sp40Color *self, float r, float g, float b);

SP_API void sp40Color_setFromColor(sp40Color *color, sp40Color *otherColor);

SP_API void sp40Color_setFromColor3(sp40Color *self, sp40Color *otherColor);

SP_API void sp40Color_addFloats(sp40Color *color, float r, float g, float b, float a);

SP_API void sp40Color_addFloats3(sp40Color *color, float r, float g, float b);

SP_API void sp40Color_addColor(sp40Color *color, sp40Color *otherColor);

SP_API void sp40Color_clamp(sp40Color *color);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_COLOR_H_ */

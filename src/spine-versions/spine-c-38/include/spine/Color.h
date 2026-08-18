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

typedef struct sp38Color {
	float r, g, b, a;

#ifdef __cplusplus
	sp38Color() :
		r(0), g(0), b(0), a(0) {
	}

	bool operator==(const sp38Color& rhs) {
		return r == rhs.r && g == rhs.g && b == rhs.b && a == rhs.a;
	}
#endif
} sp38Color;

/* @param attachmentName May be 0 for no setup pose attachment. */
SP_API sp38Color* sp38Color_create();
SP_API void sp38Color_dispose(sp38Color* self);
SP_API void sp38Color_setFromFloats(sp38Color* color, float r, float g, float b, float a);
SP_API void sp38Color_setFromColor(sp38Color* color, sp38Color* otherColor);
SP_API void sp38Color_addFloats(sp38Color* color, float r, float g, float b, float a);
SP_API void sp38Color_addColor(sp38Color* color, sp38Color* otherColor);
SP_API void sp38Color_clamp(sp38Color* color);

#ifdef SPINE_SHORT_NAMES
typedef sp38Color color;
#define Color_create() sp38Color_create()
#define Color_dispose(...) sp38Color_dispose(__VA_ARGS__)
#define Color_setFromFloats(...) sp38Color_setFromFloats(__VA_ARGS__)
#define Color_setFromColor(...) sp38Color_setFromColor(__VA_ARGS__)
#define Color_addColor(...) sp38Color_addColor(__VA_ARGS__)
#define Color_addFloats(...) sp38Color_addFloats(__VA_ARGS__)
#define Color_clamp(...) sp38Color_clamp(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_COLOR_H_ */

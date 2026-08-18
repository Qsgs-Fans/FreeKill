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

#ifndef SPINE_COLOR_H_
#define SPINE_COLOR_H_

#include <spine/dll.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct sp37Color {
	float r, g, b, a;

#ifdef __cplusplus
	sp37Color() :
		r(0), g(0), b(0), a(0) {
	}

	bool operator==(const sp37Color& rhs) {
		return r == rhs.r && g == rhs.g && b == rhs.b && a == rhs.a;
	}
#endif
} sp37Color;

/* @param attachmentName May be 0 for no setup pose attachment. */
SP_API sp37Color* sp37Color_create();
SP_API void sp37Color_dispose(sp37Color* self);
SP_API void sp37Color_setFromFloats(sp37Color* color, float r, float g, float b, float a);
SP_API void sp37Color_setFromColor(sp37Color* color, sp37Color* otherColor);
SP_API void sp37Color_addFloats(sp37Color* color, float r, float g, float b, float a);
SP_API void sp37Color_addColor(sp37Color* color, sp37Color* otherColor);
SP_API void sp37Color_clamp(sp37Color* color);

#ifdef SPINE_SHORT_NAMES
typedef sp37Color color;
#define Color_create() sp37Color_create()
#define Color_dispose(...) sp37Color_dispose(__VA_ARGS__)
#define Color_setFromFloats(...) sp37Color_setFromFloats(__VA_ARGS__)
#define Color_setFromColor(...) sp37Color_setFromColor(__VA_ARGS__)
#define Color_addColor(...) sp37Color_addColor(__VA_ARGS__)
#define Color_addFloats(...) sp37Color_addFloats(__VA_ARGS__)
#define Color_clamp(...) sp37Color_clamp(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_COLOR_H_ */

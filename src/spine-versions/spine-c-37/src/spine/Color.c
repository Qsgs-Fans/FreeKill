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

#include <spine/Color.h>
#include <spine/extension.h>

sp37Color* sp37Color_create() {
	return MALLOC(sp37Color, 1);
}

void sp37Color_dispose(sp37Color* self) {
	if (self) FREE(self);
}

void sp37Color_setFromFloats(sp37Color* self, float r, float g, float b, float a) {
	self->r = r;
	self->g = g;
	self->b = b;
	self->a = a;
	sp37Color_clamp(self);
}

void sp37Color_setFromColor(sp37Color* self, sp37Color* otherColor) {
	self->r = otherColor->r;
	self->g = otherColor->g;
	self->b = otherColor->b;
	self->a = otherColor->a;
}

void sp37Color_addColor(sp37Color* self, sp37Color* otherColor) {
	self->r += otherColor->r;
	self->g += otherColor->g;
	self->b += otherColor->b;
	self->a += otherColor->a;
	sp37Color_clamp(self);
}

void sp37Color_addFloats(sp37Color* self, float r, float g, float b, float a) {
	self->r += r;
	self->g += g;
	self->b += b;
	self->a += a;
	sp37Color_clamp(self);
}

void sp37Color_clamp(sp37Color* self) {
	if (self->r < 0) self->r = 0;
	else if (self->r > 1) self->r = 1;

	if (self->g < 0) self->g = 0;
	else if (self->g > 1) self->g = 1;

	if (self->b < 0) self->b = 0;
	else if (self->b > 1) self->b = 1;

	if (self->a < 0) self->a = 0;
	else if (self->a > 1) self->a = 1;
}

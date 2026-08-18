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

#include <spine/extension.h>
#include <stdio.h>

float _sp42InternalRandom(void) {
	return rand() / (float) RAND_MAX;
}

static void *(*mallocFunc)(size_t size) = malloc;

static void *(*reallocFunc)(void *ptr, size_t size) = realloc;

static void *(*debugMallocFunc)(size_t size, const char *file, int line) = NULL;

static void (*freeFunc)(void *ptr) = free;

static float (*randomFunc)(void) = _sp42InternalRandom;

void *_sp42Malloc(size_t size, const char *file, int line) {
	if (debugMallocFunc)
		return debugMallocFunc(size, file, line);

	return mallocFunc(size);
}

void *_sp42Calloc(size_t num, size_t size, const char *file, int line) {
	void *ptr = _sp42Malloc(num * size, file, line);
	if (ptr) memset(ptr, 0, num * size);
	return ptr;
}

void *_sp42Realloc(void *ptr, size_t size) {
	return reallocFunc(ptr, size);
}

void _sp42Free(void *ptr) {
	freeFunc(ptr);
}

float _sp42Random(void) {
	return randomFunc();
}

void _sp42SetDebugMalloc(void *(*malloc)(size_t size, const char *file, int line)) {
	debugMallocFunc = malloc;
}

void _sp42SetMalloc(void *(*malloc)(size_t size)) {
	mallocFunc = malloc;
}

void _sp42SetRealloc(void *(*realloc)(void *ptr, size_t size)) {
	reallocFunc = realloc;
}

void _sp42SetFree(void (*free)(void *ptr)) {
	freeFunc = free;
}

void _sp42SetRandom(float (*random)(void)) {
	randomFunc = random;
}

char *_sp42ReadFile(const char *path, int *length) {
	char *data;
	size_t result;
	FILE *file = fopen(path, "rb");
	if (!file) return 0;

	fseek(file, 0, SEEK_END);
	*length = (int) ftell(file);
	fseek(file, 0, SEEK_SET);

	data = MALLOC(char, *length);
	result = fread(data, 1, *length, file);
	UNUSED(result);
	fclose(file);

	return data;
}

float _sp42Math_random(float min, float max) {
	return min + (max - min) * _sp42Random();
}

float _sp42Math_randomTriangular(float min, float max) {
	return _sp42Math_randomTriangularWith(min, max, (min + max) * 0.5f);
}

float _sp42Math_randomTriangularWith(float min, float max, float mode) {
	float u = _sp42Random();
	float d = max - min;
	if (u <= (mode - min) / d) return min + SQRT(u * d * (mode - min));
	return max - SQRT((1 - u) * d * (max - mode));
}

float _sp42Math_interpolate(float (*apply)(float a), float start, float end, float a) {
	return start + (end - start) * apply(a);
}

float _sp42Math_pow2_apply(float a) {
	if (a <= 0.5) return POW(a * 2, 2) / 2;
	return POW((a - 1) * 2, 2) / -2 + 1;
}

float _sp42Math_pow2out_apply(float a) {
	return POW(a - 1, 2) * -1 + 1;
}

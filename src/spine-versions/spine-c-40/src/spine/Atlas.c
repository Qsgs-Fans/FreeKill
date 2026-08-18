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

#include <ctype.h>
#include <spine/Atlas.h>
#include <spine/extension.h>

sp40KeyValueArray *sp40KeyValueArray_create(int initialCapacity) {
	sp40KeyValueArray *array = ((sp40KeyValueArray *) _sp40Calloc(1, sizeof(sp40KeyValueArray), "_file_name_", 39));
	array->size = 0;
	array->capacity = initialCapacity;
	array->items = ((sp40KeyValue *) _sp40Calloc(initialCapacity, sizeof(sp40KeyValue), "_file_name_", 39));
	return array;
}

void sp40KeyValueArray_dispose(sp40KeyValueArray *self) {
	_sp40Free((void *) self->items);
	_sp40Free((void *) self);
}

void sp40KeyValueArray_clear(sp40KeyValueArray *self) { self->size = 0; }

sp40KeyValueArray *sp40KeyValueArray_setSize(sp40KeyValueArray *self, int newSize) {
	self->size = newSize;
	if (self->capacity < newSize) {
		self->capacity = ((8) > ((int) (self->size * 1.75f)) ? (8) : ((int) (self->size * 1.75f)));
		self->items = ((sp40KeyValue *) _sp40Realloc(self->items, sizeof(sp40KeyValue) * (self->capacity)));
	}
	return self;
}

void sp40KeyValueArray_ensureCapacity(sp40KeyValueArray *self, int newCapacity) {
	if (self->capacity >= newCapacity) return;
	self->capacity = newCapacity;
	self->items = ((sp40KeyValue *) _sp40Realloc(self->items, sizeof(sp40KeyValue) * (self->capacity)));
}

void sp40KeyValueArray_add(sp40KeyValueArray *self, sp40KeyValue value) {
	if (self->size == self->capacity) {
		self->capacity = ((8) > ((int) (self->size * 1.75f)) ? (8) : ((int) (self->size * 1.75f)));
		self->items = ((sp40KeyValue *) _sp40Realloc(self->items, sizeof(sp40KeyValue) * (self->capacity)));
	}
	self->items[self->size++] = value;
}

void sp40KeyValueArray_addAll(sp40KeyValueArray *self, sp40KeyValueArray *other) {
	int i = 0;
	for (; i < other->size; i++) { sp40KeyValueArray_add(self, other->items[i]); }
}

void sp40KeyValueArray_addAllValues(sp40KeyValueArray *self, sp40KeyValue *values, int offset, int count) {
	int i = offset, n = offset + count;
	for (; i < n; i++) { sp40KeyValueArray_add(self, values[i]); }
}

int sp40KeyValueArray_contains(sp40KeyValueArray *self, sp40KeyValue value) {
	sp40KeyValue *items = self->items;
	int i, n;
	for (i = 0, n = self->size; i < n; i++) {
		if (!strcmp(items[i].name, value.name)) return -1;
	}
	return 0;
}

sp40KeyValue sp40KeyValueArray_pop(sp40KeyValueArray *self) {
	sp40KeyValue item = self->items[--self->size];
	return item;
}

sp40KeyValue sp40KeyValueArray_peek(sp40KeyValueArray *self) { return self->items[self->size - 1]; }

sp40AtlasPage *sp40AtlasPage_create(sp40Atlas *atlas, const char *name) {
	sp40AtlasPage *self = NEW(sp40AtlasPage);
	CONST_CAST(sp40Atlas *, self->atlas) = atlas;
	MALLOC_STR(self->name, name);
	return self;
}

void sp40AtlasPage_dispose(sp40AtlasPage *self) {
	_sp40AtlasPage_disposeTexture(self);
	FREE(self->name);
	FREE(self);
}

/**/

sp40AtlasRegion *sp40AtlasRegion_create() {
	sp40AtlasRegion *region = NEW(sp40AtlasRegion);
	region->keyValues = sp40KeyValueArray_create(2);
	return region;
}

void sp40AtlasRegion_dispose(sp40AtlasRegion *self) {
	int i, n;
	FREE(self->name);
	FREE(self->splits);
	FREE(self->pads);
	for (i = 0, n = self->keyValues->size; i < n; i++) {
		FREE(self->keyValues->items[i].name);
	}
	sp40KeyValueArray_dispose(self->keyValues);
	FREE(self);
}

/**/

typedef struct SimpleString {
	char *start;
	char *end;
	int length;
} SimpleString;

static SimpleString *ss_trim(SimpleString *self) {
	while (isspace((unsigned char) *self->start) && self->start < self->end)
		self->start++;
	if (self->start == self->end) {
		self->length = self->end - self->start;
		return self;
	}
	self->end--;
	while (((unsigned char) *self->end == '\r') && self->end >= self->start)
		self->end--;
	self->end++;
	self->length = self->end - self->start;
	return self;
}

static int ss_indexOf(SimpleString *self, char needle) {
	char *c = self->start;
	while (c < self->end) {
		if (*c == needle) return c - self->start;
		c++;
	}
	return -1;
}

static int ss_indexOf2(SimpleString *self, char needle, int at) {
	char *c = self->start + at;
	while (c < self->end) {
		if (*c == needle) return c - self->start;
		c++;
	}
	return -1;
}

static SimpleString ss_substr(SimpleString *self, int s, int e) {
	SimpleString result;
	e = s + e;
	result.start = self->start + s;
	result.end = self->start + e;
	result.length = e - s;
	return result;
}

static SimpleString ss_substr2(SimpleString *self, int s) {
	SimpleString result;
	result.start = self->start + s;
	result.end = self->end;
	result.length = result.end - result.start;
	return result;
}

static int /*boolean*/ ss_equals(SimpleString *self, const char *str) {
	int i;
	int otherLen = strlen(str);
	if (self->length != otherLen) return 0;
	for (i = 0; i < self->length; i++) {
		if (self->start[i] != str[i]) return 0;
	}
	return -1;
}

static char *ss_copy(SimpleString *self) {
	char *string = CALLOC(char, self->length + 1);
	memcpy(string, self->start, self->length);
	string[self->length] = '\0';
	return string;
}

static int ss_toInt(SimpleString *self) {
	return (int) strtol(self->start, &self->end, 10);
}

typedef struct AtlasInput {
	const char *start;
	const char *end;
	char *index;
	int length;
	SimpleString line;
} AtlasInput;

static SimpleString *ai_readLine(AtlasInput *self) {
	if (self->index >= self->end) return 0;
	self->line.start = self->index;
	while (self->index < self->end && *self->index != '\n')
		self->index++;
	self->line.end = self->index;
	if (self->index != self->end) self->index++;
	self->line = *ss_trim(&self->line);
	self->line.length = self->line.end - self->line.start;
	return &self->line;
}

static int ai_readEntry(SimpleString entry[5], SimpleString *line) {
	int colon, i, lastMatch;
	SimpleString substr;
	if (line == NULL) return 0;
	ss_trim(line);
	if (line->length == 0) return 0;

	colon = ss_indexOf(line, ':');
	if (colon == -1) return 0;
	substr = ss_substr(line, 0, colon);
	entry[0] = *ss_trim(&substr);
	for (i = 1, lastMatch = colon + 1;; i++) {
		int comma = ss_indexOf2(line, ',', lastMatch);
		if (comma == -1) {
			substr = ss_substr2(line, lastMatch);
			entry[i] = *ss_trim(&substr);
			return i;
		}
		substr = ss_substr(line, lastMatch, comma - lastMatch);
		entry[i] = *ss_trim(&substr);
		lastMatch = comma + 1;
		if (i == 4) return 4;
	}
}

static const char *formatNames[] = {"", "Alpha", "Intensity", "LuminanceAlpha", "RGB565", "RGBA4444", "RGB888",
									"RGBA8888"};
static const char *textureFilterNames[] = {"", "Nearest", "Linear", "MipMap", "MipMapNearestNearest",
										   "MipMapLinearNearest",
										   "MipMapNearestLinear", "MipMapLinearLinear"};

static int indexOf(const char **array, int count, SimpleString *str) {
	int i;
	for (i = 0; i < count; i++)
		if (ss_equals(str, array[i])) return i;
	return 0;
}

sp40Atlas *sp40Atlas_create(const char *begin, int length, const char *dir, void *rendererObject) {
	sp40Atlas *self;
	AtlasInput reader;
	SimpleString *line;
	SimpleString entry[5];
	sp40AtlasPage *page = NULL;
	sp40AtlasPage *lastPage = NULL;
	sp40AtlasRegion *lastRegion = NULL;

	int count;
	int dirLength = (int) strlen(dir);
	int needsSlash = dirLength > 0 && dir[dirLength - 1] != '/' && dir[dirLength - 1] != '\\';

	self = NEW(sp40Atlas);
	self->rendererObject = rendererObject;

	reader.start = begin;
	reader.end = begin + length;
	reader.index = (char *) begin;
	reader.length = length;

	line = ai_readLine(&reader);
	while (line != NULL && line->length == 0)
		line = ai_readLine(&reader);

	while (-1) {
		if (line == NULL || line->length == 0) break;
		if (ai_readEntry(entry, line) == 0) break;
		line = ai_readLine(&reader);
	}

	while (-1) {
		if (line == NULL) break;
		if (ss_trim(line)->length == 0) {
			page = NULL;
			line = ai_readLine(&reader);
		} else if (page == NULL) {
			char *name = ss_copy(line);
			char *path = CALLOC(char, dirLength + needsSlash + strlen(name) + 1);
			memcpy(path, dir, dirLength);
			if (needsSlash) path[dirLength] = '/';
			strcpy(path + dirLength + needsSlash, name);
			page = sp40AtlasPage_create(self, name);
			FREE(name);

			if (lastPage)
				lastPage->next = page;
			else
				self->pages = page;
			lastPage = page;

			while (-1) {
				line = ai_readLine(&reader);
				if (ai_readEntry(entry, line) == 0) break;
				if (ss_equals(&entry[0], "size")) {
					page->width = ss_toInt(&entry[1]);
					page->height = ss_toInt(&entry[2]);
				} else if (ss_equals(&entry[0], "format")) {
					page->format = (sp40AtlasFormat) indexOf(formatNames, 8, &entry[1]);
				} else if (ss_equals(&entry[0], "filter")) {
					page->minFilter = (sp40AtlasFilter) indexOf(textureFilterNames, 8, &entry[1]);
					page->magFilter = (sp40AtlasFilter) indexOf(textureFilterNames, 8, &entry[2]);
				} else if (ss_equals(&entry[0], "repeat")) {
					page->uWrap = SP_ATLAS_CLAMPTOEDGE;
					page->vWrap = SP_ATLAS_CLAMPTOEDGE;
					if (ss_indexOf(&entry[1], 'x') != -1) page->uWrap = SP_ATLAS_REPEAT;
					if (ss_indexOf(&entry[1], 'y') != -1) page->vWrap = SP_ATLAS_REPEAT;
				} else if (ss_equals(&entry[0], "pma")) {
					page->pma = ss_equals(&entry[1], "true");
				}
			}

			_sp40AtlasPage_createTexture(page, path);
			FREE(path);
		} else {
			sp40AtlasRegion *region = sp40AtlasRegion_create();
			if (lastRegion)
				lastRegion->next = region;
			else
				self->regions = region;
			lastRegion = region;
			region->page = page;
			region->name = ss_copy(line);
			while (-1) {
				line = ai_readLine(&reader);
				count = ai_readEntry(entry, line);
				if (count == 0) break;
				if (ss_equals(&entry[0], "xy")) {
					region->x = ss_toInt(&entry[1]);
					region->y = ss_toInt(&entry[2]);
				} else if (ss_equals(&entry[0], "size")) {
					region->width = ss_toInt(&entry[1]);
					region->height = ss_toInt(&entry[2]);
				} else if (ss_equals(&entry[0], "bounds")) {
					region->x = ss_toInt(&entry[1]);
					region->y = ss_toInt(&entry[2]);
					region->width = ss_toInt(&entry[3]);
					region->height = ss_toInt(&entry[4]);
				} else if (ss_equals(&entry[0], "offset")) {
					region->offsetX = ss_toInt(&entry[1]);
					region->offsetY = ss_toInt(&entry[2]);
				} else if (ss_equals(&entry[0], "orig")) {
					region->originalWidth = ss_toInt(&entry[1]);
					region->originalHeight = ss_toInt(&entry[2]);
				} else if (ss_equals(&entry[0], "offsets")) {
					region->offsetX = ss_toInt(&entry[1]);
					region->offsetY = ss_toInt(&entry[2]);
					region->originalWidth = ss_toInt(&entry[3]);
					region->originalHeight = ss_toInt(&entry[4]);
				} else if (ss_equals(&entry[0], "rotate")) {
					if (ss_equals(&entry[1], "true")) {
						region->degrees = 90;
					} else if (!ss_equals(&entry[1], "false")) {
						region->degrees = ss_toInt(&entry[1]);
					}
				} else if (ss_equals(&entry[0], "index")) {
					region->index = ss_toInt(&entry[1]);
				} else {
					int i = 0;
					sp40KeyValue keyValue;
					keyValue.name = ss_copy(&entry[0]);
					for (i = 0; i < count; i++) {
						keyValue.values[i] = ss_toInt(&entry[i + 1]);
					}
					sp40KeyValueArray_add(region->keyValues, keyValue);
				}
			}
			if (region->originalWidth == 0 && region->originalHeight == 0) {
				region->originalWidth = region->width;
				region->originalHeight = region->height;
			}

			region->u = (float) region->x / page->width;
			region->v = (float) region->y / page->height;
			if (region->degrees == 90) {
				region->u2 = (float) (region->x + region->height) / page->width;
				region->v2 = (float) (region->y + region->width) / page->height;
			} else {
				region->u2 = (float) (region->x + region->width) / page->width;
				region->v2 = (float) (region->y + region->height) / page->height;
			}
		}
	}

	return self;
}

sp40Atlas *sp40Atlas_createFromFile(const char *path, void *rendererObject) {
	int dirLength;
	char *dir;
	int length;
	const char *data;

	sp40Atlas *atlas = 0;

	/* Get directory from atlas path. */
	const char *lastForwardSlash = strrchr(path, '/');
	const char *lastBackwardSlash = strrchr(path, '\\');
	const char *lastSlash = lastForwardSlash > lastBackwardSlash ? lastForwardSlash : lastBackwardSlash;
	if (lastSlash == path) lastSlash++; /* Never drop starting slash. */
	dirLength = (int) (lastSlash ? lastSlash - path : 0);
	dir = MALLOC(char, dirLength + 1);
	memcpy(dir, path, dirLength);
	dir[dirLength] = '\0';

	data = _sp40Util_readFile(path, &length);
	if (data) atlas = sp40Atlas_create(data, length, dir, rendererObject);

	FREE(data);
	FREE(dir);
	return atlas;
}

void sp40Atlas_dispose(sp40Atlas *self) {
	sp40AtlasRegion *region, *nextRegion;
	sp40AtlasPage *page = self->pages;
	while (page) {
		sp40AtlasPage *nextPage = page->next;
		sp40AtlasPage_dispose(page);
		page = nextPage;
	}

	region = self->regions;
	while (region) {
		nextRegion = region->next;
		sp40AtlasRegion_dispose(region);
		region = nextRegion;
	}

	FREE(self);
}

sp40AtlasRegion *sp40Atlas_findRegion(const sp40Atlas *self, const char *name) {
	sp40AtlasRegion *region = self->regions;
	while (region) {
		if (strcmp(region->name, name) == 0) return region;
		region = region->next;
	}
	return 0;
}

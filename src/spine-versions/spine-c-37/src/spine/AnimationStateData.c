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

#include <spine/AnimationStateData.h>
#include <spine/extension.h>

typedef struct _ToEntry _ToEntry;
struct _ToEntry {
	sp37Animation* animation;
	float duration;
	_ToEntry* next;
};

static _ToEntry* _ToEntry_create (sp37Animation* to, float duration) {
	_ToEntry* self = NEW(_ToEntry);
	self->animation = to;
	self->duration = duration;
	return self;
}

static void _ToEntry_dispose (_ToEntry* self) {
	FREE(self);
}

/**/

typedef struct _FromEntry _FromEntry;
struct _FromEntry {
	sp37Animation* animation;
	_ToEntry* toEntries;
	_FromEntry* next;
};

static _FromEntry* _FromEntry_create (sp37Animation* from) {
	_FromEntry* self = NEW(_FromEntry);
	self->animation = from;
	return self;
}

static void _FromEntry_dispose (_FromEntry* self) {
	FREE(self);
}

/**/

sp37AnimationStateData* sp37AnimationStateData_create (sp37SkeletonData* skeletonData) {
	sp37AnimationStateData* self = NEW(sp37AnimationStateData);
	CONST_CAST(sp37SkeletonData*, self->skeletonData) = skeletonData;
	return self;
}

void sp37AnimationStateData_dispose (sp37AnimationStateData* self) {
	_ToEntry* toEntry;
	_ToEntry* nextToEntry;
	_FromEntry* nextFromEntry;

	_FromEntry* fromEntry = (_FromEntry*)self->entries;
	while (fromEntry) {
		toEntry = fromEntry->toEntries;
		while (toEntry) {
			nextToEntry = toEntry->next;
			_ToEntry_dispose(toEntry);
			toEntry = nextToEntry;
		}
		nextFromEntry = fromEntry->next;
		_FromEntry_dispose(fromEntry);
		fromEntry = nextFromEntry;
	}

	FREE(self);
}

void sp37AnimationStateData_setMixByName (sp37AnimationStateData* self, const char* fromName, const char* toName, float duration) {
	sp37Animation* to;
	sp37Animation* from = sp37SkeletonData_findAnimation(self->skeletonData, fromName);
	if (!from) return;
	to = sp37SkeletonData_findAnimation(self->skeletonData, toName);
	if (!to) return;
	sp37AnimationStateData_setMix(self, from, to, duration);
}

void sp37AnimationStateData_setMix (sp37AnimationStateData* self, sp37Animation* from, sp37Animation* to, float duration) {
	/* Find existing FromEntry. */
	_ToEntry* toEntry;
	_FromEntry* fromEntry = (_FromEntry*)self->entries;
	while (fromEntry) {
		if (fromEntry->animation == from) {
			/* Find existing ToEntry. */
			toEntry = fromEntry->toEntries;
			while (toEntry) {
				if (toEntry->animation == to) {
					toEntry->duration = duration;
					return;
				}
				toEntry = toEntry->next;
			}
			break; /* Add new ToEntry to the existing FromEntry. */
		}
		fromEntry = fromEntry->next;
	}
	if (!fromEntry) {
		fromEntry = _FromEntry_create(from);
		fromEntry->next = (_FromEntry*)self->entries;
		CONST_CAST(_FromEntry*, self->entries) = fromEntry;
	}
	toEntry = _ToEntry_create(to, duration);
	toEntry->next = fromEntry->toEntries;
	fromEntry->toEntries = toEntry;
}

float sp37AnimationStateData_getMix (sp37AnimationStateData* self, sp37Animation* from, sp37Animation* to) {
	_FromEntry* fromEntry = (_FromEntry*)self->entries;
	while (fromEntry) {
		if (fromEntry->animation == from) {
			_ToEntry* toEntry = fromEntry->toEntries;
			while (toEntry) {
				if (toEntry->animation == to) return toEntry->duration;
				toEntry = toEntry->next;
			}
		}
		fromEntry = fromEntry->next;
	}
	return self->defaultMix;
}

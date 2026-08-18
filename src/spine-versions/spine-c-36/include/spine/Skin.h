/******************************************************************************
 * Spine Runtimes Software License v2.5
 *
 * Copyright (c) 2013-2016, Esoteric Software
 * All rights reserved.
 *
 * You are granted a perpetual, non-exclusive, non-sublicensable, and
 * non-transferable license to use, install, execute, and perform the Spine
 * Runtimes software and derivative works solely for personal or internal
 * use. Without the written permission of Esoteric Software (see Section 2 of
 * the Spine Software License Agreement), you may not (a) modify, translate,
 * adapt, or develop new applications using the Spine Runtimes or otherwise
 * create derivative works or improvements of the Spine Runtimes or (b) remove,
 * delete, alter, or obscure any trademarks or any copyright, trademark, patent,
 * or other intellectual property or proprietary rights notices on or in the
 * Software, including any copy thereof. Redistributions in binary or source
 * form must include this license and terms.
 *
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, BUSINESS INTERRUPTION, OR LOSS OF
 * USE, DATA, OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 * IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#ifndef SPINE_SKIN_H_
#define SPINE_SKIN_H_

#include <spine/dll.h>
#include <spine/Attachment.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Size of hashtable used in skin structure for fast attachment lookup. */
#define SKIN_ENTRIES_HASH_TABLE_SIZE 100

struct sp36Skeleton;

typedef struct sp36Skin {
	const char* const name;

#ifdef __cplusplus
	sp36Skin() :
		name(0) {
	}
#endif
} sp36Skin;

/* Private structs, needed by Skeleton */
typedef struct _Entry _Entry;
struct _Entry {
	int slotIndex;
	const char* name;
	sp36Attachment* attachment;
	_Entry* next;
};

typedef struct _SkinHashTableEntry _SkinHashTableEntry;
struct _SkinHashTableEntry {
	_Entry* entry;
	_SkinHashTableEntry* next;  /* list for elements with same hashes */
};

typedef struct {
	sp36Skin super;
	_Entry* entries; /* entries list stored for getting attachment name by attachment index */
	_SkinHashTableEntry* entriesHashTable[SKIN_ENTRIES_HASH_TABLE_SIZE];  /* hashtable for fast attachment lookup */
} _sp36Skin;

SP_API sp36Skin* sp36Skin_create (const char* name);
SP_API void sp36Skin_dispose (sp36Skin* self);

/* The Skin owns the attachment. */
SP_API void sp36Skin_addAttachment (sp36Skin* self, int slotIndex, const char* name, sp36Attachment* attachment);
/* Returns 0 if the attachment was not found. */
SP_API sp36Attachment* sp36Skin_getAttachment (const sp36Skin* self, int slotIndex, const char* name);

/* Returns 0 if the slot or attachment was not found. */
SP_API const char* sp36Skin_getAttachmentName (const sp36Skin* self, int slotIndex, int attachmentIndex);

/** Attach each attachment in this skin if the corresponding attachment in oldSkin is currently attached. */
SP_API void sp36Skin_attachAll (const sp36Skin* self, struct sp36Skeleton* skeleton, const sp36Skin* oldspSkin);

#ifdef SPINE_SHORT_NAMES
typedef sp36Skin Skin;
#define Skin_create(...) sp36Skin_create(__VA_ARGS__)
#define Skin_dispose(...) sp36Skin_dispose(__VA_ARGS__)
#define Skin_addAttachment(...) sp36Skin_addAttachment(__VA_ARGS__)
#define Skin_getAttachment(...) sp36Skin_getAttachment(__VA_ARGS__)
#define Skin_getAttachmentName(...) sp36Skin_getAttachmentName(__VA_ARGS__)
#define Skin_attachAll(...) sp36Skin_attachAll(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKIN_H_ */

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

#ifndef SPINE_SKIN_H_
#define SPINE_SKIN_H_

#include <spine/dll.h>
#include <spine/Attachment.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Size of hashtable used in skin structure for fast attachment lookup. */
#define SKIN_ENTRIES_HASH_TABLE_SIZE 100

struct sp37Skeleton;

typedef struct sp37Skin {
	const char* const name;

#ifdef __cplusplus
	sp37Skin() :
		name(0) {
	}
#endif
} sp37Skin;

/* Private structs, needed by Skeleton */
typedef struct _Entry _Entry;
struct _Entry {
	int slotIndex;
	const char* name;
	sp37Attachment* attachment;
	_Entry* next;
};

typedef struct _SkinHashTableEntry _SkinHashTableEntry;
struct _SkinHashTableEntry {
	_Entry* entry;
	_SkinHashTableEntry* next;  /* list for elements with same hashes */
};

typedef struct {
	sp37Skin super;
	_Entry* entries; /* entries list stored for getting attachment name by attachment index */
	_SkinHashTableEntry* entriesHashTable[SKIN_ENTRIES_HASH_TABLE_SIZE];  /* hashtable for fast attachment lookup */
} _sp37Skin;

SP_API sp37Skin* sp37Skin_create (const char* name);
SP_API void sp37Skin_dispose (sp37Skin* self);

/* The Skin owns the attachment. */
SP_API void sp37Skin_addAttachment (sp37Skin* self, int slotIndex, const char* name, sp37Attachment* attachment);
/* Returns 0 if the attachment was not found. */
SP_API sp37Attachment* sp37Skin_getAttachment (const sp37Skin* self, int slotIndex, const char* name);

/* Returns 0 if the slot or attachment was not found. */
SP_API const char* sp37Skin_getAttachmentName (const sp37Skin* self, int slotIndex, int attachmentIndex);

/** Attach each attachment in this skin if the corresponding attachment in oldSkin is currently attached. */
SP_API void sp37Skin_attachAll (const sp37Skin* self, struct sp37Skeleton* skeleton, const sp37Skin* oldspSkin);

#ifdef SPINE_SHORT_NAMES
typedef sp37Skin Skin;
#define Skin_create(...) sp37Skin_create(__VA_ARGS__)
#define Skin_dispose(...) sp37Skin_dispose(__VA_ARGS__)
#define Skin_addAttachment(...) sp37Skin_addAttachment(__VA_ARGS__)
#define Skin_getAttachment(...) sp37Skin_getAttachment(__VA_ARGS__)
#define Skin_getAttachmentName(...) sp37Skin_getAttachmentName(__VA_ARGS__)
#define Skin_attachAll(...) sp37Skin_attachAll(__VA_ARGS__)
#endif

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKIN_H_ */

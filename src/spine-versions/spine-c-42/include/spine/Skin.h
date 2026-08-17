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

#ifndef SPINE_SKIN_H_
#define SPINE_SKIN_H_

#include <spine/dll.h>
#include <spine/Attachment.h>
#include <spine/IkConstraintData.h>
#include <spine/TransformConstraintData.h>
#include <spine/PathConstraintData.h>
#include <spine/PhysicsConstraintData.h>
#include <spine/Array.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Size of hashtable used in skin structure for fast attachment lookup. */
#define SKIN_ENTRIES_HASH_TABLE_SIZE 100

struct sp42Skeleton;

_SP_ARRAY_DECLARE_TYPE(sp42BoneDataArray, sp42BoneData*)

_SP_ARRAY_DECLARE_TYPE(sp42IkConstraintDataArray, sp42IkConstraintData*)

_SP_ARRAY_DECLARE_TYPE(sp42TransformConstraintDataArray, sp42TransformConstraintData*)

_SP_ARRAY_DECLARE_TYPE(sp42PathConstraintDataArray, sp42PathConstraintData*)

_SP_ARRAY_DECLARE_TYPE(sp42PhysicsConstraintDataArray, sp42PhysicsConstraintData*)

typedef struct sp42Skin {
	char *name;

	sp42BoneDataArray *bones;
	sp42IkConstraintDataArray *ikConstraints;
	sp42TransformConstraintDataArray *transformConstraints;
	sp42PathConstraintDataArray *pathConstraints;
    sp42PhysicsConstraintDataArray *physicsConstraints;
    sp42Color color;
} sp42Skin;

/* Private structs, needed by Skeleton */
typedef struct _Entry _Entry;
typedef struct _Entry sp42SkinEntry;
struct _Entry {
	int slotIndex;
	char *name;
	sp42Attachment *attachment;
	_Entry *next;
};

typedef struct _SkinHashTableEntry _SkinHashTableEntry;
struct _SkinHashTableEntry {
	_Entry *entry;
	_SkinHashTableEntry *next;
};

typedef struct {
	sp42Skin super;
	_Entry *entries; /* entries list stored for getting attachment name by attachment index */
	_SkinHashTableEntry *entriesHashTable[SKIN_ENTRIES_HASH_TABLE_SIZE]; /* hashtable for fast attachment lookup */
} _sp42Skin;

SP_API sp42Skin *sp42Skin_create(const char *name);

SP_API void sp42Skin_dispose(sp42Skin *self);

/* The Skin owns the attachment. */
SP_API void sp42Skin_setAttachment(sp42Skin *self, int slotIndex, const char *name, sp42Attachment *attachment);
/* Returns 0 if the attachment was not found. */
SP_API sp42Attachment *sp42Skin_getAttachment(const sp42Skin *self, int slotIndex, const char *name);

/* Returns 0 if the slot or attachment was not found. */
SP_API const char *sp42Skin_getAttachmentName(const sp42Skin *self, int slotIndex, int attachmentIndex);

/** Attach each attachment in this skin if the corresponding attachment in oldSkin is currently attached. */
SP_API void sp42Skin_attachAll(const sp42Skin *self, struct sp42Skeleton *skeleton, const sp42Skin *oldspSkin);

/** Adds all attachments, bones, and constraints from the specified skin to this skin. */
SP_API void sp42Skin_addSkin(sp42Skin *self, const sp42Skin *other);

/** Adds all attachments, bones, and constraints from the specified skin to this skin. Attachments are deep copied. */
SP_API void sp42Skin_copySkin(sp42Skin *self, const sp42Skin *other);

/** Returns all attachments in this skin. */
SP_API sp42SkinEntry *sp42Skin_getAttachments(const sp42Skin *self);

/** Clears all attachments, bones, and constraints. */
SP_API void sp42Skin_clear(sp42Skin *self);

#ifdef __cplusplus
}
#endif

#endif /* SPINE_SKIN_H_ */

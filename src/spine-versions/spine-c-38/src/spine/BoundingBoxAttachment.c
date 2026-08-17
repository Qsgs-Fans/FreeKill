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

#include <spine/BoundingBoxAttachment.h>
#include <spine/extension.h>

void _sp38BoundingBoxAttachment_dispose (sp38Attachment* attachment) {
	sp38BoundingBoxAttachment* self = SUB_CAST(sp38BoundingBoxAttachment, attachment);

	_sp38VertexAttachment_deinit(SUPER(self));

	FREE(self);
}

sp38Attachment* _sp38BoundingBoxAttachment_copy (sp38Attachment* attachment) {
	sp38BoundingBoxAttachment* copy = sp38BoundingBoxAttachment_create(attachment->name);
	sp38BoundingBoxAttachment* self = SUB_CAST(sp38BoundingBoxAttachment, attachment);
	sp38VertexAttachment_copyTo(SUPER(self), SUPER(copy));
	return SUPER(SUPER(copy));
}

sp38BoundingBoxAttachment* sp38BoundingBoxAttachment_create (const char* name) {
	sp38BoundingBoxAttachment* self = NEW(sp38BoundingBoxAttachment);
	_sp38VertexAttachment_init(SUPER(self));
	_sp38Attachment_init(SUPER(SUPER(self)), name, SP_ATTACHMENT_BOUNDING_BOX, _sp38BoundingBoxAttachment_dispose, _sp38BoundingBoxAttachment_copy);
	return self;
}

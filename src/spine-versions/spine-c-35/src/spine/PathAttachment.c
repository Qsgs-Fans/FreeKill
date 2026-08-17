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

#include <spine/PathAttachment.h>
#include <spine/extension.h>

void _sp35PathAttachment_dispose (sp35Attachment* attachment) {
	sp35PathAttachment* self = SUB_CAST(sp35PathAttachment, attachment);

	_sp35VertexAttachment_deinit(SUPER(self));

	FREE(self->lengths);
	FREE(self);
}

sp35PathAttachment* sp35PathAttachment_create (const char* name) {
	sp35PathAttachment* self = NEW(sp35PathAttachment);
	_sp35Attachment_init(SUPER(SUPER(self)), name, SP_ATTACHMENT_PATH, _sp35PathAttachment_dispose);
	return self;
}

void sp35PathAttachment_computeWorldVertices (sp35PathAttachment* self, sp35Slot* slot, float* worldVertices) {
	sp35VertexAttachment_computeWorldVertices(SUPER(self), slot, worldVertices);
}

void sp35PathAttachment_computeWorldVertices1 (sp35PathAttachment* self, sp35Slot* slot, int start, int count, float* worldVertices, int offset) {
	sp35VertexAttachment_computeWorldVertices1(SUPER(self), start, count, slot, worldVertices, offset);
}

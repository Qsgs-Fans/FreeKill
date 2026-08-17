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

void _sp34PathAttachment_dispose (sp34Attachment* attachment) {
	sp34PathAttachment* self = SUB_CAST(sp34PathAttachment, attachment);

	_sp34VertexAttachment_deinit(SUPER(self));

	FREE(self->lengths);
	FREE(self);
}

sp34PathAttachment* sp34PathAttachment_create (const char* name) {
	sp34PathAttachment* self = NEW(sp34PathAttachment);
	_sp34Attachment_init(SUPER(SUPER(self)), name, SP_ATTACHMENT_PATH, _sp34PathAttachment_dispose);
	return self;
}

void sp34PathAttachment_computeWorldVertices (sp34PathAttachment* self, sp34Slot* slot, float* worldVertices) {
	sp34VertexAttachment_computeWorldVertices(SUPER(self), slot, worldVertices);
}

void sp34PathAttachment_computeWorldVertices1 (sp34PathAttachment* self, sp34Slot* slot, int start, int count, float* worldVertices, int offset) {
	sp34VertexAttachment_computeWorldVertices1(SUPER(self), start, count, slot, worldVertices, offset);
}

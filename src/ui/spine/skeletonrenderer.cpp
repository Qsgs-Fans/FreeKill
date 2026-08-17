/******************************************************************************
 * Spine Runtimes Software License
 * Version 2.1
 *
 * Copyright (c) 2013, Esoteric Software
 * All rights reserved.
 *
 * You are granted a perpetual, non-exclusive, non-sublicensable and
 * non-transferable license to install, execute and perform the Spine Runtimes
 * Software (the "Software") solely for internal use. Without the written
 * permission of Esoteric Software (typically granted by licensing Spine), you
 * may not (a) modify, translate, adapt or otherwise create derivative works,
 * improvements of the Software or develop new applications using the Software
 * or (b) remove, delete, alter or obscure any trademarks or any copyright,
 * trademark, patent or other intellectual property or proprietary rights
 * notices on or in the Software, including any copy thereof. Redistributions
 * in binary or source form must include this license and terms.
 *
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

#include "skeletonrenderer.h"
#include <QOpenGLFramebufferObject>
#include <QOpenGLTexture>
#include "rendercmdscache.h"
#include "skeletonanimationfbo.h"
#include "texture.h"

SkeletonRenderer::SkeletonRenderer()
{
    mCache = new RenderCmdsCache;
}

SkeletonRenderer::~SkeletonRenderer()
{
    delete mCache;
    releaseTextures();
}

QOpenGLFramebufferObject *SkeletonRenderer::createFramebufferObject(const QSize &size)
{
    QOpenGLFramebufferObjectFormat format;
    format.setAttachment(QOpenGLFramebufferObject::CombinedDepthStencil);
    return new QOpenGLFramebufferObject(size, format);
}

void SkeletonRenderer::render()
{
    mCache->render();
}

void SkeletonRenderer::synchronize(QQuickFramebufferObject *item)
{
    SkeletonAnimationFbo* animation = qobject_cast<SkeletonAnimationFbo*>(item);
    if (!animation)
        return;

    animation->renderToCache(this, mCache);
}

QOpenGLTexture *SkeletonRenderer::getGLTexture(Texture* texture)
{
    if (!texture || texture->name().isEmpty())
        return 0;

    if (mTextureHash.contains(texture->name()))
        return mTextureHash.value(texture->name());

    if (!texture->image())
        return 0;

    QOpenGLTexture* tex = new QOpenGLTexture(*texture->image());
    tex->setMinificationFilter(QOpenGLTexture::LinearMipMapLinear);
    tex->setMagnificationFilter(QOpenGLTexture::Linear);
    tex->setWrapMode(QOpenGLTexture::ClampToEdge);
    mTextureHash.insert(texture->name(), tex);
    return tex;
}

void SkeletonRenderer::releaseTextures()
{
    if (mTextureHash.isEmpty())
        return;

    QHashIterator<QString, QOpenGLTexture*> i(mTextureHash);
    while (i.hasNext()) {
        i.next();
        if (i.value())
            delete i.value();
    }

    mTextureHash.clear();
}

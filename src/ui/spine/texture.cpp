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

#include "texture.h"
#include <QImage>
#include <QFileInfo>
#include <QDir>
#include <QDebug>

Texture::Texture(const QString& filePath)
    :mImage(0)
    ,mName(filePath)
{
    QString resolved = filePath;
    if (!QFileInfo::exists(resolved)) {
        // Android/Linux 文件系统大小写敏感：骨骼皮肤包常在 Windows 上制作，
        // atlas 内部引用的贴图名可能与磁盘实际文件名大小写不一致
        // （例如 atlas 写 *_Ren.png 而文件是 *_ren.png）。若直接按原名打开会
        // 失败 → 纹理为空 → 骨骼渲染成空白。这里在同类目录做一次
        // 不区分大小写的兜底匹配（Windows 上 exists 已通过则跳过，无副作用）。
        const QFileInfo fi(resolved);
        const QDir dir = fi.dir();
        const QString wanted = fi.fileName();
        if (wanted.isEmpty()) {
            qWarning() << "Texture::Texture Error: empty file name. Path:" << filePath;
            return;
        }
        if (dir.exists()) {
            const QStringList entries =
                dir.entryList(QDir::Files | QDir::NoDotAndDotDot);
            for (const QString &e : entries) {
                if (e.compare(wanted, Qt::CaseInsensitive) == 0) {
                    resolved = dir.absoluteFilePath(e);
                    break;
                }
            }
        }
        if (resolved == filePath) {
            qWarning() << "Texture::Texture Error: file not exists. Path:" << filePath;
            return;
        }
    }

    mImage = new QImage(resolved);
    if (mImage->isNull()){
        qWarning() << "Texture::Texture Error: image file isNull. Path:" << resolved;
        delete mImage;
        mImage = 0;
        return;
    }

    mSize = mImage->size();
}

Texture::~Texture()
{
    if (mImage) {
        delete mImage;
        mImage = 0;
    }
}

QSize Texture::size() const
{
    return mSize;
}

QString Texture::name() const
{
    return mName;
}

QImage *Texture::image()
{
    return mImage;
}

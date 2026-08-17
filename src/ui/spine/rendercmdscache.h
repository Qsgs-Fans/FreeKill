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

#ifndef POLYGONBATCH_H
#define POLYGONBATCH_H

#include <QtGlobal>
#include <QColor>
#include <QList>
#include <QRectF>
#include <QOpenGLFunctions>

QT_FORWARD_DECLARE_CLASS(QOpenGLTexture)
QT_FORWARD_DECLARE_CLASS(QOpenGLShaderProgram)

struct Point
{
    Point(float _x, float _y) :x(_x), y(_y) {}
    Point(): x(0.0f), y(0.0f) {}
    GLfloat x;
    GLfloat y;
};

struct TexCoord {
    TexCoord(float _u, float _v): u(_u), v(_v) {}
    TexCoord(): u(0.0f), v(0.0f) {}
    GLfloat u;
    GLfloat v;
};

struct Color
{
    Color(GLubyte _r, GLubyte _g, GLubyte _b, GLubyte _a): r(_r), g(_g), b(_b), a(_a){}
    Color():r(0), g(0), b(0), a(0){}
    GLubyte r;
    GLubyte g;
    GLubyte b;
    GLubyte a;
};

struct Vertex
{
    Point       position;
    Color       color;
    TexCoord    texCoord;
};

class ICachedGLFunctionCall
{
public:
    virtual void invoke() = 0;
    virtual void release();
    virtual ~ICachedGLFunctionCall(){}

    QOpenGLFunctions* glFuncs();
};

class RenderCmdsCache
{
public:
    RenderCmdsCache();
    ~RenderCmdsCache();

    enum ShaderType {
        ShaderTexture,
        ShaderColor
    };

    void clear();

    void blendFunc(GLenum sfactor, GLenum dfactor);
    void bindShader(ShaderType);
    void drawColor(GLubyte r, GLubyte g, GLubyte b, GLubyte a);
    void lineWidth(GLfloat width);
    void pointSize(GLfloat pointSize);

    void drawTriangles(QOpenGLTexture* texture,
                       const float* vertices, const float* uvs, int verticesCount,
                       const unsigned short* triangles, int trianglesCount,
                       const Color& color);
    void drawPoly(const Point* points, int pointCount);
    void drawLine(const Point& origin, const Point& destination);
    void drawPoint(const Point& point);

    void cacheTriangleDrawCall();
    void render();
    void setSkeletonRect(const QRectF& rect);
    void setPremultipliedAlpha(bool premultiplied);

private:
    QList<ICachedGLFunctionCall*> mglFuncs;

    int mCapacity;
    Vertex* mVertices;
    int mVerticesCount;
    GLushort* mTriangles;
    int mTrianglesCount;
    QRectF mRect;

    QOpenGLTexture* mTexture;
    QOpenGLShaderProgram* mTextureShaderProgram;
    QOpenGLShaderProgram* mTextureShaderProgramStraight;
    QOpenGLShaderProgram* mColorShaderProgram;
    bool mPremultipliedAlpha;
};

#endif // POLYGONBATCH_H

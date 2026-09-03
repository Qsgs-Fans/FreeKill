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

#include "rendercmdscache.h"
#include <QOpenGLFunctions>
#include <QOpenGLContext>
#include <QOpenGLTexture>
#include <QOpenGLShaderProgram>

static const char *textureVertexShaderSource =
        "attribute vec2 a_position;\n"
        "attribute vec4 a_color;\n"
        "attribute vec2 a_texCoord;\n"

        "uniform mat4 u_matrix;\n"

        "varying vec4 v_color;\n"
        "varying vec2 v_texCoord;\n"

        "void main() {\n"
        "   gl_Position = u_matrix * vec4(a_position.xy, 0.0, 1.0);\n"
        "   v_color = a_color;\n"
        "   v_texCoord = a_texCoord;\n"
        "}\n";

static const char *textureFragmentShaderSource =
        "varying vec4 v_color;\n"
        "varying vec2 v_texCoord;\n"
        "uniform sampler2D u_texture; \n"
        "void main() {\n"
        "   vec4 tex = texture2D(u_texture, v_texCoord);\n"
        "   tex.rgb *= v_color.a;\n"
        "   gl_FragColor = v_color * tex;\n"
        "}\n";

// 非预乘纹理：采样后先把 RGB 乘上纹理 alpha 转成预乘，再乘顶点 alpha（slot 透明度）
static const char *textureFragmentShaderSourceStraight =
        "varying vec4 v_color;\n"
        "varying vec2 v_texCoord;\n"
        "uniform sampler2D u_texture; \n"
        "void main() {\n"
        "   vec4 tex = texture2D(u_texture, v_texCoord);\n"
        "   tex.rgb *= tex.a * v_color.a;\n"
        "   gl_FragColor = v_color * tex;\n"
        "}\n";

static const char *colorVertexShaderSource =
        "attribute vec2 a_position;\n"

        "uniform vec4 u_color;\n"
        "uniform mat4 u_matrix;\n"

        "varying vec4 v_color;\n"

        "void main() {\n"
        "   gl_Position = u_matrix * vec4(a_position.xy, 0.0, 1.0);\n"
        "   v_color = u_color;\n"
        "}\n";

static const char *colorFragmentShaderSource =
        "varying vec4 v_color;\n"

        "void main() {\n"
        "   gl_FragColor = v_color;\n"
        "}\n";

void ICachedGLFunctionCall::release()
{
    delete this;
}

QOpenGLFunctions *ICachedGLFunctionCall::glFuncs()
{
    return QOpenGLContext::currentContext()->functions();
}

class BlendFunction: public ICachedGLFunctionCall
{
public:
    explicit BlendFunction(GLenum sfactor, GLenum dfactor):msfactor(sfactor), mdfactor(dfactor){}
    virtual ~BlendFunction(){}

    virtual void invoke(){
        if (msfactor == GL_ONE && mdfactor == GL_ZERO){
            glFuncs()->glDisable(GL_BLEND);
        }
        else
        {
            glFuncs()->glEnable(GL_BLEND);
            glFuncs()->glBlendFunc(msfactor, mdfactor);
        }
    }

private:
    GLenum msfactor;
    GLenum mdfactor;
};

class BindShader: public ICachedGLFunctionCall
{
public:
    explicit BindShader(QOpenGLShaderProgram* program, const QRectF& rect):mShaderProgram(program), mRect(rect){}
    virtual ~BindShader(){}

    virtual void invoke(){
        QMatrix4x4 matrix;
        matrix.ortho(mRect);

        mShaderProgram->bind();
        mShaderProgram->setUniformValue("u_matrix", matrix);

        if (mShaderProgram->attributeLocation("a_position") != -1)
            mShaderProgram->enableAttributeArray("a_position");

        if (mShaderProgram->attributeLocation("a_color") != -1)
            mShaderProgram->enableAttributeArray("a_color");

        if (mShaderProgram->attributeLocation("a_texCoord") != -1)
            mShaderProgram->enableAttributeArray("a_texCoord");
    }

private:
    QOpenGLShaderProgram* mShaderProgram;
    QRectF  mRect;
};

class DrawColor: public ICachedGLFunctionCall
{
public:
    explicit DrawColor(QOpenGLShaderProgram* program, const QColor& color):mShaderProgram(program), mColor(color){}
    virtual ~DrawColor(){}

    virtual void invoke(){
        if (mShaderProgram->uniformLocation("u_color") != -1)
            mShaderProgram->setUniformValue("u_color", mColor);
    }

private:
    QOpenGLShaderProgram* mShaderProgram;
    QColor mColor;
};

class LineWidth: public ICachedGLFunctionCall
{
public:
    explicit LineWidth(GLfloat width):mWidth(width){}
    virtual ~LineWidth(){}

    virtual void invoke(){
        glFuncs()->glLineWidth(mWidth);
    }

private:
    GLfloat mWidth;
};

class PointSize: public ICachedGLFunctionCall
{
public:
    explicit PointSize(GLfloat size):mSize(size){}
    virtual ~PointSize(){}

    virtual void invoke(){
        // Qt6 的 QOpenGLFunctions 仅提供 ES 2.0 子集，没有 glPointSize。
        // 该设置仅影响调试模式下的骨骼原点大小，保持默认 1px 即可。
        Q_UNUSED(mSize);
    }

private:
    GLfloat mSize;
};

class DrawTrigngles: public ICachedGLFunctionCall
{
public:
    explicit DrawTrigngles(QOpenGLShaderProgram* program, QOpenGLTexture* texture, Vertex* vertices, int verticesCount, GLushort* triangles, int trianglesCount)
        :mShaderProgram(program)
        ,mTexture(texture)
        ,mVertices(0)
        ,mVerticesCount(verticesCount)
        ,mTriangles(0)
        ,mTrianglesCount(trianglesCount)
    {
        if (trianglesCount <= 0 || verticesCount <= 0 || !vertices || !triangles)
            return;

        mVertices = new Vertex[mVerticesCount];
        memcpy(mVertices, vertices, sizeof(Vertex)*mVerticesCount);

        mTriangles = new GLushort[mTrianglesCount];
        memcpy(mTriangles, triangles, sizeof(GLushort)*mTrianglesCount);
    }

    virtual ~DrawTrigngles()
    {
        if (mVertices)
            delete []mVertices;
        if (mTriangles)
            delete []mTriangles;
    }

    virtual void invoke()
    {
        if (mTexture)
            mTexture->bind();

        mShaderProgram->setAttributeArray("a_position", GL_FLOAT, &mVertices[0].position, 2, sizeof(Vertex));
        mShaderProgram->setAttributeArray("a_color", GL_UNSIGNED_BYTE, &mVertices[0].color, 4, sizeof(Vertex));
        mShaderProgram->setAttributeArray("a_texCoord", GL_FLOAT, &mVertices[0].texCoord, 2, sizeof(Vertex));

        glFuncs()->glDrawElements(GL_TRIANGLES, mTrianglesCount, GL_UNSIGNED_SHORT, mTriangles);
    }

private:
    QOpenGLShaderProgram* mShaderProgram;
    QOpenGLTexture* mTexture;
    Vertex* mVertices;
    int mVerticesCount;
    GLushort* mTriangles;
    int mTrianglesCount;
};

class DrawPolygon: public ICachedGLFunctionCall
{
public:
    explicit DrawPolygon(QOpenGLShaderProgram* program, const Point* points, int pointsCount)
        :mShaderProgram(program)
        ,mPoints(0)
        ,mPointsCount(pointsCount)
    {
        if (pointsCount <= 0 || !points)
            return;

        mPoints = new Point[mPointsCount];
        memcpy(mPoints, points, sizeof(Point)*mPointsCount);
    }

    virtual ~DrawPolygon()
    {
        if (mPoints)
            delete []mPoints;
    }

    virtual void invoke()
    {
        mShaderProgram->setAttributeArray("a_position", GL_FLOAT, mPoints, 2, sizeof(Point));
        glFuncs()->glDrawArrays(GL_LINE_LOOP, 0, (GLsizei) mPointsCount);
    }

private:
    QOpenGLShaderProgram* mShaderProgram;
    Point* mPoints;
    int mPointsCount;
};

class DrawLine: public ICachedGLFunctionCall
{
public:
    explicit DrawLine(QOpenGLShaderProgram* program, const Point& origin, const Point& destination)
        :mShaderProgram(program)
    {
        mPoints[0] = origin;
        mPoints[1] = destination;
    }

    virtual ~DrawLine(){}

    virtual void invoke()
    {
        mShaderProgram->setAttributeArray("a_position", GL_FLOAT, mPoints, 2, sizeof(Point));
        glFuncs()->glDrawArrays(GL_LINES, 0, 2);
    }

private:
    QOpenGLShaderProgram* mShaderProgram;
    Point mPoints[2];
};

class DrawPoint: public ICachedGLFunctionCall
{
public:
    explicit DrawPoint(QOpenGLShaderProgram* program, const Point& point)
        :mShaderProgram(program)
        ,mPoint(point)
    {}

    virtual ~DrawPoint(){}

    virtual void invoke()
    {
        mShaderProgram->setAttributeArray("a_position", GL_FLOAT, &mPoint, 2, sizeof(Point));
        glFuncs()->glDrawArrays(GL_POINTS, 0, 1);
    }

private:
    QOpenGLShaderProgram* mShaderProgram;
    Point mPoint;
};

RenderCmdsCache::RenderCmdsCache()
    :mCapacity(0)
    ,mVertices(0)
    ,mVerticesCount(0)
    ,mTriangles(0)
    ,mTrianglesCount(0)
    ,mTexture(0)
    ,mTextureShaderProgram(0)
    ,mTextureShaderProgramStraight(0)
    ,mColorShaderProgram(0)
    ,mPremultipliedAlpha(true)
{
    mCapacity = 2000; // Max number of vertices and triangles per batch.
    mVertices = new Vertex[mCapacity];
    mTriangles = new GLushort[mCapacity * 3];

    mTextureShaderProgram = new QOpenGLShaderProgram();
    bool res = mTextureShaderProgram->addShaderFromSourceCode(QOpenGLShader::Vertex, textureVertexShaderSource);
    if (!res)
        qDebug()<<"PolygonBatch::PolygonBatch texture shader program addShaderFromSourceCode error:"<<mTextureShaderProgram->log();

    res = mTextureShaderProgram->addShaderFromSourceCode(QOpenGLShader::Fragment, textureFragmentShaderSource);
    if (!res)
        qDebug()<<"PolygonBatch::PolygonBatch texture shader program addShaderFromSourceCode error:"<<mTextureShaderProgram->log();

    res = mTextureShaderProgram->link();
    if (!res)
        qDebug()<<"PolygonBatch::PolygonBatch texture shader program link error:"<<mTextureShaderProgram->log();

    mTextureShaderProgramStraight = new QOpenGLShaderProgram();
    res = mTextureShaderProgramStraight->addShaderFromSourceCode(QOpenGLShader::Vertex, textureVertexShaderSource);
    if (!res)
        qDebug()<<"PolygonBatch::PolygonBatch straight shader program addShaderFromSourceCode error:"<<mTextureShaderProgramStraight->log();

    res = mTextureShaderProgramStraight->addShaderFromSourceCode(QOpenGLShader::Fragment, textureFragmentShaderSourceStraight);
    if (!res)
        qDebug()<<"PolygonBatch::PolygonBatch straight shader program addShaderFromSourceCode error:"<<mTextureShaderProgramStraight->log();

    res = mTextureShaderProgramStraight->link();
    if (!res)
        qDebug()<<"PolygonBatch::PolygonBatch straight shader program link error:"<<mTextureShaderProgramStraight->log();

    mColorShaderProgram = new QOpenGLShaderProgram();
    res = mColorShaderProgram->addShaderFromSourceCode(QOpenGLShader::Vertex, colorVertexShaderSource);
    if (!res)
        qDebug()<<"PolygonBatch::PolygonBatch texture shader program addShaderFromSourceCode error:"<<mColorShaderProgram->log();

    res = mColorShaderProgram->addShaderFromSourceCode(QOpenGLShader::Fragment, colorFragmentShaderSource);
    if (!res)
        qDebug()<<"PolygonBatch::PolygonBatch texture shader program addShaderFromSourceCode error:"<<mColorShaderProgram->log();

    res = mColorShaderProgram->link();
    if (!res)
        qDebug()<<"PolygonBatch::PolygonBatch texture shader program link error:"<<mColorShaderProgram->log();
}

RenderCmdsCache::~RenderCmdsCache()
{
    clear();
    delete []mVertices;
    delete []mTriangles;
    delete mTextureShaderProgram;
    delete mTextureShaderProgramStraight;
    delete mColorShaderProgram;
}

void RenderCmdsCache::clear()
{
    if (mglFuncs.isEmpty())
        return;

    Q_FOREACH (ICachedGLFunctionCall* func, mglFuncs) {
        func->release();
    }

    mglFuncs.clear();
}

void RenderCmdsCache::drawTriangles(QOpenGLTexture* addTexture,const float* addVertices, const float* uvs, int addVerticesCount,
                       const unsigned short* addTriangles, int addTrianglesCount, const Color& color)
{
    if (addTexture != mTexture
            || mVerticesCount + (addVerticesCount >> 1) > mCapacity
            || mTrianglesCount + addTrianglesCount > mCapacity * 3) {
        this->cacheTriangleDrawCall();
        mTexture = addTexture;
    }

    for (int i = 0; i < addTrianglesCount; ++i, ++mTrianglesCount)
        mTriangles[mTrianglesCount] = addTriangles[i] + mVerticesCount;

    for (int i = 0; i < addVerticesCount; i += 2, ++mVerticesCount) {
        Vertex* vertex = mVertices + mVerticesCount;
        vertex->position.x = addVertices[i];
        vertex->position.y = addVertices[i + 1];
        vertex->color = color;
        vertex->texCoord.u = uvs[i];
        vertex->texCoord.v = uvs[i + 1];
    }
}

void RenderCmdsCache::blendFunc(GLenum sfactor, GLenum dfactor)
{
    mglFuncs.push_back(new BlendFunction(sfactor, dfactor));
}

void RenderCmdsCache::bindShader(RenderCmdsCache::ShaderType type)
{
    if (type == ShaderTexture)
        mglFuncs.push_back(new BindShader(mPremultipliedAlpha ? mTextureShaderProgram : mTextureShaderProgramStraight, mRect));
    else if (type == ShaderColor)
        mglFuncs.push_back(new BindShader(mColorShaderProgram, mRect));
}

void RenderCmdsCache::setPremultipliedAlpha(bool premultiplied)
{
    mPremultipliedAlpha = premultiplied;
}

void RenderCmdsCache::drawColor(GLubyte r, GLubyte g, GLubyte b, GLubyte a)
{
    mglFuncs.push_back(new DrawColor(mColorShaderProgram, QColor(r,g,b,a)));
}

void RenderCmdsCache::lineWidth(GLfloat width)
{
    mglFuncs.push_back(new LineWidth(width));
}

void RenderCmdsCache::pointSize(GLfloat pointSize)
{
    mglFuncs.push_back(new PointSize(pointSize));
}

void RenderCmdsCache::drawPoly(const Point *points, int pointCount)
{
    mglFuncs.push_back(new DrawPolygon(mColorShaderProgram, points, pointCount));
}

void RenderCmdsCache::drawLine(const Point &origin, const Point &destination)
{
    mglFuncs.push_back(new DrawLine(mColorShaderProgram, origin, destination));
}

void RenderCmdsCache::drawPoint(const Point &point)
{
    mglFuncs.push_back(new DrawPoint(mColorShaderProgram, point));
}

void RenderCmdsCache::cacheTriangleDrawCall()
{
    const bool valid = mVerticesCount>0 && mTrianglesCount > 0;
    if (!valid){
        if (mVerticesCount > 0)
            mVerticesCount = 0;
        if (mTrianglesCount > 0)
            mTrianglesCount = 0;
        return;
    }

    mglFuncs.push_back(new DrawTrigngles(mTextureShaderProgram, mTexture, mVertices, mVerticesCount, mTriangles, mTrianglesCount));
    mVerticesCount = 0;
    mTrianglesCount = 0;
}

void RenderCmdsCache::render()
{
    QOpenGLFunctions* glFuncs = QOpenGLContext::currentContext()->functions();
    glFuncs->glDisable(GL_DEPTH_TEST);
    glFuncs->glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glFuncs->glClear(GL_COLOR_BUFFER_BIT);

    if (mglFuncs.isEmpty())
        return;

    Q_FOREACH (ICachedGLFunctionCall* func, mglFuncs) {
        func->invoke();
    }
}

void RenderCmdsCache::setSkeletonRect(const QRectF &rect)
{
    mRect = rect;
}


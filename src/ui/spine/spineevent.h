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

#ifndef SPINEEVENT_H
#define SPINEEVENT_H
#include <QString>
#include <QObject>
#include "spinebackend.h"

class SpineEventData: public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY(SpineEventData)

    Q_PROPERTY(QString name READ name)
    Q_PROPERTY(int intValue READ intValue)
    Q_PROPERTY(float floatValue READ floatValue)
    Q_PROPERTY(QString stringValue READ stringValue)

public:
    SpineEventData(QObject* parent = 0);
    void setEventData(const SpineEventInfo& info);

    QString name()const { return mName;}
    int intValue()const { return mIntValue;}
    float floatValue()const { return mFloatValue;}
    QString stringValue()const { return mStringValue;}

private:
    QString mName;
    int mIntValue;
    float mFloatValue;
    QString mStringValue;
};

class SpineEvent: public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY(SpineEvent)

    Q_PROPERTY(SpineEventData* data READ data)
    Q_PROPERTY(int intValue READ intValue)
    Q_PROPERTY(float floatValue READ floatValue)
    Q_PROPERTY(QString stringValue READ stringValue)

public:
    SpineEvent(QObject* parent = 0);
    void setEvent(const SpineEventInfo& info);

    SpineEventData* data() { return mData;}
    int intValue()const { return mIntValue;}
    float floatValue()const { return mFloatValue;}
    QString stringValue()const { return mStringValue;}

private:
    SpineEventData* mData;
    int mIntValue;
    float mFloatValue;
    QString mStringValue;
};

#endif // SPINEEVENT_H

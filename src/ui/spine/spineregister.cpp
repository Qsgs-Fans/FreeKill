#include "spineregister.h"
#include "skeletonanimationfbo.h"
#include "spineevent.h"
#include "spineversion.h"
#include <QUrl>
#include <QtQml>

void registerSpineQmlTypes()
{
    // 版本枚举（只读，供 QML 使用 SpineVersion.Auto/V21/.../V42）
    qmlRegisterUncreatableMetaObject(
        SpineVersion::staticMetaObject, "Spine", 1, 0, "SpineVersion",
        QStringLiteral("SpineVersion is an enum-only type"));

    qmlRegisterType<SpineEventData>("Spine", 1, 0, "SpineEventData");
    qmlRegisterType<SpineEvent>("Spine", 1, 0, "SpineEvent");
    qmlRegisterType<SkeletonAnimationFbo>("Spine", 1, 0, "SkeletonAnimationFbo");
    qmlRegisterType(QString("qrc:/SkeletonAnimation.qml"), "Spine", 1, 0, "SkeletonAnimation");
}

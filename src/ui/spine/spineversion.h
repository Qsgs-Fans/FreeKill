#ifndef SPINEVERSION_H
#define SPINEVERSION_H

#include <QObject>
#include <QString>

// Spine 运行时版本枚举。Auto 表示根据文件内容自动检测。
namespace SpineVersion {
    Q_NAMESPACE
    enum Type {
        Auto = 0,
        V21,
        V34,
        V35,
        V36,
        V37,
        V38,
        V40,
        V41,
        V42,
        Unknown
    };
    Q_ENUM_NS(Type)
}

// 根据文件内容检测版本：JSON 读取 skeleton.spine 字段；.skel 读取二进制版本字符串。
SpineVersion::Type detectSpineVersion(const QString &filePath);

// 版本号转字符串（用于日志/调试）。
QString spineVersionToString(SpineVersion::Type v);

#endif // SPINEVERSION_H

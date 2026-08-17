#include "spineversion.h"
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>

namespace {

SpineVersion::Type parseVersionString(const QString &v)
{
    const QStringList parts = v.split('.');
    if (parts.size() < 2)
        return SpineVersion::Unknown;
    bool ok1 = false, ok2 = false;
    const int major = parts[0].toInt(&ok1);
    const int minor = parts[1].toInt(&ok2);
    if (!ok1 || !ok2)
        return SpineVersion::Unknown;

    if (major == 2 && minor == 1) return SpineVersion::V21;
    if (major == 3 && minor == 4) return SpineVersion::V34;
    if (major == 3 && minor == 5) return SpineVersion::V35;
    if (major == 3 && minor == 6) return SpineVersion::V36;
    if (major == 3 && minor == 7) return SpineVersion::V37;
    if (major == 3 && minor == 8) return SpineVersion::V38;
    if (major == 4 && minor == 0) return SpineVersion::V40;
    if (major == 4 && minor == 1) return SpineVersion::V41;
    if (major == 4 && minor == 2) return SpineVersion::V42;
    return SpineVersion::Unknown;
}

// 7-bit 变长整数（与 Spine 二进制格式一致）。
int readVarInt(const char *&p, const char *end)
{
    int result = 0;
    int shift = 0;
    while (p < end && shift <= 28) {
        const unsigned char b = static_cast<unsigned char>(*p++);
        result |= (b & 0x7F) << shift;
        if (!(b & 0x80))
            break;
        shift += 7;
    }
    return result;
}

SpineVersion::Type detectJson(const QByteArray &data)
{
    QString text = QString::fromUtf8(data);
    // 去掉可能的 BOM
    if (text.startsWith(QChar(0xFEFF)))
        text.remove(0, 1);

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(text.toUtf8(), &err);
    if (err.error == QJsonParseError::NoError && doc.isObject()) {
        const QJsonObject skeleton = doc.object().value("skeleton").toObject();
        const QString v = skeleton.value("spine").toString();
        if (!v.isEmpty())
            return parseVersionString(v);
    }

    // 兜底：直接正则匹配 "spine":"x.y.z"
    static const QRegularExpression re(
        QStringLiteral("\"spine\"\\s*:\\s*\"([0-9]+\\.[0-9]+[^\"]*)\""));
    const QRegularExpressionMatch m = re.match(text);
    if (m.hasMatch())
        return parseVersionString(m.captured(1));

    return SpineVersion::Unknown;
}

SpineVersion::Type detectSkel(const QByteArray &data)
{
    const char *p = data.constData();
    const char *end = p + data.size();

    // 4.0+ 格式：8 字节大端 hash + 变长长度的版本字符串
    if (data.size() >= 12) {
        const char *q = p + 8;
        const int len = readVarInt(q, end);
        if (len >= 1 && len <= 13 && q + (len - 1) <= end) {
            const QString v = QString::fromUtf8(q, len - 1);
            if (!v.isEmpty() && v[0].isDigit())
                return parseVersionString(v);
        }
    }

    // 3.8 及更早格式：变长长度的 hash 字符串 + 变长长度的版本字符串
    const char *q = p;
    int hashLen = readVarInt(q, end);
    if (hashLen > 1) {
        q += hashLen - 1;
        if (q > end)
            return SpineVersion::Unknown;
    }
    const int vLen = readVarInt(q, end);
    if (vLen > 1 && vLen <= 13 && q + (vLen - 1) <= end) {
        const QString v = QString::fromUtf8(q, vLen - 1);
        return parseVersionString(v);
    }

    return SpineVersion::Unknown;
}

} // namespace

SpineVersion::Type detectSpineVersion(const QString &filePath)
{
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly))
        return SpineVersion::Unknown;
    const QByteArray data = f.readAll();
    f.close();

    const QString suffix = QFileInfo(filePath).suffix().toLower();
    if (suffix == "skel")
        return detectSkel(data);
    return detectJson(data); // .json / .skel.json 等
}

QString spineVersionToString(SpineVersion::Type v)
{
    switch (v) {
    case SpineVersion::V21: return QStringLiteral("2.1");
    case SpineVersion::V34: return QStringLiteral("3.4");
    case SpineVersion::V35: return QStringLiteral("3.5");
    case SpineVersion::V36: return QStringLiteral("3.6");
    case SpineVersion::V37: return QStringLiteral("3.7");
    case SpineVersion::V38: return QStringLiteral("3.8");
    case SpineVersion::V40: return QStringLiteral("4.0");
    case SpineVersion::V41: return QStringLiteral("4.1");
    case SpineVersion::V42: return QStringLiteral("4.2");
    case SpineVersion::Auto: return QStringLiteral("auto");
    default: return QStringLiteral("unknown");
    }
}

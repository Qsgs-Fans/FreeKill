// SPDX-License-Identifier: GPL-3.0-or-later

/** @file util.h

  util.h负责提供各种全局函数、全局变量等。

  @todo 好像在调用C库时C++程序会为它们创建包装类才对吧？
  总之这种写法实在是不太推荐，以后说不定会改成另外的写法。

  */

#ifndef _GLOBAL_H
#define _GLOBAL_H

// utilities

QString calcFileMD5();
/// 判断 packages/<dir> 是否为 UI 包（init.lua 中以 Package.UIPack 声明）。
/// UI 包只包含界面代码，不影响游戏逻辑，因此不参与 MD5 校验和扩展包同步。
bool IsUIPackDir(const QString &pkgDir);
QByteArray JsonArray2Bytes(const QJsonArray &arr);
QJsonDocument String2Json(const QString &str);

QString GetDeviceUuid();

QString GetDisabledPacks();

namespace fkShell {
  enum TextColor {
    Black,
    Red,
    Green,
    Yellow,
    Blue,
    Magenta,
    Cyan,
  };
  enum TextType {
    NoType,
    Bold,
    UnderLine
  };
}

QString Color(const QString &raw, fkShell::TextColor color,
                                  fkShell::TextType type = fkShell::NoType);

// QVariant AskOllama(const QString &apiEndpoint, const QVariant &body);

#endif // _GLOBAL_H

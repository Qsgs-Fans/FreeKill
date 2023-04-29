// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _GLOBAL_H
#define _GLOBAL_H

// utilities

lua_State *CreateLuaState();
bool DoLuaScript(lua_State *L, const char *script);

sqlite3 *OpenDatabase(const QString &filename = "./server/users.db", const QString &initSql = "./server/init.sql");
QJsonArray SelectFromDatabase(sqlite3 *db, const QString &sql);
// For Lua
QString SelectFromDb(sqlite3 *db, const QString &sql);
void ExecSQL(sqlite3 *db, const QString &sql);
void CloseDatabase(sqlite3 *db);

#ifndef Q_OS_WASM
RSA *InitServerRSA();
#endif

QString calcFileMD5();
QByteArray JsonArray2Bytes(const QJsonArray &arr);
QJsonDocument String2Json(const QString &str);

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

#endif // _GLOBAL_H

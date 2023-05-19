// SPDX-License-Identifier: GPL-3.0-or-later

#include "util.h"
#include <qcryptographichash.h>
#include <qnamespace.h>
#include <qregularexpression.h>

extern "C" {
int luaopen_fk(lua_State *);
}

lua_State *CreateLuaState() {
  lua_State *L = luaL_newstate();
  luaL_openlibs(L);
  luaopen_fk(L);

  return L;
}

bool DoLuaScript(lua_State *L, const char *script) {
  lua_getglobal(L, "debug");
  lua_getfield(L, -1, "traceback");
  lua_replace(L, -2);

  luaL_loadfile(L, script);
  int error = lua_pcall(L, 0, LUA_MULTRET, -2);

  if (error) {
    const char *error_msg = lua_tostring(L, -1);
    qCritical() << error_msg;
    lua_pop(L, 2);
    return false;
  }
  lua_pop(L, 1);
  return true;
}

// For Lua debugging
void Dumpstack(lua_State *L) {
  int top = lua_gettop(L);
  for (int i = 1; i <= top; i++) {
    printf("%d\t%s\t", i, luaL_typename(L, i));
    switch (lua_type(L, i)) {
    case LUA_TNUMBER:
      printf("%g\n", lua_tonumber(L, i));
      break;
    case LUA_TSTRING:
      printf("%s\n", lua_tostring(L, i));
      break;
    case LUA_TBOOLEAN:
      printf("%s\n", (lua_toboolean(L, i) ? "true" : "false"));
      break;
    case LUA_TNIL:
      printf("%s\n", "nil");
      break;
    default:
      printf("%p\n", lua_topointer(L, i));
      break;
    }
  }
}

sqlite3 *OpenDatabase(const QString &filename, const QString &initSql) {
  sqlite3 *ret;
  int rc;

  QFile file(initSql);
  if (!file.open(QIODevice::ReadOnly)) {
    qFatal("cannot open %s. Quit now.", initSql.toUtf8().data());
    qApp->exit(1);
  }
  QTextStream in(&file);

  if (!QFile::exists(filename)) {
    char *err_msg;
    sqlite3_open(filename.toLatin1().data(), &ret);
    rc = sqlite3_exec(ret, in.readAll().toLatin1().data(), nullptr, nullptr,
                      &err_msg);

    if (rc != SQLITE_OK) {
      qCritical() << "sqlite error:" << err_msg;
      sqlite3_free(err_msg);
      sqlite3_close(ret);
      qApp->exit(1);
    }
  } else {
    rc = sqlite3_open(filename.toLatin1().data(), &ret);
    if (rc != SQLITE_OK) {
      qCritical() << "Cannot open database:" << sqlite3_errmsg(ret);
      sqlite3_close(ret);
      qApp->exit(1);
    }

    char *err_msg;
    rc = sqlite3_exec(ret, in.readAll().toLatin1().data(), nullptr, nullptr,
                      &err_msg);

    if (rc != SQLITE_OK) {
      qCritical() << "sqlite error:" << err_msg;
      sqlite3_free(err_msg);
      sqlite3_close(ret);
      qApp->exit(1);
    }
  }
  return ret;
}

bool CheckSqlString(const QString &str) {
  static const QRegularExpression exp("['\";#]+|(--)|(/\\*)|(\\*/)|(--\\+)");
  return (!exp.match(str).hasMatch() && !str.isEmpty());
}

// callback for handling SELECT expression
static int callback(void *jsonDoc, int argc, char **argv, char **cols) {
  QJsonObject obj;
  for (int i = 0; i < argc; i++) {
    obj[QString(cols[i])] = QString(argv[i] ? argv[i] : "#null");
  }
  ((QJsonArray *)jsonDoc)->append(obj);
  return 0;
}

QJsonArray SelectFromDatabase(sqlite3 *db, const QString &sql) {
  QJsonArray arr;
  auto bytes = sql.toUtf8();
  sqlite3_exec(db, bytes.data(), callback, (void *)&arr, nullptr);
  return arr;
}

QString SelectFromDb(sqlite3 *db, const QString &sql) {
  auto obj = SelectFromDatabase(db, sql);
  return QJsonDocument(obj).toJson(QJsonDocument::Compact);
}

void ExecSQL(sqlite3 *db, const QString &sql) {
  auto bytes = sql.toUtf8();
  sqlite3_exec(db, bytes.data(), nullptr, nullptr, nullptr);
}

void CloseDatabase(sqlite3 *db) { sqlite3_close(db); }

#ifndef Q_OS_WASM
RSA *InitServerRSA() {
  RSA *rsa = RSA_new();
  if (!QFile::exists("server/rsa_pub")) {
    BIGNUM *bne = BN_new();
    BN_set_word(bne, RSA_F4);
    RSA_generate_key_ex(rsa, 2048, bne, NULL);

    BIO *bp_pub = BIO_new_file("server/rsa_pub", "w+");
    PEM_write_bio_RSAPublicKey(bp_pub, rsa);
    BIO *bp_pri = BIO_new_file("server/rsa", "w+");
    PEM_write_bio_RSAPrivateKey(bp_pri, rsa, NULL, NULL, 0, NULL, NULL);

    BIO_free_all(bp_pub);
    BIO_free_all(bp_pri);
    BN_free(bne);
  }
  FILE *keyFile = fopen("server/rsa_pub", "r");
  PEM_read_RSAPublicKey(keyFile, &rsa, NULL, NULL);
  fclose(keyFile);
  keyFile = fopen("server/rsa", "r");
  PEM_read_RSAPrivateKey(keyFile, &rsa, NULL, NULL);
  fclose(keyFile);
  return rsa;
}
#endif

static void writeFileMD5(QFile &dest, const QString &fname) {
  QString name = fname;
  // If the is a corresponding fkp file, check fkp's MD5 instead.
  if (name.endsWith(".lua")) {
    name.chop(4);
    name = name + ".fkp";
    if (!QFile::exists(name))
      name = fname;
  }
  QFile f(name);
  if (!f.open(QIODevice::ReadOnly)) {
    return;
  }

  auto data = f.readAll();
  data.replace(QByteArray("\r\n"), QByteArray("\n"));
  auto hash = QCryptographicHash::hash(data, QCryptographicHash::Md5).toHex();
  dest.write(name.toUtf8() + '=' + hash + ';');
}

static void writeDirMD5(QFile &dest, const QString &dir,
                        const QString &filter) {
  QDir d(dir);
  auto entries = d.entryInfoList(
      QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
  auto re = QRegularExpression::fromWildcard(filter);
  foreach (QFileInfo info, entries) {
    if (info.isDir() && !info.fileName().endsWith(".disabled")) {
      writeDirMD5(dest, info.filePath(), filter);
    } else {
      if (re.match(info.fileName()).hasMatch()) {
        writeFileMD5(dest, info.filePath());
      }
    }
  }
}

QString calcFileMD5() {
  // First, generate flist.txt
  // flist.txt is a file contains all md5sum for code files
  QFile flist("flist.txt");
  if (!flist.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
    qFatal("Cannot open flist.txt. Quitting.");
  }

  writeDirMD5(flist, "packages", "*.lua");
  writeDirMD5(flist, "packages", "*.qml");
  writeDirMD5(flist, "packages", "*.js");
  writeDirMD5(flist, "lua", "*.lua");
  writeDirMD5(flist, "qml", "*.qml");
  writeDirMD5(flist, "qml", "*.js");
  writeDirMD5(flist, "Fk", "*.qml");
  writeDirMD5(flist, "Fk", "*.js");

  // then, return flist.txt's md5
  flist.close();
  flist.open(QIODevice::ReadOnly);
  auto ret = QCryptographicHash::hash(flist.readAll(), QCryptographicHash::Md5);
  flist.remove(); // delete flist.txt
  flist.close();
  return ret.toHex();
}

QByteArray JsonArray2Bytes(const QJsonArray &arr) {
  auto doc = QJsonDocument(arr);
  return doc.toJson(QJsonDocument::Compact);
}

QJsonDocument String2Json(const QString &str) {
  auto bytes = str.toUtf8();
  return QJsonDocument::fromJson(bytes);
}

QString Color(const QString &raw, fkShell::TextColor color,
              fkShell::TextType type) {
#ifdef Q_OS_LINUX
  static const char *suffix = "\e[0;0m";
  int col = 30 + color;
  int t = type == fkShell::Bold ? 1 : 0;
  auto prefix = QString("\e[%2;%1m").arg(col).arg(t);

  return prefix + raw + suffix;
#else
  return raw;
#endif
}

#include "util.h"

extern "C" {
    int luaopen_fk(lua_State *);
}

lua_State *CreateLuaState()
{
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);
    luaopen_fk(L);

    return L;
}

bool DoLuaScript(lua_State *L, const char *script)
{
    int error = luaL_dofile(L, script);
    if (error) {
        QString error_msg = lua_tostring(L, -1);
        qDebug() << error_msg;
        return false;
    }
    return true;
}

sqlite3 *OpenDatabase(const QString &filename)
{
    sqlite3 *ret;
    int rc;
    if (!QFile::exists(filename)) {
        QFile file("./server/init.sql");
        if (!file.open(QIODevice::ReadOnly)) {
            qDebug() << "cannot open init.sql. Quit now.";
            qApp->exit(1);
        }

        QTextStream in(&file);
        char *err_msg;
        sqlite3_open(filename.toLatin1().data(), &ret);
        rc = sqlite3_exec(ret, in.readAll().toLatin1().data(), nullptr, nullptr, &err_msg);

        if (rc != SQLITE_OK ) {
            qDebug() << "sqlite error:" << err_msg;
            sqlite3_free(err_msg);
            sqlite3_close(ret);
            qApp->exit(1);
        }
    } else {
        rc = sqlite3_open(filename.toLatin1().data(), &ret);
        if (rc != SQLITE_OK) {
            qDebug() << "Cannot open database:" << sqlite3_errmsg(ret);
            sqlite3_close(ret);
            qApp->exit(1);
        }
    }
    return ret;
}

// callback for handling SELECT expression
static int callback(void *jsonDoc, int argc, char **argv, char **cols) {
    QJsonObject obj;
    for (int i = 0; i < argc; i++) {
        QJsonArray arr = obj[QString(cols[i])].toArray();
        arr << QString(argv[i] ? argv[i] : "#null");
        obj[QString(cols[i])] = arr;
    }
    ((QJsonObject *)jsonDoc)->swap(obj);
    return 0;
}

QJsonObject SelectFromDatabase(sqlite3 *db, const QString &sql) {
    QJsonObject obj;
    sqlite3_exec(db, sql.toUtf8().data(), callback, (void *)&obj, nullptr);
    return obj;
}

QString SelectFromDb(sqlite3 *db, const QString &sql) {
    QJsonObject obj = SelectFromDatabase(db, sql);
    return QJsonDocument(obj).toJson();
}

void ExecSQL(sqlite3 *db, const QString &sql) {
    sqlite3_exec(db, sql.toUtf8().data(), nullptr, nullptr, nullptr);
}

void CloseDatabase(sqlite3 *db) {
    sqlite3_close(db);
}

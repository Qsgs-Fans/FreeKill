// SPDX-License-Identifier: GPL-3.0-or-later

struct sqlite3;

sqlite3 *OpenDatabase(const QString &filename);
QString SelectFromDb(sqlite3 *db, const QString &sql);
void ExecSQL(sqlite3 *db, const QString &sql);
void CloseDatabase(sqlite3 *db);

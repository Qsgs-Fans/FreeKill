// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _DIY_H
#define _DIY_H

#include <qtmetamacros.h>
class ModMaker : public QObject {
  Q_OBJECT
public:
  ModMaker(QObject *parent = nullptr);
  ~ModMaker();

  Q_INVOKABLE void initKey();

  Q_INVOKABLE QString readFile(const QString &fileName);
  Q_INVOKABLE void saveToFile(const QString &fileName, const QString &content);
  Q_INVOKABLE void mkdir(const QString &path);
  Q_INVOKABLE void rmrf(const QString &path);

  Q_INVOKABLE void createMod(const QString &name);
  Q_INVOKABLE void removeMod(const QString &name);
  Q_INVOKABLE void stageFiles(const QString &name) { add(name); }
  Q_INVOKABLE void commitChanges(const QString &name, const QString &msg,
      const QString &user, const QString &email);

private:
  sqlite3 *db;

  // git functions
  int init(const QString &pkg);
  int add(const QString &pkg);
  int commit(const QString &pkg, const QString &msg, const char *user, const char *email);
};

#endif

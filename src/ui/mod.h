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

private:
  sqlite3 *db;

  // git functions
  int init(const QString &pkg);
};

#endif

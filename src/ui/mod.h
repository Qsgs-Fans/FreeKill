// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _DIY_H
#define _DIY_H

class ModMaker : public QObject {
  Q_OBJECT
public:
  ModMaker(QObject *parent = nullptr);
  ~ModMaker();

private:
  sqlite3 *db;

  // git functions
  int init(const QString &pkg);
};

#endif

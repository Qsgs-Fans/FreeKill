// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _DIY_H
#define _DIY_H


class DIYMaker : public QObject {
  Q_OBJECT
public:
  DIYMaker(QObject *parent = nullptr);
  ~DIYMaker();

private:
  sqlite3 *db;

  // git functions
  int init(const QString &pkg);
};

#endif

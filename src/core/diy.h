// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _DIY_H
#define _DIY_H


class DIYMaker : public QObject {
  Q_OBJECT
public:
  DIYMaker(QObject *parent = nullptr);
  ~DIYMaker();

  static void initSSHKeyPair();
private:
  sqlite3 *db;
};

#endif

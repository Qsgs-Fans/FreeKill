// SPDX-License-Identifier: GPL-3.0-or-later

%nodefaultctor QmlBackend;
%nodefaultdtor QmlBackend;
class QmlBackend : public QObject {
public:
  static void cd(const QString &path);
  static QStringList ls(const QString &dir);
  static QString pwd();
  static bool exists(const QString &file);
  static bool isDir(const QString &file);
};

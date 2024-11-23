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

extern QmlBackend *Backend;

%nodefaultctor Client;
%nodefaultdtor Client;
class Client : public QObject {
public:
  void sendSetupPacket(const QString &pubkey);
  void setupServerLag(long long server_time);

  void replyToServer(const QString &command, const QString &json_data);
  void notifyServer(const QString &command, const QString &json_data);

  ClientPlayer *addPlayer(int id, const QString &name, const QString &avatar);
  void removePlayer(int id);
  ClientPlayer *getSelf() const;
  void changeSelf(int id);

  void saveRecord(const QString &json, const QString &fname);
  void notifyUI(const QString &command, const QVariant &jsonData);
};

%extend Client {
  void installMyAESKey() {
    $self->installAESKey($self->getAESKey().toLatin1());
  }
}

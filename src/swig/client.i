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

  Player *addPlayer(int id, const QString &name, const QString &avatar);
  void removePlayer(int id);
  Player *getSelf() const;
  void changeSelf(int id);

  void saveRecord(const char *json, const QString &fname);
  void saveGameData(const QString &mode, const QString &general, const QString &deputy,
                    const QString &role, int result, const QString &replay,
                    const char *room_data, const char *record);
  void notifyUI(const QString &command, const QVariant &jsonData);
};

%extend Client {
  void installMyAESKey() {
    $self->installAESKey($self->getAESKey().toLatin1());
  }
}

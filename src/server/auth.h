#ifndef _AUTH_H
#define _AUTH_H

#include <openssl/rsa.h>
#include <openssl/pem.h>

class Server;
class Sqlite3;
class ClientSocket;

class AuthManager : public QObject {
  Q_OBJECT
public:
  AuthManager(Server *parent);
  ~AuthManager() noexcept;
  auto getPublicKey() const { return public_key; }

  bool checkClientVersion(ClientSocket *client, const QString &ver);
  QMap<QString, QString> checkPassword(ClientSocket *client, const QString &name, const QString &password);

private:
  RSA *rsa;
  Sqlite3 *db;
  QString public_key;

  static RSA *initRSA();
  QMap<QString, QString> queryUserInfo(ClientSocket *client, const QString &name, const QByteArray &password);
};

#endif // _AUTH_H

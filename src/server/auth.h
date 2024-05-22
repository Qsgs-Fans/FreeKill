#ifndef _AUTH_H
#define _AUTH_H

#include <openssl/rsa.h>
#include <openssl/pem.h>

class ClientSocket;

class AuthManager : public QObject {
  Q_OBJECT
public:
  AuthManager(QObject *parent = nullptr);
  ~AuthManager() noexcept;
  auto getPublicKey() const { return public_key; }

  bool checkClientVersion(ClientSocket *client, const QString &ver);
  QJsonObject checkPassword(ClientSocket *client, const QString &name, const QString &password);

private:
  RSA *rsa;
  QString public_key;

  static RSA *initRSA();
  QJsonObject queryUserInfo(ClientSocket *client, const QString &name, const QByteArray &password);
};

#endif // _AUTH_H

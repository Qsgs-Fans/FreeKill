#include "server/auth.h"
#include "server/server.h"
#include "server/serverplayer.h"
#include "core/util.h"
#include "network/client_socket.h"
#include <openssl/bn.h>

AuthManager::AuthManager(QObject *parent) : QObject(parent) {
  rsa = initRSA();

  QFile file("server/rsa_pub");
  file.open(QIODevice::ReadOnly);
  QTextStream in(&file);
  public_key = in.readAll();
}

AuthManager::~AuthManager() noexcept {
  RSA_free(rsa);
}

RSA *AuthManager::initRSA() {
  RSA *rsa = RSA_new();
  if (!QFile::exists("server/rsa_pub")) {
    BIGNUM *bne = BN_new();
    BN_set_word(bne, RSA_F4);
    RSA_generate_key_ex(rsa, 2048, bne, NULL);

    BIO *bp_pub = BIO_new_file("server/rsa_pub", "w+");
    PEM_write_bio_RSAPublicKey(bp_pub, rsa);
    BIO *bp_pri = BIO_new_file("server/rsa", "w+");
    PEM_write_bio_RSAPrivateKey(bp_pri, rsa, NULL, NULL, 0, NULL, NULL);

    BIO_free_all(bp_pub);
    BIO_free_all(bp_pri);
    QFile("server/rsa")
        .setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    BN_free(bne);
  }
  FILE *keyFile = fopen("server/rsa_pub", "r");
  PEM_read_RSAPublicKey(keyFile, &rsa, NULL, NULL);
  fclose(keyFile);
  keyFile = fopen("server/rsa", "r");
  PEM_read_RSAPrivateKey(keyFile, &rsa, NULL, NULL);
  fclose(keyFile);
  return rsa;
}

bool AuthManager::checkClientVersion(ClientSocket *client, const QString &cver) {
  auto server = qobject_cast<Server *>(parent());
  auto client_ver = QVersionNumber::fromString(cver);
  auto ver = QVersionNumber::fromString(FK_VERSION);
  int cmp = QVersionNumber::compare(ver, client_ver);
  if (cmp != 0) {
    auto errmsg = QString();
    if (cmp < 0) {
      errmsg = QString("[\"server is still on version %%2\",\"%1\"]")
                      .arg(FK_VERSION, "1");
    } else {
      errmsg = QString("[\"server is using version %%2, please update\",\"%1\"]")
                      .arg(FK_VERSION, "1");
    }

    server->sendEarlyPacket(client, "ErrorDlg", errmsg);
    client->disconnectFromHost();
    return false;
  }
  return true;
}

QJsonObject AuthManager::queryUserInfo(ClientSocket *client, const QString &name,
                                      const QByteArray &password) {
  auto server = qobject_cast<Server *>(parent());
  auto db = server->getDatabase();
  auto pw = password;

  auto sql_find = QString("SELECT * FROM userinfo WHERE name='%1';")
                     .arg(name);

  auto result = SelectFromDatabase(db, sql_find);
  if (result.isEmpty()) {
    auto salt_gen = QRandomGenerator::securelySeeded();
    auto salt = QByteArray::number(salt_gen(), 16);
    pw.append(salt);
    auto passwordHash =
      QCryptographicHash::hash(pw, QCryptographicHash::Sha256).toHex();

    auto sql_reg = QString("INSERT INTO userinfo (name,password,salt,\
                      avatar,lastLoginIp,banned) VALUES ('%1','%2','%3','%4','%5',%6);")
                      .arg(name).arg(QString(passwordHash))
                      .arg(salt).arg("liubei").arg(client->peerAddress())
                      .arg("FALSE");

    ExecSQL(db, sql_reg);
    result = SelectFromDatabase(db, sql_find); // refresh result
    auto obj = result[0].toObject();

    auto info_update = QString("INSERT INTO usergameinfo (id, registerTime) VALUES (%1, %2);").arg(obj["id"].toString().toInt()).arg(QDateTime::currentSecsSinceEpoch());
    ExecSQL(db, info_update);
  }

  return result[0].toObject();
}

QJsonObject AuthManager::checkPassword(ClientSocket *client, const QString &name,
                                const QString &password) {

  auto server = qobject_cast<Server *>(parent());
  bool passed = false;
  QString error_msg;
  QJsonObject obj;
  int id;
  QByteArray salt;
  QByteArray passwordHash;
  auto players = server->getPlayers();

  auto encryted_pw = QByteArray::fromBase64(password.toLatin1());
  unsigned char buf[4096] = {0};
  RSA_private_decrypt(RSA_size(rsa), (const unsigned char *)encryted_pw.data(),
                      buf, rsa, RSA_PKCS1_PADDING);
  auto decrypted_pw =
      QByteArray::fromRawData((const char *)buf, strlen((const char *)buf));

  if (decrypted_pw.length() > 32) {
    auto aes_bytes = decrypted_pw.first(32);

    // tell client to install aes key
    server->sendEarlyPacket(client, "InstallKey", "");
    client->installAESKey(aes_bytes);
    decrypted_pw.remove(0, 32);
  } else {
    // FIXME
    // decrypted_pw = "\xFF";
    error_msg = "unknown password error";
    goto FAIL;
  }

  if (!CheckSqlString(name) || !server->checkBanWord(name)) {
    error_msg = "invalid user name";
    goto FAIL;
  }

  if (server->getConfig("whitelist").isArray() &&
      !server->getConfig("whitelist").toArray().toVariantList().contains(name)) {
    error_msg = "user name not in whitelist";
    goto FAIL;
  }

  obj = queryUserInfo(client, name, decrypted_pw);

  // check ban account
  id = obj["id"].toString().toInt();
  passed = obj["banned"].toString().toInt() == 0;
  if (!passed) {
    error_msg = "you have been banned!";
    goto FAIL;
  }

  // check if password is the same
  salt = obj["salt"].toString().toLatin1();
  decrypted_pw.append(salt);
  passwordHash =
    QCryptographicHash::hash(decrypted_pw, QCryptographicHash::Sha256).toHex();
  passed = (passwordHash == obj["password"].toString());
  if (!passed) {
    error_msg = "username or password error";
    goto FAIL;
  }

  if (players.value(id)) {
    auto player = players.value(id);
    // 顶号机制，如果在线的话就让他变成不在线
    if (player->getState() == Player::Online || player->getState() == Player::Robot) {
      player->doNotify("ErrorDlg", "others logged in again with this name");
      emit player->kicked();
    }

    if (player->getState() == Player::Offline) {
      player->reconnect(client);
      passed = true;
      return QJsonObject();
    } else {
      error_msg = "others logged in with this name";
      passed = false;
    }
  }

FAIL:
  if (!passed) {
    qInfo() << client->peerAddress() << "lost connection:" << error_msg;
    server->sendEarlyPacket(client, "ErrorDlg", error_msg);
    client->disconnectFromHost();
    return QJsonObject();
  }

  return obj;
}

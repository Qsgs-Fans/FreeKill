#include "server/user/auth.h"
#include "server/server.h"
#include "server/user/serverplayer.h"
#include "core/c-wrapper.h"
#include "core/util.h"
#include "core/packman.h"
#include "network/client_socket.h"
#include "network/router.h"
#include <openssl/bn.h>
#include <openssl/rsa.h>
#include <openssl/pem.h>

class AuthManagerPrivate {
public:
  AuthManagerPrivate();
  ~AuthManagerPrivate() {
    RSA_free(rsa);
  }

  RSA *rsa;

  // setup message
  ClientSocket *client;
  QString name;
  QByteArray password;
  QByteArray password_decrypted;
  QString md5;
  QString version;
  QString uuid;
};

AuthManagerPrivate::AuthManagerPrivate() {
  rsa = RSA_new();
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
}

AuthManager::AuthManager(Server *parent) : QObject(parent) {
  server = parent;
  p_ptr = new AuthManagerPrivate;
  db = parent->getDatabase();

  QFile file("server/rsa_pub");
  file.open(QIODevice::ReadOnly);
  QTextStream in(&file);
  public_key = in.readAll();
}

AuthManager::~AuthManager() noexcept {
  delete p_ptr;
}

#define CHK(cond) if (!(cond)) { return; }

void AuthManager::processNewConnection(const QCborArray &arr) {
  ClientSocket *client = qobject_cast<ClientSocket *>(sender());
  disconnect(client, &ClientSocket::message_got, this, &AuthManager::processNewConnection);
  client->timerSignup.stop();

  p_ptr->client = client;

  CHK(loadSetupData(arr));
  CHK(checkVersion());
  CHK(checkIfUuidNotBanned());
  CHK(checkMd5());

  auto obj = checkPassword();
  if (obj.isEmpty()) return;

  int id = obj["id"].toInt();
  updateUserLoginData(id);
  server->createNewPlayer(client, p_ptr->name, obj["avatar"], id, p_ptr->uuid);
}

#undef CHK

bool AuthManager::loadSetupData(const QCborArray &doc) {
  QCborArray arr;
  if (doc.size() != 4 || doc[0].toInteger() != -2 ||
    doc[1].toInteger() != (Router::TYPE_NOTIFICATION | Router::SRC_CLIENT | Router::DEST_SERVER) ||
    doc[2].toByteArray() != "Setup")
  {
    goto FAIL;
  }

  arr = QCborValue::fromCbor(doc[3].toByteArray()).toArray();

  if (arr.size() != 5) {
    goto FAIL;
  }

  p_ptr->name = arr[0].toString();
  p_ptr->password = arr[1].toByteArray();
  p_ptr->md5 = arr[2].toString();
  p_ptr->version = arr[3].toString();
  p_ptr->uuid = arr[4].toString();

  return true;

FAIL:
  qWarning() << "Invalid setup string:" << doc.toCborValue().toDiagnosticNotation();
  server->sendEarlyPacket(p_ptr->client, "ErrorDlg", "INVALID SETUP STRING");
  p_ptr->client->disconnectFromHost();
  return false;
}

bool AuthManager::checkVersion() {
  auto client_ver = QVersionNumber::fromString(p_ptr->version);
  auto ver = QVersionNumber::fromString(FK_VERSION);
  int cmp = QVersionNumber::compare(ver, client_ver);
  if (cmp != 0) {
    auto errmsg = QString();
    if (cmp < 0) {
      errmsg = QStringLiteral("[\"server is still on version %%2\",\"%1\"]")
                      .arg(FK_VERSION, "1");
    } else {
      errmsg = QStringLiteral("[\"server is using version %%2, please update\",\"%1\"]")
                      .arg(FK_VERSION, "1");
    }

    server->sendEarlyPacket(p_ptr->client, "ErrorDlg", errmsg.toUtf8());
    p_ptr->client->disconnectFromHost();
    return false;
  }
  return true;
}

bool AuthManager::checkIfUuidNotBanned() {
  auto uuid_str = p_ptr->uuid;
  Sqlite3::QueryResult result2 = { {} };
  if (Sqlite3::checkString(uuid_str)) {
    result2 = db->select(QStringLiteral("SELECT * FROM banuuid WHERE uuid='%1';").arg(uuid_str));
  }

  if (!result2.isEmpty()) {
    server->sendEarlyPacket(p_ptr->client, "ErrorDlg", "you have been banned!");
    qInfo() << "Refused banned UUID:" << uuid_str;
    p_ptr->client->disconnectFromHost();
    return false;
  }

  return true;
}

bool AuthManager::checkMd5() {
  auto md5_str = p_ptr->md5;
  if (server->getMd5() != md5_str) {
    server->sendEarlyPacket(p_ptr->client, "ErrorMsg", "MD5 check failed!");
    server->sendEarlyPacket(
      p_ptr->client,
      "UpdatePackage",
      QCborValue::fromJsonValue(
        QJsonDocument::fromJson(
          Pacman->getPackSummary().toUtf8()
        ).array()
      ).toCbor()
    );
    p_ptr->client->disconnectFromHost();
    return false;
  }
  return true;
}

QMap<QString, QString> AuthManager::queryUserInfo(const QByteArray &password) {
  auto db = server->getDatabase();
  auto pw = password;
  auto sql_find = QStringLiteral("SELECT * FROM userinfo WHERE name='%1';")
    .arg(p_ptr->name);
  auto sql_count_uuid = QStringLiteral("SELECT COUNT() AS cnt FROM uuidinfo WHERE uuid='%1';")
    .arg(p_ptr->uuid);

  auto result = db->select(sql_find);
  if (result.isEmpty()) {
    auto result2 = db->select(sql_count_uuid);
    auto num = result2[0]["cnt"].toInt();
    if (num >= server->getConfig("maxPlayersPerDevice").toInt()) {
      return {};
    }
    auto salt_gen = QRandomGenerator::securelySeeded();
    auto salt = QByteArray::number(salt_gen(), 16);
    pw.append(salt);
    auto passwordHash =
      QCryptographicHash::hash(pw, QCryptographicHash::Sha256).toHex();
    auto sql_reg = QString("INSERT INTO userinfo (name,password,salt,\
avatar,lastLoginIp,banned) VALUES ('%1','%2','%3','%4','%5',%6);")
      .arg(p_ptr->name).arg(QString(passwordHash))
      .arg(salt).arg("liubei").arg(p_ptr->client->peerAddress())
      .arg("FALSE");
    db->exec(sql_reg);
    result = db->select(sql_find); // refresh result
    auto obj = result[0];

    auto info_update = QString("INSERT INTO usergameinfo (id, registerTime) VALUES (%1, %2);").arg(obj["id"].toInt()).arg(QDateTime::currentSecsSinceEpoch());
    db->exec(info_update);
  }
  return result[0];
}

QMap<QString, QString> AuthManager::checkPassword() {
  auto client = p_ptr->client;
  auto name = p_ptr->name;
  auto password = p_ptr->password;
  bool passed = false;
  const char *error_msg = nullptr;
  QMap<QString, QString> obj;
  int id;
  QByteArray salt;
  QByteArray passwordHash;
  auto players = server->getPlayers();

  unsigned char buf[4096] = {0};
  RSA_private_decrypt(RSA_size(p_ptr->rsa), (const unsigned char *)password.data(),
                      buf, p_ptr->rsa, RSA_PKCS1_PADDING);
  auto decrypted_pw =
      QByteArray::fromRawData((const char *)buf, strlen((const char *)buf));

  if (decrypted_pw.length() > 32) {
    // TODO: 先不加密吧，把CBOR搭起来先
    // auto aes_bytes = decrypted_pw.first(32);

    // tell client to install aes key
    // server->sendEarlyPacket(client, "InstallKey", "");
    // client->installAESKey(aes_bytes);
    decrypted_pw.remove(0, 32);
  } else {
    // FIXME
    // decrypted_pw = "\xFF";
    error_msg = "unknown password error";
    goto FAIL;
  }

  if (name.isEmpty() || !Sqlite3::checkString(name) || !server->checkBanWord(name)) {
    error_msg = "invalid user name";
    goto FAIL;
  }

  if (!server->nameIsInWhiteList(name)) {
    error_msg = "user name not in whitelist";
    goto FAIL;
  }

  obj = queryUserInfo(decrypted_pw);
  if (obj.isEmpty()) {
    error_msg = "cannot register more new users on this device";
    goto FAIL;
  }

  // check ban account
  id = obj["id"].toInt();
  passed = obj["banned"].toInt() == 0;
  if (!passed) {
    error_msg = "you have been banned!";
    goto FAIL;
  }

  // check if password is the same
  salt = obj["salt"].toLatin1();
  decrypted_pw.append(salt);
  passwordHash =
    QCryptographicHash::hash(decrypted_pw, QCryptographicHash::Sha256).toHex();
  passed = (passwordHash == obj["password"]);
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
      updateUserLoginData(id);
      player->reconnect(client);
      passed = true;
      return {};
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
    return {};
  }

  return obj;
}

void AuthManager::updateUserLoginData(int id) {
  server->beginTransaction();
  auto sql_update =
    QStringLiteral("UPDATE userinfo SET lastLoginIp='%1' WHERE id=%2;")
    .arg(p_ptr->client->peerAddress())
    .arg(id);
  db->exec(sql_update);

  auto uuid_update = QString("REPLACE INTO uuidinfo (id, uuid) VALUES (%1, '%2');")
    .arg(id).arg(p_ptr->uuid);
  db->exec(uuid_update);

  // 来晚了，有很大可能存在已经注册但是表里面没数据的人
  db->exec(QStringLiteral("INSERT OR IGNORE INTO usergameinfo (id) VALUES (%1);").arg(id));
  auto info_update = QStringLiteral("UPDATE usergameinfo SET lastLoginTime=%2 where id=%1;").arg(id).arg(QDateTime::currentSecsSinceEpoch());
  db->exec(info_update);
  server->endTransaction();
}

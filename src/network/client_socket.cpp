// SPDX-License-Identifier: GPL-3.0-or-later

#include "network/client_socket.h"
#include <openssl/aes.h>

ClientSocket::ClientSocket() : socket(new QTcpSocket(this)) {
  aes_ready = false;
  init();
}

ClientSocket::ClientSocket(QTcpSocket *socket) {
  aes_ready = false;
  socket->setParent(this);
  this->socket = socket;
  timerSignup.setSingleShot(true);
  connect(&timerSignup, &QTimer::timeout, this,
          &ClientSocket::disconnectFromHost);
  connect(&timerSignup, &QTimer::timeout, this, &QObject::deleteLater);
  init();
}

void ClientSocket::init() {
  connect(socket, &QTcpSocket::connected, this, &ClientSocket::connected);
  connect(socket, &QTcpSocket::disconnected, this, &ClientSocket::disconnected);
  connect(socket, &QTcpSocket::disconnected, this, &ClientSocket::removeAESKey);
  connect(socket, &QTcpSocket::readyRead, this, &ClientSocket::getMessage);
  connect(socket, &QTcpSocket::errorOccurred, this, &ClientSocket::raiseError);
  socket->setSocketOption(QAbstractSocket::KeepAliveOption, 1);
}

void ClientSocket::connectToHost(const QString &address, ushort port) {
  socket->connectToHost(address, port);
}

void ClientSocket::getMessage() {
  cborBuffer += socket->readAll();
  QCborError err;
  auto arr = readCborArrsFromBuffer(&err);
  if (err == QCborError::EndOfFile || err == QCborError::NoError) {
    for (auto &a : arr) emit message_got(a);
    return;
  } else {
    // TODO: close conn?
    // 反正肯定会有不合法数据的，比如invalid setup string
    // 旧版客户端啥的
    disconnectFromHost();
    return;
  }
  // while (socket->canReadLine()) {
  //   auto msg = socket->readLine();
  //   msg = aesDec(msg);
  //   if (msg.startsWith("Compressed")) {
  //     msg = msg.sliced(10);
  //     msg = qUncompress(QByteArray::fromBase64(msg));
  //   }
  //   emit message_got(msg.simplified());
  // }
}

void ClientSocket::disconnectFromHost() {
  aes_ready = false;
  socket->disconnectFromHost();
}

void ClientSocket::send(const QByteArray &msg) {
  if (socket->state() != QTcpSocket::ConnectedState) {
    emit error_message("Cannot send messages if not connected");
    return;
  }
  // QByteArray _msg;
  // if (msg.length() >= 1024) {
  //   auto comp = qCompress(msg);
  //   _msg = QByteArrayLiteral("Compressed") + comp.toBase64();
  //   _msg = aesEnc(_msg) + "\n";
  // } else {
  //   _msg = aesEnc(msg) + "\n";
  // }

  socket->write(msg);
  socket->flush();
}

bool ClientSocket::isConnected() const {
  return socket->state() == QTcpSocket::ConnectedState;
}

QString ClientSocket::peerName() const {
  QString peer_name = socket->peerName();
  if (peer_name.isEmpty())
    peer_name = QString("%1:%2")
                    .arg(socket->peerAddress().toString())
                    .arg(socket->peerPort());

  return peer_name;
}

QString ClientSocket::peerAddress() const {
  return socket->peerAddress().toString();
}

void ClientSocket::raiseError(QAbstractSocket::SocketError socket_error) {
  // translate error message
  QString reason;
  switch (socket_error) {
  case QAbstractSocket::ConnectionRefusedError:
    reason = tr("Connection was refused or timeout");
    break;
  case QAbstractSocket::RemoteHostClosedError:
    reason = tr("Remote host close this connection");
    break;
  case QAbstractSocket::HostNotFoundError:
    reason = tr("Host not found");
    break;
  case QAbstractSocket::SocketAccessError:
    reason = tr("Socket access error");
    break;
  case QAbstractSocket::SocketResourceError:
    reason = tr("Socket resource error");
    break;
  case QAbstractSocket::SocketTimeoutError:
    reason = tr("Socket timeout error");
    break;
  case QAbstractSocket::DatagramTooLargeError:
    reason = tr("Datagram too large error");
    break;
  case QAbstractSocket::NetworkError:
    reason = tr("Network error");
    break;
  case QAbstractSocket::UnsupportedSocketOperationError:
    reason = tr("Unsupprted socket operation");
    break;
  case QAbstractSocket::UnfinishedSocketOperationError:
    reason = tr("Unfinished socket operation");
    break;
  case QAbstractSocket::ProxyAuthenticationRequiredError:
    reason = tr("Proxy auth error");
    break;
  case QAbstractSocket::ProxyConnectionRefusedError:
    reason = tr("Proxy refused");
    break;
  case QAbstractSocket::ProxyConnectionClosedError:
    reason = tr("Proxy closed");
    break;
  case QAbstractSocket::ProxyConnectionTimeoutError:
    reason = tr("Proxy timeout");
    break;
  case QAbstractSocket::ProxyProtocolError:
    reason = tr("Proxy protocol error");
    break;
  case QAbstractSocket::OperationError:
    reason = tr("Operation error");
    break;
  case QAbstractSocket::TemporaryError:
    reason = tr("Temporary error");
    break;
  default:
    reason = tr("Unknown error");
    break;
  }

  emit error_message(tr("Connection failed, error code = %1\n reason: %2")
                         .arg(socket_error)
                         .arg(reason));
}

void ClientSocket::installAESKey(const QByteArray &key) {
  if (key.length() != 32) {
    return;
  }
  auto key_ = QByteArray::fromHex(key);
  if (key_.length() != 16) {
    return;
  }

  AES_set_encrypt_key((const unsigned char *)key_.data(), 16 * 8, &aes_key);
  aes_ready = true;
}

void ClientSocket::removeAESKey() {
  aes_ready = false;
}

QByteArray ClientSocket::aesEnc(const QByteArray &in) {
  if (!aes_ready) {
    return in;
  }
  int num = 0;
  QByteArray out;
  out.resize(in.length());

  static auto rand_generator = QRandomGenerator::securelySeeded();
  static QByteArray iv_raw(16, Qt::Uninitialized);

  rand_generator.fillRange(reinterpret_cast<quint32*>(iv_raw.data()), 4);

  static unsigned char tempIv[16];
  strncpy((char *)tempIv, iv_raw.constData(), 16);
  AES_cfb128_encrypt((const unsigned char *)in.constData(),
                     (unsigned char *)out.data(), in.length(), &aes_key, tempIv,
                     &num, AES_ENCRYPT);

  return iv_raw.toHex() + out.toBase64();
}
QByteArray ClientSocket::aesDec(const QByteArray &in) {
  if (!aes_ready) {
    return in;
  }

  int num = 0;
  auto iv = in.first(32);
  auto aes_iv = QByteArray::fromHex(iv);

  auto real_in = in;
  real_in.remove(0, 32);
  auto inenc = QByteArray::fromBase64(real_in);
  QByteArray out;
  out.resize(inenc.length());
  unsigned char tempIv[16];
  strncpy((char *)tempIv, aes_iv.constData(), 16);
  AES_cfb128_encrypt((const unsigned char *)inenc.constData(),
                     (unsigned char *)out.data(), inenc.length(), &aes_key,
                     tempIv, &num, AES_DECRYPT);

  return out;
}

// 通信上只涉及数字、bytes两种类型而已，以及array
static QCborValue readItem(QCborStreamReader &reader) {
  switch (reader.type()) {
    case QCborStreamReader::UnsignedInteger:
    case QCborStreamReader::NegativeInteger: {
      auto val = reader.toInteger();
      reader.next();
      return val;
    }
    case QCborStreamReader::ByteArray: {
      QByteArray ret;
      auto r = reader.readByteArray();
      while (r.status == QCborStreamReader::Ok) {
        ret += r.data;
        r = reader.readByteArray();
      }

      if (r.status == QCborStreamReader::Error) {
        // handle error condition
        ret.clear();
      }
      return ret;
    }
    case QCborStreamReader::Array: {
      QCborArray arr;
      reader.enterContainer();
      while (reader.lastError() == QCborError::NoError && reader.hasNext()) {
        auto item = readItem(reader);
        if (item.isUndefined()) break;
        arr << item;
      }
      if (reader.lastError() == QCborError::NoError)
        reader.leaveContainer();
      return arr;
    }
    default:
      break;
  }
  return QCborValue();
}

QList<QCborArray> ClientSocket::readCborArrsFromBuffer(QCborError *err) {
  // 由于qt神秘机制，此处干脆用const char *和len手动操作缓冲区
  auto cbuf = cborBuffer.constData();
  auto len = cborBuffer.size();
  QList<QCborArray> ret;

  while (true) {
    QCborStreamReader reader(cbuf, len);
    auto item = readItem(reader);
    if (reader.lastError() != QCborError::NoError) {
      *err = reader.lastError();
      break;
    }
    if (!item.isArray()) break;
    ret << item.toArray();
    auto off = reader.currentOffset();
    cbuf += off;
    len -= off;
  }

  // 对剩余的不全数据深拷贝 重新造bytes
  cborBuffer = { cbuf, len };
  return ret;
}

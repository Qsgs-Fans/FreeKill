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
  init();
}

void ClientSocket::init() {
  connect(socket, &QTcpSocket::connected, this, &ClientSocket::connected);
  connect(socket, &QTcpSocket::disconnected, this, &ClientSocket::disconnected);
  connect(socket, &QTcpSocket::readyRead, this, &ClientSocket::getMessage);
  connect(socket, &QTcpSocket::errorOccurred, this, &ClientSocket::raiseError);
  socket->setSocketOption(QAbstractSocket::KeepAliveOption, 1);
}

void ClientSocket::connectToHost(const QString &address, ushort port) {
  socket->connectToHost(address, port);
}

void ClientSocket::getMessage() {
  while (socket->canReadLine()) {
    auto msg = socket->readLine();
    msg = aesDec(msg);
    if (msg.startsWith("Compressed")) {
      msg = msg.sliced(10);
      msg = qUncompress(QByteArray::fromBase64(msg));
    }
    emit message_got(msg);
  }
}

void ClientSocket::disconnectFromHost() {
  aes_ready = false;
  socket->disconnectFromHost();
}

void ClientSocket::send(const QByteArray &msg) {
  QByteArray _msg;
  if (msg.length() >= 1024) {
    auto comp = qCompress(msg);
    _msg = "Compressed" + comp.toBase64();
    _msg = aesEnc(_msg) + "\n";
  } else {
    _msg = aesEnc(msg) + "\n";
  }

  socket->write(_msg);
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

  AES_set_encrypt_key((const unsigned char *)key_.data(), 16 * 8, &aes_key);
  aes_ready = true;
}

QByteArray ClientSocket::aesEnc(const QByteArray &in) {
  if (!aes_ready) {
    return in;
  }
  int num = 0;
  QByteArray out;
  out.resize(in.length());

  auto rand_generator = QRandomGenerator::securelySeeded();

  QByteArray iv;
  iv.append(QByteArray::number(rand_generator.generate64(), 16));
  iv.append(QByteArray::number(rand_generator.generate64(), 16));
  if (iv.length() < 32) {
    iv.append(QByteArray("0").repeated(32 - iv.length()));
  }
  auto iv_raw = QByteArray::fromHex(iv);

  unsigned char tempIv[16];
  strncpy((char *)tempIv, iv_raw.constData(), 16);
  AES_cfb128_encrypt((const unsigned char *)in.constData(),
                     (unsigned char *)out.data(), in.length(), &aes_key, tempIv,
                     &num, AES_ENCRYPT);

  return iv + out.toBase64();
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

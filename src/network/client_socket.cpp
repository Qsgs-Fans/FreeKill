// SPDX-License-Identifier: GPL-3.0-or-later

#include "client_socket.h"
#include <openssl/aes.h>

ClientSocket::ClientSocket() : socket(new QTcpSocket(this)) {
  aes_ready = false;
  init();
}

ClientSocket::ClientSocket(QTcpSocket *socket) {
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
    msg = aesDecrypt(msg);
    if (msg.startsWith("Compressed")) {
      msg = msg.sliced(10);
      msg = qUncompress(QByteArray::fromBase64(msg));
    }
    emit message_got(msg);
  }
}

void ClientSocket::disconnectFromHost() { socket->disconnectFromHost(); }

void ClientSocket::send(const QByteArray &msg) {
  if (msg.length() >= 300) {
    auto comp = qCompress(msg);
    auto _msg = "Compressed" + comp.toBase64();
    _msg = aesEncrypt(_msg) + "\n";
    socket->write(_msg);
    socket->flush();
    return;
  }
  auto _msg = aesEncrypt(msg) + "\n";
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
  case QAbstractSocket::NetworkError:
    return; // this error is ignored ...
  default:
    reason = tr("Unknown error");
    break;
  }

  emit error_message(tr("Connection failed, error code = %1\n reason: %2")
                         .arg(socket_error)
                         .arg(reason));
}

void ClientSocket::installAESKey(const QByteArray &key) {
  auto key_ = QByteArray::fromHex(key.first(32));
  auto iv = QByteArray::fromHex(key.last(32));

  AES_set_encrypt_key((const unsigned char *)key_.data(), 16 * 8, &aes_key);
  aes_iv = iv;
  aes_ready = true;
}

QByteArray ClientSocket::aesEncrypt(const QByteArray &in) {
  if (!aes_ready) {
    return in;
  }
  int num = 0;
  QByteArray out;
  out.resize(in.length());
  unsigned char tempIv[16];
  strncpy((char *)tempIv, aes_iv.constData(), 16);
  AES_cfb128_encrypt((const unsigned char *)in.constData(),
                     (unsigned char *)out.data(), in.length(), &aes_key, tempIv,
                     &num, AES_ENCRYPT);

  return out.toBase64();
}
QByteArray ClientSocket::aesDecrypt(const QByteArray &in) {
  if (!aes_ready) {
    return in;
  }

  int num = 0;
  auto inenc = QByteArray::fromBase64(in);
  QByteArray out;
  out.resize(inenc.length());
  unsigned char tempIv[16];
  strncpy((char *)tempIv, aes_iv.constData(), 16);
  AES_cfb128_encrypt((const unsigned char *)inenc.constData(),
                     (unsigned char *)out.data(), inenc.length(), &aes_key,
                     tempIv, &num, AES_DECRYPT);

  return out;
}

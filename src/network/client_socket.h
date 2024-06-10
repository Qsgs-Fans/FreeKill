// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _CLIENT_SOCKET_H
#define _CLIENT_SOCKET_H

#include <openssl/aes.h>

class ClientSocket : public QObject {
  Q_OBJECT

public:
  ClientSocket();
  // For server use
  ClientSocket(QTcpSocket *socket);

  void connectToHost(const QString &address = "127.0.0.1", ushort port = 9527u);
  void disconnectFromHost();
  void installAESKey(const QByteArray &key);
  void send(const QByteArray& msg);
  bool isConnected() const;
  QString peerName() const;
  QString peerAddress() const;
  QTimer timerSignup;

signals:
  void message_got(const QByteArray& msg);
  void error_message(const QString &msg);
  void disconnected();
  void connected();

private slots:
  void getMessage();
  void raiseError(QAbstractSocket::SocketError error);

private:
  QByteArray aesEnc(const QByteArray &in);
  QByteArray aesDec(const QByteArray &out);
  AES_KEY aes_key;
  bool aes_ready;
  QTcpSocket *socket;
  void init();
};

#endif // _CLIENT_SOCKET_H

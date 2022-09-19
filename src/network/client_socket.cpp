#include "client_socket.h"

ClientSocket::ClientSocket() : socket(new QTcpSocket(this))
{
  init();
}

ClientSocket::ClientSocket(QTcpSocket* socket)
{
  socket->setParent(this);
  this->socket = socket;
  timerSignup.setSingleShot(true);
  connect(&timerSignup, &QTimer::timeout, this, &ClientSocket::disconnectFromHost);
  init();
}

void ClientSocket::init()
{
  connect(socket, &QTcpSocket::connected,
          this, &ClientSocket::connected);
  connect(socket, &QTcpSocket::disconnected,
          this, &ClientSocket::disconnected);
  connect(socket, &QTcpSocket::readyRead,
          this, &ClientSocket::getMessage);
  connect(socket, &QTcpSocket::errorOccurred,
          this, &ClientSocket::raiseError);
}

void ClientSocket::connectToHost(const QString &address, ushort port)
{
  socket->connectToHost(address, port);
}

void ClientSocket::getMessage()
{
  while (socket->canReadLine()) {
    char msg[16000];  // buffer
    socket->readLine(msg, sizeof(msg));
    emit message_got(msg);
  }
}

void ClientSocket::disconnectFromHost()
{
  socket->disconnectFromHost();
}

void ClientSocket::send(const QByteArray &msg)
{
  socket->write(msg);
  if (!msg.endsWith("\n"))
    socket->write("\n");
  socket->flush();
}

bool ClientSocket::isConnected() const
{
  return socket->state() == QTcpSocket::ConnectedState;
}

QString ClientSocket::peerName() const
{
  QString peer_name = socket->peerName();
  if (peer_name.isEmpty())
    peer_name = QString("%1:%2").arg(socket->peerAddress().toString()).arg(socket->peerPort());

  return peer_name;
}

QString ClientSocket::peerAddress() const
{
  return socket->peerAddress().toString();
}

void ClientSocket::raiseError(QAbstractSocket::SocketError socket_error)
{
  // translate error message
  QString reason;
  switch (socket_error) {
  case QAbstractSocket::ConnectionRefusedError:
    reason = tr("Connection was refused or timeout"); break;
  case QAbstractSocket::RemoteHostClosedError:
    reason = tr("Remote host close this connection"); break;
  case QAbstractSocket::HostNotFoundError:
    reason = tr("Host not found"); break;
  case QAbstractSocket::SocketAccessError:
    reason = tr("Socket access error"); break;
  case QAbstractSocket::NetworkError:
    return; // this error is ignored ...
  default: reason = tr("Unknow error"); break;
  }

  emit error_message(tr("Connection failed, error code = %1\n reason: %2")
    .arg(socket_error).arg(reason));
}

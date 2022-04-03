#include "router.h"
#include "client.h"
#include "client_socket.h"
#include "server.h"
#include "serverplayer.h"

Router::Router(QObject *parent, ClientSocket *socket, RouterType type)
    : QObject(parent)
{
    this->type = type;
    this->socket = nullptr;
    setSocket(socket);
    expectedReplyId = -1;
    replyTimeout = 0;
    extraReplyReadySemaphore = nullptr;
}

Router::~Router()
{
    abortRequest();
}

ClientSocket* Router::getSocket() const
{
    return socket;
}

void Router::setSocket(ClientSocket *socket)
{
    if (this->socket != nullptr) {
        this->socket->disconnect(this);
        disconnect(this->socket);
        this->socket->deleteLater();
    }

    this->socket = nullptr;
    if (socket != nullptr) {
        connect(this, &Router::messageReady, socket, &ClientSocket::send);
        connect(socket, &ClientSocket::message_got, this, &Router::handlePacket);
        connect(socket, &ClientSocket::disconnected, this, &Router::abortRequest);
        socket->setParent(this);
        this->socket = socket;
    }
}

void Router::setReplyReadySemaphore(QSemaphore *semaphore)
{
    extraReplyReadySemaphore = semaphore;
}

void Router::request(int type, const QString& command,
                     const QString& jsonData, int timeout)
{
    // In case a request is called without a following waitForReply call
    if (replyReadySemaphore.available() > 0)
        replyReadySemaphore.acquire(replyReadySemaphore.available());

    static int requestId = 0;
    requestId++;

    replyMutex.lock();
    expectedReplyId = requestId;
    replyTimeout = timeout;
    requestStartTime = QDateTime::currentDateTime();
    m_reply = QString();
    replyMutex.unlock();

    QJsonArray body;
    body << requestId;
    body << type;
    body << command;
    body << jsonData;
    body << timeout;

    emit messageReady(QJsonDocument(body).toJson(QJsonDocument::Compact));
}

void Router::reply(int type, const QString& command, const QString& jsonData)
{
    QJsonArray body;
    body << this->requestId;
    body << type;
    body << command;
    body << jsonData;

    emit messageReady(QJsonDocument(body).toJson(QJsonDocument::Compact));
}

void Router::notify(int type, const QString& command, const QString& jsonData)
{
    QJsonArray body;
    body << -2;         // requestId = -2 mean this is for notification
    body << type;
    body << command;
    body << jsonData;

    emit messageReady(QJsonDocument(body).toJson(QJsonDocument::Compact));
}

int Router::getTimeout() const
{
    return requestTimeout;
}

// cancel last request from the sender
void Router::cancelRequest()
{
    replyMutex.lock();
    expectedReplyId = -1;
    replyTimeout = 0;
    extraReplyReadySemaphore = nullptr;
    replyMutex.unlock();

    if (replyReadySemaphore.available() > 0)
        replyReadySemaphore.acquire(replyReadySemaphore.available());
}

QString Router::waitForReply()
{
    replyReadySemaphore.acquire();
    return m_reply;
}

QString Router::waitForReply(int timeout)
{
    replyReadySemaphore.tryAcquire(1, timeout * 1000);
    return m_reply;
}

void Router::abortRequest()
{
    replyMutex.lock();
    if (expectedReplyId != -1) {
        replyReadySemaphore.release();
        if (extraReplyReadySemaphore)
            extraReplyReadySemaphore->release();
        expectedReplyId = -1;
        extraReplyReadySemaphore = nullptr;
    }
    replyMutex.unlock();
}

void Router::handlePacket(const QByteArray& rawPacket)
{
    QJsonDocument packet = QJsonDocument::fromJson(rawPacket);
    if (packet.isNull() || !packet.isArray())
        return;

    int requestId = packet[0].toInt();
    int type = packet[1].toInt();
    QString command = packet[2].toString();
    QString jsonData = packet[3].toString();

    if (type & TYPE_NOTIFICATION) {
        if (type & DEST_CLIENT) {
            ClientInstance->callLua(command, jsonData);
        } else {
            ServerPlayer *player = qobject_cast<ServerPlayer *>(parent());
            // Add the uid of sender to jsonData
            QJsonArray arr = QJsonDocument::fromJson(jsonData.toUtf8()).array();
            arr.prepend(player->getId());

            Room *room = player->getRoom();
            room->lockLua(__FUNCTION__);
            room->callLua(command, QJsonDocument(arr).toJson());
            room->unlockLua(__FUNCTION__);
        }
    }
    else if (type & TYPE_REQUEST) {
        this->requestId = requestId;
        this->requestTimeout = packet[4].toInt();

        if (type & DEST_CLIENT) {
            qobject_cast<Client *>(parent())->callLua(command, jsonData);
        } else {
            // requesting server is not allowed
            Q_ASSERT(false);
        }
    }
    else if (type & TYPE_REPLY) {
        QMutexLocker locker(&replyMutex);

        if (requestId != this->expectedReplyId)
            return;

        this->expectedReplyId = -1;

        if (replyTimeout >= 0 && replyTimeout <
            requestStartTime.secsTo(QDateTime::currentDateTime()))
            return;

        m_reply = jsonData;
        // TODO: callback?

        replyReadySemaphore.release();
        if (extraReplyReadySemaphore) {
            extraReplyReadySemaphore->release();
            extraReplyReadySemaphore = nullptr;
        }
        locker.unlock();
        emit replyReady();
    }
}


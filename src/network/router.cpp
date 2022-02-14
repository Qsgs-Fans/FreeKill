#include <QJsonArray>
#include <QJsonDocument>
#include "router.h"

Router::Router(QObject *parent, QObject *receiver, ClientSocket *socket)
    : QObject(parent)
{
    this->receiver = receiver;
    socket = nullptr;
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
    if (socket != nullptr) {
        socket->disconnect(this);
        disconnect(socket);
        socket->deleteLater();
    }

    this->socket = nullptr;
    if (socket != Q_NULLPTR) {
        connect(this, &Router::messageReady, socket, &ClientSocket::send);
        connect(socket, &ClientSocket::message_got, this, &Router::handlePacket);
        connect(socket, &ClientSocket::disconnected, this, &Router::abortRequest);
        socket->setParent(this);
    }
}

void Router::setReplyReadySemaphore(QSemaphore *semaphore)
{
    extraReplyReadySemaphore = semaphore;
}

void Router::request(int type, const QString& command,
                     const QString& json_data, int timeout)
{
    // In case a request is called without a following waitForReply call
    if (replyReadySemaphore.available() > 0)
        replyReadySemaphore.acquire(replyReadySemaphore.available());

    static int requestId = 0;
    requestId++;

    replyMutex.lock();
    expectedReplyId = requestId;
    replyTimeout = 0;
    requestStartTime = QDateTime::currentDateTime();
    m_reply = QString();
    replyMutex.unlock();

    QJsonArray body;
    body << requestId;
    body << type;
    body << command;
    body << json_data;
    body << timeout;

    emit messageReady(QJsonDocument(body).toJson());
}

void Router::reply(int type, const QString& command, const QString& json_data)
{
    QJsonArray body;
    body << this->requestId;
    body << type;
    body << command;
    body << json_data;

    emit messageReady(QJsonDocument(body).toJson());
}

void Router::notify(int type, const QString& command, const QString& json_data)
{
    QJsonArray body;
    body << -2;         // requestId = -2 mean this is for notification
    body << type;
    body << command;
    body << json_data;

    emit messageReady(QJsonDocument(body).toJson());
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
    replyReadySemaphore.tryAcquire(1, timeout);
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
    if (receiver == nullptr)
        return;

    QJsonDocument packet = QJsonDocument::fromJson(rawPacket);
    if (packet.isNull() || !packet.isArray())
        return;

    int requestId = packet[0].toInt();
    int type = packet[1].toInt();
    QString command = packet[2].toString();
    QString json_data = packet[3].toString();

    if (type & TYPE_NOTIFICATION) {
        // TODO: let receiver call function
        // sender->func
    }
    else if (type & TYPE_REQUEST) {
        this->requestId = requestId;
        this->requestTimeout = packet[4].toInt();

        // TODO: callback
    }
    else if (type & TYPE_REPLY) {
        QMutexLocker locker(&replyMutex);

        if (requestId != this->expectedReplyId)
            return;

        this->expectedReplyId = -1;

        if (replyTimeout >= 0 && replyTimeout <
            requestStartTime.secsTo(QDateTime::currentDateTime()))
            return;

        m_reply = json_data;
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


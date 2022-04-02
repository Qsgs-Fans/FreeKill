#include "qmlbackend.h"
#include "server.h"
#include "client.h"

QmlBackend *Backend;

QmlBackend::QmlBackend(QObject* parent)
    : QObject(parent)
{
    Backend = this;
    engine = nullptr;
}

QQmlApplicationEngine *QmlBackend::getEngine() const
{
    return engine;
}

void QmlBackend::setEngine(QQmlApplicationEngine *engine)
{
    this->engine = engine;
}

void QmlBackend::startServer(ushort port)
{
    if (!ServerInstance) {
        Server *server = new Server(this);

        if (!server->listen(QHostAddress::Any, port)) {
            server->deleteLater();
            emit notifyUI("ErrorMsg", tr("Cannot start server!"));
        }
    }
}

void QmlBackend::joinServer(QString address)
{
    if (ClientInstance != nullptr) return;
    Client *client = new Client(this);
    connect(client, &Client::error_message, [this, client](const QString &msg){
        client->deleteLater();
        emit notifyUI("ErrorMsg", msg);
        emit notifyUI("BackToStart", "[]");
    });
    QString addr = "127.0.0.1";
    ushort port = 9527u;

    if (address.contains(QChar(':'))) {
        QStringList texts = address.split(QChar(':'));
        addr = texts.value(0);
        port = texts.value(1).toUShort();
    } else {
        addr = address;
    }

    client->connectToHost(QHostAddress(addr), port);
}

void QmlBackend::quitLobby()
{
    delete ClientInstance;
}

void QmlBackend::emitNotifyUI(const QString &command, const QString &jsonData) {
    emit notifyUI(command, jsonData);
}

void QmlBackend::cd(const QString &path) {
    QDir::setCurrent(path);
}

QStringList QmlBackend::ls(const QString &dir) {
    return QDir(dir).entryList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
}

QString QmlBackend::pwd() {
    return QDir::currentPath();
}

bool QmlBackend::exists(const QString &file) {
    return QFile::exists(file);
}

bool QmlBackend::isDir(const QString &file) {
    return QFileInfo(file).isDir();
}

QString QmlBackend::translate(const QString &src) {
    lua_State *L = ClientInstance->getLuaState();
    lua_getglobal(L, "Translate");
    lua_pushstring(L, src.toUtf8().data());

    int err = lua_pcall(L, 1, 1, 0);
    const char *result = lua_tostring(L, -1);
    if (err) {
        qDebug() << result;
        lua_pop(L, 1);
        return "";
    }
    lua_pop(L, 1);
    return QString(result);
}

QString QmlBackend::getGeneralData(const QString &general_name) {
    lua_State *L = ClientInstance->getLuaState();
    lua_getglobal(L, "GetGeneralData");
    lua_pushstring(L, general_name.toUtf8().data());

    int err = lua_pcall(L, 1, 1, 0);
    const char *result = lua_tostring(L, -1);
    if (err) {
        qDebug() << result;
        lua_pop(L, 1);
        return "";
    }
    lua_pop(L, 1);
    return QString(result);
}

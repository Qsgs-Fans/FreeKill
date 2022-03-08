#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QCommandLineParser>
#include <QDir>
#include "qmlbackend.h"
#include "server.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("FreeKill");
    QGuiApplication::setApplicationVersion("Alpha 0.0.1");

    QCommandLineParser parser;
    parser.setApplicationDescription("FreeKill server");
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addOption({{"s", "server"}, "start server at <port>", "port"});
    parser.process(app);

    bool startServer = parser.isSet("server");
    ushort serverPort = 9527;

    if (startServer) {
        bool ok = false;
        if (parser.value("server").toInt(&ok) && ok)
            serverPort = parser.value("server").toInt();
        Server *server = new Server;
        if (!server->listen(QHostAddress::Any, serverPort)) {
            fprintf(stderr, "cannot listen on port %d!\n", serverPort);
            exit(1);
        }
        return app.exec();
    }

    QQmlApplicationEngine engine;
    QmlBackend backend;
    engine.rootContext()->setContextProperty("Backend", &backend);
    QUrl currentDir = QUrl::fromLocalFile(QDir::currentPath());
    engine.rootContext()->setContextProperty("AppPath", currentDir);
    engine.load("qml/main.qml");

    return app.exec();
}

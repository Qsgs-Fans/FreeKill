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
            app.exit(1);
        }
        return app.exec();
    }

    QQmlApplicationEngine engine;
    
    QmlBackend backend;
    backend.setEngine(&engine);
    
    engine.rootContext()->setContextProperty("Backend", &backend);
    engine.rootContext()->setContextProperty("AppPath", QUrl::fromLocalFile(QDir::currentPath()));
#ifdef QT_DEBUG
    bool debugging = true;
#else
    bool debugging = false;
#endif
    engine.rootContext()->setContextProperty("Debugging", debugging);
    engine.load("qml/main.qml");

    return app.exec();
}

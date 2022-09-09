#include "qmlbackend.h"
#include "server.h"

int main(int argc, char *argv[])
{
  QCoreApplication *app;
  QCoreApplication::setApplicationName("FreeKill");
  QCoreApplication::setApplicationVersion("Alpha 0.0.1");

#ifdef Q_OS_ANDROID
  QDir::setCurrent("/storage/emulated/0/FreeKill");
#endif

  QCommandLineParser parser;
  parser.setApplicationDescription("FreeKill server");
  parser.addHelpOption();
  parser.addVersionOption();
  parser.addOption({{"s", "server"}, "start server at <port>", "port"});
  QStringList cliOptions;
  for (int i = 0; i < argc; i++)
    cliOptions << argv[i];

  parser.parse(cliOptions);

  bool startServer = parser.isSet("server");
  ushort serverPort = 9527;

  if (startServer) {
    app = new QCoreApplication(argc, argv);
    bool ok = false;
    if (parser.value("server").toInt(&ok) && ok)
      serverPort = parser.value("server").toInt();
    Server *server = new Server;
    if (!server->listen(QHostAddress::Any, serverPort)) {
      fprintf(stderr, "cannot listen on port %d!\n", serverPort);
      app->exit(1);
    }
    return app->exec();
  }

  app = new QGuiApplication(argc, argv);

  QQmlApplicationEngine *engine = new QQmlApplicationEngine;
  
  QmlBackend backend;
  backend.setEngine(engine);
  
  engine->rootContext()->setContextProperty("Backend", &backend);
  engine->rootContext()->setContextProperty("AppPath", QUrl::fromLocalFile(QDir::currentPath()));
#ifdef QT_DEBUG
  bool debugging = true;
#else
  bool debugging = false;
#endif
  engine->rootContext()->setContextProperty("Debugging", debugging);
  engine->load("qml/main.qml");
  if (engine->rootObjects().isEmpty())
    return -1;

  int ret = app->exec();

  // delete the engine first
  // to avoid "TypeError: Cannot read property 'xxx' of null"
  delete engine;

  return ret;
}

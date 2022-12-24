#include "qmlbackend.h"
#ifndef Q_OS_WASM
#include "server.h"
#endif

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
#include "shell.h"
#endif

#if defined(Q_OS_WIN32)
#include "applink.c"
#endif

#include <QSplashScreen>
#include <QScreen>

#ifdef Q_OS_ANDROID
static bool copyPath(const QString &srcFilePath, const QString &tgtFilePath)
{
  QFileInfo srcFileInfo(srcFilePath);
  if (srcFileInfo.isDir()) {
    QDir targetDir(tgtFilePath);
    if (!targetDir.exists()) {
      targetDir.cdUp();
      if (!targetDir.mkdir(QFileInfo(tgtFilePath).fileName()))
        return false;
    }
    QDir sourceDir(srcFilePath);
    QStringList fileNames = sourceDir.entryList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System);
    foreach (const QString &fileName, fileNames) {
      const QString newSrcFilePath
          = srcFilePath + QLatin1Char('/') + fileName;
      const QString newTgtFilePath
          = tgtFilePath + QLatin1Char('/') + fileName;
      if (!copyPath(newSrcFilePath, newTgtFilePath))
        return false;
    }
  } else {
    QFile::remove(tgtFilePath);
    if (!QFile::copy(srcFilePath, tgtFilePath))
      return false;
  }
  return true;
}
#endif

void fkMsgHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg) {
  fprintf(stderr, "\r[%s] ", QTime::currentTime().toString("hh:mm:ss").toLatin1().constData());
  auto localMsg = msg.toUtf8();
  auto threadName = QThread::currentThread()->objectName().toLatin1().constData();
  switch (type) {
  case QtDebugMsg:
    fprintf(stderr, "[%s/\e[1;30mDEBUG\e[0m] %s\n", threadName, localMsg.constData());
    break;
  case QtInfoMsg:
    fprintf(stderr, "[%s/\e[1;32mINFO\e[0m] %s\n", threadName, localMsg.constData());
    break;
  case QtWarningMsg:
    fprintf(stderr, "[%s/\e[1;33mWARNING\e[0m] %s\n", threadName, localMsg.constData());
    break;
  case QtCriticalMsg:
    fprintf(stderr, "[%s/\e[1;31mCRITICAL\e[0m] %s\n", threadName, localMsg.constData());
    break;
  case QtFatalMsg:
    fprintf(stderr, "[%s/\e[1;31mFATAL\e[0m] %s\n", threadName, localMsg.constData());
    break;
  }
}

int main(int argc, char *argv[])
{
  QThread::currentThread()->setObjectName("Main");
  qInstallMessageHandler(fkMsgHandler);
  QCoreApplication *app;
  QCoreApplication::setApplicationName("FreeKill");
  QCoreApplication::setApplicationVersion("Alpha 0.0.1");

#ifndef Q_OS_WASM
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
      qFatal("cannot listen on port %d!\n", serverPort);
      app->exit(1);
    } else {
      qInfo("Server is listening on port %d", serverPort);
#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
      auto shell = new Shell;
      shell->start();
#endif
    }
    return app->exec();
  }
#endif

  app = new QApplication(argc, argv);

#define SHOW_SPLASH_MSG(msg) \
  splash.showMessage(msg, Qt::AlignHCenter | Qt::AlignBottom);

#ifdef Q_OS_ANDROID
  QScreen *screen = qobject_cast<QApplication *>(app)->primaryScreen();
  QRect screenGeometry = screen->geometry();
  int screenWidth = screenGeometry.width();
  int screenHeight = screenGeometry.height();
  QSplashScreen splash(QPixmap("assets:/res/image/splash.jpg").scaled(screenWidth, screenHeight));
  splash.showFullScreen();
  SHOW_SPLASH_MSG("Copying resources...");
  copyPath("assets:/res", QDir::currentPath());
#else
  QSplashScreen splash(QPixmap("image/splash.jpg"));
  splash.show();
#endif

  SHOW_SPLASH_MSG("Loading qml files...");
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
#ifdef Q_OS_ANDROID
  engine->rootContext()->setContextProperty("Android", true);
#else
  engine->rootContext()->setContextProperty("Android", false);
#endif
  engine->load("qml/main.qml");
  if (engine->rootObjects().isEmpty())
    return -1;

  splash.close();
  int ret = app->exec();

  // delete the engine first
  // to avoid "TypeError: Cannot read property 'xxx' of null"
  delete engine;

  return ret;
}

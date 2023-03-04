#include "qmlbackend.h"
#ifndef Q_OS_WASM
#include "server.h"
#include "packman.h"
#endif

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
#include "shell.h"
#endif

#if defined(Q_OS_WIN32)
#include "applink.c"
#endif

#include <QSplashScreen>
#include <QScreen>
#include <QFileDialog>
#ifndef Q_OS_ANDROID
#include <QQuickStyle>
#endif

#if defined(Q_OS_ANDROID) || defined(Q_OS_WASM)
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

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
#include <stdlib.h>
#include <unistd.h>
static void prepareForLinux() {
  // if user executes /usr/bin/FreeKill, that means freekill is installed by
  // package manager, and then we need to copy assets to ~/.local and change cwd
  char buf[256] = {0};
  int len = readlink("/proc/self/exe", buf, 256);
  if (!strcmp(buf, "/usr/bin/FreeKill")) {
    system("mkdir -p ~/.local/share/FreeKill");
    system("cp -r /usr/share/FreeKill ~/.local/share");
    chdir(getenv("HOME"));
    chdir(".local/share/FreeKill");
  } else if (!strcmp(buf, "/usr/local/bin/FreeKill")) {
    system("mkdir -p ~/.local/share/FreeKill");
    system("cp -r /usr/local/share/FreeKill ~/.local/share");
    chdir(getenv("HOME"));
    chdir(".local/share/FreeKill");
  }
}
#endif

void fkMsgHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg) {
  fprintf(stderr, "\r[%s] ", QTime::currentTime().toString("hh:mm:ss").toLatin1().constData());
  auto localMsg = msg.toUtf8();
  auto threadName = QThread::currentThread()->objectName().toLatin1();
  switch (type) {
  case QtDebugMsg:
    fprintf(stderr, "[%s/DEBUG] %s\n", threadName.constData(), localMsg.constData());
    break;
  case QtInfoMsg:
    fprintf(stderr, "[%s/INFO] %s\n", threadName.constData(), localMsg.constData());
    break;
  case QtWarningMsg:
    fprintf(stderr, "[%s/WARNING] %s\n", threadName.constData(), localMsg.constData());
    // if (Backend != nullptr) {
    //   Backend->notifyUI("ErrorDialog", localMsg);
    // }
    break;
  case QtCriticalMsg:
    fprintf(stderr, "[%s/CRITICAL] %s\n", threadName.constData(), localMsg.constData());
    if (Backend != nullptr) {
      Backend->notifyUI("ErrorDialog", QString("⛔ %1/Error occured!\n  %2")
        .arg(threadName).arg(localMsg));
    }
    break;
  case QtFatalMsg:
    fprintf(stderr, "[%s/FATAL] %s\n", threadName.constData(), localMsg.constData());
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

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
  prepareForLinux();
#endif

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
      Pacman = new PackMan;
      shell->start();
#endif
    }
    return app->exec();
  }
#else
  copyPath(":/", QDir::currentPath());
#endif

  app = new QApplication(argc, argv);
#ifdef DESKTOP_BUILD
  ((QApplication *)app)->setWindowIcon(QIcon("image/icon.png"));
#endif

#define SHOW_SPLASH_MSG(msg) \
  splash.showMessage(msg, Qt::AlignHCenter | Qt::AlignBottom);

#ifdef Q_OS_ANDROID
  QJniObject::callStaticMethod <void>("org/notify/FreeKill/Helper", "InitView", "()V");
  QDir::setCurrent("/storage/emulated/0/Android/data/org.notify.FreeKill/files");

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
#ifndef Q_OS_ANDROID
  QQuickStyle::setStyle("Material");
#endif

  QTranslator translator;
  Q_UNUSED(translator.load("zh_CN.qm"));
  QCoreApplication::installTranslator(&translator);

  QmlBackend backend;
  backend.setEngine(engine);

#ifndef Q_OS_WASM
  Pacman = new PackMan;
#endif

  engine->rootContext()->setContextProperty("Backend", &backend);
  engine->rootContext()->setContextProperty("Pacman", Pacman);

#ifdef QT_DEBUG
  bool debugging = true;
#else
  bool debugging = false;
#endif
  engine->rootContext()->setContextProperty("Debugging", debugging);


  QString system;
#if defined(Q_OS_ANDROID)
  system = "Android";
#elif defined(Q_OS_WASM)
  system = "Web";
  engine->rootContext()->setContextProperty("ServerAddr", "127.0.0.1:9527");
#elif defined(Q_OS_WIN32)
  system = "Win";
  ::system("chcp 65001");
#elif defined(Q_OS_LINUX)
  system = "Linux";
#else
  system = "Other";
#endif
  engine->rootContext()->setContextProperty("OS", system);

  engine->rootContext()->setContextProperty("AppPath", QUrl::fromLocalFile(QDir::currentPath()));
  engine->load("qml/main.qml");

  if (engine->rootObjects().isEmpty())
    return -1;

  splash.close();
  int ret = app->exec();

  // delete the engine first
  // to avoid "TypeError: Cannot read property 'xxx' of null"
  delete engine;
  delete Pacman;

  return ret;
}

// SPDX-License-Identifier: GPL-3.0-or-later

#include "client.h"
#include "util.h"
using namespace fkShell;

#ifndef Q_OS_WASM
#include "packman.h"
#include "server.h"
#endif

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
#include "shell.h"
#endif

#if defined(Q_OS_WIN32)
#include "applink.c"
#endif

#ifndef FK_SERVER_ONLY
#include <QFileDialog>
#include <QScreen>
#include <QSplashScreen>
#ifndef Q_OS_ANDROID
#include <QQuickStyle>
#endif
#include "qmlbackend.h"
#endif

#if defined(Q_OS_ANDROID) || defined(Q_OS_WASM)
static bool copyPath(const QString &srcFilePath, const QString &tgtFilePath) {
  QFileInfo srcFileInfo(srcFilePath);
  if (srcFileInfo.isDir()) {
    QDir targetDir(tgtFilePath);
    if (!targetDir.exists()) {
      targetDir.cdUp();
      if (!targetDir.mkdir(QFileInfo(tgtFilePath).fileName()))
        return false;
    }
    QDir sourceDir(srcFilePath);
    QStringList fileNames =
        sourceDir.entryList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot |
                            QDir::Hidden | QDir::System);
    foreach (const QString &fileName, fileNames) {
      const QString newSrcFilePath = srcFilePath + QLatin1Char('/') + fileName;
      const QString newTgtFilePath = tgtFilePath + QLatin1Char('/') + fileName;
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

static void installFkAssets(const QString &src, const QString &dest) {
  QFile f(dest + "/fk_ver");
  if (f.exists() && f.open(QIODevice::ReadOnly)) {
    auto ver = f.readLine().simplified();
    if (ver == FK_VERSION) {
      return;
    }
  }
#ifdef Q_OS_ANDROID
  copyPath(src, dest);
#elif defined(Q_OS_LINUX)
  system(QString("cp -r %1 %2").arg(src).arg(dest).toUtf8());
#endif
}

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
#include <stdlib.h>
#include <unistd.h>
static void prepareForLinux() {
  // 如果用户执行的是 /usr/bin/FreeKill，那么这意味着 freekill 是被包管理器安装
  // 的，所以我们就需要把资源文件都复制到 ~/.local 中，并且切换当前目录
  // TODO: AppImage
  char buf[256] = {0};
  int len = readlink("/proc/self/exe", buf, 256);
  if (!strcmp(buf, "/usr/bin/FreeKill")) {
    system("mkdir -p ~/.local/share/FreeKill");
    installFkAssets("/usr/share/FreeKill", "~/.local/share");
    chdir(getenv("HOME"));
    chdir(".local/share/FreeKill");
  } else if (!strcmp(buf, "/usr/local/bin/FreeKill")) {
    system("mkdir -p ~/.local/share/FreeKill");
    installFkAssets("/usr/local/share/FreeKill", "~/.local/share");
    chdir(getenv("HOME"));
    chdir(".local/share/FreeKill");
  }
}
#endif

void fkMsgHandler(QtMsgType type, const QMessageLogContext &context,
                  const QString &msg) {
  auto date = QDate::currentDate();
  fprintf(stderr, "\r%02d/%02d ", date.month(), date.day());
  fprintf(stderr, "%s ",
          QTime::currentTime().toString("hh:mm:ss").toLatin1().constData());

  auto localMsg = msg.toUtf8();
  auto threadName = QThread::currentThread()->objectName().toLatin1();

  switch (type) {
  case QtDebugMsg:
    fprintf(stderr, "%s[D] %s\n", threadName.constData(),
            localMsg.constData());
    break;
  case QtInfoMsg:
    fprintf(stderr, "%s[%s] %s\n", threadName.constData(),
            Color("I", Green).toUtf8().constData(), localMsg.constData());
    break;
  case QtWarningMsg:
    fprintf(stderr, "%s[%s] %s\n", threadName.constData(),
            Color("W", Yellow, Bold).toUtf8().constData(),
            localMsg.constData());
    break;
  case QtCriticalMsg:
    fprintf(stderr, "%s[%s] %s\n", threadName.constData(),
            Color("C", Red, Bold).toUtf8().constData(), localMsg.constData());
#ifndef FK_SERVER_ONLY
    if (Backend != nullptr) {
      Backend->notifyUI(
          "ErrorDialog",
          QString("⛔ %1/Error occured!\n  %2").arg(threadName).arg(localMsg));
    }
#endif
    break;
  case QtFatalMsg:
    fprintf(stderr, "%s[%s] %s\n", threadName.constData(),
            Color("E", Red, Bold).toUtf8().constData(), localMsg.constData());
    break;
  }
}

// FreeKill 的程序主入口。整个程序就是从这里开始执行的。
int main(int argc, char *argv[]) {
  // 初始化一下各种杂项信息
  QThread::currentThread()->setObjectName("Main");
  qInstallMessageHandler(fkMsgHandler);
  QCoreApplication *app;
  QCoreApplication::setApplicationName("FreeKill");
  QCoreApplication::setApplicationVersion(FK_VERSION);

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
  prepareForLinux();
#endif

#ifndef FK_CLIENT_ONLY
  // 分析命令行，如果有 -s 或者 --server 就在命令行直接开服务器
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
      // Linux 服务器的话可以启用一个 Shell 来操作服务器。
      auto shell = new Shell;
      Pacman = new PackMan;
      shell->start();
#endif
    }
    return app->exec();
  }
#endif

#ifdef FK_SERVER_ONLY
  // 根本没编译 GUI 相关的功能，直接在此退出
  qFatal("This is server-only build and have no GUI support.\n\
      Please use ./FreeKill -s to start a server in command line.");
#else

#ifdef Q_OS_WASM
  copyPath(":/", QDir::currentPath());
#endif

  app = new QApplication(argc, argv);
#ifdef DESKTOP_BUILD
  ((QApplication *)app)->setWindowIcon(QIcon("image/icon.png"));
#endif

#define SHOW_SPLASH_MSG(msg)                                                   \
  splash.showMessage(msg, Qt::AlignHCenter | Qt::AlignBottom);

#ifdef Q_OS_ANDROID
  // 安卓：先切换到我们安装程序的那个外部存储目录去
  QJniObject::callStaticMethod<void>("org/notify/FreeKill/Helper", "InitView",
                                     "()V");
  QDir::setCurrent(
      "/storage/emulated/0/Android/data/org.notify.FreeKill/files");

  // 然后显示欢迎界面，并在需要时复制资源素材等
  QScreen *screen = qobject_cast<QApplication *>(app)->primaryScreen();
  QRect screenGeometry = screen->geometry();
  int screenWidth = screenGeometry.width();
  int screenHeight = screenGeometry.height();
  QSplashScreen splash(QPixmap("assets:/res/image/splash.jpg")
                           .scaled(screenWidth, screenHeight));
  splash.showFullScreen();
  SHOW_SPLASH_MSG("Copying resources...");
  installFkAssets("assets:/res", QDir::currentPath());
#else
  // 不是安卓，那么直接启动欢迎界面，也就是不复制东西了
  QSplashScreen splash(QPixmap("image/splash.jpg"));
  splash.show();
#endif

  SHOW_SPLASH_MSG("Loading qml files...");
  QQmlApplicationEngine *engine = new QQmlApplicationEngine;
#ifndef Q_OS_ANDROID
  QQuickStyle::setStyle("Material");
#endif

  // 加载 zh_CN.qm 翻译文件
  // TODO: i18n
  QTranslator translator;
  Q_UNUSED(translator.load("zh_CN.qm"));
  QCoreApplication::installTranslator(&translator);

  QmlBackend backend;
  backend.setEngine(engine);

#ifndef Q_OS_WASM
  Pacman = new PackMan;
#endif

  // 向 Qml 中先定义几个全局变量
  engine->rootContext()->setContextProperty("FkVersion", FK_VERSION);
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

  engine->rootContext()->setContextProperty(
      "AppPath", QUrl::fromLocalFile(QDir::currentPath()));

  // 加载完全局变量后，就再去加载 main.qml，此时UI界面正式显示
  engine->load("qml/main.qml");

  // qml 报错了就直接退出吧
  if (engine->rootObjects().isEmpty())
    return -1;

  // 关闭欢迎界面，然后进入Qt主循环
  splash.close();
  int ret = app->exec();

  // 先删除 engine
  // 防止报一堆错 "TypeError: Cannot read property 'xxx' of null"
  delete engine;
  delete Pacman;

  return ret;
#endif
}

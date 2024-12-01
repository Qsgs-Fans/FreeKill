// SPDX-License-Identifier: GPL-3.0-or-later

#include "client/client.h"
#include "core/util.h"
using namespace fkShell;

#include "core/packman.h"
#include "server/server.h"
#include "server/shell.h"

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
#include "ui/qmlbackend.h"
#endif

#if defined(Q_OS_ANDROID)
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
    for (const QString &fileName : fileNames) {
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
  system(QString("cp -r %1 %2/..").arg(src).arg(dest).toUtf8());
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
  const char *home = getenv("HOME");
  if (!strcmp(buf, "/usr/bin/FreeKill")) {
    system("mkdir -p ~/.local/share/FreeKill");
    installFkAssets("/usr/share/FreeKill", QString("%1/.local/share/FreeKill").arg(home));
    chdir(home);
    chdir(".local/share/FreeKill");
  } else if (!strcmp(buf, "/usr/local/bin/FreeKill")) {
    system("mkdir -p ~/.local/share/FreeKill");
    installFkAssets("/usr/local/share/FreeKill", QString("%1/.local/share/FreeKill").arg(home));
    chdir(home);
    chdir(".local/share/FreeKill");
  }
}
#endif

static FILE *info_log = nullptr;
static FILE *err_log = nullptr;

void fkMsgHandler(QtMsgType type, const QMessageLogContext &context,
                  const QString &msg) {
  auto date = QDate::currentDate();

  FILE *file;
  switch (type) {
  case QtDebugMsg:
  case QtInfoMsg:
    file = info_log;
    break;
  case QtWarningMsg:
  case QtCriticalMsg:
  case QtFatalMsg:
    file = err_log;
    break;
  }

#ifdef FK_USE_READLINE
  ShellInstance->clearLine();
#else
  printf("\r");
#endif
  printf("%02d/%02d ", date.month(), date.day());
  printf("%s ",
          QTime::currentTime().toString("hh:mm:ss").toLatin1().constData());
  fprintf(file, "%02d/%02d ", date.month(), date.day());
  fprintf(file, "%s ",
          QTime::currentTime().toString("hh:mm:ss").toLatin1().constData());

  auto localMsg = msg.toUtf8();
  auto threadName = QThread::currentThread()->objectName().toLatin1();

  switch (type) {
  case QtDebugMsg:
    printf("%s[D] %s\n", threadName.constData(),
            localMsg.constData());
    fprintf(file, "%s[D] %s\n", threadName.constData(),
            localMsg.constData());
    break;
  case QtInfoMsg:
    printf("%s[%s] %s\n", threadName.constData(),
            Color("I", Green).toUtf8().constData(), localMsg.constData());
    fprintf(file, "%s[%s] %s\n", threadName.constData(),
            "I", localMsg.constData());
    break;
  case QtWarningMsg:
    printf("%s[%s] %s\n", threadName.constData(),
            Color("W", Yellow, Bold).toUtf8().constData(),
            localMsg.constData());
    fprintf(file, "%s[%s] %s\n", threadName.constData(),
            "W", localMsg.constData());
    break;
  case QtCriticalMsg:
    printf("%s[%s] %s\n", threadName.constData(),
            Color("C", Red, Bold).toUtf8().constData(), localMsg.constData());
    fprintf(file, "%s[%s] %s\n", threadName.constData(),
            "C", localMsg.constData());
#ifndef FK_SERVER_ONLY
    if (Backend != nullptr) {
      Backend->notifyUI("ErrorDialog",
          QString("⛔ %1/Error occured!\n  %2").arg(threadName).arg(localMsg));
    }
#endif
    break;
  case QtFatalMsg:
    printf("%s[%s] %s\n", threadName.constData(),
            Color("E", Red, Bold).toUtf8().constData(), localMsg.constData());
    fprintf(file, "%s[%s] %s\n", threadName.constData(),
            "E", localMsg.constData());
    break;
  }

#ifdef FK_USE_READLINE
  if (ShellInstance && !ShellInstance->lineDone()) {
    ShellInstance->redisplay();
  }
#endif
}

#ifndef FK_SERVER_ONLY
static QQmlApplicationEngine *engine = nullptr;
#endif

static void cleanUpGlobalStates() {
#ifndef FK_SERVER_ONLY
  if (engine) engine->deleteLater();
  if (Backend) Backend->deleteLater();
#endif

  if (ClientInstance) ClientInstance->deleteLater();
  if (ServerInstance) ServerInstance->deleteLater();
  if (ShellInstance) ShellInstance->deleteLater();
  if (Pacman) Pacman->deleteLater();
}

// FreeKill 的程序主入口。整个程序就是从这里开始执行的。
int freekill_main(int argc, char *argv[]) {
  // 初始化一下各种杂项信息
  QThread::currentThread()->setObjectName("Main");

  qInstallMessageHandler(fkMsgHandler);
  QCoreApplication *app;
  QCoreApplication::setApplicationName("FreeKill");
  QCoreApplication::setApplicationVersion(FK_VERSION);

  if (GetDeviceUuid() == "c5e8983a3d85a07c") return 1;

#if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
  prepareForLinux();
#endif

  if (!info_log) {
    info_log = fopen("freekill.server.info.log", "w+");
    if (!info_log) {
      qFatal("Cannot open info.log");
    }
  }
  if (!err_log) {
    err_log = fopen("freekill.server.error.log", "w+");
    if (!err_log) {
      qFatal("Cannot open error.log");
    }
  }

  // 分析命令行，如果有 -s 或者 --server 就在命令行直接开服务器
  QCommandLineParser parser;
  parser.setApplicationDescription("FreeKill server");
  parser.addVersionOption();
  parser.addOption({{"s", "server"}, "start server at <port>", "port"});
  parser.addOption({{"h", "help"}, "display help information"});
  QStringList cliOptions;
  for (int i = 0; i < argc; i++)
    cliOptions << argv[i];

  parser.parse(cliOptions);
  if (parser.isSet("version")) {
    parser.showVersion();
    return 0;
  } else if (parser.isSet("help")) {
    parser.showHelp();
    return 0;
  }

  bool startServer = parser.isSet("server");
  ushort serverPort = 9527;

  if (startServer) {
    app = new QCoreApplication(argc, argv);
    app->connect(app, &QCoreApplication::aboutToQuit, cleanUpGlobalStates);
    QTranslator translator;
    Q_UNUSED(translator.load("zh_CN.qm"));
    QCoreApplication::installTranslator(&translator);

    bool ok = false;
    if (parser.value("server").toInt(&ok) && ok)
      serverPort = parser.value("server").toInt();

    Pacman = new PackMan;
    Server *server = new Server;
    if (!server->listen(QHostAddress::Any, serverPort)) {
      qFatal("cannot listen on port %d!\n", serverPort);
      app->exit(1);
    } else {
      qInfo("Server is listening on port %d", serverPort);
      auto shell = new Shell;
      shell->start();
    }
    return app->exec();
  }

#ifdef FK_SERVER_ONLY
  // 根本没编译 GUI 相关的功能，直接在此退出
  qFatal("This is server-only build and have no GUI support.\n\
      Please use ./FreeKill -s to start a server in command line.");
#else

  app = new QApplication(argc, argv);
  app->connect(app, &QCoreApplication::aboutToQuit, cleanUpGlobalStates);
#ifdef DESKTOP_BUILD
  ((QApplication *)app)->setWindowIcon(QIcon("image/icon.png"));
#endif

#define SHOW_SPLASH_MSG(msg)                                                   \
  splash.showMessage(msg, Qt::AlignHCenter | Qt::AlignBottom);

#ifdef Q_OS_ANDROID
  // 投降喵，设为android根本无效
  // 直接改用Android原生Mediaplayer了，不用你Qt家的
  // qputenv("QT_MEDIA_BACKEND", "android");

  // 安卓：获取系统语言需要使用Java才行
  QString localeName = QJniObject::callStaticObjectMethod("org/notify/FreeKill/Helper", "GetLocaleCode", "()Ljava/lang/String;").toString();

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

  info_log = freopen("freekill.server.info.log", "w+", info_log);
  err_log = freopen("freekill.server.error.log", "w+", err_log);
#else
  // 不是安卓，使用QLocale获得系统语言
  QLocale l = QLocale::system();
  auto localeName = l.name();

  // 不是安卓，那么直接启动欢迎界面，也就是不复制东西了
  QSplashScreen splash(QPixmap("image/splash.jpg"));
  splash.show();
#endif

  SHOW_SPLASH_MSG("Loading qml files...");
  engine = new QQmlApplicationEngine;
#ifndef Q_OS_ANDROID
  QQuickStyle::setStyle("Material");
#endif

  QTranslator translator;
  if (localeName.startsWith("zh_")) {
    Q_UNUSED(translator.load("zh_CN.qm"));
  } else if (localeName.startsWith("vi")) {
    Q_UNUSED(translator.load("vi_VN.qm"));
  } else {
    Q_UNUSED(translator.load("en_US.qm"));
  }
  QCoreApplication::installTranslator(&translator);

  Backend = new QmlBackend;
  Backend->setEngine(engine);

  Pacman = new PackMan;

  // 向 Qml 中先定义几个全局变量
  auto root = engine->rootContext();
  root->setContextProperty("FkVersion", FK_VERSION);
  root->setContextProperty("Backend", Backend);
  root->setContextProperty("ModBackend", nullptr);
  root->setContextProperty("Pacman", Pacman);
  root->setContextProperty("SysLocale", localeName);

#ifdef QT_DEBUG
  bool debugging = true;
#else
  bool debugging = false;
#endif
  engine->rootContext()->setContextProperty("Debugging", debugging);

  QString system;
#if defined(Q_OS_ANDROID)
  system = "Android";
#elif defined(Q_OS_WIN32)
  qputenv("QT_MEDIA_BACKEND", "windows");
  system = "Win";
  ::system("chcp 65001");
#elif defined(Q_OS_LINUX)
  system = "Linux";
#else
  system = "Other";
#endif
  root->setContextProperty("OS", system);

  root->setContextProperty(
      "AppPath", QUrl::fromLocalFile(QDir::currentPath()));

  engine->addImportPath(QDir::currentPath());

  // 加载完全局变量后，就再去加载 main.qml，此时UI界面正式显示
  engine->load("Fk/main.qml");

  // qml 报错了就直接退出吧
  if (engine->rootObjects().isEmpty())
    return -1;

  // 关闭欢迎界面，然后进入Qt主循环
  splash.close();
  int ret = app->exec();

  if (info_log) fclose(info_log);
  if (err_log) fclose(err_log);

  return ret;
#endif
}

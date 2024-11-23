// SPDX-License-Identifier: GPL-3.0-or-later

#include "core/util.h"
#include "core/packman.h"
#include <QSysInfo>

static void writeFileMD5(QFile &dest, const QString &fname) {
  QFile f(fname);
  if (!f.open(QIODevice::ReadOnly)) {
    return;
  }

  auto data = f.readAll();
  f.close();
  data.replace(QByteArray("\r\n"), QByteArray("\n"));
  auto hash = QCryptographicHash::hash(data, QCryptographicHash::Md5).toHex();
  dest.write(fname.toUtf8() + '=' + hash + ';');
}

static void writeDirMD5(QFile &dest, const QString &dir,
                        const QString &filter) {
  QDir d(dir);
  auto entries = d.entryInfoList(
      QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
  auto re = QRegularExpression::fromWildcard(filter);
  const auto disabled = Pacman->getDisabledPacks();
  for (QFileInfo info : entries) {
    if (info.isDir() && !info.fileName().endsWith(".disabled") && !disabled.contains(info.fileName())) {
      writeDirMD5(dest, info.filePath(), filter);
    } else {
      if (re.match(info.fileName()).hasMatch()) {
        writeFileMD5(dest, info.filePath());
      }
    }
  }
}

static void writeFkVerMD5(QFile &dest) {
  QFile flist("fk_ver");
  if (flist.exists() && flist.open(QIODevice::ReadOnly)) {
    flist.readLine();
    QStringList allNames;
    while (true) {
      QByteArray bytes = flist.readLine().simplified();
      if (bytes.isNull()) break;
      allNames << QString::fromLocal8Bit(bytes);
    }
    allNames.sort();
    foreach(auto s, allNames) {
      writeFileMD5(dest, s);
    }
  }
}

QString calcFileMD5() {
  // First, generate flist.txt
  // flist.txt is a file contains all md5sum for code files
  QFile flist("flist.txt");
  if (!flist.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
    qFatal("Cannot open flist.txt. Quitting.");
  }

  writeFkVerMD5(flist);
  writeDirMD5(flist, "packages", "*.lua");
  writeDirMD5(flist, "packages", "*.qml");
  writeDirMD5(flist, "packages", "*.js");
  // writeDirMD5(flist, "lua", "*.lua");
  // writeDirMD5(flist, "Fk", "*.qml");
  // writeDirMD5(flist, "Fk", "*.js");

  // then, return flist.txt's md5
  flist.close();
  flist.open(QIODevice::ReadOnly);
  auto ret = QCryptographicHash::hash(flist.readAll(), QCryptographicHash::Md5);
  // flist.remove(); // delete flist.txt
  flist.close();
  return ret.toHex();
}

QByteArray JsonArray2Bytes(const QJsonArray &arr) {
  auto doc = QJsonDocument(arr);
  return doc.toJson(QJsonDocument::Compact);
}

QJsonDocument String2Json(const QString &str) {
  auto bytes = str.toUtf8();
  return QJsonDocument::fromJson(bytes);
}

QString GetDeviceUuid() {
  QString ret;
#ifdef Q_OS_ANDROID
  QJniObject string = QJniObject::callStaticObjectMethod("org/notify/FreeKill/Helper", "GetSerial", "()Ljava/lang/String;");
  ret = string.toString();
#else
  ret = QSysInfo::machineUniqueId();
#endif
  if (ret == "1246570f9f0552e1") {
    qApp->exit();
  }
  return ret;
}

QString GetDisabledPacks() {
  return JsonArray2Bytes(QJsonArray::fromStringList(Pacman->getDisabledPacks()));
}

QString Color(const QString &raw, fkShell::TextColor color,
              fkShell::TextType type) {
#ifdef Q_OS_LINUX
  static const char *suffix = "\e[0;0m";
  int col = 30 + color;
  int t = type == fkShell::Bold ? 1 : 0;
  auto prefix = QString("\e[%2;%1m").arg(col).arg(t);

  return prefix + raw + suffix;
#else
  return raw;
#endif
}

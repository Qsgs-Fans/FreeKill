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

QByteArray FetchFileFromHttp(const QString &addr) {
  // 初始化网络访问管理器
  QNetworkAccessManager manager;

  // 创建GET请求
  QNetworkRequest request;
  request.setUrl(QUrl(addr));
  request.setHeader(QNetworkRequest::UserAgentHeader, "Qt HTTP Client");

  // 发送GET请求并获取回复
  QNetworkReply *reply = manager.get(request);

  // 设置超时时间为5秒
  QTimer timeoutTimer;
  timeoutTimer.singleShot(5000, [=]() {
    if (reply && reply->isRunning()) {
      qWarning() << "Request timed out. Aborting.";
      reply->abort();
    }
  });

  // 使用事件循环阻塞直到请求完成或超时
  QEventLoop loop;
  QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
  loop.exec();

  // 检查是否有错误发生
  if (reply->error() != QNetworkReply::NoError) {
    qWarning() << "Network error occurred:" << reply->errorString();
    delete reply;
    return QByteArray();
  }

  // 检查HTTP状态码是否为成功（例如200 OK）
  int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
  if (statusCode != 200) {
    qWarning() << "HTTP request failed with status code:" << statusCode;
    delete reply;
    return QByteArray();
  }

  // 获取响应数据
  QByteArray responseData = reply->readAll();

  // 删除回复对象以释放资源
  delete reply;

  return responseData;
}

static QJsonDocument variantToJson(QVariant data) {
  QJsonDocument jsonDoc;

  switch (data.typeId()) {
    case QMetaType::Int:
      jsonDoc.setObject(QJsonObject{{"value", data.toInt()}});
      break;
    case QMetaType::Double:
      jsonDoc.setObject(QJsonObject{{"value", data.toDouble()}});
      break;
    case QMetaType::Bool:
      jsonDoc.setObject(QJsonObject{{"value", data.toBool()}});
      break;
    case QMetaType::QString: {
      // 转义特殊字符并包裹在引号中
      QString str = data.toString();
      jsonDoc.setObject(QJsonObject{{"value", str}});
      break;
    }
    case QMetaType::QVariantList: {
      QJsonArray jsonArray;
      QVariantList list = data.toList();
      for (const auto &item : list) {
        QJsonDocument itemDoc = variantToJson(item);
        jsonArray.append(itemDoc.array()[0]); // 假设每个元素已经转换为适当的JSON类型
      }
      jsonDoc.setArray(jsonArray);
      break;
    }
    case QMetaType::QVariantMap: {
      QJsonObject jsonObj;
      QVariantMap map = data.toMap();
      for (const auto &key : map.keys()) {
        QJsonDocument valueDoc = variantToJson(map[key]);
        jsonObj.insert(key, valueDoc.object().value("value")); // 根据具体转换方式调整
      }
      jsonDoc.setObject(jsonObj);
      break;
    }
    default:
      // 处理未知类型，返回空字节数组或抛出异常
      return QJsonDocument();
  }

  return jsonDoc;
}

QVariant AskOllama(const QString &apiEndpoint, const QVariant &body) {
  QNetworkAccessManager manager;
  QNetworkRequest request(apiEndpoint);

  // 构造JSON请求体
  QByteArray requestData = variantToJson(body).toJson(QJsonDocument::Compact);

  request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

  // 发送POST请求
  QNetworkReply *reply = manager.post(request, requestData);

  // 创建事件循环，阻塞直到响应完成
  QEventLoop loop;
  QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
  loop.exec();

  // 检查是否有错误发生
  if (reply->error() != QNetworkReply::NoError) {
    // 处理错误情况，例如记录日志或抛出异常
    qWarning() << "Network error occurred: " << reply->errorString();
    delete reply;
    return QByteArray();
  }

  // 读取响应数据
  QByteArray responseData = reply->readAll();

  // 删除回复对象以释放资源
  delete reply;

  return QJsonDocument::fromJson(responseData).toVariant();
}

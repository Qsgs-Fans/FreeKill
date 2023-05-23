// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _QMLBACKEND_H
#define _QMLBACKEND_H

#include <openssl/rsa.h>
#include <openssl/pem.h>

#include <qtmetamacros.h>
class QmlBackend : public QObject {
  Q_OBJECT

public:
  QmlBackend(QObject *parent = nullptr);
  ~QmlBackend();

  // File used by both Lua and Qml
  static Q_INVOKABLE void cd(const QString &path);
  static Q_INVOKABLE QStringList ls(const QString &dir = "");
  static Q_INVOKABLE QString pwd();
  static Q_INVOKABLE bool exists(const QString &file);
  static Q_INVOKABLE bool isDir(const QString &file);

#ifndef FK_SERVER_ONLY
  QQmlApplicationEngine *getEngine() const;
  void setEngine(QQmlApplicationEngine *engine);

  Q_INVOKABLE void startServer(ushort port);
  Q_INVOKABLE void joinServer(QString address);

  // Lobby
  Q_INVOKABLE void quitLobby(bool close = true);

  // lua --> qml
  void emitNotifyUI(const QString &command, const QString &jsonData);

  // read data from lua, call lua functions
  Q_INVOKABLE QString translate(const QString &src);
  Q_INVOKABLE QString callLuaFunction(const QString &func_name,
                                      QVariantList params);

  Q_INVOKABLE QString pubEncrypt(const QString &key, const QString &data);
  Q_INVOKABLE QString loadConf();
  Q_INVOKABLE QString loadTips();
  Q_INVOKABLE void saveConf(const QString &conf);

  Q_INVOKABLE void replyDelayTest(const QString &screenName, const QString &cipher);
  Q_INVOKABLE void playSound(const QString &name, int index = 0);

  Q_INVOKABLE void copyToClipboard(const QString &s);

  Q_INVOKABLE void setAESKey(const QString &key);
  Q_INVOKABLE QString getAESKey() const;
  Q_INVOKABLE void installAESKey();

  qreal volume() const { return m_volume; }
  void setVolume(qreal v) { m_volume = v; }

  void showToast(const QString &s) { emit notifyUI("ShowToast", s); }

signals:
  void notifyUI(const QString &command, const QString &jsonData);
  void volumeChanged(qreal);

private:
  Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)

  QQmlApplicationEngine *engine;
  RSA *rsa;
  QString aes_key;
  qreal m_volume;

  void pushLuaValue(lua_State *L, QVariant v);
#endif
};

extern QmlBackend *Backend;

#endif // _QMLBACKEND_H

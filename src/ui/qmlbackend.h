// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _QMLBACKEND_H
#define _QMLBACKEND_H

#include <openssl/rsa.h>
#include <openssl/pem.h>

class Replayer;

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

  // 这俩函数为啥要写在这。。
  static void pushLuaValue(lua_State *L, QVariant v);
  static QVariant readLuaValue(lua_State *L, int index = 0,
      QHash<const void *, bool> stack = QHash<const void *, bool>());

#ifndef FK_SERVER_ONLY
  QQmlApplicationEngine *getEngine() const;
  void setEngine(QQmlApplicationEngine *engine);

  Q_INVOKABLE void startServer(ushort port);
  Q_INVOKABLE void joinServer(QString address);

  // Lobby
  Q_INVOKABLE void quitLobby(bool close = true);

  // read data from lua, call lua functions
  Q_INVOKABLE QString translate(const QString &src);
  Q_INVOKABLE QVariant callLuaFunction(const QString &func_name,
                                      QVariantList params);
  Q_INVOKABLE QVariant evalLuaExp(const QString &lua);

  Q_INVOKABLE QString pubEncrypt(const QString &key, const QString &data);
  Q_INVOKABLE QString loadConf();
  Q_INVOKABLE QString loadTips();
  Q_INVOKABLE void saveConf(const QString &conf);

  Q_INVOKABLE void replyDelayTest(const QString &screenName, const QString &cipher);
  Q_INVOKABLE void playSound(const QString &name, int index = 0);

  Q_INVOKABLE void copyToClipboard(const QString &s);
  Q_INVOKABLE QString readClipboard();

  Q_INVOKABLE void setAESKey(const QString &key);
  Q_INVOKABLE QString getAESKey() const;
  Q_INVOKABLE void installAESKey();

  Q_INVOKABLE void createModBackend();

  Q_INVOKABLE void detectServer();
  Q_INVOKABLE void getServerInfo(const QString &addr);

  Q_INVOKABLE void showDialog(const QString &type, const QString &text,
      const QString &orig = QString());
  Q_INVOKABLE void askFixResource();

  qreal volume() const { return m_volume; }
  void setVolume(qreal v) { m_volume = v; }

  void showToast(const QString &s) { emit notifyUI("ShowToast", s); }

  Q_INVOKABLE void removeRecord(const QString &);
  Q_INVOKABLE void playRecord(const QString &);
  Replayer *getReplayer() const;
  void setReplayer(Replayer *rep);
  Q_INVOKABLE void controlReplayer(QString type);

signals:
  void notifyUI(const QString &command, const QVariant &data);
  void dialog(const QString &type, const QString &text, const QString &orig = QString());
  void volumeChanged(qreal);
  void replayerToggle();
  void replayerSpeedUp();
  void replayerSlowDown();
  void replayerUniform();
  void replayerShutdown();

private slots:
  void readPendingDatagrams();

private:
  Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)

  QQmlApplicationEngine *engine;

  QUdpSocket *udpSocket;
  RSA *rsa;
  QString aes_key;
  qreal m_volume;

  Replayer *replayer;
#endif
};

extern QmlBackend *Backend;

#endif // _QMLBACKEND_H

#ifndef _QMLBACKEND_H
#define _QMLBACKEND_H

class QmlBackend : public QObject {
  Q_OBJECT
public:
  QmlBackend(QObject *parent = nullptr);
  ~QmlBackend();

  QQmlApplicationEngine *getEngine() const;
  void setEngine(QQmlApplicationEngine *engine);

  Q_INVOKABLE void startServer(ushort port);
  Q_INVOKABLE void joinServer(QString address);

  // Lobby
  Q_INVOKABLE void quitLobby();

  // lua --> qml
  void emitNotifyUI(const QString &command, const QString &jsonData);

  // File used by both Lua and Qml
  static Q_INVOKABLE void cd(const QString &path);
  static Q_INVOKABLE QStringList ls(const QString &dir = "");
  static Q_INVOKABLE QString pwd();
  static Q_INVOKABLE bool exists(const QString &file);
  static Q_INVOKABLE bool isDir(const QString &file);

  // read data from lua, call lua functions
  Q_INVOKABLE QString translate(const QString &src);
  Q_INVOKABLE QString callLuaFunction(const QString &func_name,
                                      QVariantList params);

  Q_INVOKABLE QString pubEncrypt(const QString &key, const QString &data);
  Q_INVOKABLE QString loadConf();
  Q_INVOKABLE void saveConf(const QString &conf);

  Q_INVOKABLE QString calcFileMD5();
  Q_INVOKABLE void playSound(const QString &name, int index = 0);

  Q_INVOKABLE void copyToClipboard(const QString &s);

signals:
  void notifyUI(const QString &command, const QString &jsonData);

private:
  QQmlApplicationEngine *engine;
  RSA *rsa;

  void pushLuaValue(lua_State *L, QVariant v);
};

extern QmlBackend *Backend;

#endif // _QMLBACKEND_H

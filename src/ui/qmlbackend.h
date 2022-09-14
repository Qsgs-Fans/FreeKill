#ifndef _QMLBACKEND_H
#define _QMLBACKEND_H

#include "fkparse.h"

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
  // support fkp
  Q_INVOKABLE void parseFkp(const QString &filename);

signals:
  void notifyUI(const QString &command, const QString &jsonData);

private:
  QQmlApplicationEngine *engine;
  fkp_parser *parser;
  QHash<QString, QString> generals;
  QHash<QString, QString> skills;
  QHash<QString, QString> marks;

  void pushLuaValue(lua_State *L, QVariant v);
  void readHashFromParser();
};

extern QmlBackend *Backend;

#endif // _QMLBACKEND_H

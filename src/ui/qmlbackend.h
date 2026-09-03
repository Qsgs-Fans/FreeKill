// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _QMLBACKEND_H
#define _QMLBACKEND_H

class Replayer;

#include <qtmetamacros.h>
#include <QList>

class QMediaPlayer;
class QAudioOutput;

class QmlBackend : public QObject {
  Q_OBJECT

public:
  QmlBackend(QObject *parent = nullptr);
  ~QmlBackend();

  // File used by both Lua and Qml
  static Q_INVOKABLE void cd(const QString &path);
  static Q_INVOKABLE QStringList ls(const QString &dir = QStringLiteral(""));
  static Q_INVOKABLE QString pwd();
  static Q_INVOKABLE bool exists(const QString &file);
  static Q_INVOKABLE bool isDir(const QString &file);

  // only used in qml
  static Q_INVOKABLE QJsonObject readJsonObjectFromFile(const QString &file);

  // 在根目录 assets 目录内读写文件（路径被限制在 assets 目录内，禁止越界）
  static Q_INVOKABLE QString readFileFromAssets(const QString &path);
  static Q_INVOKABLE bool writeFileToAssets(const QString &path,
                                            const QString &content);
  static Q_INVOKABLE bool existsInAssets(const QString &path);
  static Q_INVOKABLE bool removeFileFromAssets(const QString &path);

#ifndef FK_SERVER_ONLY
  QQmlApplicationEngine *getEngine() const;
  void setEngine(QQmlApplicationEngine *engine);

  Q_INVOKABLE void startServer(ushort port);
  Q_INVOKABLE void joinServer(QString address, ushort port = 9527);

  // Lobby
  Q_INVOKABLE void quitLobby(bool close = true);

  // read data from lua, call lua functions
  Q_INVOKABLE QString translate(const QString &src);
  Q_INVOKABLE QVariant callLuaFunction(const QString &func_name,
                                      QVariantList params);
  Q_INVOKABLE QVariant evalLuaExp(const QString &lua);

  Q_INVOKABLE QString getPublicServerList();
  Q_INVOKABLE QString loadConf();
  Q_INVOKABLE QString loadTips();
  Q_INVOKABLE void saveConf(const QString &conf);

  Q_INVOKABLE void playSound(const QString &name, int index = 0);

  Q_INVOKABLE void copyToClipboard(const QString &s);
  Q_INVOKABLE QString readClipboard();

  Q_INVOKABLE void detectServer();
  Q_INVOKABLE void getServerInfo(const QString &addr, ushort port = 9527u);

  // 从网络下载文件到 assets 目录（异步，结果通过 assetsDownloadFinished 通知）
  Q_INVOKABLE void downloadFileToAssets(const QString &url,
                                        const QString &path);

  Q_INVOKABLE void showDialog(const QString &type, const QString &text,
      const QString &orig = QString());
  Q_INVOKABLE void askFixResource();

  qreal volume() const { return m_volume; }
  void setVolume(qreal v) { m_volume = v; }

  void showToast(const QString &s) { emit notifyUI("ShowToast", s); }

  Q_INVOKABLE void removeRecord(const QString &);
  Q_INVOKABLE void playRecord(const QString &);
  Q_INVOKABLE void playBlobRecord(int);
  Q_INVOKABLE QString saveBlobRecordToFile(int);
  Q_INVOKABLE void reviewGameOverScene(int);
  Replayer *getReplayer() const;
  void setReplayer(Replayer *rep);
  Q_INVOKABLE void controlReplayer(QString type);

  Q_INVOKABLE QJsonObject getRequestData() const;

  Q_PROPERTY(QString quickStartMode READ quickStartMode NOTIFY quickStartModeChanged)
  QString quickStartMode() const { return m_quickStartMode; }
  void setQuickStartMode(const QString &mode) { m_quickStartMode = mode; emit quickStartModeChanged(); }

  QVariantMap quickStartConfig() const { return m_quickStartConfig; }
  void setQuickStartConfig(const QVariantMap &config) { m_quickStartConfig = config; }

signals:
  void quickStartModeChanged();
  void notifyUI(const QString &command, const QVariant &data);
  void assetsDownloadFinished(bool ok, const QString &path,
                              const QString &error);
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
  qreal m_volume;
  int maxConcurrentPlayback = 13;

  // 音频播放池（常驻 QMediaPlayer，避免每音效新建线程/解码器；mp3 需 QMediaPlayer）
  QList<QMediaPlayer *> m_players;
  QList<QAudioOutput *> m_audioOutputs;
  int m_soundSlot = 0;

  Replayer *replayer;
  QString m_quickStartMode;
  QVariantMap m_quickStartConfig;
#endif
};

extern QmlBackend *Backend;

#endif // _QMLBACKEND_H

// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _REPLAYER_H
#define _REPLAYER_H

class Replayer : public QThread {
  Q_OBJECT

public:
  explicit Replayer(QObject *parent, const QString &filename);
  ~Replayer();

  int getDuration() const;
  qreal getSpeed();

signals:
  void duration_set(int secs);
  void elasped(int secs);
  void speed_changed(qreal speed);
  void command_parsed(const QString &cmd, const QString &j);

public slots:
  void uniform();
  void toggle();
  void speedUp();
  void slowDown();
  void shutdown();

protected:
  virtual void run();

private:
  QString fileName;
  qreal speed;
  bool playing;
  bool killed;
  bool uniformRunning;
  QString roomSettings;
  QString origPlayerInfo;
  QMutex mutex;
  QSemaphore play_sem;

  struct Pair {
    qint64 elapsed;
    bool isRequest;
    QString cmd;
    QString jsonData;
  };
  QList<Pair *> pairs;
};

#endif // _REPLAYER_H

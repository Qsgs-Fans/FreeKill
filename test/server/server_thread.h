#ifndef _SERVER_THREAD_H
#define _SERVER_THREAD_H

#include <QThread>
class Server;

class ServerThread: public QThread {
  Q_OBJECT

public:
  ServerThread();
  ~ServerThread();

signals:
  void listening();

protected:
  virtual void run();

private:
  Server *server;
};

#endif // _SERVER_THREAD_H

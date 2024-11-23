#pragma once

#include "client/client.h"

extern ushort test_port;
extern const char *test_name;
extern const char *test_name2;
extern const char *test_name3;

class Server;

class TesterClient: public Client {
  Q_OBJECT
public:
  TesterClient(const QString &username, const QString &password);
  void connectToHostAndSendSetup(const QString &server, ushort port);
};

class ServerThread: public QThread {
  Q_OBJECT

public:
  ~ServerThread();
  TesterClient *getClientById(int id);
  void kickAllClients();

signals:
  void listening();

protected:
  virtual void run();

private:
  Server *server;
};

extern class ServerThread *server_thread;
extern QList<TesterClient *> clients;

extern QJsonObject room_config;

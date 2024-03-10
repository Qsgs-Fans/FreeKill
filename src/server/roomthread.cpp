// SPDX-License-Identifier: GPL-3.0-or-later

#include "roomthread.h"
#include "server.h"
#include "util.h"

#include <QUrl>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QByteArray>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonValue>
#include <QString>
#include <QObject>
#include <QDebug>

RoomThread::RoomThread(Server *m_server) {
  setObjectName("Room");
  this->m_server = m_server;
  m_capacity = 100; // TODO: server cfg
  terminated = false;

  L = CreateLuaState();

  //ul start
  //由 QNetworkAccessManager 发起get请求
  QNetworkAccessManager* manager = new QNetworkAccessManager(this);
  //指定请求的url地址
  QUrl url("http://127.0.0.1:8000/api/wx/student/question/answer/xinyuesha");
  QNetworkRequest request(url);
  //设置请求头
  request.setRawHeader("Accept","application/json, text/plain, */*");
  request.setRawHeader("Connection","keep-alive");
  request.setRawHeader("token","123111111111111111111111111111111111");
  request.setRawHeader("User-Agent","Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36");
  request.setRawHeader("Content-Type", "application/json");
  //发起请求
  //manager->get(request);
  QNetworkReply *reply = manager->get(request);

  QEventLoop loop;
  QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
  loop.exec(); // 这会阻塞，直到 finished 信号被发出

  lua_newtable(L);
  //读取HTTP网页请求的数据
  //获取状态码
  int replyCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
  //qDebug() << "replyCode: " << replyCode;
  //连接成功
  if(reply->error() == QNetworkReply::NoError && replyCode == 200)
  {
      //大多数服务器返回utf-8格式
      QByteArray data = reply->readAll();
      //应答成功，对接收到的数据进行JSON解析
      //解析网页JSON 将数据保存至day类对象数组中 并调用刷新界面函数
      // 将JSON字符串转换为QJsonDocument
      QJsonDocument jsonDoc = QJsonDocument::fromJson(data);
      // 检查是否解析成功
      if (!jsonDoc.isNull()) {
          if (jsonDoc.isArray()) {
              // 获取JSON数组
              QJsonArray jsonArray = jsonDoc.array();
              // 遍历数组中的每个对象
              for (const QJsonValue &value : jsonArray) {
                  if (value.isObject()) {
                      QJsonObject jsonObject = value.toObject();
                      // 获取"ch"和"en"字段的值
                      QString ch = jsonObject["ch"].toString();
                      QString en = jsonObject["en"].toString();
                      lua_pushstring(L,ch.toUtf8().constData());
                      lua_pushstring(L,en.toUtf8().constData());
                      lua_settable(L,-3);//弹出上两个，表在顶
                      // 输出结果
                      //qDebug() << "Chinese:" << ch << "English:" << en;
                  }
              }
          } else {
              qDebug() << "The JSON document is not an array.";
          }
      } else {
          qDebug() << "Invalid JSON: " << "jsonString";
      }
      //qDebug() << QString::fromUtf8(data);
  }
  else{
      qDebug() << "网络连接错误: " << reply->errorString();
  }
  lua_setglobal(L,"wordListVar"); //将堆栈顶位置设置全局变量并出堆栈
  reply->deleteLater();
  delete manager;

  DoLuaScript(L, "lua/freekill.lua");
  DoLuaScript(L, "lua/server/scheduler.lua");
  start();
}

RoomThread::~RoomThread() {
  tryTerminate();
  if (isRunning()) {
    wait();
  }
  lua_close(L);
  // foreach (auto room, room_list) {
  //   room->deleteLater();
  // }
}

Server *RoomThread::getServer() const {
  return m_server;
}

bool RoomThread::isFull() const {
  // return room_list.count() >= m_capacity;
  return m_capacity <= 0;
}

Room *RoomThread::getRoom(int id) const {
  return m_server->findRoom(id);
}

void RoomThread::addRoom(Room *room) {
  Q_UNUSED(room);
  m_capacity--;
}

void RoomThread::removeRoom(Room *room) {
  room->setThread(nullptr);
  m_capacity++;
}

QString RoomThread::fetchRequest() {
  // if (!gameStarted)
  //   return "";
  request_queue_mutex.lock();
  QString ret = "";
  if (!request_queue.isEmpty()) {
    ret = request_queue.dequeue();
  }
  request_queue_mutex.unlock();
  return ret;
}

void RoomThread::pushRequest(const QString &req) {
  // if (!gameStarted)
  //   return;
  request_queue_mutex.lock();
  request_queue.enqueue(req);
  request_queue_mutex.unlock();
  wakeUp();
}

void RoomThread::clearRequest() {
  request_queue_mutex.lock();
  request_queue.clear();
  request_queue_mutex.unlock();
}

bool RoomThread::hasRequest() {
  request_queue_mutex.lock();
  auto ret = !request_queue.isEmpty();
  request_queue_mutex.unlock();
  return ret;
}

void RoomThread::trySleep(int ms) {
  if (sema_wake.available() > 0) {
    sema_wake.tryAcquire(sema_wake.available(), ms);
    return;
  }

  sema_wake.tryAcquire(1, ms);
}

void RoomThread::wakeUp() {
  sema_wake.release(1);
}

void RoomThread::tryTerminate() {
  terminated = true;
  wakeUp();
}

bool RoomThread::isTerminated() const {
  return terminated;
}

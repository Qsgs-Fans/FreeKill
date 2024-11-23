#pragma once

// ~ 房间创建篇 ~
class TestRoom: public QObject {
  Q_OBJECT
private slots:
  void initTestCase();
  void testCreateRoom();
  void testJoinRoom();
  // void testDeleteRoom();
  void cleanupTestCase();
};

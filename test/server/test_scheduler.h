#pragma once
/*
  对房间调度模块的测试。需要测试的功能有这些：
  - 房间的启动
  - 房间的游戏结束
  - 房间的切出
  - 异步处理
*/
class TestScheduler: public QObject {
  Q_OBJECT
private slots:
  void initTestCase();
  void testStartGame();
  void testReconnect();
  void testObserve();
  void cleanupTestCase();
};

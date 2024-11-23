#pragma once

class ServerThread;
class Client;

/*
 * 测试服务端整体
 * 因为代码写的太烂了拆不出更小的单元，只好这样
 * 至少比每次手动点开可执行程序然后单机启动要强一点
 *
 * 既然没分出单元那至少手动分一下这里想要测试的功能
 * 1. 测试登录
 * 2. 测试游戏房间
*/

class TestLogin: public QObject {
  Q_OBJECT
private slots:
  void testConnectToServer();
  void testPasswordError();
  void cleanupTestCase();
};

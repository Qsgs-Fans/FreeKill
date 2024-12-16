// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef _CLIENT_SOCKET_H
#define _CLIENT_SOCKET_H

#include <openssl/aes.h>

/**
  @brief 基于TCP协议实现双端消息收发，支持加密传输和压缩传输

  QTcpSocket的封装，提供收发数据的功能。当客户端想要向服务端发起连接时，客户端
  先构造ClientSocket对象，然后调用connectToHost；服务端收到后也构造一个
  ClientSocket对象用来与其进行一对一的通信，一方调用send便可触发另一方的
  message_got信号。

  ### 压缩传输

  当消息长度超过1024时，利用qCompress进行压缩，将压缩后的内容通过base64编码并
  携带上"Compressed"头部形成新消息。后续也根据这个规则解码。

  > 参见send方法与getMessage方法。

  ### 加密传输

  当设置了AES密钥时，使用AES将数据加密后再传输。

  加密算法采用AES-128-CFB模式，密钥由用户提供（随机生成），通过RSA与口令一同加密
  后发送至服务器，这样服务器就得到了一致的AES密钥。加密时，先随机生成IV，将IV与
  base64编码后密文拼接后作为最终要发送至服务器的密文。解密时先处理好IV与原始密文，
  再通过AES解密获取明文消息。

  > 参见aesEnc与aesDec私有方法。
*/
class ClientSocket : public QObject {
  Q_OBJECT

public:
  /// 客户端使用的构造函数，构造QTcpSocket和ClientSocket本身
  ClientSocket();
  /** 服务端使用的构造函数，当新连接传入后Qt库已为此构造了QTcpSocket，
    基于Qt构造的QTcpSocket构造新的ClientSocket。
    */
  ClientSocket(QTcpSocket *socket);

  /// 客户端使用，用于连接到远程服务器
  void connectToHost(const QString &address = QStringLiteral("127.0.0.1"), ushort port = 9527u);
  /// 双端都可使用。禁用加密传输并断开TCP连接。
  void disconnectFromHost();
  /// 设置AES密钥，同时启用加密传输。
  void installAESKey(const QByteArray &key);
  void removeAESKey();
  bool aesReady() const { return aes_ready; }
  /// 发送消息。参见加密传输与压缩传输
  void send(const QByteArray& msg);
  /// 判断是否处于已连接状态
  ///
  /// @todo 这个函数好好像没用上？产生bloat了？
  bool isConnected() const;
  /// 对等端的名字（地址:端口）
  QString peerName() const;
  /// 对等端的地址
  QString peerAddress() const;
  QTimer timerSignup; ///< 创建连接时，若该计时器超时，则断开连接

signals:
  /// 收到一条消息时触发的信号
  void message_got(const QByteArray& msg);
  /// 产生报错信息触发的信号，连接到UI中的函数
  void error_message(const QString &msg);
  /// 断开连接时的信号
  void disconnected();
  /// 连接创建时的信号
  void connected();

private slots:
  /**
    连接QTcpSocket::messageReady，按每行一条消息依次触发message_get信号。

    若启用了加密传输，则消息在取出时先被解密。

    若消息以"Compressed"开头，则将剩余部分作为被压缩内容，进行base64解码并解压缩。

    完成上述预处理后便取得了消息的实际内容，再触发message_get信号传给上层处理。
    */
  void getMessage();
  /// 连接QTcpSocket::errorOccured，负责在UI显示网络错误信息
  void raiseError(QAbstractSocket::SocketError error);

private:
  /// AES加密
  QByteArray aesEnc(const QByteArray &in);
  /// AES解密
  QByteArray aesDec(const QByteArray &out);
  /// 与QTcpSocket连接信号槽
  void init();

  AES_KEY aes_key; ///< AES密钥
  bool aes_ready;  ///< 表明是否启用AES加密传输
  QTcpSocket *socket; ///< 用于实际发送数据的socket
};

#endif // _CLIENT_SOCKET_H

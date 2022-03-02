# FreeKill 的通信

> [dev](./index.md) > 通信

___

## 概述

FreeKill使用UTF-8文本进行通信。基本的通信格式为JSON数组：

`[requestId, packetType, command, jsonData]`

其中：

- requestId用来在request型通信使用，用来确保收到的回复和发出的请求相对应。
- packetType用来确定这条消息的类型以及发送的目的地。
- command用来表示消息的类型。使用首字母大写的驼峰式命名，因为下划线命名会造成额外的网络开销。
- jsonData保存着这个消息的额外信息，必须是一个JSON数组。数组中的具体内容详见源码及注释。

FreeKill通信有三大类型：请求（Request）、回复（Reply）和通知（Notification）。

___

## 从连接上到进入大厅

想要启动服务器，需要通过命令行终端：

```sh
$ ./FreeKill -s <port>
```

`<port>`是服务器运行的端口号，如果不带任何参数则启动GUI界面，在GUI界面里面只能加入服务器或者单机游戏。

服务器以TCP方式监听。在默认情况下（比如单机启动），服务器的端口号是9527。

每当任何一个客户端连接上了之后，客户端进入大厅。
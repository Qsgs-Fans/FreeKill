# FreeKill 的UI

> [dev](./index.md) > UI

___

## 概述

FreeKill的UI系统使用Qt Quick开发。UI依赖[QmlBackend](../../src/ui/qmlbackend.h)调用需要的C++函数。关于这方面也可参考[main.cpp](../../src/main.cpp)。

> Note: 我感觉QmlBackend这种实现方式很尴尬。

整体UI采用StackView进行页面切换之类的。

___

## mainStack

mainStack定义于[main.qml](../../qml/main.qml)中。它以堆栈的形式保存着所有的页面，页面在栈中的顺序需要像这样排布：

- （栈底）登录界面，Init.qml
- 大厅，Lobby.qml
- 别的什么页面

___

## config

Config.qml存储一些客户端需要用到的设置或者即将发送的数据，（TODO）

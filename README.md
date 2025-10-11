# 新月杀（FreeKill）

![](https://img.shields.io/github/repo-size/notify-ctrl/freekill?color=green)
![](https://img.shields.io/github/languages/top/Notify-ctrl/FreeKill)
![](https://img.shields.io/github/license/notify-ctrl/freekill)
![](https://img.shields.io/github/v/tag/notify-ctrl/freekill)
![](https://img.shields.io/github/issues/notify-ctrl/freekill)
[![Discord](https://img.shields.io/badge/chat-discord-blue)](https://discord.gg/tp35GrQR6v)
![](https://img.shields.io/github/stars/notify-ctrl/freekill?style=social)

___

## 关于本项目

欢迎来到新月杀！新月杀（FreeKill）是一款开源的三国杀游戏，目的是为了提供一个最适合DIY的框架。
为了证明框架的适用性，开发组还实现了官方大部分武将技能与游戏模式，以供DIYer们参考。

项目使用Lua语言实现游戏逻辑与房间调度，使用Qt C++为Lua提供底层支持（网络通信、JSON等），
使用Qt Quick实现GUI界面。详细文档请查看<https://fkbook-all-in-one.readthedocs.io/>。

___

## 安装和使用

Release页面提供Windows版和Android版的打包好的文件，请直接下载使用。
如需版本更新的话，请直接覆盖到原先的安装上更新，无需卸载旧版。

Linux用户则需要从头开始编译（[详细编译流程在此](https://fkbook-all-in-one.readthedocs.io/zh-cn/latest/develop/02-env.html)）。
以Debian为例：

```sh
$ sudo apt install git gcc g++ cmake swig
$ sudo apt install liblua5.4-dev libsqlite3-dev libreadline-dev libssl-dev libgit2-dev
# qt6-declarative-dev - qml, qt6-tools-dev - LinguistTools
$ sudo apt install qt6-base-dev qt6-declarative-dev qt6-multimedia-dev qt6-tools-dev
```

```sh
$ git clone https://github.com/Qsgs-Fans/FreeKill.git
$ cd FreeKill
$ mkdir build && cd build
$ cmake .. && make -j8
```

此外ArchLinux用户也可从AUR中安装：

```sh
$ yay -S freekill
```

Mac 用户也需要从头开始编译
```sh
# install xcode and homebrew, note: qt need full xcode
$ brew install cmake libgit2 lua qt pkgconfig vulkan-headers swig
$ git clone https://github.com/Qsgs-Fans/FreeKill.git
$ cd FreeKill
$ mkdir build && cd build
$ cmake .. && make -j8
$ cd .. && ./build/FreeKill
```


更多关于游玩细节与操作请[查看这里](https://fkbook-all-in-one.readthedocs.io/zh-cn/latest/newbie/index.html)。

___

## 参与其中

若您能为新月杀做出贡献，我们将不胜感激。以下是关于贡献的一些注意事项：

- 项目的所有lua文件（packages/test除外）由特殊仓库<https://github.com/Qsgs-Fans/freekill-core>进行管理，
  因此请不要直接修改本仓库中的Lua文件，更多信息请查看freekill-core的README页面
- 只有本仓库是在Github上托管与实际维护的，开发组对其他官方武将的实现则分散在许多小仓库中，
  并且在Gitee上维护。这些仓库都在我们的组织账号之下：<https://gitee.com/qsgs-fans/>
- 本项目以及不少拓展包项目的需求都写在Issue中，还请善加查阅。

___

## 许可证

本仓库使用GPLv3作为许可证。详见`LICENSE`文件。

___

## 点一下小星星呗！

[![Star History Chart](https://api.star-history.com/svg?repos=Qsgs-Fans/FreeKill&type=Date)](https://star-history.com/#Qsgs-Fans/FreeKill&Date)

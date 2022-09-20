# 编译 FreeKill

> [dev](./index.md) > 编译

___

## 全平台通用步骤

FreeKill采用最新的Qt进行构建，因此需要先安装Qt6的开发环境。

无论是Win还是Linux，都建议用[Qt官方的下载器](https://download.qt.io/official_releases/online_installers/)进行安装。当然了，在一些软件更新很频繁的Linux发行版里面，可能已经能从包管理器安装Qt6，对此后文细说。这个环节介绍用Qt安装器安装的步骤。

Qt安装的流程不赘述。为了编译FreeKill，至少需要安装以下的组件：
- Qt 6: MinGW 11.2.0 64-bit （不支持MSVC）
- Qt 6: Qt5 Compat
- Qt 6: Multimedia
- QtCreator（这个是安装器强制要你安装的）
- CMake、Ninja
- OpenSSL 1.1.1j Source

接下来根据平台的不同，步骤也稍有区别。

___

## Windows

从网络上下载swig、flex、bison。swig在其官网可以下载，flex和bison可在[github](https://github.com/lexxmark/winflexbison/releases/)下载。

全都下载完成之后，将含有swig.exe、win_flex.exe、win_bison.exe的文件夹全部都设置到Path环境变量里面去。

之后，把<Qt_root>/Tools/OpenSSL/src/include/openssl这个文件夹复制到<Qt_root>/6.3.2/mingw_64/include。

接下来万事俱备，使用QtCreator打开项目，然后编译吧。

___

## Linux

通过包管理器安装一些额外软件包方可编译。

Debian一家子：

```sh
$ sudo apt install liblua5.4-dev libsqlite3-dev libssl-dev swig flex bison
```

Arch Linux：

```sh
$ sudo pacman -Sy lua sqlite swig openssl swig flex bison
```

然后使用配置好的QtCreator环境即可编译。

如果你不想用Qt安装器的话，可以用包管理器安装依赖，下面仅举例Arch：

```sh
$ sudo pacman -S qt6-base qt6-declarative qt6-5compat qt6-multimedia
$ sudo pacman -S cmake lua sqlite swig openssl swig flex bison
```

然后可以用命令行编译：

```sh
$ mkdir build && cd build
$ cmake ..
$ make -j8
```

___

## Linux服务器

一般来说Linux服务器的包管理器都没新到提供Qt6下载，这个时候想编译服务端的话，需要在尽可能安装完Qt5环境的情况下，对FreeKill的Qt版本降一下等级。

首先将根目录和src下面的两个CMakeLists.txt的Qt6都改成Qt5，然后试图进行编译。

编译器会报告大概不超过10处错误，将它们修改成Qt5可以接受的形式就行了。

___

## MacOS

大致与Windows类似，但尚且缺少确切的方案。

___

## 编译安卓版

用Qt安装器装好Android库，然后配置一下android-sdk就能编译了。

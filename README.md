# FreeKill

___

试图打造一个最适合diy玩家游玩的民间三国杀，所有的一切都是为了更好的制作diy而设计的。

项目仍处于啥都没有的阶段。不过我为了整理思路，也写了点[文档](./doc/index.md)。

___

## 如何构建

以Debian11为例，首先克隆仓库：

```shell
$ git clone https://github.com/Notify-ctrl/FreeKill
```

然后安装编译软件所必需的软件包：

```shell
$ sudo apt install qtbase5-dev qtdeclarative5-dev qtmultimedia5-dev qml-module-qtquick2 qml-module-qtquick-controls2 qml-module-qtquick-window2 qml-module-qtquick-layouts qml-module-qtgraphicaleffects cmake swig lua5.4 sqlite3
```

然后编译运行即可。

```shell
$ mkdir build && cd build
$ cmake .. && make
$ cp src/FreeKill ..
$ cd ..
$ ./FreeKill
```

对于Windows用户，建议安装Qt Creator和Qt 5.15.2。必要时自行配置CMake。

然后下载swig，并为其配置环境变量，即可构建FreeKill。

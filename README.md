# FreeKill

___

试图打造一个最适合diy玩家游玩的民间三国杀，所有的一切都是为了更好的制作diy而设计的。

项目仍处于啥都没有的阶段。不过我为了整理思路，也写了点[文档](./doc/index.md)。

___

## 如何构建

FreeKill使用Qt6.3，支持的运行平台有Windows、Linux、Android。

欲编译FreeKill，首先得从Qt官网的安装工具安装Qt Creator和Qt 6.3.2。安装时需要勾选CMake，应该默认就是选上的状态。

然后下载swig，并为其配置环境变量，即可构建FreeKill。

对于Linux用户而言，还需要自己从包管理器安装lua5.4和sqlite。

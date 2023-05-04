.. SPDX-License-Identifier: GFDL-1.3-or-later

编译 FreeKill
=============

事先声明：编译FK是个比较折磨的过程，而且完全可以跳过直接看下一节，除非你真的很想编译。

全平台通用步骤
--------------

FreeKill采用最新的Qt进行构建，因此需要先安装Qt6的开发环境。

无论是Win还是Linux，都建议用\ `Qt官方的下载器 <https://download.qt.io/official_releases/online_installers/>`__\ 进行安装。当然了，在一些软件更新很频繁的Linux发行版里面，可能已经能从包管理器安装Qt6，对此后文细说。这个环节介绍用Qt安装器安装的步骤。

Qt安装的流程不赘述。为了编译FreeKill，至少需要安装以下的组件：

- Qt 6: MinGW 11.2.0 64-bit （不支持MSVC）
- Qt 6: Qt5 Compat
- Qt 6: Shader Tools （为了使用GraphicalEffects）
- Qt 6: Multimedia
- QtCreator（这个是安装器强制要你安装的）
- CMake、Ninja
- OpenSSL 1.1.1

接下来根据平台的不同，步骤也稍有区别。

--------------

Windows
-------

从网络上下载swig、flex、bison。swig在其官网可以下载，flex和bison可在\ `github <https://github.com/lexxmark/winflexbison/releases/>`__\ 或者SourceForge下载。

全都下载完成之后，将含有swig.exe、win_flex.exe、win_bison.exe的文件夹全部都设置到Path环境变量里面去。

接下来使用QtCreator打开项目，然后尝试编译。

这时遇到cmake报错：OpenSSL:Crypto not found.  这是因为我们还没有告诉编译器OpenSSL的位置，点左侧“项目”，查看构建选项，在CMake的Initial Configuration中，点击添加按钮，新增String型环境变量OPENSSL_ROOT_DIR，将其值设为跟Qt一同安装的OpenSSL的位置（如C:/Qt/Tools/OpenSSL/Win_x64）。然后点下方的Re-configure with Initial Parameters，这样就能正常编译了。

运行的话，在Qt Creator的项目选项->运行中，先将工作目录改为项目所在的目录（git仓库的目录）。然后先将编译好了的FreeKill.exe放到项目目录中，在目录下打开CMD，执行windeployqt FreeKill.exe。调整目录下的dll文件直到能运行起来为止，之后就可以在Qt Creator中正常运行和调试了。

--------------

Linux
-----

通过包管理器安装一些额外软件包方可编译。

Debian一家子：

.. code:: sh

   $ sudo apt install liblua5.4-dev libsqlite3-dev libreadline-dev libssl-dev swig flex bison

Arch Linux：

.. code:: sh

   $ sudo pacman -Sy lua sqlite swig openssl flex bison libgit2

然后使用配置好的QtCreator环境即可编译。

如果你不想用Qt安装器的话，可以用包管理器安装依赖，下面仅举例Arch：

.. code:: sh

   $ sudo pacman -S qt6-base qt6-declarative qt6-5compat qt6-multimedia
   $ sudo pacman -S cmake lua sqlite swig openssl swig flex bison

然后可以用命令行编译：

.. code:: sh

   $ mkdir build && cd build
   $ cmake ..
   $ make -j8

如果你使用 Nix/NixOs 的话，可以在clone repo后直接使用 nix flake 构建：

.. code:: sh

   $ git clone https://github.com/Notify-ctrl/FreeKill
   $ nix build '.?submodules=1'

--------------

Linux服务器
-----------

一般来说Linux服务器的包管理器都没新到提供Qt6下载，这个时候想编译服务端的话，需要在尽可能安装完Qt5环境的情况下，对FreeKill的Qt版本降一下等级。

首先将根目录和src下面的两个CMakeLists.txt的Qt6都改成Qt5，然后试图进行编译。

编译器会报告大概不超过10处错误，将它们修改成Qt5可以接受的形式就行了。

--------------

MacOS
-----

大致与Windows类似，但尚且缺少确切的方案。

--------------

编译安卓版
----------

用Qt安装器装好Android库，然后配置一下android-sdk就能编译了。

(Qt
6.4的刘海屏bug，手动往QActivity.java的onCreate函数追加如下代码即可实现完全全屏。这里做个笔记方便复制粘贴，等Qt修了再说)

.. code:: java

   getWindow().addFlags(LayoutParams.FLAG_FULLSCREEN);
   if (Build.VERSION.SDK_INT > Build.VERSION_CODES.KITKAT) {
       getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);
   }
   if (Build.VERSION.SDK_INT > 28) {
       WindowManager.LayoutParams lp = getWindow().getAttributes();
       lp.layoutInDisplayCutoutMode = LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
       getWindow().setAttributes(lp);
   }

--------------

WASM下编译
----------

WASM大概就是能在浏览器中跑C++。编译用Qt Creator即可。

1. 条件与局限性
~~~~~~~~~~~~~~~

如果程序运行在网页上的话，那么理应只有客户端，然后提供网页的服务器上自然也运行着一个后端服务器。所以说在编译时应该舍弃掉服务端相关的代码。因此依赖库就不再需要sqlite3。

总之是编译个纯客户端的FK。

2. 编译OpenSSL
~~~~~~~~~~~~~~

进入OpenSSL的src目录，然后

::

   $ ./config -no-asm -no-engine -no-dso
   $ emmake make -j8 build_generated libssl.a libcrypto.a

编译Lua的话直接emmake make就行了，总之库已经传到仓库了。

3. 部署资源文件
~~~~~~~~~~~~~~~

由于CMake中\ ``file(GLOB_RECURSE)``\ 所带来的缺陷，每当资源文件变动时，需要手动更新。

把构建目录中的.rcc目录删掉然后重新执行CMake->make即可。每次编译资源文件总要消耗相当多的时间。

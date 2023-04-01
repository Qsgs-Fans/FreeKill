编译fkparse
===========

Linux
-----

::

   $ git clone https://github.com/Notify-ctrl/fkparse
   $ sudo apt install cmake flex bison
   $ cd fkparse
   $ mkdir build && cd build
   $ cmake .. && make

Windows
-------

配置好MinGW和CMake环境，从github上下载最新版的\ ``win_flex_bison``\ ，将其解压缩并设置好环境变量，然后

::

   D:\> git clone https://github.com/Notify-ctrl/fkparse
   D:\> cd fkparse
   D:\fkparse> mkdir build && cd build
   D:\fkparse\build> cmake -G "MinGW Makefiles" .. && mingw32-make

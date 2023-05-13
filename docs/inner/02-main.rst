从main函数开始
===============

FK说到底，本质上是个C++项目，所以程序的入口自然是在main.cpp的main函数中。
本文档不至于把代码一行行拿出来分析，而是尽可能基于main函数来解答一些常见问题。

由于大家比较关注的点都是程序怎么开始执行Lua，所以尽可能往这方面靠吧。
至于main函数的其他功能，比如安卓版执行之前先复制文件之类的，请大家自行查看吧。

服务器端相关
-------------

FK是一个遵循C/S架构的游戏，所以它才支持联机游玩功能。
从文档可以知道 ``./FreeKill -s`` 就能启动服务端进程，来看相应main代码吧。

.. code:: cpp

  // main.cpp: 180行左右
  Server *server = new Server;
  if (!server->listen(QHostAddress::Any, serverPort)) {
    qFatal("cannot listen on port %d!\n", serverPort);

上面的代码就是检测到命令行参数 ``-s`` 之后，开始启动服务器的代码。
这里创造了Server对象，然后在相应端口监听。
不过如果你去看Server的构造函数的话，却找不到Lua相关的代码。

这是因为在服务器端中，可能同时运行多个游戏房间，每个游戏房间是一个单独的线程，
所以是每个游戏房间维护一个Lua虚拟机。总体而言，这是为了让各个房间之间的Lua
不产生冲突。

所以服务端只有在创建新房间的时候才会执行Lua，来看Room的构造函数吧：

.. code:: cpp

    // room.cpp: 31行左右
    L = CreateLuaState();
    DoLuaScript(L, "lua/freekill.lua");
    DoLuaScript(L, "lua/server/room.lua");
    initLua();

首先 ``DoLuaScript`` 从神杀抄的，就是个dofile函数的C++封装版本。
然后调查initLua函数：

.. code:: cpp

    // swig/server.i 31行左右
    void Room::initLua()
    {
      lua_getglobal(L, "debug");
      lua_getfield(L, -1, "traceback");
      lua_replace(L, -2);
      lua_getglobal(L, "CreateRoom");
      SWIG_NewPointerObj(L, this, SWIGTYPE_p_Room, 0);
      int error = lua_pcall(L, 1, 0, -2);
      lua_pop(L, 1);
      if (error) {
        const char *error_msg = lua_tostring(L, -1);
        qCritical() << error_msg;
      }
    }

这个C++函数翻译成Lua就是
``pcall(function() CreateRoom(C++层面的Room) end, debug.traceback)`` ，
意思就是以这个c++版的Room对象为参数，执行Lua全局函数CreateRoom。
就不贴代码了，在room.lua的底端，自己看吧。

不过即使到了这一步，游戏还是没运行起来。
游戏运行函数是 ``Room::run()`` ，里面调用的那个函数已经给注释了。

至此，服务端的Lua开始执行，游戏逻辑也开始运行了。
至于这块是如何运行的，相信熟悉Lua的各位能自己去阅读。

客户端相关
-----------

如果main函数中没有检测到 ``-s`` 命令行参数，那么就绘制UI并显示一个窗口。

.. code:: cpp

    // main.cpp: 292行左右
    // 加载完全局变量后，就再去加载 main.qml，此时UI界面正式显示
    engine->load("qml/main.qml");

这里就加载了main.qml，然后剩下就交给qml来处理UI了。至此main函数结束。

客户端的Lua就简单了，在Client的构造函数里面。客户端的Lua代码只在需要时
执行，而这个就不在main的讨论范畴了，这个在后面通信模块会提到。

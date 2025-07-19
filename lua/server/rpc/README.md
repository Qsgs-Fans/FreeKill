新月杀Lua server：rpc版
=====================================

基于stdio与json-rpc协议的简单rpc方案，旨在避免单进程的oom问题。

依赖：

- 必须是Linux系统，已测试过Debian与Arch
- 安装lua-posix包
- 安装lua-socket包
- 安装lua-filesystem包
- 去freekill的repo底下找到src/swig/qrandom文件夹，按里面README操作

（TODO）如果用AUR中的freekill安装的话，这些依赖会直接安装

（github rpc分支的freekill）按以下命令行开服，就会启用RPC模式，将lua相关运行在单独进程：

```sh
$ ./FreeKill --rpc -s <port>
```

或者想要测试的话就在根目录下（core的）执行命令

```sh
$ lua lua/server/rpc/entry.sh
```

以下是开发时思路。

_______

目前是一个`RoomThread`线程管一个`lua_State *`。
这样的坏处是lua虚拟机和我们共用内存空间，虽然拼尽全力的在找c++内存问题也拼尽全力的修复了，
但是RSS猛增不减还是没消失。

只能怀疑Lua了吗，其实LuaVM才是吃内存最狠的，为了服务端不崩该切割了

我在想要不直接在新进程直接跑lua（`lua entry.lua`之类的），
然后主进程用`QProcess`直接和子进程通信（有和`QIODevice`一样的手段可以用`read()`和`write()`，
本质上是通过stdio交流，也就是lua可以用`io.read()`接收输入，用`print`发送），
以及后面换了别的什么语言后依然可以交流。

当然这么做的目的是update后的销毁luaVM和新建luaVM就变成操作进程了，内存交给系统，或许能让服务端免遭OOM？

基本需求
---------

* 为了节约生命只支持Linux（因此为了其他端能单机启动**必须兼容线程方案**）
* 新的lua进程中，拓展作者自己调普通print打东西出来怎么处置？调了dbg()打算占stdin调试怎么办？
    （~不使用stdio~；禁掉dbg；设计通信协议，可参考json-rpc协议中的一些做法）

实现方面需求
--------------

我们目前的设计中，lua和cpp之间的交流是通过：

```cpp
L->call("InitScheduler", { QVariant::fromValue(thread) });
L->call("HandleRequest", { bytes });
return L->call("ResumeRoom", { roomId, reason }).toBool();
```
 
由此可见，传到lua的cpp内容只有一个`RoomThread *`而已，
但有`thread->getRoom(id)`引申出room一堆，
`room->getPlayers()`引申出player一堆，`player->doNotify`和`player->doRequest`引出网络通信。

此外shell中还用到了`L->eval`读取房间信息等，其实服务端用到eval的场景不多，可以改成`L->call`方便分析。

总之Lua扮演的角色就是：

* 从父进程读取，进而call相关函数
* Lua不能用绝大部分cpp设施，数据必须全部父进程事先告诉
* 完全无法避免的通信这一块就只能发消息到父进程让其代发

除了`RoomThread`牵扯到的之外，Lua还用了以下几个设施：

* QRandomGenerator，目的是固定种子生成一系列随机数
* os.getms，目的是获得微秒级时间戳
* cd ls pwd exists isDir等文件系统函数

这几项么。。还是用c++弄得了，纯血lua拼尽全力做不到。
除了通信类的server相关函数其实基本上是数据读写，给主进程发消息就是了，这三个常用设施直接用lua C API好了，
那么又有分歧：可以用lua的require c lib做，也可以swig。
那还是前者吧，不想碰swig了，luarock启动？但是QRandomGenerator可能需要费点心思啊。

通信协议
------------

拓展包作者用不了io库，所以io.read()放心用就是（**必须禁掉`dbg()`和`debug.debug()`**），
`print`的话，一律交给父进程处理吧，如果符合协议就接受，否则原样写到父进程的stdout？
应该可以。当然也可以禁掉print函数，都用fk.qInfo系列（并不要）

通信协议抄一下json-rpc，并魔改一下（并没有魔改），内容为：

```
Request与Reply:
--> {"jsonrpc": "2.0", "method": "subtract", "params": {"minuend": 42, "subtrahend": 23}, "id": 3}
<-- {"jsonrpc": "2.0", "result": 19, "id": 3}

Notify:
--> {"jsonrpc": "2.0", "method": "update", "params": [1,2,3,4,5]}
```

说明：

* jsonrpc字段固定为2.0
* params的类型：object | array | (nil)
* id的类型： int | (nil) 不填id就是notify

确实是很精简的协议，不用调库，稍微写点代码就能实现，因此通信也可以用stdio来弄了。以上是父子进程通信协议这一块。
关于jsonrpc完整版详见https://wiki.geekdream.com/Specification/json-rpc_2.0.html，我反正用到啥就实现啥
接下来规定双方怎么调用相关函数就行。

实现细节
----------

首先我们要有两套方案，这个很好区分：

* 通用方案：RoomThread中`L->dofile("server/scheduler.lua")`然后信号槽
* rpc方案：RoomThread中起新进程`lua entry.lua`，与进程之间通信，RoomThread里面定义所有对方需要用到的rpc方法，并帮他调cpp函数，同时调lua的方法

然后是依赖问题。C++这边需要用到`QProcess`建立与子进程连接，那不就等于没有依赖了。

Lua直接用lua命令启动进程，在纯血lua的基础上必须引入依赖，只考虑Linux，可以选包管理器里面有的：

* lua-socket: `socket.gettime()`解决微秒问题
* lua-filesystem: 解决文件系统相关问题
* QRandomGenerator: 我没有什么可以说的，自己从新月杀Repo中编译安装一个（src/swig/qrandom）

Lua的话应该运行一个主循环，循环就不断从stdin读取一行，然后处理。

其次就是设计双方具体的RPC方法了。

我们先回顾当前线程方案的做法：

- 平时，RoomThread线程待命（`poll()`）
- 主线程传来的signal会唤醒RoomThread线程，进而执行一个Lua函数
- 直到Lua函数返回为止，这个过程中其他线程传来的信号量会放在Qt内部的消息队列中
- RoomThread调用Lua的过程中，Lua会调用很多C++函数，但这些C++函数不会反过来调用更多Lua函数
- 其他线程调用Lua时，如果有锁则必须等待锁

如此看来其实不用考虑异步之类的东西，做个阻塞式RPC完全能满足要求，在RPC情景下：

- 平时，RoomThread线程待命（`poll()`），Lua进程待命（`socket:receive()`）
- 主线程传来的signal会唤醒RoomThread线程，进而执行一个Lua函数（通过发送rpc请求）
- 直到Lua函数返回（通过收到rpc答复判断）为止，槽函数不可返回 这个过程中其他线程传来的信号量会放在Qt内部的消息队列中
- 因此槽函数必须用阻塞式等待（`QProcess::waitForReadyRead()`）等待Lua发来rpc包，若为request（执行C++函数），则执行并返回response，若为正在等的response，则返回
- 其他线程调用Lua时，必须等待锁（一样的阻塞式等待到response）

综上所述，不需要考虑得太复杂，调用一次rpc方法的伪代码如下就行了，两端都可以这么做：

```py
def callRpc(method, params):
  packetToSend = jsonrpc.request(method, params)
  socket.write(json.encode(packetToSend))
  waitingId = packetToSend.id

  while True:
    msg = socket.read()
    packet, ok = json.decode(msg)
    if not ok:
      socket.write(jsonrpc.error())
    if packet.id == waitingId and packet.method == None:
      return packet.result
    else:
      jsonrpc.server_response(methodDict, packet)
```

RPC方法一览
--------------

C++侧需要实现的：前面提到过的几乎所有swig方法。

Lua需要实现的：

- HandleRequest
- ResumeRoom
- SetPlayerProperty: 新增。因为ServerPlayer中含多个cpp侧自由变化的成员。
- AddObserver: 新增。因为`cRoom.observers`为cpp自由变化。
- RemoveObserver: 新增。理由同上。

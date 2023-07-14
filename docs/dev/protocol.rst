.. SPDX-License-Identifier: GFDL-1.3-or-later

FreeKill 的通信
===============

概述
----

FreeKill使用UTF-8文本进行通信。基本的通信格式为JSON数组：

``[requestId, packetType, command, jsonData]``

其中：

-  requestId用来在request型通信使用，用来确保收到的回复和发出的请求相对应。
-  packetType用来确定这条消息的类型以及发送的目的地。
-  command用来表示消息的类型。使用首字母大写的驼峰式命名，因为下划线命名会造成额外的网络开销。
-  jsonData保存着这个消息的额外信息，必须是一个JSON数组。数组中的具体内容详见源码及注释。

FreeKill通信有三大类型：请求（Request）、回复（Reply）和通知（Notification）。

--------------

从连接上到进入大厅
------------------

想要启动服务器，需要通过命令行终端：

.. code:: sh

   $ ./FreeKill -s <port>

``<port>``\ 是服务器运行的端口号，如果不带任何参数则启动GUI界面，在GUI界面里面只能加入服务器或者单机游戏。

服务器以TCP方式监听。在默认情况下（比如单机启动），服务器的端口号是9527。

每当任何一个客户端连接上了之后，游戏会先进行以下流程：

1. 检查IP是否被封禁。 // TODO: 数据库
2. 服务端将RSA公钥发给客户端，然后检查客户端的延迟是否小于30秒。
3. 在网络检测环节，若客户端网速达标的话，客户端应该会发回一个字符串。这个字符串保存着用户的用户名和RSA公钥加密后的密码，服务端检查这个字符串是否合法。如果合法，检查密码是否正确。
4. 上述检查都通过后，重连（TODO:）
5. 不要重连的话，服务端便为新连接新建一个\ ``ServerPlayer``\ 对象，并将其添加到大厅中。

--------------

大厅和房间
----------

大厅（Lobby）是一个比较特殊的房间。除了大厅之外，所有的房间都被作为游戏房间对待。

对于普通房间而言，有这几个特点：

1. 只要房间被添加玩家，那么那名玩家就自动从大厅移除。
2. 当玩家离开房间时，玩家便会自动进入大厅。
3. 当所有玩家都离开房间后，房间被“销毁”（其实是进入Server的空闲房间列表，毕竟新建lua_State的开销十分大）。

大厅的特点：

1. 只要有玩家进入，就刷新一次房间列表。
2. 只要玩家变动，就更新大厅内人数（TODO:）

..

   因为上述特点都是通过信号槽实现的，通过阅读代码不易发现，故记录之。

--------------

对游戏内交互的实例分析
----------------------

下面围绕着askForSkillInvoke对游戏内的交互进行简析，其他交互也是一样的原理。

.. code:: lua

   function Room:askForSkillInvoke(player, skill_name, data)
     local command = "AskForSkillInvoke"
     self:notifyMoveFocus(player, skill_name)
     local invoked = false
     local result = self:doRequest(player, command, skill_name)
     if result ~= "" then invoked = true end
     return invoked
   end

在这期间，一共涉及两步走：

1. Room向所有玩家发送消息，让大家看到进度条和进度条上显示的原因（notifyMoveFocus）
2. Room向询问的玩家发送一次Request信息，进行询问，然后返回玩家发回的reply。

首先看第一步：通知。这里涉及的函数是doNotify。（调查notifyMoveFocus的代码即可知道）

调查\ ``ServerPlayer:doNotify``\ 发现：

.. code:: lua

     self.serverplayer:doNotify(command, jsonData)

这里的self.serverplayer，其实指的是C++中的ServerPlayer实例，因此这一行代码实际上调用的是C++中的ServerPlayer::doNotify。调查C++中对应的函数，发现实际上调用了Router::notify，调查Router::notify，发现发送了一个信号量，调查Router::setSocket发现这个信号量连接到了ClientSocket::send。调查ClientSocket::send后发现：

.. code:: cpp

   void ClientSocket::send(const QByteArray &msg)
   {
     if (msg.length() >= 1024) {
       auto comp = qCompress(msg);
       auto _msg = "Compressed" + comp.toBase64() + "\n";
       socket->write(_msg);
       socket->flush();
     }
     socket->write(msg);
     if (!msg.endsWith("\n"))
       socket->write("\n");
     socket->flush();
   }

核心在于socket->write，这里其实就调用了QTcpSocket::write，正式向网络中发送数据。从前面的分析也慢慢可以发现，发送的其实就是json字符串。

那么问题又来了，客户端接收到服务端发送的通知时，如何进行响应呢？

这就涉及到Router::handlePacket函数，具体的信号槽连接方式不赘述，这个函数在socket接收到消息时就会自行调用。

其中有这样的一段：

.. code:: cpp

     if (type & TYPE_NOTIFICATION) {
       if (type & DEST_CLIENT) {
         ClientInstance->callLua(command, jsonData);
       }

调用了ClientInstance::callLua函数，这个函数不做详细追究，只要知道他调用了这个lua函数即可：

.. code:: lua

     self.client.callback = function(_self, command, jsonData)
       local cb = fk.client_callback[command]
       if (type(cb) == "function") then
         cb(jsonData)
       else
         self:notifyUI(command, jsonData);
       end
     end

至此，我们已经可以基本得出结论：Client在接收到信息时就根据信息的command类型调用相应的函数，若无则直接调用qml中的函数。

接下来聊聊doRequest。和前面类似，doRequest最终也是向玩家发送了一个JSON字符串，但是然后它就进入了等待回复的状态。在此期间，可以使用waitForReply函数尝试获取对方的reply，若无则得到默认结果\__notready，然后在Lua侧进行进一步处理。

客户在收到request类型的消息后，可以用reply对服务端进行答复。reply本身也是JSON字符串，服务端在handlePacket环节发觉这个是reply后，就知道自己已经收到回复了。这时用waitForReply即可得到正确的回复结果。

在Lua侧，对waitForReply其实有所封装：

.. code:: lua

     while true do
       result = player.serverplayer:waitForReply(0)
       if result ~= "__notready" then
         return result
       end
       local rest = timeout * 1000 - (os.getms() - start) / 1000
       if timeout and rest <= 0 then
         return ""
       end
       coroutine.yield(rest)
     end

这里就是一个死循环，不断的试图读取玩家的回复，直到超时为止。因为waitForReply指定的等待时间为0，所以会立刻返回（这也是为什么waitForReply在读取reply时需要加锁的原因，因为读取操作很频繁），此时若lua发现玩家并未给出答复，就会调用coroutine.yield切换到其他线程去做点别的事情（比如处理旁观请求，调用QThread::msleep睡眠一阵子等等），别的协程办完事情后再次切换回这个协程（yield函数返回），然后开启新一轮循环，如此往复直到等待时间耗尽或者收到了回复。

--------------

对掉线的处理
------------

因为每个连接都对应着一个\ ``new ClientSocket``\ 和\ ``new ServerPlayer``\ ，所以对于掉线的处理要慎重，处理不当会导致内存泄漏以及各种奇怪的错误。

一般来说掉线有以下几种情况：

1. 刚刚登入，服务端还在检测时掉线。
2. 在大厅里面掉线。
3. 在未开始游戏的房间里面掉线。
4. 在已开始游戏的房间里掉线。

首先对所有的这些情况，都应该把ClientSocket释放掉。这部分代码写在\ `server_socket.cpp <../../src/network/server_socket.cpp>`__\ 里面。

对于2、3两种情况，都算是在游戏开始之前的房间中掉线。这种情况下直接从房间中删除这个玩家，并告诉其他玩家一声，然后从服务器玩家列表中也删除那名玩家。但对于情况3，因为从普通房间删除玩家的话，那名玩家会自动进入大厅，所以需要大厅再删除一次玩家。

对于情况4，因为游戏已经开始，所以不能直接删除玩家，需要把玩家的状态设为“离线”并继续游戏。在游戏结束后，若玩家仍未重连，则按情况2、3处理。

   Note: 这部分处理见于ServerPlayer类的析构函数。

--------------

断线重连
--------

根据用户id找到掉线的那位玩家，将玩家的状态设置为“在线”，并将房间的状态都发送给他即可。

但是为了UI不出错，依然需要对重连的玩家走一遍进大厅的流程。

重连的流程应为：

1. 总之先新建\ ``ServerPlayer``\ 并加到大厅
2. 在默认的处理流程中，此时会提醒玩家“已经有同名玩家加入”，然后断掉连接。
3. 在这时可以改成：如果这个已经在线的玩家是Offline状态，那么就继续，否则断开。
4. pass之后，走一遍流程，把玩家加到大厅里面先。
5. 既然是Offline，那么掉线玩家肯定是在已经开始游戏的房间里面，而且其socket处于deleted但没有置为nullptr的状态。
6. 那么在pass之后不要创建旧的SPlayer对象，而复用以前的。也不必走一次进lobby流程。
7. 所以先手动发送Setup和EnterLobby消息。
8. 发送Reconnect消息，内含房间的所有信息。Client据此加入房间并设定好信息。

房间应该有哪些信息？

直接从UI着手：

1. 首先EnterRoom消息，需要\ **人数**\ 和\ **操作时长**\ 。
2. 既然需要人数了，那么就需要\ **所有玩家**\ 。
3. 此外还需要让玩家知道牌堆、弃牌堆、轮数之类的。
4. 玩家的信息就更多了，武将、身份、血量、id…

所以Lua要在某时候让出一段时间，处理重连等其他内容，可能还会处理一下AI。

这种让出时间处理的东西时间要尽可能的短，不要在里面搞个大循环。

会阻塞住lua代码的函数有：

-  ServerPlayer:waitForReplay()
-  Room:delay()

在这里让出主线程，然后调度函数查找目前的请求列表。事实上，整个Room的游戏主流程就是一个协程：

.. code:: lua

   -- room.lua:53
   local co_func = function()
     self:run()
   end
   local co = coroutine.create(co_func)
   while not self.game_finished do
     local ret, err_msg = coroutine.resume(co)
     ...
   end

如果在游戏流程中调用yield的话，那么这里的resume会返回true，然后可以带有额外的返回值。不过只要返回true就好了，这时候lua就可以做一些简单的任务。而这个简单的任务其实也可以另外写个协程解决。

--------------

旁观（TODO）
------------

因为房间不允许加入比玩家上限的玩家，可以考虑在房间里新建一个列表存储旁观中的玩家。但是这样或许会让某些处理（如掉线）变得复杂化。

也可以考虑旁观者在服务端中处于大厅中，自己的端中在旁观房间。但是这样的话无法在房间中发送聊天。

所以还是让旁观者在房间中吧。可以给ServerPlayer设置个属性保存正在旁观的房间的id。

旁观者的处理方式或许可以像观看录像那样，过滤所有的request事件。这样就确确实实只能看着了。

而不过滤request的旁观就可以理解为操控其他玩家了。hhh

总而言之，旁观的处理流程基本如下：

1. 客户端从大厅中发起旁观房间的请求。
2. 服务器知晓后，进行一些C++的活，把这个玩家加到房间去。
3. 之后把这个请求丢到请求列表去。等房间让出协程后，进行对旁观玩家的处理流程。
4. Lua中如同断线重连那样，肯定要让玩家知晓房间内的状况。
5. 此时由于Lua的Room中并没有这个玩家，因此也要新建一个SPlayer对象。
6. 但这种Player比较特殊，他与游戏无关，所以肯定不能加到Room的players中。考虑另外弄个数组，但是这样就可能被notify函数啥的过滤掉了。
7. 这种情况下可以魔改doBroadcastNotify函数，如果是对全员广播消息的话，那么也跟旁观者说一声。

考虑到UI中是以fk.Self决定主视角，因此有必要发一条Setup信息改掉旁观者视角？或者修改Room.qml专门适配旁观者。

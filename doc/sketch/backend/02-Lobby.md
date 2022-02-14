# 大厅

## 连线

连上去就是了。

主要还是具体怎么弄的问题。就是说怎么利用好lua。比如服务器更新一下房间列表：

1. 服务器（lua）调用doNotify；
2. doNotify内部调用服务器的socket（c）发送字符串；
3. 客户端（c）接收了
4. 信号槽，槽函数内部调用lua
5. lua函数内部通知ui
6. ui是用qml，因此需要有个c一起交互，但是通知ui的函数多种多样。这些内部最终调用了某个c。
7. 这个充当lua和qml桥梁的c函数只要能传递一下字符串就够了。

...

lua可以考虑用middleclass库。现在有

```lua
room:doNotify(player, json.encode(json_data))
```

在神杀中这又会调用player的成员函数，然后player最终socket:write。

所以把两个socket类注册给lua就好了。

那么再看client这边的lua。socket也是触发了readyRead并交给了getMessage，最后发出一个信号。为了lua可以把信号改成调用某个lua函数。那么lua收到字符串之后就分析字符串并调用对应的函数。那个函数里面就要开始调用c了，c又调用qml。c调用qml利用信号槽机制就好了。c还要再注册个函数把东西传回给lua。比如有个QmlRouter类，提供函数CallQml(string, data)和ReturnFromQml(string, data)。

参考一下神杀的ai机制，LuaAI类和Lua里面的Smart类只通过一个函数callback进行交流。我们的Server也可以C这边一个类，Lua那边又一个类。

所以C这边的类需要定义好所有的需要被C和QML调用的函数；Lua是主战场。

所以要有LuaServer和LuaClient这两个C类。还应该有LuaRoom、LuaGameLogic（即RoomThread，感觉取这名字好理解一些）。这是后话了。

我们需要能够拓展的是游戏内部的ui，所以这部分ui在qml写死就好了；意思是开始之前和大厅内的ui。

## ui

游戏开始之前的话放一个启动服务器和加入服务器就行了。也不用弹框。启动服务器的话提供端口号即可，加入服务器的话提供服务器地址和用户名就行了。

这之后大厅内部ui：房间列表就行了。

## 客户端

由于我们只要拓展游戏内部就够了（即客户端处各个处理函数使用lua），所以大部分写死就行了。

## 服务端

现在点击了启动服务器按钮，就会新建一个server并试图监听对应的端口。

考虑一下服务器端需要什么：

1. 首先是Server，服务器本身。
2. 然后是ServerPlayer，用来管理每个连接到本服的玩家。
3. 然后是Room，游戏房间，是一个线程。
4. GameLogic，游戏的具体执行方法，也是一个线程，执行游戏的具体内容。

Server需要开放Lua吗？自然是不需要。

ServerPlayer需要开放Lua吗？也不用。

Room需要开放Lua吗？需要使用Lua的部分为askfor之类的，目标之一就是要让这里可拓展。

GameLogic需要开放Lua吗？肯定需要啦。

由于这些原因，所以Server内部肯定需要一个lua_State。这个用来创建房间用。不过现在还没有房间。这个markdown还只考虑Lobby。

所以暂时用不到Lua。就考虑纯C++和Qml实现一个大厅吧。

## 开始通信



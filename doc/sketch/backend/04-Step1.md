# 阶段总结1

___

## 通信

socket之上包装一层router，用来实现三种主要通信方式。

client和serverplayer之间直接调用router就能通信了。

## 服务端

Server -> Room -> ServerPlayer

Server: 大服务器本身，存放各种Room，同时也总管所有的ServerPlayer

Room: 游戏房间，ServerPlayer直接所在的地方

ServerPlayer: 游戏玩家，也是直接和Client发起通信者。也可以是bot。

## 客户端

Client -> ClientPlayer

Client: 客户端本身，与服务端通信。

ClientPlayer: 客户端所知的其他玩家的信息。包括这个玩家他自己。

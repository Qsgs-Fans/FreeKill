# 通信

___

## 如何通信

通信一律用JSON字符串进行，JSON分为这几个部分：

1. Packet的大类型，Enum，分为Notify和Request和Reply这几种。然后根据目标的不同分为Client、Lobby、Room。位运算。
2. Packet的详细类型，是一个字符串。
3. Packet附带的更多信息，是JSON对象。反正是根据不同字符串去调用不同的处理函数。

服务器可能同时收到很多，可以把待处理的用队列存住。(这暂且不是我需要考虑的)

## 例子

现在要对一个刚进大厅的玩家刷新房间列表。

1. 大类型，是Notify，SRC_LOBBY，DEST_CLIENT
2. 详细类型："lobby_notify_updateRoomList"
3. 详细信息：房间列表的json

Packet就那样。

## 类

讨论一下Packet的三种发送：notify、request、reply。

notify就提示一下信息，直来直去就行了。主要看看会产生阻塞的后两个。

当发起request的时候，此时一方应该等待另一方回应。request方已经被阻塞着，就看回应了。首先回应要合法，这个可以通过id检验。然后回应不能超过timeout。等待相应时间通过信号量实现。其他细节抄。

由于client和server都用这个，所以淡出出个类。

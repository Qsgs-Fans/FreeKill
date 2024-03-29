关于好友系统
=============

“好友系统”这几个字可谓是囊括的面有点多啊。总而言之：

- 添加好友、管理好友、删除好友
- 和好友进行私聊

没了，就只有以上两点而已。

好友信息肯定要放在各个服务器自己的数据库中。

登入时自动获取好友列表和消息列表。因此好友列表有上限，最多50人，不然负载太大。
列表至少要有好友的名字、头像，然后最好还有在线状态。前二者查数据库，第三者要根据id在Server范围查询玩家，然后根据是否找的出、Room是大厅还是确切Room、Room是否已开始分为离线、空闲、等待中、游戏中、观战中四个状态。

好友列表查出之后就要暂时放在ServerPlayer类里面，也就是放在RAM中。因为状态一变动就要广播所有好友自己的状态，变动的情况有：

- 登入/登出；
- 进入房间/进入大厅；
- 游戏开始时/结束时

每当状态变化了就通知好友？还是好友进大厅的时候就获取一次信息？答案是要一直通知。
但是现阶段可以先只针对大厅中的好友通知。毕竟房间里面没地方摆好友UI呢。

简而言之，只要进入大厅，就获取好友信息（和自动获取房间列表性质一致）。然后一直接收通知修改好友状态。

接下来就是处理如何加好友了，顺便处理私聊之事。
首先加好友只能在Room中加，这就避免了搜索好友的问题。将加好友请求视为一种特殊的私信吧。

私信
-----

私信的问题在于已读和未读。未读信息要暂存在服务器；已读信息和聊天记录可以放在客户端本地的数据库中。

反正二者都要用到数据库啊。综上，涉及三张表：服务端需要好友关系表、未读信息表；客户端需要聊天记录表。

服务器端 - 好友关系表：

.. code:: sql

   CREATE TABLE 好友 {
     user1, user2, type
     }

type是个数字，可能是好友或者黑名单。

神貂蝉
======

“本回合改为由你操控。” ——神貂蝉

封装
----

先画好靶子！想一下怎么定义函数才好！

- 你来操控别的角色
- 别的角色重新操控自己
- 你同时控制自己和别人
- 询问无懈
- 老朱然

考虑中：。...

.. code:: lua

   ServerPlayer:control(ServerPlayer)
   ServerPlayer:observe(ServerPlayer)

两函数差不多了吧。。。

这样一来，神貂蝉就是让被控者observe，然后自己去control；回合结束后，被控者开始control。

observe
-------

对机器人：无视。

对人：发送observe消息。但这个人依然处于room.players中，无论是Lua还是cpp。

只是这个人对应的cpp层面的ServerPlayer进旁观了而已。

control
-------

控制者：发送control消息。控制者多了个可以控制的角色，仅此而已。

如果已有控制者：发送dontcontrol消息，不准打架 而这个消息最终还是走到observe消息处理

客户端实现
----------

想好了怎么发消息那消息该怎么处理？

首先dontcontrol 把可控制者-1 没有可控了就进旁观呗

然后是control加一个受控者 要是旁观直接切视角

切视角
------

先给个dashboard向下滑出并淡出消失的动画

Lua 改变 Self

根据服务端的信息填充这个新Self的信息

dashboard手牌清空

dashboard填入新Self的新手牌

dashboard重新出现

根据新Self重新安排所有photo

由于不影响烧条 这个动画效果越快越好

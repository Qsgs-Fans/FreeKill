.. SPDX-License-Identifier: GFDL-1.3-or-later

游戏逻辑
========

概述
----

FreeKill的游戏相关处理逻辑完全使用lua实现。在服务端上，每个Room都有自己的lua_State，并且只会在Room线程启动后才会去调用lua函数进行游戏逻辑处理。

本文档将简要介绍几个最为复杂的逻辑实现。

--------------

触发技
------

在lua/fk_ex.lua中有对触发技的描述：

.. code:: lua

   ---@alias TrigFunc fun(self: TriggerSkill, event: Event, target: ServerPlayer, player: ServerPlayer):boolean
   ---@class TriggerSkillSpec: SkillSpec
   ---@field global boolean
   ---@field events Event | Event[]
   ---@field refresh_events Event | Event[]
   ---@field priority number | table<Event, number>
   ---@field on_trigger TrigFunc
   ---@field can_trigger TrigFunc
   ---@field on_cost TrigFunc
   ---@field on_use TrigFunc
   ---@field on_refresh TrigFunc

具体的\ ``fk.CreateTriggerSkill``\ 函数接受一个类型为如上所述的TriggerSkillSpec形式的表。这个表中的属性一共有一下这些：

-  所有技能通用的\ ``name``\ 、\ ``anim_type``\ 、\ ``mute``\ 。其中name为必需项。
-  global: 是否是全局技能。
-  events: 技能的所有触发时机
-  can_trigger: 技能能否被触发
-  on_trigger: 技能触发时具体的行为
-  on_cost: 技能如何执行消耗
-  on_use: 技能被发动后，具体的生效内容
-  priority:
   技能的优先级。在同一时机有多个技能能够被触发时，先触发优先级高的。

refresh等一系列函数与前面同理，下面会对其展开细说。

首先先来看看触发技究竟是如何被触发的：（以下代码详见room.lua和gamelogic.lua，这里只是简单说明一下）

1. 某处调用\ ``logic:trigger(event, player, data)``
2. 开始调用GameLogic:trigger，首先从所有符合该时机的技能中选出那个技能列表。这里说明一下，所有的触发技都保存在GameLogic的\ ``skill_table``\ 表中，这个表的键是相应的触发时机，值则是技能列表。每当GameLogic被创建时，首先会将全局触发技都加入到表中；然后，在游戏中每当有角色获得了一个触发技，就将这个技能加入到表中直到游戏结束。
3. 若调用trigger函数时对target参数传入了nil，表示这是一个通用型时机，没有特定的承担者，比如fk.GameStart时机。这时候会对技能进行can_trigger检测并直接触发。
4. 若target不是nil，那么将对整个Room中所有玩家进行遍历。在这个遍历过程中，对每个玩家分别判断其能否触发这个技能，若能的话就进行on_trigger的内容，中间的优先级和选择发动哪个技能暂且不说明，可以在代码中查看到。
5. 若on_trigger函数返回了true，那么就说明这个时机被中断了，此时trigger函数返回，否则就这样一直遍历完所有玩家为止。

这就是整个触发技的流程了，可见只涉及了can_trigger和on_trigger函数，并没有on_cost和on_use环节。熟悉太阳神三国杀Lua的朋友知道触发技的发动时机难以定义，因为没有很好的办法知道究竟在哪个时候才算是“发动”了技能。为了解决这个问题，FreeKill引入了on_cost和on_use这两个函数。

这部分相关的代码位于core/skill_type/trigger.lua中。来看看这些函数的默认值：

.. code:: lua

   function TriggerSkill:triggerable(event, target, player, data)
     return target and (target == player)
       and (self.global or (target:isAlive() and target:hasSkill(self)))
   end

   function TriggerSkill:trigger(event, target, player, data)
     return self:doCost(event, target, player, data)
   end

这就是can_trigger和on_trigger的默认值了。can_trigger默认情况下判断遍历到的角色就是承担者角色，并且这个角色要拥有本技能才行。这种判断适用于绝大多数情况，比如英姿等技能。而on_trigger则是调用了TriggerSkill:doCost函数了。doCost函数并不是fk_ex.lua中的on_cost，而是triggerSkill中的一个特别的函数，其内容如下：

.. code:: lua

   function TriggerSkill:doCost(event, target, player, data)
     local ret = self:cost(event, target, player, data)
     if ret then
       local room = player.room
       if not self.mute then
         room:broadcastSkillInvoke(self.name)
       end
       room:notifySkillInvoked(player, self.name)
       player:addSkillUseHistory(self.name)
       ret = self:use(event, target, player, data)
       return ret
     end
   end

这个函数首先调用self:cost（即on_cost），判断是否返回了true。（返回true的话意味着玩家已经完成了消耗，技能被正式发动了）如果返回true的话，那么就认为技能发动了，这时会添加技能发动记录、播放配音等行为，然后正式执行self:use（即on_use）。这就是触发技完整的从触发到使用的过程。

现在以鬼才为例：（packages/standard/init.lua）

.. code:: lua

   local guicai = fk.CreateTriggerSkill{
     name = "guicai",
     anim_type = "control",
     events = {fk.AskForRetrial},
     can_trigger = function(self, event, target, player, data)
       return player:hasSkill(self.name) and not player:isKongcheng()
     end,
     on_cost = function(self, event, target, player, data)
       local room = player.room
       local prompt = "#guicai-ask::" .. target.id
       local card = room:askForResponse(player, self.name, ".|.|.|hand", prompt, true)
       if card ~= nil then
         self.cost_data = card
         return true
       end
     end,
     on_use = function(self, event, target, player, data)
       local room = player.room
       room:retrial(self.cost_data, player, data, self.name)
     end,
   }

首先name和anim_type啥的不多说。技能的时机是AskForRetrial，这也就是询问改判的时机。由于鬼才的触发条件是只要自己有手牌就能触发，无需判定者是自己，因此这里没有用默认的can_trigger。on_trigger函数采用默认方案，直接只执行doCost。在on_cost环节，玩家需要选择是否打出一张手牌。如果确实打出牌了，那么就返回true，并把打出的牌保存到self.cost_data中。（self是这个技能本身，注意技能的本质其实就是一张表，因此可以像这样指定一个新的键值也是没问题的）在on_use，也就是技能的生效部分，才会正式执行改判这一动作。

on_trigger在非常多情况下仅仅只是简单的执行一下doCost而已，但对于有些技能则不然，比如遗计，它能在一次伤害事件中执行许多次，每受一点伤害就能发动一次，因此这种情况下需要自己对on_trigger中的内容手动编写一下。

在有些时候，只是想在特定的时机执行一些代码，而不想进行询问和发动技能流程时，可以使用on_refresh执行。在refresh的情况下，代码仅仅只是执行了一次，不会做出发动技能之类的动作、

--------------

移动牌
------

移动牌的核心函数是\ ``Room:moveCards(...)``\ 。这是个变长参数函数，根据Emmy注解可知所有的参数都应该是CardsMoveInfo类型。CardsMoveInfo在\ `system_enum.lua <../../lua/server/system_enum.lua>`__\ 里面有类型注解，来看看：

.. code:: lua

   ---@class CardsMoveInfo
   ---@field ids integer[]
   ---@field from integer|null
   ---@field to integer|null
   ---@field toArea CardArea
   ---@field moveReason CardMoveReason
   ---@field proposer integer
   ---@field skillName string|null
   ---@field moveVisible bool
   ---@field specialName string|null
   ---@field specialVisible bool

moveCards函数的第一步是将参数中所有的moveInfo都转化为CardsMoveStruct。CardsMoveStruct与CardsMoveInfo几乎没有区别，除了它将每一张牌都单独划分出了一个moveinfo之外。这么做是为了在同时移动来源不同的牌的时候，让牌能该明牌明牌，该暗牌暗牌。

全部转化完成后，先针对这个CardsMoveStruct[]触发一次BeforeCardsMove，给各种奇怪的触发技修改移动牌信息的机会。如此如此之后就正式开始移动牌了，移动完了之后再触发AfterCardsMove，这样就完成了对卡牌的移动。

正式移牌中，首先服务器会向各个客户端发送一条消息让客户端知道牌被移动了。

然后，对所有的CardsMoveStruct进行遍历，根据move.from和move.fromArea获取这张牌的id实际所在的数组，然后将这个id移动到目标数组中。如此就在服务端的数据层面移动了一张牌。移牌OK后，Room会更新这张牌的位置信息，然后视情况更新这张牌的锁定视为技信息。如果是装备牌的话，那么就做一些跟装备技能有关的事情。

--------------

使用牌
------

使用一张牌应该是全游戏最复杂而又最常见的一种事件了。说他复杂，其实也是被狗卡各种乱七八糟的技能和规则搞得很复杂的。

使用牌的核心函数是\ ``Room:useCard``\ ，接收的参数是CardUseStruct。不行太复杂了，过一阵子再来看吧。

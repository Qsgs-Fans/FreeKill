.. SPDX-License-Identifier: GFDL-1.3-or-later

技能解析：触发技
======================

在上回中，我们创造了第一个技能“激姿”，就是一个改造版的英姿，它的作用是摸牌阶段摸牌时候让摸牌数+4。

像这种在游戏特定时机被触发的技能，就称为触发技，它们通常都是形如“当xxx时，你可以xxx”的技能。

下面来介绍触发技。首先介绍触发技的几个基本函数，再说明触发技的执行流程，最后说明怎么创建触发技。这篇文章大多为比较无聊的概念解析，也没有实操，建议自己对着已经写好的触发技实操。

触发技的基本函数
--------------------

触发技中涉及这些函数：

- ``can_trigger`` ：技能能否被触发？
- ``on_trigger`` ：技能是如何执行的？
- ``on_cost`` ：技能的执行消耗是什么？
- ``on_use`` ：技能正式发动后，执行什么代码？

所有这些函数的函数原型全都是一样的：

.. code:: lua

   ---@param self TriggerSkill
   ---@param event Event
   ---@param target ServerPlayer
   ---@param player ServerPlayer
   ---@param data any
   function(self, event, target, player, data)
   end

这个函数原型还是稍微有些难以理解，得结合触发技的具体执行流程来看。

触发技的执行流程
--------------------

第一步 触发一个时机
~~~~~~~~~~~~~~~~~~~~~

触发技若是想要被发动，那么肯定就先要有时机被触发了。而用来触发事件的函数就是如下这位：

.. code:: lua

   ---@param event Event
   ---@param target ServerPlayer
   ---@param data any
   function GameLogic:trigger(event, target, data) end

直接调查这个函数的代码就能知道触发技执行的所有细节了。但这个函数并没有那么好懂，故在此进行说明。

首先，从这个函数可以看出，某一个触发时机一共有三要素：

- ``event`` ：具体是哪个触发时机。
- ``target`` ：这个触发时机涉及的玩家，这名玩家在后面会称为“时机的承担者”。
- ``data`` ：可以是任何值，视具体时机而定。

首先，event是这个时机具体是什么，比如“受到伤害后”（ ``fk.Damaged`` ）；target则是时机的承担者，比如“受到伤害后”这个时机，承担者就是此次伤害的目标；data就完完全全是根据时机而定了。

想要知道某个时机具体对应着哪个target和data，最直接的办法就是直接从源码中找到trigger函数调用的点了，这样一下子就知道这个时机的相关数据了。不过呢，文档后面也是会一一列出的，毕竟有些时机的data还是多少复杂了点。

第一步（续） 假设出一个例子情景
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

在开始接下来的解说之前，还是想象一下有这么一桌军五吧：

::

       郭嘉      司马懿

  *关羽 -------杀------>  郭嘉 -1

         周瑜（一号位）

如图所示，关羽杀郭嘉（二号位），郭嘉掉血，此时执行到了伤害流程的“受到伤害后”时机。

假设当前回合的角色是关羽。

假设郭嘉拥有在这个时机可以发动的技能“遗计”，其代码如下：

.. code:: lua

  local easy_yiji = fk.CreateTriggerSkill{
    name = "easy_yiji",
    events = {fk.Damaged},
    on_use = function(self, event, target, player, data)
      player:drawCards(2)
    end,
  }

为了简化说明，这是是一段简化版的遗计代码。其作用是受到伤害后，可以摸两张牌。

前面说到一个触发技得有4种函数，而这里却只有个 ``on_use`` 啊。这是因为其他三个函数此处可以取默认值，所以实际写Lua的时候省略掉了。为了便于说明，现在将这4个函数补全（包括默认情况）：

.. code:: lua

  local easy_yiji = fk.CreateTriggerSkill{
    name = "easy_yiji",
    events = {fk.Damaged},
    can_trigger = function(self, event, target, player, data)
      return target == player and target:hasSkill(self.name)
    end,
    on_trigger = function(self, event, target, player, data)
      return self:doCost(event, target, player, data)
    end,
    on_cost = function(self, event, target, player, data)
      return player.room:askForSkillInvoke(player, self.name)
    end,
    on_use = function(self, event, target, player, data)
      player:drawCards(2)
    end,
  }

这里假设出来的情景是“受到伤害后”时机，写成代码就是

.. code:: lua

   logic:trigger(fk.Damaged, guojia, data)

这里不关心data。第二个参数guojia表示受到伤害后的那个郭嘉。注意场上有两个郭嘉，这是为了后面详细解释而安排的。

第二步 遍历场上玩家
~~~~~~~~~~~~~~~~~~~~

现在的时机是fk.Damaged，刚好遗计的时机也是fk.Damaged，所以遗计就能在这个时机发动了。隔壁司马懿也有个反馈能在这个时机发动。所以现在能够在该时机发动的技能有：遗计、反馈。

假设反馈的代码和上文的遗计一模一样，只是技能名不同罢了。

确定了可能可以发动的技能后，Fk就会从当前回合角色开始，对所有角色进行遍历。每一趟遍历的步骤如下：

1. 把当前正在遍历到的玩家称为player。
2. 执行 ``can_trigger(self, event, target, player, data)``
3. 如果第二步的执行返回了true，就执行 ``on_trigger`` 。

事已至此，触发技函数中的参数也基本明朗了：

- ``self`` ：这个技能本身。
- ``event`` ：当前的触发时机。
- ``target`` ：时机的承担者。
- ``player`` ：当前被遍历到的玩家。
- ``data`` ： ``logic:trigger`` 函数中传入的那个额外的data参数。

下面进行针对前面那桌军五，模拟一下这么个遍历流程。

::

  可能可以发动的技能： 遗计，反馈
  当前回合角色：关羽
  当前时机：受到伤害后
  时机的承担者（target）：郭嘉 - 二号位
  当前的data：没人在意data

  对 关羽 进行遍历，令 player 为 关羽
    -> 遗计的can_trigger：失败，target ~= player
    -> 反馈的can_trigger：失败，target ~= player

  对 周瑜 进行遍历，令 player 为 周瑜
    -> 遗计的can_trigger：失败，target ~= player
    -> 反馈的can_trigger：失败，target ~= player

  对 郭嘉二号位 进行遍历，令 player 为 郭嘉二号位
    -> 遗计的can_trigger：通过，target == player and player:hasSkill(self.name)
      -> 遗计的 on_trigger 开始执行
      -> 执行 TriggerSkill:doCost
    -> 反馈的can_trigger：失败，target == player，但是player:hasSkill(反馈)为false，郭嘉不会反馈

  对 司马懿 进行遍历，令 player 为 司马懿
    -> 遗计的can_trigger：失败，target ~= player
    -> 反馈的can_trigger：失败，target ~= player，虽然player拥有技能反馈

  对 郭嘉四号位 进行遍历，令 player 为 郭嘉四号位
    -> 遗计的can_trigger：失败，target ~= player
    -> 反馈的can_trigger：失败，target ~= player

  遍历结束了，本次触发时机也随之结束了。

从上面的实机演练中我们差不多能明白 ``can_trigger`` 和 ``on_trigger`` 的执行流程。

.. note::

  在实际的执行中，其实是先都执行 ``can_trigger`` ，然后将所有通过的技能暂存在表中，玩家可以从这里面选出自己想要先发动的技能，然后再去执行那个技能的 ``on_trigger`` 。

第三步 询问消耗执行，以及正式发动技能
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

而 ``on_cost`` 和 ``on_use`` ，则是在on_trigger中调用doCost函数时候调用的。doCost的内容如下：

.. code:: lua

  -- do cost and skill effect.
  -- DO NOT modify this function
  function TriggerSkill:doCost(event, target, player, data)
    local ret = self:cost(event, target, player, data)
    if ret then
      return player.room:useSkill(player, self, function()
        return self:use(event, target, player, data)
      end)
    end
  end

在这段代码中，首先执行一下cost函数（也就是这里聊的on_use），如果返回true，那么调用useSkill函数正式发动技能。useSkill函数先播放技能发动的特效、增加技能发动次数，再去调用传入的第三个函数（这里就是on_use了）。

这也就是说，on_cost函数掌握的是技能是否确实要发动，用户得在这里做出自己的选择。如果用户作出了肯定的答复，那么on_cost就返回true，这之后技能发动次数的历史记录便加一，然后开始真正执行技能的效果。

创建触发技的办法
------------------

要创建一个触发技，我们使用 ``fk.CreateTriggerSkill`` 函数。该函数接收一个表作为参数，表中各种键值的含义如下：

- ``name`` ：技能名。别和其他技能重名了。
- ``frequency`` ：技能的发动频率，可能是锁定技。
- ``anim_type`` ：技能的动画类型。上一篇好像已经聊过了。
- ``mute`` ：技能是否静默。

.. tip::

  静默的技能不会播放配音、动画、发log，如果你想播放配音，就得自己手动做这些工作。
  有些需要根据情况手动播放相应配音的技能，比如自书、英魂等，就得先设为静默，然后自己去技能发动的环节添加这些跟播放特效有关的代码。

上面这4项其实是对所有技能都通用的。下面是一些触发技专用的：

- ``global`` ：是否是全局技能。全局技能必定会参与到遍历中。
- ``events`` ：一个数组，保存着可能可以触发这个技能的所有时机。
- ``can_trigger`` ：触发该技能的条件。
- ``on_trigger`` ：技能触发的内容。这个函数一般是自定义如何去询问发动、发动几次的。总之自定义的话，记得在里面调用doCost进行实际的询问和生效就行了。
- ``on_cost`` ：技能生效前要对玩家进行询问的内容，或者说是“消耗”。
- ``on_use`` ：技能生效环节。

.. danger::

  除非万不得已，不要把技能的global设为true！global技能在任何情况下都会被纳入游戏的处理范围，随着global的增多，遍历的技能也会变多，这会使游戏的性能下降！

有些时候我们不希望增加技能发动的次数，只想执行一些代码而已，比如说清理掉某些不可见标记等等。为了实现这个效果，触发技中还有一种称为“refresh”的行为（相对于发动技能的“use”），创建触发技的时候可以用这些来指定：

- ``refresh_events`` ：可能触发refresh的所有时机。
- ``can_refresh`` ：类似 ``can_trigger`` ，只不过是针对refresh的。注意这个函数没有默认值。
- ``on_refresh`` ：类似 ``on_trigger`` ，但是是针对refresh。

refresh和实际发动技能也差不多，一样的遍历，判断can_refresh，执行on_refresh。在实际trigger中，是 **先执行refresh，再执行use** 。

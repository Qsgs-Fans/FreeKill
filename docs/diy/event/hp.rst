.. SPDX-License-Identifier: GFDL-1.3-or-later

与体力值相关的事件
==================

以下列出了一些和体力值改变有关的事件。

改变体力
--------

涉及的类如下：

.. lua:autoclass:: HpChangedData

事件流程如下：

.. code:: lua

   local data = HpChangedData
   local player = xxx -- 体力变动的那位角色

   -- 先触发“体力变化前”时机 ** 可中断 **
   logic:trigger(fk.BeforeHpChanged, player, data)

   -- 然后对player的hp作出修改

   -- 最后触发“体力变化后”时机
   logic:trigger(fk.HpChanged, player, data)

   -- 如果体力变化之后，玩家的hp < 1
   -- 并且这次体力变化的变化量是负数，那么进入濒死阶段

伤害
----

涉及的类如下：

.. lua:autoclass:: DamageStruct

在整个伤害事件中，触发时机时候传递的data都是DamageStruct类型。

事件的流程如下：

.. code:: lua

   local data = DamageStruct
   -- 下面的data.from是伤害来源，data.to是伤害目标

   -- 在处理过程中，如果伤害目标死了，事件就结束。

   -- 触发时机“伤害结算开始前” ** 可中断 **
   logic:trigger(fk.PreDamage, data.from, data)

   -- 触发时机“造成伤害时” ** 可中断 **
   logic:trigger(fk.DamageCaused, data.from, data)

   -- 触发时机“受到伤害时” ** 可中断 **
   logic:trigger(fk.DamageInflicted, data.to, data)

   -- 进行一个“改变体力”事件，以修改伤害目标的体力

   -- 触发时机“造成伤害后”
   logic:trigger(fk.Damage, data.from, data)

   -- 触发时机“受到伤害后”
   logic:trigger(fk.Damaged, data.to, data)

   -- 触发时机“伤害结算完成后”
   logic:trigger(fk.DamageFinished, data.from, data)


失去体力
--------

涉及的类如下：

.. lua:autoclass:: HpLostData

流程如下：

.. code:: lua

   local data = HpLostData
   local player = xxx -- 失去体力的那位角色

   -- 触发时机“失去体力前” ** 可中断 **
   logic:trigger(fk.PreHpLost, player, data)

   -- 进行一次“改变体力”事件，以更新受害者的hp

   -- 触发时机“失去体力后”
   logic:trigger(fk.HpLost, player, data)

回复体力
--------

涉及的类如下：

.. lua:autoclass:: RecoverStruct

流程如下：

.. code:: lua

   local data = HpLostData
   local player = xxx -- 失去体力的那位角色

   -- 触发时机“回复体力前” ** 可中断 **
   logic:trigger(fk.PreHpRecover, player, data)

   -- 进行一次“改变体力”事件，以更新回复者的hp

   -- 触发时机“回复体力后”
   logic:trigger(fk.HpRecover, player, data)

改变体力上限
-------------

TODO

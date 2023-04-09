.. SPDX-License-Identifier: GFDL-1.3-or-later

fk技能类型总览
==============

fk的目的是便于三国杀的DIY，而三国杀DIY的核心就是制作各种技能了。

fk的技能分为两大类，这两大类又各自细分为更小的分类：

（关于这部分的源码详见lua/core/skill.lua和lua/core/skill_type下的所有文件）

-  可使用类技能（UsableSkill）

   -  触发技（TriggerSkill）：在满足一定条件时，能够通过被动触发发挥效果的技能
   -  主动技（ActiveSkill）：玩家主动发动的技能
   -  视为技（ViewAsSkill）：将一张牌当做另一张牌的技能

-  状态技（StatusSkill）

   -  距离技（DistanceSkill）：影响距离计算的技能
   -  攻击范围技（DistanceSkill）：影响攻击范围计算的技能
   -  手牌上限技（MaxCardsSkill）：影响手牌上限计算的技能
   -  禁止技（ProhibitSkill）：禁止成为卡牌目标的技能
   -  卡牌增强技（TargetModSkill）：影响卡牌使用次数上限、目标上限、距离限制等等的技能
   -  锁定视为技（FilterSkill）：让一张牌强制视为另一张牌的技能

其中，触发技的逻辑最为复杂，但是\ :doc:`已经在这里分析过了 <../dev/gamelogic>`\ ，故不再赘述。

主动技和状态技应该不算难，先按下不表。视为技与神杀有所区别，区别如下：

在神杀中，视为技是否可响应是专门写在enabled_at_response的，fk则不然，看倾国的代码：

.. code:: lua

   local qingguo = fk.CreateViewAsSkill{
     name = "qingguo",
     anim_type = "defensive",
     pattern = "jink",
     card_filter = function(self, to_select, selected)
       -- ...
     end,
     view_as = function(self, cards)
       -- ...
     end,
   }

可见并没有编写跟响应时候有关的函数，也没有声明出牌阶段不可用。其中的奥妙就在于pattern中，视为技可以转化的卡牌都应该写在pattern里面，Fk会根据pattern的内容判断技能出牌阶段是否可用、是否能够响应等。

.. SPDX-License-Identifier: GFDL-1.3-or-later

与游戏流程有关的事件
====================

先来看游戏流程本身。以下节选自lua/server/gamelogic.lua

.. code:: lua

   function GameLogic:action()
     self:trigger(fk.GameStart)
     local room = self.room

     for _, p in ipairs(room.alive_players) do
       self:trigger(fk.DrawInitialCards, p, { num = 4 })
     end

     local function checkNoHuman()
       -- 如果房里已经没有人类玩家了就结束游戏
     end

     while true do
       self:trigger(fk.TurnStart, room.current)
       if room.game_finished then break end
       room.current = room.current:getNextAlive()
       if checkNoHuman() then
         room:gameOver("")
       end
     end
   end

以上这段代码，述说的就是整个游戏流程的核心。首先开始游戏、摸初始手牌，然后按照座位顺序每人依次执行回合直到游戏结束。

--------------

TODO

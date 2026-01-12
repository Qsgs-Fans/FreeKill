local active = require 'lunarltk.server.ai.strategies.active'
local card_skill = require 'lunarltk.server.ai.strategies.card_skill'
local discard = require 'lunarltk.server.ai.strategies.discard'
local choose_player = require 'lunarltk.server.ai.strategies.choose_player'
local cards = require 'lunarltk.server.ai.strategies.cards'
local view_cards = require 'lunarltk.server.ai.strategies.view_cards'
local view_cards_and_choice = require 'lunarltk.server.ai.strategies.view_cards_and_choice'
local choose_cards_and_choice = require 'lunarltk.server.ai.strategies.choose_cards_and_choice'
local choose_cards_and_players = require 'lunarltk.server.ai.strategies.choose_cards_and_players'
local yiji = require 'lunarltk.server.ai.strategies.yiji'
local choose_general = require 'lunarltk.server.ai.strategies.choose_general'
local choose_kingdom = require 'lunarltk.server.ai.strategies.choose_kingdom'
local choose_card = require 'lunarltk.server.ai.strategies.choose_card'
local poxi = require 'lunarltk.server.ai.strategies.poxi'
local choose_cards = require 'lunarltk.server.ai.strategies.choose_cards'
local choice = require 'lunarltk.server.ai.strategies.choice'
local choices = require 'lunarltk.server.ai.strategies.choices'
local joint_choice = require 'lunarltk.server.ai.strategies.joint_choice'
local joint_cards = require 'lunarltk.server.ai.strategies.joint_cards'
local invoke = require 'lunarltk.server.ai.strategies.invoke'
local arrange_cards = require 'lunarltk.server.ai.strategies.arrange_cards'
local guanxing = require 'lunarltk.server.ai.strategies.guanxing'
local exchange = require 'lunarltk.server.ai.strategies.exchange'
local number = require 'lunarltk.server.ai.strategies.number'
local ag = require 'lunarltk.server.ai.strategies.ag'

---@class AIReuseSpec
---@field public _reuse boolean
---@field public _reuse_key string
---@field public _reuse_type AIStrategy?

--- 复用来自其他技能的策略，或策略的单个字段（可以是函数或固定值）
---
--- 若为复用策略，则还需要在参数2指定策略类型，复用函数时无需指定。
---
--- 复用策略只在使用到的时候会进行复用解析，若解析失败则相当于nil，解析成功会替换掉值避免重复解析。
--- 同时支持链式复用。不过如果出现循环式复用的话整个循环依赖会全部变成nil。
---
--- 例1：
---   skill:addAI(Fk.Ltk.AI.reuse('zhiheng', Fk.Ltk.AI.ActiveStrategy))
--- 例2：
---   skill:addAI(Fk.Ltk.AI.newActiveStrategy {
---     -- ...
---     choose_players = Fk.Ltk.AI.reuse 'tuxi',
---   })
---@param name string 要复用的技能名或预定策略名
---@param tp AIStrategy? 若直接复用整个策略，需指定类型
---@return any
local reuse = function(name, tp)
  return {
    _reuse = true,
    _reuse_key = name,
    _reuse_type = tp,
  }
end

return {
  ActiveStrategy = active[1],
  newActiveStrategy = active[2],

  CardSkillStrategy = card_skill[1],
  newCardSkillStrategy = card_skill[2],

  --- AskTo

  DiscardStrategy = discard[1],
  newDiscardStrategy = discard[2],

  ChoosePlayersStrategy = choose_player[1],
  newChoosePlayersStrategy = choose_player[2],

  CardsStrategy = cards[1],
  newCardsStrategy = cards[2],

  ViewCardsStrategy = view_cards[1], -- 这个指令只能点确定……
  newViewCardsStrategy = view_cards[2],

  ViewCardsAndChoiceStrategy = view_cards_and_choice[1],
  newViewCardsAndChoiceStrategy = view_cards_and_choice[2],

  ChooseCardsAndChoiceStrategy = choose_cards_and_choice[1],
  newChooseCardsAndChoiceStrategy = choose_cards_and_choice[2],

  ChooseCardsAndPlayersStrategy = choose_cards_and_players[1],
  newChooseCardsAndPlayersStrategy = choose_cards_and_players[2],

  YijiStrategy = yiji[1],
  newYijiStrategy = yiji[2],

  ChooseGeneralStrategy = choose_general[1],
  newChooseGeneralStrategy = choose_general[2],

  ChooseKingdomStrategy = choose_kingdom[1],
  newChooseKingdomStrategy = choose_kingdom[2],

  ChooseCardStrategy = choose_card[1],
  newChooseCardStrategy = choose_card[2],

  PoxiStrategy = poxi[1],
  newPoxiStrategy = poxi[2],

  ChooseCardsStrategy = choose_cards[1],
  newChooseCardsStrategy = choose_cards[2],

  ChoiceStrategy = choice[1],
  newChoiceStrategy = choice[2],

  ChoicesStrategy = choices[1],
  newChoicesStrategy = choices[2],

  JointChoiceStrategy = joint_choice[1],
  newJointChoiceStrategy = joint_choice[2],

  JointCardsStrategy = joint_cards[1],
  newJointCardsStrategy = joint_cards[2],

  InvokeStrategy = invoke[1],
  newInvokeStrategy = invoke[2],

  ArrangeCardsStrategy = arrange_cards[1],
  newArrangeCardsStrategy = arrange_cards[2],

  GuanxingStrategy = guanxing[1],
  newGuanxingStrategy = guanxing[2],

  ExchangeStrategy = exchange[1],
  newExchangeStrategy = exchange[2],

  NumberStrategy = number[1],
  newNumberStrategy = number[2],

  AGStrategy = ag[1],
  newAGStrategy = ag[2],

  reuse = reuse,
}

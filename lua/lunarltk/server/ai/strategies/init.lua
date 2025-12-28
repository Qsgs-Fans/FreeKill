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
local use_real_card = require 'lunarltk.server.ai.strategies.use_real_card'
local use_virtual_card = require 'lunarltk.server.ai.strategies.use_virtual_card'
local play_card = require 'lunarltk.server.ai.strategies.play_card'
local number = require 'lunarltk.server.ai.strategies.number'
local use_card = require 'lunarltk.server.ai.strategies.use_card'
local response = require 'lunarltk.server.ai.strategies.response'
local nullification = require 'lunarltk.server.ai.strategies.nullification'
local ag = require 'lunarltk.server.ai.strategies.ag'
local mini_game = require 'lunarltk.server.ai.strategies.mini_game'
local custom_dialog = require 'lunarltk.server.ai.strategies.custom_dialog'
local move_card_in_board = require 'lunarltk.server.ai.strategies.move_card_in_board'
local choose_to_move_card_in_board = require 'lunarltk.server.ai.strategies.choose_to_move_card_in_board'

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

  -- UseRealCardStrategy = use_real_card[1],
  -- newUseRealCardStrategy = use_real_card[2],

  -- UseVirtualCardStrategy = use_virtual_card[1],
  -- newUseVirtualCardStrategy = use_virtual_card[2],

  -- PlayCardStrategy = play_card[1],
  -- newPlayCardStrategy = play_card[2],

  NumberStrategy = number[1],
  newNumberStrategy = number[2],

  -- UseCardStrategy = use_card[1],
  -- newUseCardStrategy = use_card[2],

  -- ResponseStrategy = response[1],
  -- newResponseStrategy = response[2],

  -- NullificationStrategy = nullification[1],
  -- newNullificationStrategy = nullification[2],

  AGStrategy = ag[1],
  newAGStrategy = ag[2],

  -- MiniGameStrategy = mini_game[1],
  -- newMiniGameStrategy = mini_game[2],

  -- CustomDialogStrategy = custom_dialog[1],
  -- newCustomDialogStrategy = custom_dialog[2],

  -- MoveCardInBoardStrategy = move_card_in_board[1],
  -- newMoveCardInBoardStrategy = move_card_in_board[2],

  -- ChooseToMoveCardInBoardStrategy = choose_to_move_card_in_board[1],
  -- newChooseToMoveCardInBoardStrategy = choose_to_move_card_in_board[2],
}

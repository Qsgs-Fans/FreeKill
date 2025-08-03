local prefix = "packages.standard.aux_skills_dir."
if UsingNewCore then
  prefix = "packages.freekill-core.standard.aux_skills_dir."
end

return {
  require(prefix .. "discard_skill"),
  require(prefix .. "choose_cards_skill"),
  require(prefix .. "choose_players_skill"),
  require(prefix .. "ex__choose_skill"),
  require(prefix .. "userealcard_skill"),
  require(prefix .. "virtual_viewas"),
  require(prefix .. "spin_skill"),
  require(prefix .. "max_cards_skill"),
  require(prefix .. "distribution_select_skill"),
  require(prefix .. "choose_players_to_move_card_in_board"),
  require(prefix .. "uncompulsory_invalidity"),
  require(prefix .. "reveal_prohibited"),
  require(prefix .. "reveal_skill"),

  require(prefix .. "game_rule"),
  fk.CreateSkill{ name = "fastchat_m" },
  fk.CreateSkill{ name = "fastchat_f" },
}


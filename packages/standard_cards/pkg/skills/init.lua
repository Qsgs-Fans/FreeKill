local prefix = "packages.standard_cards.pkg.skills."
if UsingNewCore then
  prefix = "packages.freekill-core.standard_cards.pkg.skills."
end

return {
  require(prefix .. "slash"),
  require(prefix .. "jink"),
  require(prefix .. "peach"),
  require(prefix .. "dismantlement"),
  require(prefix .. "snatch"),
  require(prefix .. "duel"),
  require(prefix .. "collateral"),
  require(prefix .. "ex_nihilo"),
  require(prefix .. "nullification"),
  require(prefix .. "savage_assault"),
  require(prefix .. "archery_attack"),
  require(prefix .. "god_salvation"),
  require(prefix .. "amazing_grace"),
  require(prefix .. "lightning"),
  require(prefix .. "indulgence"),
  require(prefix .. "crossbow"),
  require(prefix .. "qinggang_sword"),
  require(prefix .. "ice_sword"),
  require(prefix .. "double_swords"),
  require(prefix .. "blade"),
  require(prefix .. "spear"),
  require(prefix .. "axe"),
  require(prefix .. "halberd"),
  require(prefix .. "kylin_bow"),
  require(prefix .. "eight_diagram"),
  require(prefix .. "nioh_shield"),
  require(prefix .. "dilu"),
  require(prefix .. "jueying"),
  require(prefix .. "zhuahuangfeidian"),
  require(prefix .. "chitu"),
  require(prefix .. "dayuan"),
  require(prefix .. "zixing"),

  require(prefix .. "default_card_skill"),
  require(prefix .. "default_equip_skill"),
  require(prefix .. "armor_invalidity"),
}

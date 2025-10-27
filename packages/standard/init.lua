-- SPDX-License-Identifier: GPL-3.0-or-later

local prefix = "packages."
if UsingNewCore then prefix = "packages.freekill-core." end

require(prefix .. "standard.aux_poxi")
require(prefix .. "standard.aux_choose_general")

Fk:appendKingdomMap("god", {"wei", "shu", "wu", "qun"})

require(prefix .. "standard.i18n")

local extension = require(prefix .. "standard.pkg") ---@type Package
-- 覆盖安装的话会有个aux_skills.lua被优先加载，修复这个sb bug
extension:loadSkillSkels(require(prefix .. "standard.aux_skills_dir"))

-- 武将一览和卡牌一览解耦？
-- 注：这里name是因为已经有对应翻译了。实际并不建议把页面name写成这样
-- 注：注册新页面的写法有待商讨。
extension.customPages = {
  {
    name = "Generals Overview",
    iconUrl = "http://175.178.66.93/symbolic/lunarltk/jiang.png",
    qml = {
      uri = "Fk.Pages.Common",
      name = "GeneralsOverview",
    }
  },
  {
    name = "Cards Overview",
    iconUrl = "http://175.178.66.93/symbolic/lunarltk/cards.svg",
    qml = {
      uri = "Fk.Pages.Common",
      name = "CardsOverview",
    }
  },
  {
    name = "Ban List",
    iconUrl = "http://175.178.66.93/symbolic/mimetypes/x-office-document-symbolic.svg",
    popup = true,
    qml = {
      uri = "Fk.Pages.Common",
      name = "GeneralPoolOverview",
    }
  }
}

return extension

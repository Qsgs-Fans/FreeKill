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
return extension

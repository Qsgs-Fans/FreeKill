-- SPDX-License-Identifier: GPL-3.0-or-later

local prefix = "packages."
if UsingNewCore then prefix = "packages.freekill-core." end

require(prefix .. "standard.aux_poxi")

Fk:appendKingdomMap("god", {"wei", "shu", "wu", "qun"})

require(prefix .. "standard.i18n")

local extension = require(prefix .. "standard.pkg") ---@type Package
extension:loadSkillSkels(require(prefix .. "standard.aux_skills"))
return extension

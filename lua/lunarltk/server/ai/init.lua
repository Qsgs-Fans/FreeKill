-- SPDX-License-Identifier: GPL-3.0-or-later

AI = require "lunarltk.server.ai.ai"
TrustAI = require "lunarltk.server.ai.trust_ai"
-- RandomAI = require "lunarltk.server.ai.random_ai"

SmartAI = require "lunarltk.server.ai.smart_ai"

for _, pname in ipairs(Fk.package_names) do
  local pack = Fk.packages[pname]
  for _, skel in ipairs(pack.skill_skels) do
    for _, sa in ipairs(skel.ai_list) do
      local key, ai_spec, inherit, setTriggerSkillAI = table.unpack(sa)
      if setTriggerSkillAI then
        SmartAI:setTriggerSkillAI(key, ai_spec)
      else -- 有 inherit 的稍后加载？
        SmartAI:setSkillAI(key, ai_spec, inherit)
      end
    end
  end
end

-- load ai module from packages (legacy)
local directories = {}
if UsingNewCore then
  require "standard_cards.ai"
  require "standard.ai"
  require "maneuvering.ai"
  FileIO.cd("../..")
  directories = FileIO.ls("packages")
else
  directories = FileIO.ls("packages")
  require "packages.standard_cards.ai"
  require "packages.standard.ai"
  require "packages.maneuvering.ai"
end
table.removeOne(directories, "standard")
table.removeOne(directories, "standard_cards")
table.removeOne(directories, "maneuvering")

local _disable_packs = json.decode(fk.GetDisabledPacks())

for _, dir in ipairs(directories) do
  if (not string.find(dir, ".disabled")) and not table.contains(_disable_packs, dir)
    and FileIO.isDir("packages/" .. dir)
    and FileIO.exists("packages/" .. dir .. "/ai/init.lua") then

    require(string.format("packages.%s.ai", dir))

  end
end

if UsingNewCore then
  FileIO.cd("packages/freekill-core")
end

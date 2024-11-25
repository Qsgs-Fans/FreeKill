-- SPDX-License-Identifier: GPL-3.0-or-later

AI = require "server.ai.ai"
TrustAI = require "server.ai.trust_ai"
-- RandomAI = require "server.ai.random_ai"

SmartAI = require "server.ai.smart_ai"

-- load ai module from packages
local directories
if UsingNewCore then
  directories = FileIO.ls("..")
  require "standard_cards.ai"
  require "standard.ai"
  require "maneuvering.ai"
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

-- SPDX-License-Identifier: GPL-3.0-or-later

AI = require "server.ai.ai"
TrustAI = require "server.ai.trust_ai"
RandomAI = require "server.ai.random_ai"
SmartAI = require "server.ai.smart_ai"

-- load ai module from packages
local directories = FileIO.ls("packages")
dofile "packages.standard"
dofile "packages.standard_cards"
dofile "packages.maneuvering"
table.removeOne(directories, "standard")
table.removeOne(directories, "standard_cards")
table.removeOne(directories, "maneuvering")

local _disable_packs = json.decode(fk.GetDisabledPacks())

for _, dir in ipairs(directories) do
  if (not string.find(dir, ".disabled")) and not table.contains(_disable_packs, dir)
    and FileIO.isDir("packages/" .. dir)
    and FileIO.exists("packages/" .. dir .. "/ai/init.lua") then

    dofile(string.format("packages.%s.ai", dir))

  end
end

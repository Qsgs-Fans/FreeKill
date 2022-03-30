local extension = Package:new("standard_cards", Package.CardPack)
extension.metadata = require "packages.standard_cards.metadata"

local slash = BasicCard:new("slash")

return extension

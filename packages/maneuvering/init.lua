local prefix = "packages."
if UsingNewCore then prefix = "packages.freekill-core." end

local extension = require(prefix .. "maneuvering.pkg")
return extension

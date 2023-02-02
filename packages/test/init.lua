local fkp_extensions = require "packages.test.test"
local extension = fkp_extensions[1]

test2 = General(extension, "test2", "wu", 4)

Fk:loadTranslationTable{
  ["test2"] = "谋徐盛",
}

return fkp_extensions

local fkp_extensions = require "packages.test.test"
local extension = fkp_extensions[1]

test2 = General(extension, "mouxusheng", "wu", 4)

Fk:loadTranslationTable{
  ["test"] = "测试",
  ["mouxusheng"] = "谋徐盛",
}

return fkp_extensions

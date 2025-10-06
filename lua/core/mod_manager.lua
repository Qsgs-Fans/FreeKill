--- 这位只能作为mixin注入到Fk中，也不会有别的子类了
---
--- 它作为整个游戏比较核心的一部分，而并非仅仅是三国杀的engine
---@class Base.ModManager : Object
---@field public extensions table<string, string[]> @ 所有mod列表及其包含的拓展包
---@field public extension_names string[] @ Mod名字的数组，为了方便排序
---@field public translations table<string, table<string, string>> @ 翻译表
---@field public boardgames { [string] : BoardGame } @ name -> game
local ModManager = {}

local BoardGame = require "core.boardgame"

function ModManager:initModManager()
  self.extensions = {
    ["standard"] = { "standard" },
    ["standard_cards"] = { "standard_cards" },
    ["maneuvering"] = { "maneuvering" },
    ["test"] = { "test_p_0" },
  }
  self.extension_names = { "standard", "standard_cards", "maneuvering", "test" }

  self.translations = {}  -- srcText --> translated

  self.boardgames = {}

  self.Base = {
    Player = require "core.player",
    RoomBase = require "core.roombase",
    ClientBase = require "client.clientbase",
    ClientPlayerBase = require "client.clientplayer_base",
    ServerRoomBase = require "server.roombase",
    ServerPlayerBase = require "server.serverplayer_base",
    GameLogic = require "server.gamelogic",
    Engine = require "core.engine",
    AI = require "server.ai",
  }
end

--- 加载所有拓展包。
---
--- Engine会在packages/下搜索所有含有init.lua的文件夹，并把它们作为拓展包加载进来。
---
--- 这样的init.lua可以返回单个拓展包，也可以返回拓展包数组，或者什么都不返回。
---
--- 标包和标准卡牌包比较特殊，它们永远会在第一个加载。
---@param self Engine FIXME
---@return nil
function ModManager:loadPackages()
  if FileIO.pwd():endsWith("packages/freekill-core") then
    UsingNewCore = true
    FileIO.cd("../..")
  end
  local directories = FileIO.ls("packages")

  -- load standard & standard_cards first
  if UsingNewCore then
    require("packages.freekill-core.standard"):install(self)
    require("packages.freekill-core.standard_cards"):install(self)
    require("packages.freekill-core.maneuvering"):install(self)
    require("packages.freekill-core.test"):install(self)
    table.removeOne(directories, "freekill-core")
  else
    require("packages.standard"):install(self)
    require("packages.standard_cards"):install(self)
    require("packages.maneuvering"):install(self)
    require("packages.test"):install(self)
  end
  table.removeOne(directories, "standard")
  table.removeOne(directories, "standard_cards")
  table.removeOne(directories, "maneuvering")
  table.removeOne(directories, "test")

  ---@type string[]
  local _disable_packs = json.decode(fk.GetDisabledPacks())

  for _, dir in ipairs(directories) do
    if (not string.find(dir, ".disabled")) and not table.contains(_disable_packs, dir)
      and FileIO.isDir("packages/" .. dir)
      and FileIO.exists("packages/" .. dir .. "/init.lua") then
      local pack = Pcall(require, string.format("packages.%s", dir))
      -- Note that instance of Package is a table too
      -- so dont use type(pack) == "table" here
      if type(pack) == "table" then
        table.insert(self.extension_names, dir)
        if pack[1] ~= nil then
          self.extensions[dir] = {}
          for _, p in ipairs(pack) do
            table.insert(self.extensions[dir], p.name)
            p:install(self)
          end
        else
          self.extensions[dir] = { pack.name }
          pack:install(self)
        end
      end
    end
  end

  if UsingNewCore then
    FileIO.cd("packages/freekill-core")
  end
end

--- 向翻译表中加载新的翻译表。
---@param t table @ 要加载的翻译表，这是一个 原文 --> 译文 的键值对表
---@param lang? string @ 目标语言，默认为zh_CN
function ModManager:loadTranslationTable(t, lang)
  assert(type(t) == "table")
  lang = lang or "zh_CN"
  self.translations[lang] = self.translations[lang] or {}
  for k, v in pairs(t) do
    self.translations[lang][k] = v
  end
end

--- 翻译一段文本。其实就是从翻译表中去找
---@param src string @ 要翻译的文本
---@param lang? string @ 要使用的语言，默认读取config
function ModManager:translate(src, lang)
  lang = lang or (Config.language or "zh_CN")
  if not self.translations[lang] then lang = "zh_CN" end
  local ret = self.translations[lang][src]
  return ret or src
end

---@param game BoardGameSpec
function ModManager:addBoardGame(game)
  self.boardgames[game.name] = BoardGame:new(game)
end

---@param name string 游戏模式名 并非桌游类型
---@return BoardGame
function ModManager:getBoardGame(name)
  local gameMode = Fk.game_modes[name or ""]
  local gameName = gameMode and gameMode.game_name
  local ret = self.boardgames[gameName or "lunarltk"]
  if ret then return ret end
  return BoardGame {
    name = "lunarltk",
    room_klass = Room,
    client_klass = Client,
    engine = Fk,
    page = {
      uri = "Fk.Pages.LunarLTK",
      name = "Room",
    }
  }
end

--- 获知当前的Engine是跑在服务端还是客户端，并返回相应的实例。
---@return AbstractRoom
function ModManager:currentRoom()
  if RoomInstance then
    return RoomInstance
  end
  return ClientInstance
end

return ModManager

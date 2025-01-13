---@class TriggerEvent
---@field public id integer
---@field public room Room
---@field public target ServerPlayer?
---@field public data any 具体的触发时机会继承这个类 进而获得具体的data类型
local TriggerEvent = class("TriggerEvent")

return TriggerEvent
